#!/usr/bin/env bash

# Updates every Alice repository and recreates the production Compose stack.
# The script deliberately does not use `down -v`: PostgreSQL and other named
# volumes are retained.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
BRANCH="${DEPLOY_BRANCH:-main}"

REPOSITORIES=(
  "$WORKSPACE_DIR/desktop"
  "$WORKSPACE_DIR/infra"
  "$WORKSPACE_DIR/microservices/llm"
  "$WORKSPACE_DIR/microservices/mail"
  "$WORKSPACE_DIR/microservices/time_coordinator"
  "$WORKSPACE_DIR/microservices/weather"
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

  [[ -d "$repository/.git" ]] || {
    echo "Brak repozytorium Git: $repository" >&2
    exit 1
  }

  if [[ -n "$(git -C "$repository" status --porcelain --untracked-files=no)" ]]; then
    echo "Repozytorium $name ma zmienione pliki sledzone przez Git. Przerywam wdrozenie." >&2
    exit 1
  fi

  echo "Aktualizacja: $name ($BRANCH)"
  git -C "$repository" fetch origin "$BRANCH"
  git -C "$repository" merge --ff-only "origin/$BRANCH"
}

require_command git
require_command docker

[[ -f "$SCRIPT_DIR/.env" ]] || {
  echo "Brak pliku produkcyjnego: $SCRIPT_DIR/.env" >&2
  exit 1
}

for repository in "${REPOSITORIES[@]}"; do
  update_repository "$repository"
done

echo "Walidacja konfiguracji Docker Compose"
docker compose --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" config -q

echo "Zatrzymywanie stosu produkcyjnego (wolumeny danych zostaja zachowane)"
docker compose --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" down --remove-orphans

echo "Budowanie i uruchamianie stosu produkcyjnego"
docker compose --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" up -d --build --remove-orphans

echo "Aktualny stan kontenerow"
docker compose --env-file "$SCRIPT_DIR/.env" -f "$COMPOSE_FILE" ps
