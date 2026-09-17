#!/bin/bash
set -euo pipefail
export PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD:-${POSTGRES_PASSWORD}}"
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_SUPERUSER:-postgres}" --dbname "${POSTGRES_BOOTSTRAP_DB:-postgres}" \
  -v db="${BUDGET_DB_NAME:-budget}" -v role="${BUDGET_DB_USERNAME:-budget}" -v password="${BUDGET_DB_PASSWORD:?BUDGET_DB_PASSWORD is required}" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'role', :'password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'role') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db', :'role')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db') \gexec
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', :'db') \gexec
SQL
