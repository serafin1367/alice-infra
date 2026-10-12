#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
WORKSPACE_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd -P)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
ENV_FILE="${ALICE_ENV_FILE:-${SCRIPT_DIR}/.env}"

if [[ ! -r "${ENV_FILE}" ]]; then
  printf 'ERROR: Brak czytelnego pliku środowiska: %s\n' "${ENV_FILE}" >&2
  exit 1
fi

read_env_value() {
  local key="$1" line value=""
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    if [[ "${line}" == "${key}="* ]]; then
      value="${line#*=}"
    fi
  done <"${ENV_FILE}"
  if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "${value}"
}

POSTGRES_SUPERUSER="${POSTGRES_SUPERUSER:-$(read_env_value POSTGRES_SUPERUSER)}"
POSTGRES_SUPERUSER="${POSTGRES_SUPERUSER:-postgres}"
POSTGRES_BOOTSTRAP_DB="${POSTGRES_BOOTSTRAP_DB:-$(read_env_value POSTGRES_BOOTSTRAP_DB)}"
POSTGRES_BOOTSTRAP_DB="${POSTGRES_BOOTSTRAP_DB:-postgres}"
KNOWLEDGE_STORAGE_HOST_DIR="${KNOWLEDGE_STORAGE_HOST_DIR:-$(read_env_value KNOWLEDGE_STORAGE_HOST_DIR)}"
MAIL_ATTACHMENTS_HOST_DIR="${MAIL_ATTACHMENTS_HOST_DIR:-$(read_env_value MAIL_ATTACHMENTS_HOST_DIR)}"
WORK_ATTACHMENTS_HOST_DIR="${WORK_ATTACHMENTS_HOST_DIR:-$(read_env_value WORK_ATTACHMENTS_HOST_DIR)}"
WEATHER_DB_NAME="${WEATHER_DB_NAME:-$(read_env_value WEATHER_DB_NAME)}"; WEATHER_DB_NAME="${WEATHER_DB_NAME:-weather}"
TIME_COORDINATOR_DB_NAME="${TIME_COORDINATOR_DB_NAME:-$(read_env_value TIME_COORDINATOR_DB_NAME)}"; TIME_COORDINATOR_DB_NAME="${TIME_COORDINATOR_DB_NAME:-time_coordinator}"
MAIL_DB_NAME="${MAIL_DB_NAME:-$(read_env_value MAIL_DB_NAME)}"; MAIL_DB_NAME="${MAIL_DB_NAME:-mail}"
LLM_DB_NAME="${LLM_DB_NAME:-$(read_env_value LLM_DB_NAME)}"; LLM_DB_NAME="${LLM_DB_NAME:-llm}"
WORK_DB_NAME="${WORK_DB_NAME:-$(read_env_value WORK_DB_NAME)}"; WORK_DB_NAME="${WORK_DB_NAME:-work}"
SHOPPING_DB_NAME="${SHOPPING_DB_NAME:-$(read_env_value SHOPPING_DB_NAME)}"; SHOPPING_DB_NAME="${SHOPPING_DB_NAME:-shopping}"
KNOWLEDGE_DB_NAME="${KNOWLEDGE_DB_NAME:-$(read_env_value KNOWLEDGE_DB_NAME)}"; KNOWLEDGE_DB_NAME="${KNOWLEDGE_DB_NAME:-knowledge}"
HEALTH_DB_NAME="${HEALTH_DB_NAME:-$(read_env_value HEALTH_DB_NAME)}"; HEALTH_DB_NAME="${HEALTH_DB_NAME:-health}"
BUDGET_DB_NAME="${BUDGET_DB_NAME:-$(read_env_value BUDGET_DB_NAME)}"; BUDGET_DB_NAME="${BUDGET_DB_NAME:-budget}"
# Opcjonalne zmienne są eksportowane nawet jako puste, aby Docker Compose nie
# powtarzał ostrzeżeń przy każdym wywołaniu podczas backupu.
export MAIL_SMTP_HOST="${MAIL_SMTP_HOST:-$(read_env_value MAIL_SMTP_HOST)}"
export MAIL_DEFAULT_FROM="${MAIL_DEFAULT_FROM:-$(read_env_value MAIL_DEFAULT_FROM)}"
BACKUP_DIR="${1:-${ALICE_BACKUP_DIR:-$(read_env_value ALICE_BACKUP_DIR)}}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/alice}"
RETENTION_DAYS="${ALICE_BACKUP_RETENTION_DAYS:-$(read_env_value ALICE_BACKUP_RETENTION_DAYS)}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
BACKUP_RABBITMQ_DATA="${ALICE_BACKUP_RABBITMQ_DATA:-$(read_env_value ALICE_BACKUP_RABBITMQ_DATA)}"
BACKUP_RABBITMQ_DATA="${BACKUP_RABBITMQ_DATA:-true}"
BACKUP_EMAIL="${ALICE_BACKUP_EMAIL:-$(read_env_value ALICE_BACKUP_EMAIL)}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
HOST_NAME="$(hostname -s 2>/dev/null || hostname)"
ARCHIVE_NAME="alice-backup-${HOST_NAME}-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"
STAGING_DIR=""
RABBITMQ_STOPPED=false

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
fail() { log "ERROR: $*" >&2; exit 1; }
compose() { docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" "$@"; }

cleanup() {
  local status=$?
  if [[ "${RABBITMQ_STOPPED}" == true ]]; then
    log "Ponowne uruchamianie RabbitMQ po backupie"
    compose start rabbitmq >/dev/null || true
  fi
  if [[ -n "${STAGING_DIR}" && -d "${STAGING_DIR}" ]]; then
    rm -rf -- "${STAGING_DIR}"
  fi
  if (( status != 0 )); then
    rm -f -- "${ARCHIVE_PATH}" "${ARCHIVE_PATH}.sha256"
    log "Backup zakończył się błędem (kod ${status})"
  fi
  exit "${status}"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

command -v docker >/dev/null || fail "Nie znaleziono polecenia docker"
command -v tar >/dev/null || fail "Nie znaleziono polecenia tar"
command -v gzip >/dev/null || fail "Nie znaleziono polecenia gzip"
command -v sha256sum >/dev/null || fail "Nie znaleziono polecenia sha256sum"
command -v flock >/dev/null || fail "Nie znaleziono polecenia flock"
[[ "${RETENTION_DAYS}" =~ ^[0-9]+$ ]] || fail "ALICE_BACKUP_RETENTION_DAYS musi być liczbą całkowitą"
[[ "${BACKUP_RABBITMQ_DATA}" == true || "${BACKUP_RABBITMQ_DATA}" == false ]] || fail "ALICE_BACKUP_RABBITMQ_DATA musi mieć wartość true albo false"

mkdir -p -- "${BACKUP_DIR}"
BACKUP_DIR="$(cd -- "${BACKUP_DIR}" && pwd -P)"
ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"
if [[ "${BACKUP_DIR}/" == "${WORKSPACE_DIR}/"* ]]; then
  fail "Katalog backupu musi znajdować się poza katalogiem projektu: ${WORKSPACE_DIR}"
fi
exec 9>"${BACKUP_DIR}/.backup.lock"
flock -n 9 || fail "Inny backup Alice jest już wykonywany"
STAGING_DIR="$(mktemp -d "${BACKUP_DIR}/.alice-backup-${TIMESTAMP}.XXXXXX")"
mkdir -p "${STAGING_DIR}/postgres" "${STAGING_DIR}/files" "${STAGING_DIR}/docker"

log "Rozpoczynanie backupu Alice do ${ARCHIVE_PATH}"
compose config --quiet

POSTGRES_ID="$(compose ps -q postgres)"
[[ -n "${POSTGRES_ID}" ]] || fail "Kontener PostgreSQL nie działa"
compose exec -T postgres pg_isready --username "${POSTGRES_SUPERUSER:-postgres}" --dbname "${POSTGRES_BOOTSTRAP_DB:-postgres}" >/dev/null

log "Eksport ról i uprawnień PostgreSQL"
compose exec -T postgres pg_dumpall \
  --globals-only \
  --username "${POSTGRES_SUPERUSER:-postgres}" \
  >"${STAGING_DIR}/postgres/globals.sql"

log "Eksport wszystkich baz PostgreSQL"
DATABASES="$(compose exec -T postgres psql \
  --tuples-only --no-align \
  --username "${POSTGRES_SUPERUSER:-postgres}" \
  --dbname "${POSTGRES_BOOTSTRAP_DB:-postgres}" \
  --command "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY datname")"
EXPECTED_DATABASES=(
  "${WEATHER_DB_NAME}"
  "${TIME_COORDINATOR_DB_NAME}"
  "${MAIL_DB_NAME}"
  "${LLM_DB_NAME}"
  "${WORK_DB_NAME}"
  "${SHOPPING_DB_NAME}"
  "${KNOWLEDGE_DB_NAME}"
  "${HEALTH_DB_NAME}"
  "${BUDGET_DB_NAME}"
)
for expected_database in "${EXPECTED_DATABASES[@]}"; do
  if ! grep -Fqx -- "${expected_database}" <<<"${DATABASES}"; then
    fail "Brak oczekiwanej bazy PostgreSQL '${expected_database}'. Dostępne bazy: $(tr '\n' ' ' <<<"${DATABASES}")"
  fi
done
while IFS= read -r database; do
  database="${database%$'\r'}"
  [[ -n "${database}" ]] || continue
  [[ "${database}" =~ ^[A-Za-z0-9_.-]+$ ]] || fail "Nazwa bazy zawiera niedozwolone znaki: ${database}"
  log "  pg_dump: ${database}"
  compose exec -T postgres pg_dump \
    --format=custom \
    --compress=6 \
    --no-owner \
    --no-privileges \
    --username "${POSTGRES_SUPERUSER:-postgres}" \
    --dbname "${database}" \
    </dev/null >"${STAGING_DIR}/postgres/${database}.dump"
  [[ -s "${STAGING_DIR}/postgres/${database}.dump" ]] || fail "Dump bazy '${database}' jest pusty"
done <<<"${DATABASES}"
[[ -s "${STAGING_DIR}/postgres/globals.sql" ]] || fail "Eksport ról PostgreSQL jest pusty"
for expected_database in "${EXPECTED_DATABASES[@]}"; do
  [[ -s "${STAGING_DIR}/postgres/${expected_database}.dump" ]] || fail "Brak poprawnego dumpu oczekiwanej bazy '${expected_database}'"
done

copy_host_path() {
  local configured_path="$1" destination_name="$2" source_path
  [[ -n "${configured_path}" ]] || return 0
  if [[ "${configured_path}" = /* ]]; then
    source_path="${configured_path}"
  else
    source_path="${SCRIPT_DIR}/${configured_path}"
  fi
  if [[ -e "${source_path}" ]]; then
    log "Kopiowanie ${destination_name}: ${source_path}"
    cp -a -- "${source_path}" "${STAGING_DIR}/files/${destination_name}"
  else
    log "WARN: Pominięto nieistniejącą ścieżkę ${source_path}"
  fi
}

copy_host_path "${KNOWLEDGE_STORAGE_HOST_DIR:-/mnt/md0/docker/docker-volume/alice_ai/knowledge}" knowledge
copy_host_path "${MAIL_ATTACHMENTS_HOST_DIR:-./data/mail-attachments}" mail-attachments
copy_host_path "${WORK_ATTACHMENTS_HOST_DIR:-./data/work-attachments}" work-attachments
copy_host_path "./secrets/google-calendar" google-calendar

log "Kopiowanie danych Dashboardu"
DASHBOARD_ID="$(compose ps -q dashboard-service)"
if [[ -n "${DASHBOARD_ID}" ]]; then
  mkdir -p "${STAGING_DIR}/docker/dashboard"
  docker cp "${DASHBOARD_ID}:/data/." "${STAGING_DIR}/docker/dashboard/"
else
  fail "Kontener dashboard-service nie działa"
fi

RABBITMQ_ID="$(compose ps -q rabbitmq)"
[[ -n "${RABBITMQ_ID}" ]] || fail "Kontener RabbitMQ nie działa"
log "Eksport definicji RabbitMQ"
compose exec -T rabbitmq rabbitmqctl export_definitions /tmp/alice-backup-definitions.json >/dev/null
docker cp "${RABBITMQ_ID}:/tmp/alice-backup-definitions.json" "${STAGING_DIR}/docker/rabbitmq-definitions.json"
compose exec -T rabbitmq rm -f /tmp/alice-backup-definitions.json

if [[ "${BACKUP_RABBITMQ_DATA}" == true ]]; then
  log "Zatrzymywanie RabbitMQ na czas spójnej kopii danych"
  compose stop -t 60 rabbitmq >/dev/null
  RABBITMQ_STOPPED=true
  mkdir -p "${STAGING_DIR}/docker/rabbitmq-data"
  docker cp "${RABBITMQ_ID}:/var/lib/rabbitmq/." "${STAGING_DIR}/docker/rabbitmq-data/"
  log "Uruchamianie RabbitMQ"
  compose start rabbitmq >/dev/null
  RABBITMQ_STOPPED=false
fi

log "Archiwizowanie kodu i konfiguracji projektu"
tar \
  --exclude='*/.git' \
  --exclude='*/target' \
  --exclude='*/node_modules' \
  --exclude='./.tmp' \
  --exclude='./autosave_*.log' \
  --exclude='./infra/environments/production/data' \
  -C "${WORKSPACE_DIR}" \
  -czf "${STAGING_DIR}/source-and-config.tar.gz" .

cp -- "${ENV_FILE}" "${STAGING_DIR}/production.env"
cp -- "${COMPOSE_FILE}" "${STAGING_DIR}/docker-compose.yml"
{
  printf 'created_at_utc=%s\n' "${TIMESTAMP}"
  printf 'hostname=%s\n' "${HOST_NAME}"
  printf 'workspace=%s\n' "${WORKSPACE_DIR}"
  printf 'rabbitmq_data=%s\n' "${BACKUP_RABBITMQ_DATA}"
  printf 'docker_version=%s\n' "$(docker version --format '{{.Server.Version}}')"
  compose images
} >"${STAGING_DIR}/manifest.txt"

log "Tworzenie archiwum końcowego"
tar -C "${STAGING_DIR}" -czf "${ARCHIVE_PATH}" .
gzip -t "${ARCHIVE_PATH}"
tar -tzf "${ARCHIVE_PATH}" >/dev/null
(
  cd -- "${BACKUP_DIR}"
  sha256sum "${ARCHIVE_NAME}" >"${ARCHIVE_NAME}.sha256"
)

log "Usuwanie backupów starszych niż ${RETENTION_DAYS} dni"
find "${BACKUP_DIR}" -maxdepth 1 -type f \
  \( -name 'alice-backup-*.tar.gz' -o -name 'alice-backup-*.tar.gz.sha256' \) \
  -mtime "+${RETENTION_DAYS}" -delete

ARCHIVE_SIZE="$(du -h "${ARCHIVE_PATH}" | awk '{print $1}')"
log "Backup zakończony: ${ARCHIVE_PATH} (${ARCHIVE_SIZE})"

if [[ -n "${BACKUP_EMAIL}" ]]; then
  if command -v mail >/dev/null; then
    CHECKSUM="$(awk '{print $1}' "${ARCHIVE_PATH}.sha256")"
    if printf '%s\n' \
      "Backup Alice zakończył się pomyślnie." \
      "" \
      "Host: ${HOST_NAME}" \
      "Czas UTC: ${TIMESTAMP}" \
      "Archiwum: ${ARCHIVE_PATH}" \
      "Rozmiar: ${ARCHIVE_SIZE}" \
      "SHA-256: ${CHECKSUM}" \
      "Retencja: ${RETENTION_DAYS} dni" \
      | mail -s "[Alice] Backup zakończony pomyślnie — ${HOST_NAME}" "${BACKUP_EMAIL}"; then
      log "Wysłano potwierdzenie backupu na ${BACKUP_EMAIL}"
    else
      log "WARN: Backup jest poprawny, ale nie udało się wysłać e-maila na ${BACKUP_EMAIL}"
    fi
  else
    log "WARN: Backup jest poprawny, ale nie znaleziono polecenia 'mail'; zainstaluj mailutils lub s-nail"
  fi
fi
