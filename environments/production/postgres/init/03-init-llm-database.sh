#!/bin/bash
set -euo pipefail

POSTGRES_SUPERUSER_PASSWORD="${POSTGRES_SUPERUSER_PASSWORD:-postgres}"
POSTGRES_SUPERUSER="${POSTGRES_SUPERUSER:-postgres}"
POSTGRES_BOOTSTRAP_DB="${POSTGRES_BOOTSTRAP_DB:-postgres}"
LLM_DB_NAME="${LLM_DB_NAME:-llm}"
LLM_DB_USERNAME="${LLM_DB_USERNAME:-llm}"
LLM_DB_PASSWORD="${LLM_DB_PASSWORD:-llm123}"
POSTGRES_CONTAINER_NAME="${POSTGRES_CONTAINER_NAME:-alice-postgres}"

required_vars=(
  POSTGRES_SUPERUSER_PASSWORD
  POSTGRES_SUPERUSER
  POSTGRES_BOOTSTRAP_DB
  LLM_DB_NAME
  LLM_DB_USERNAME
  LLM_DB_PASSWORD
  POSTGRES_CONTAINER_NAME
)

for var_name in "${required_vars[@]}"; do
  if [ -z "${!var_name:-}" ]; then
    echo "Missing required environment variable: ${var_name}" >&2
    exit 1
  fi
done

export PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}"

run_psql() {
  if [ -f "/.dockerenv" ]; then
    psql "$@"
    return
  fi

  docker exec -i -e "PGPASSWORD=${POSTGRES_SUPERUSER_PASSWORD}" "${POSTGRES_CONTAINER_NAME}" psql "$@"
}

run_psql -v ON_ERROR_STOP=1 --username "${POSTGRES_SUPERUSER}" --dbname "${POSTGRES_BOOTSTRAP_DB}" <<-EOSQL
DO
\$do\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${LLM_DB_USERNAME}') THEN
        EXECUTE format('CREATE USER %I WITH PASSWORD %L', '${LLM_DB_USERNAME}', '${LLM_DB_PASSWORD}');
    ELSE
        EXECUTE format('ALTER USER %I WITH PASSWORD %L', '${LLM_DB_USERNAME}', '${LLM_DB_PASSWORD}');
    END IF;
END
\$do\$;
EOSQL

if ! run_psql -tA --username "${POSTGRES_SUPERUSER}" --dbname "${POSTGRES_BOOTSTRAP_DB}" \
    -c "SELECT 1 FROM pg_database WHERE datname = '${LLM_DB_NAME}'" | grep -q 1; then
    run_psql -v ON_ERROR_STOP=1 --username "${POSTGRES_SUPERUSER}" --dbname "${POSTGRES_BOOTSTRAP_DB}" \
        -c "CREATE DATABASE \"${LLM_DB_NAME}\" OWNER \"${LLM_DB_USERNAME}\""
fi

run_psql -v ON_ERROR_STOP=1 --username "${POSTGRES_SUPERUSER}" --dbname "${LLM_DB_NAME}" <<-EOSQL
REVOKE ALL ON DATABASE "${LLM_DB_NAME}" FROM PUBLIC;
GRANT ALL PRIVILEGES ON DATABASE "${LLM_DB_NAME}" TO "${LLM_DB_USERNAME}";
EOSQL
