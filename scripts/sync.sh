#!/usr/bin/env bash
# AliceAI: periodic GitHub -> GitLab fast-forward synchronization (Linux).
# Uses SSH for GitHub and configured GitLab credentials; never force-pushes.
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)"
SYNC_SCRIPT="$SCRIPT_DIR/l-github-gitlab-sync.py"
CONFIG_FILE="$REPO_ROOT/config/github-gitlab-projects.json"

INTERVAL_SECONDS="${ALICE_SYNC_INTERVAL_SECONDS:-100}"
WORKERS="${ALICE_SYNC_WORKERS:-8}"
ONCE=0
DRY_RUN=0
NO_COLLECT_CI=0
ONLY_REPOS=()

usage() {
    cat <<'USAGE'
Użycie: scripts/sync.sh [--once] [--dry-run] [--interval SEKUNDY] [--workers N]
                         [--only REPO]... [--no-collect-ci] [--help]

Bez argumentów: synchronizuj wszystkie repozytoria co 100 sekund (tryb apply).
  --once           Wykonaj jeden przebieg i zwróć jego kod zakończenia.
  --dry-run        Jeden przebieg bez push i bez publikowania raportów CI.
  --interval N     Odstęp między przebiegami, w sekundach (10-999999).
  --workers N      Równoległe repozytoria (1-16, domyślnie 8).
  --only REPO      Ogranicz do repozytorium GitHub; można powtarzać.
  --no-collect-ci  Nie pobieraj i nie publikuj raportów GitLab CI.
  --help           Pokaż tę pomoc.

Przykłady:
  scripts/sync.sh --once --dry-run --only alice-speech-service
  scripts/sync.sh --once --only alice-speech-service --only alice-web
  scripts/sync.sh --interval 300 --workers 4

Zmienne: ALICE_SYNC_INTERVAL_SECONDS, ALICE_SYNC_WORKERS, ALICE_SYNC_LOCK_FILE.
USAGE
}

fail() {
    printf 'BŁĄD: %s\n' "$*" >&2
    exit 2
}

while (( $# > 0 )); do
    case "$1" in
        --once)
            ONCE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            ONCE=1
            shift
            ;;
        --interval|--workers|--only)
            option="$1"
            (( $# >= 2 )) || fail "Brak wartości dla $option"
            [[ -n "$2" ]] || fail "Pusta wartość dla $option"
            case "$option" in
                --interval) INTERVAL_SECONDS="$2" ;;
                --workers) WORKERS="$2" ;;
                --only) ONLY_REPOS+=("$2") ;;
            esac
            shift 2
            ;;
        --no-collect-ci)
            NO_COLLECT_CI=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Nieznana opcja: $1 (użyj --help)"
            ;;
    esac
done

[[ "$INTERVAL_SECONDS" =~ ^[1-9][0-9]{0,5}$ ]] \
    || fail "Interwał musi być liczbą całkowitą 10-999999"
(( INTERVAL_SECONDS >= 10 )) || fail "Interwał musi wynosić co najmniej 10 sekund"
[[ "$WORKERS" =~ ^([1-9]|1[0-6])$ ]] || fail "Liczba workerów musi wynosić 1-16"

for executable in python3 git flock; do
    command -v "$executable" >/dev/null 2>&1 \
        || fail "Brakuje wymaganego polecenia: $executable"
done
[[ -f "$SYNC_SCRIPT" ]] || fail "Nie znaleziono $SYNC_SCRIPT"
[[ -f "$CONFIG_FILE" ]] || fail "Nie znaleziono $CONFIG_FILE"

# A per-user lock covers all checkout copies of alice-infra on this host.
# Keep the descriptor open for the entire process lifetime, including sleep.
LOCK_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache/alice-infra}"
mkdir -p -m 700 -- "$LOCK_DIR"
LOCK_FILE="${ALICE_SYNC_LOCK_FILE:-$LOCK_DIR/github-gitlab-sync.lock}"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    fail "Synchronizacja już działa (blokada: $LOCK_FILE)"
fi

sync_args=(--config "$CONFIG_FILE" --workers "$WORKERS")
if (( DRY_RUN )); then
    sync_args+=(--dry-run)
else
    sync_args+=(--apply)
fi
if (( NO_COLLECT_CI )); then
    sync_args+=(--no-collect-ci)
fi
for repository in "${ONLY_REPOS[@]}"; do
    sync_args+=(--only "$repository")
done

# The sync implementation returns nonzero on failed/diverged projects or CI
# publication errors. Do not terminate the daemon; retry next interval.
log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
trap 'log "Zatrzymano synchronizację"; exit 0' TERM
while :; do
    log "Start synchronizacji GitHub -> GitLab"
    if python3 "$SYNC_SCRIPT" "${sync_args[@]}"; then
        result=0
        log "Synchronizacja zakończona poprawnie"
    else
        result=$?
        log "BŁĄD synchronizacji (kod $result); sprawdź raport w katalogu reports/" >&2
    fi

    if (( ONCE )); then
        exit "$result"
    fi
    log "Kolejny przebieg za $INTERVAL_SECONDS s"
    sleep "$INTERVAL_SECONDS"
done
