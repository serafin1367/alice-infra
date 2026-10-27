#!/usr/bin/env bash

# Updates every Alice repository and recreates the production Compose stack.
# The script deliberately does not use `down -v`: PostgreSQL and other named
# volumes are retained.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-production}"
BRANCH="${DEPLOY_BRANCH:-main}"
source "$SCRIPT_DIR/repository-functions.sh"

declare -A REPOSITORY_URLS=(
  [infra]="http://gitlab.mbb.net.pl/alice/infra.git"
  [llm]="http://gitlab.mbb.net.pl/alice/microservices/llm.git"
  [mail]="http://gitlab.mbb.net.pl/alice/microservices/mail.git"
  [time_coordinator]="http://gitlab.mbb.net.pl/alice/microservices/time_coordinator.git"
  [weather]="http://gitlab.mbb.net.pl/alice/microservices/weather.git"
  [work]="http://gitlab.mbb.net.pl/alice/microservices/work.git"
  [shopping]="http://gitlab.mbb.net.pl/alice/microservices/shop.git"
  [knowledge]="http://gitlab.mbb.net.pl/alice/microservices/knowledge.git"  
  [dashboard]="http://gitlab.mbb.net.pl/alice/microservices/dashboard.git"
  [health]="http://gitlab.mbb.net.pl/alice/microservices/health.git"
  [budget]="http://gitlab.mbb.net.pl/alice/microservices/budget.git"
  [smarthome]="http://gitlab.mbb.net.pl/alice/microservices/smarthome.git"
  [alice-web]="http://gitlab.mbb.net.pl/alice/alice-web.git"
)

REPOSITORIES=(
  "$WORKSPACE_DIR/infra"
  "$WORKSPACE_DIR/microservices/llm"
  "$WORKSPACE_DIR/microservices/mail"
  "$WORKSPACE_DIR/microservices/time_coordinator"
  "$WORKSPACE_DIR/microservices/weather"
  "$WORKSPACE_DIR/microservices/work"
  "$WORKSPACE_DIR/microservices/shopping"
  "$WORKSPACE_DIR/microservices/knowledge"
  "$WORKSPACE_DIR/microservices/dashboard"
  "$WORKSPACE_DIR/microservices/health"
  "$WORKSPACE_DIR/microservices/budget"
  "$WORKSPACE_DIR/microservices/smarthome"
  "$WORKSPACE_DIR/alice-web"
)

OPTIONAL_REPOSITORIES=(
  "$WORKSPACE_DIR/desktop"
)

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Brakuje wymaganego polecenia: $1" >&2
    exit 1
  }
}

update_repository() {
  local repository="$1"
  local name
  name="$(basename "$repository")"

  ensure_repository "$repository" "${REPOSITORY_URLS[$name]:-}" "$BRANCH"

  if [[ -n "$(git -C "$repository" status --porcelain --untracked-files=no)" ]]; then
    echo "Repozytorium $name ma zmienione pliki sledzone przez Git. Przerywam wdrozenie." >&2
    exit 1
  fi

  echo "Aktualizacja: $name ($BRANCH)"
  if [[ "$(git -C "$repository" branch --show-current)" != "$BRANCH" ]]; then
    echo "Repozytorium $name nie jest na galezi $BRANCH. Przerywam." >&2
    exit 1
  fi
  git -C "$repository" fetch origin "$BRANCH"
  git -C "$repository" merge --ff-only "origin/$BRANCH"
}

require_command git
require_command docker

[[ -f "$SCRIPT_DIR/.env" ]] || {
  echo "Brak pliku produkcyjnego: $SCRIPT_DIR/.env" >&2
  exit 1
}

# Starsze pliki .env nie zawieraja tokenu dodanego wraz z integracja Health-LLM.
# Wygeneruj go raz; obie uslugi otrzymaja te sama wartosc.
if ! grep -Eq '^HEALTH_INTERNAL_TOKEN=.+$' "$SCRIPT_DIR/.env"; then
  health_internal_token="$(od -An -N32 -tx1 /dev/urandom | tr -d '[:space:]')"
  printf '\nHEALTH_INTERNAL_TOKEN=%s\n' "$health_internal_token" >> "$SCRIPT_DIR/.env"
  chmod 600 "$SCRIPT_DIR/.env"
  echo "Wygenerowano brakujacy HEALTH_INTERNAL_TOKEN w produkcyjnym .env"
fi
for repository in "${REPOSITORIES[@]}"; do
  update_repository "$repository"
done

for repository in "${OPTIONAL_REPOSITORIES[@]}"; do
  if [[ -e "$repository/.git" ]]; then
    update_repository "$repository"
  else
    echo "Pominieto opcjonalne repozytorium: $repository"
  fi
done

echo "Walidacja konfiguracji Docker Compose"
docker compose --project-name "$COMPOSE_PROJECT_NAME" --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" config -q

echo "Budowanie obrazow przed zmiana dzialajacych uslug"
docker compose --project-name "$COMPOSE_PROJECT_NAME" --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" build

echo "Uruchomienie infrastruktury i uzupelnienie brakujacych baz"
docker compose --project-name "$COMPOSE_PROJECT_NAME" --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" up -d --wait postgres rabbitmq
docker compose --project-name "$COMPOSE_PROJECT_NAME" --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" exec -T postgres bash /docker-entrypoint-initdb.d/05-init-shopping-database.sh
docker compose --project-name "$COMPOSE_PROJECT_NAME" --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" exec -T postgres bash /docker-entrypoint-initdb.d/06-init-knowledge-database.sh
docker compose --project-name "$COMPOSE_PROJECT_NAME" --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" exec -T postgres bash /docker-entrypoint-initdb.d/07-init-health-database.sh
docker compose --project-name "$COMPOSE_PROJECT_NAME" --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" exec -T postgres bash /docker-entrypoint-initdb.d/08-init-budget-database.sh

echo "Aktualizacja uslug bez usuwania wolumenow"
docker compose --project-name "$COMPOSE_PROJECT_NAME" --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" up -d --no-build

echo "Aktualny stan kontenerow"
docker compose --project-name "$COMPOSE_PROJECT_NAME" --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" ps
