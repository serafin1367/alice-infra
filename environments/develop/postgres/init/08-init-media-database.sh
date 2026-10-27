#!/bin/bash
set -euo pipefail
export PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD:-${POSTGRES_PASSWORD}}"
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_SUPERUSER:-postgres}" --dbname "${POSTGRES_BOOTSTRAP_DB:-postgres}" \
  -v db="${MEDIA_DB_NAME:-media}" -v role="${MEDIA_DB_USERNAME:-media}" -v password="${MEDIA_DB_PASSWORD:-dev-media}" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'role', :'password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'role') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db', :'role')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db') \gexec
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', :'db') \gexec
SQL
