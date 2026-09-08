#!/bin/bash
set -euo pipefail
export PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}"

# Create missing resources only. Never reset an existing production password.
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_SUPERUSER}" --dbname "${POSTGRES_BOOTSTRAP_DB}" \
    -v service_user="${KNOWLEDGE_DB_USERNAME}" -v service_password="${KNOWLEDGE_DB_PASSWORD}" -v service_db="${KNOWLEDGE_DB_NAME}" <<'EOSQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'service_user', :'service_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'service_user') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'service_db', :'service_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'service_db') \gexec
EOSQL
