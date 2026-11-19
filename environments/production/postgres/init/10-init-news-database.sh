#!/usr/bin/env bash
# Idempotent bootstrap for existing and new PostgreSQL volumes.
set -Eeuo pipefail

export PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD:?POSTGRES_SUPERUSER_PASSWORD is required}"

psql -X -v ON_ERROR_STOP=1 \
  --username "${POSTGRES_SUPERUSER:-postgres}" \
  --dbname "${POSTGRES_BOOTSTRAP_DB:-postgres}" \
  -v db="${NEWS_DB_NAME:-alice_news}" \
  -v role="${NEWS_DB_USERNAME:-alice_news}" \
  -v password="${NEWS_DB_PASSWORD:?NEWS_DB_PASSWORD is required}" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'role', :'password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role') \gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'db', :'role')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db') \gexec

SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', :'db') \gexec
SELECT format('GRANT CONNECT, TEMPORARY, CREATE ON DATABASE %I TO %I', :'db', :'role') \gexec
SQL

echo "Alice NEWS: PostgreSQL database and role verified (existing credentials not rotated)."
