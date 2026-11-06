#!/bin/bash
set -euo pipefail
# Runs automatically only on FIRST PostgreSQL volume initialization.
# Existing volumes: run this script manually inside the postgres container.
: "${IOT_WORKSHOP_DB_NAME:=iot_workshop}"
: "${IOT_WORKSHOP_DB_USERNAME:=iot_workshop}"
: "${IOT_WORKSHOP_DB_PASSWORD:=dev-iot-workshop}"
: "${POSTGRES_SUPERUSER:=postgres}"
: "${POSTGRES_BOOTSTRAP_DB:=postgres}"
export PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}"
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_SUPERUSER}" --dbname "${POSTGRES_BOOTSTRAP_DB}" \
  -v db_user="${IOT_WORKSHOP_DB_USERNAME}" -v db_password="${IOT_WORKSHOP_DB_PASSWORD}" <<'EOSQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'db_user', :'db_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'db_user')\gexec
EOSQL
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_SUPERUSER}" --dbname "${POSTGRES_BOOTSTRAP_DB}" \
  -v db_name="${IOT_WORKSHOP_DB_NAME}" -v db_user="${IOT_WORKSHOP_DB_USERNAME}" <<'EOSQL'
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')\gexec
EOSQL
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_SUPERUSER}" --dbname "${POSTGRES_BOOTSTRAP_DB}" \
  -v db_name="${IOT_WORKSHOP_DB_NAME}" -v db_user="${IOT_WORKSHOP_DB_USERNAME}" <<'EOSQL'
SELECT format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', :'db_name', :'db_user')\gexec
EOSQL
