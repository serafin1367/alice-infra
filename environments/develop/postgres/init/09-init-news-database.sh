#!/bin/bash
# Idempotent Alice News database bootstrap for DEV only.
# Existing postgres volumes: execute explicitly inside the running postgres container.
set -euo pipefail
: "${NEWS_DB_NAME:=alice_news}"
: "${NEWS_DB_USERNAME:=alice_news}"
: "${NEWS_DB_PASSWORD:?NEWS_DB_PASSWORD is required}"
: "${POSTGRES_SUPERUSER:=postgres}"
: "${POSTGRES_BOOTSTRAP_DB:=postgres}"
export PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD:-${POSTGRES_PASSWORD:?Postgres superuser password is required}}"

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_SUPERUSER}" --dbname "${POSTGRES_BOOTSTRAP_DB}" \
  -v db="${NEWS_DB_NAME}" -v role="${NEWS_DB_USERNAME}" -v password="${NEWS_DB_PASSWORD}" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'role', :'password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db', :'role')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db') \gexec
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', :'db') \gexec
SQL

echo "Alice News database/role check completed (existing data preserved)."
