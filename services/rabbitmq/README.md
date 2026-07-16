# RabbitMQ

This directory is reserved for shared RabbitMQ runtime assets.

Current contents:
- `docker-compose.yml` for a shared RabbitMQ runtime
- `.env.example` with required variables

Planned additions:
- optional broker definitions and policies
- notes about exchanges, queues, routing keys, and credentials

RabbitMQ is treated as shared infrastructure, not as part of a single microservice repository.
