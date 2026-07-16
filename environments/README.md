# Environments

This directory is reserved for environment and host layout.

Suggested direction:
- `local/`
- `stage/`
- `prod/`

Inside each environment, group files by host or logical stack when the topology becomes clear.

Current setup:
- `production/` - wspolny stack Docker Compose dla `postgres`, `rabbitmq`, `weather-service` i `time-coordinator-service`
