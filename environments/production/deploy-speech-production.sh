#!/usr/bin/env bash
# Targeted, reversible-by-image rollout for Alice Speech and Alice Web.
# Does not deploy/stop/rebuild Postgres, RabbitMQ, NEWS or other microservices.
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
WORKSPACE_DIR="$(cd -- "$SCRIPT_DIR/../../.." && pwd -P)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"
PROJECT="${COMPOSE_PROJECT_NAME:-production}"
BRANCH="${DEPLOY_BRANCH:-main}"
BACKUP_DIR="${ALICE_SPEECH_BACKUP_DIR:-/var/backups/alice/speech}"
MODE=check
SPEECH_REPO="$WORKSPACE_DIR/microservices/speech"
WEB_REPO="$WORKSPACE_DIR/alice-web"
SPEECH_URL="${ALICE_SPEECH_GIT_URL:-http://gitlab.mbb.net.pl/alice/microservices/speech.git}"
WEB_URL="${ALICE_WEB_GIT_URL:-http://gitlab.mbb.net.pl/alice/alice-web.git}"

usage() {
  cat <<'HELP'
Usage: ./deploy-speech-production.sh [--check | --deploy]

 --check    Default: validate prerequisites/configuration without any deployment.
 --deploy   Pull only Speech and Web, back up an existing speech_data volume,
            build both images, recreate and check health of just these services.

Requirements: production .env with a 32+ char SPEECH_API_TOKEN, running RabbitMQ,
              Git access and Docker Compose V2. Use a maintenance window.
Environment: COMPOSE_PROJECT_NAME, DEPLOY_BRANCH, ALICE_SPEECH_BACKUP_DIR,
             ALICE_SPEECH_GIT_URL, ALICE_WEB_GIT_URL.
Never use docker compose down -v. The retention service deletes old MP3 on startup.
HELP
}

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
compose() {
  docker compose --project-name "$PROJECT" --profile speech \
    --project-directory "$SCRIPT_DIR" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

if (( $# > 1 )); then usage >&2; exit 2; fi
case "${1:---check}" in
  --check) MODE=check ;;
  --deploy) MODE=deploy ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

for command in docker git grep sed mktemp tar; do
  command -v "$command" >/dev/null 2>&1 || fail "Brak narzędzia: $command"
done
[[ -f "$ENV_FILE" ]] || fail "Brak prywatnego pliku $ENV_FILE"
[[ -f "$COMPOSE_FILE" ]] || fail "Brak pliku Compose"
[[ "$PROJECT" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || fail "Nieprawidłowa nazwa projektu Compose"
[[ "$BRANCH" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || fail "Nieprawidłowa nazwa gałęzi"
[[ "$BRANCH" != *..* ]] || fail "Nieprawidłowa nazwa gałęzi"
if ! grep -Eq '^SPEECH_API_TOKEN=[^[:space:]]{32,}$' "$ENV_FILE"; then
  fail "Ustaw SPEECH_API_TOKEN (co najmniej 32 znaki) w produkcyjnym .env; nie drukuj sekretu"
fi
if ! grep -Eq '^COMPOSE_PROFILES=([^#]*,)?speech(,|[[:space:]]|$)' "$ENV_FILE"; then
  log "UWAGA: dodaj COMPOSE_PROFILES=speech do .env, aby inne wdrożenia nie pomijały usługi"
fi

docker info >/dev/null 2>&1 || fail "Docker daemon jest niedostępny"
compose config --quiet || fail "Konfiguracja Docker Compose jest niepoprawna"
# Existing production RabbitMQ must remain untouched during this targeted release.
if ! compose ps --status running --services rabbitmq | grep -qx rabbitmq; then
  fail "Produkcyjny RabbitMQ nie jest uruchomiony; nie restartuję go automatycznie"
fi

check_repo() {
  local dest="$1"
  [[ ! -e "$dest" || -d "$dest/.git" ]] || fail "Katalog nie jest repozytorium Git: $dest"
  if [[ -d "$dest/.git" ]]; then
    [[ -z "$(git -C "$dest" status --porcelain --untracked-files=no)" ]] ||
      fail "Lokalne zmiany w $dest; nie nadpisuję ich"
    [[ "$(git -C "$dest" branch --show-current)" == "$BRANCH" ]] ||
      fail "Repozytorium nie jest na gałęzi $BRANCH: $dest"
  fi
}
check_repo "$SPEECH_REPO"
check_repo "$WEB_REPO"
if [[ "$MODE" == check ]]; then
  log "Preflight OK: profil Speech, sekret, RabbitMQ, Git i Docker Compose"
  log "Sprawdź połączenie workera Windows z produkcyjnym RabbitMQ i ogranicz port 5672 firewallem/VPN"
  exit 0
fi

# A dedicated lock prevents two overlapping targeted releases on this host.
exec 9>"$SCRIPT_DIR/.deploy-speech.lock"
command -v flock >/dev/null 2>&1 || fail "Brakuje flock"
flock -n 9 || fail "Inne wdrożenie Speech jest już wykonywane"

update_repo() {
  local dest="$1" url="$2"
  if [[ ! -d "$dest/.git" ]]; then
    [[ ! -e "$dest" ]] || fail "Nie można sklonować do istniejącego katalogu $dest"
    mkdir -p -- "$(dirname -- "$dest")"
    git clone --branch "$BRANCH" -- "$url" "$dest" || fail "Klonowanie nie powiodło się: $dest"
  else
    git -C "$dest" fetch --no-tags origin "$BRANCH" || fail "Git fetch nie powiódł się: $dest"
    git -C "$dest" merge --ff-only "origin/$BRANCH" || fail "Nie można wykonać fast-forward: $dest"
  fi
}

log "Aktualizuję tylko repozytoria Speech Service i Alice Web"
update_repo "$SPEECH_REPO" "$SPEECH_URL"
update_repo "$WEB_REPO" "$WEB_URL"

[[ -f "$SPEECH_REPO/src/retention.js" ]] || fail "Brak mechanizmu retencji: sprawdź aktualność GitLab Speech"
grep -q 'pruneRetention' "$SPEECH_REPO/src/main.js" ||
  fail "Backend Speech nie ma najnowszego czyszczenia retencji"
grep -q 'speech-history-retention' "$WEB_REPO/public/settings/index.html" ||
  fail "Alice Web nie zawiera nowego panelu historii"

# A backup is mandatory when the volume already exists, because retention
# may irreversibly delete historic recordings during startup.
VOLUME="${PROJECT}_speech_data"
if docker volume inspect "$VOLUME" >/dev/null 2>&1; then
  mkdir -p -m 700 -- "$BACKUP_DIR"
  timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
  archive="speech_data-${PROJECT}-${timestamp}.tar.gz"
  log "Tworzę obowiązkowy backup istniejącego woluminu: $BACKUP_DIR/$archive"
  # Read-only mount of the source; never prune or stop other services.
  docker run --rm --network none --read-only \
    -v "$VOLUME:/source:ro" -v "$BACKUP_DIR:/backup" \
    -e "BACKUP_ARCHIVE=$archive" alpine:3.21 \
    sh -ec 'tar -C /source -czf "/backup/$BACKUP_ARCHIVE" .' ||
    fail "Nie udało się wykonać backupu; przerywam przed odtworzeniem kontenerów"
  [[ -s "$BACKUP_DIR/$archive" ]] || fail "Backup woluminu jest pusty"
  chmod 600 "$BACKUP_DIR/$archive" || fail "Nie udało się zabezpieczyć backupu"
  log "Backup wykonany. Zachowaj archiwum poza serwerem."
else
  log "Wolumin $VOLUME jeszcze nie istnieje; nowe wdrożenie rozpocznie pustą historię"
fi

compose config --quiet || fail "Błąd konfiguracji Compose po aktualizacji"
log "Buduję tylko obrazy Speech Service i Alice Web"
compose build speech-service alice-web || fail "Budowanie obrazu nie powiodło się"
log "Odtwarzam Speech Service (bez restartu RabbitMQ i baz danych)"
compose up -d --no-deps --wait --wait-timeout 120 speech-service ||
  fail "Speech Service nie osiągnął statusu healthy; sprawdź jego logi"
log "Odtwarzam Alice Web"
compose up -d --no-deps --wait --wait-timeout 120 alice-web ||
  fail "Alice Web nie osiągnął statusu healthy; sprawdź jego logi"

log "Weryfikacja historii przez rzeczywistą bramkę Alice Web"
compose exec -T alice-web wget -q -O - \
  'http://127.0.0.1/api/speech/tts/history?limit=1' | grep -q '"retention"' ||
  fail "Alice Web nie zwrócił historii z polityką retencji"
log "Wdrożenie dwóch usług zakończone; sprawdź workery i próbny odczyt NEWS"
compose ps speech-service alice-web
