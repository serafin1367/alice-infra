# ALICE Infra

This repository is for shared infrastructure and environment-level runtime concerns across the ALICE system.

It is not a microservice repository. Service application code belongs in `ALICE/microservices/*`.

## Scope

Use this repository for:
- shared components such as RabbitMQ, reverse proxy, monitoring, and other common runtime services
- environment topology and host grouping
- shared configuration examples
- operational documentation

Do not put service source code here.

## Initial structure

- `services/`
  shared infrastructure components
- `environments/`
  environment and host layout
- `docs/`
  operational notes and architecture decisions

## Current direction

At this stage the repository is intentionally lightweight. The first shared component planned here is RabbitMQ, because it is used across multiple ALICE services and should not belong to a single microservice repository.

## Next steps

1. Define host layout for local, stage, and production environments.
2. Add shared RabbitMQ runtime configuration.
3. Add service-to-host mapping documentation.
4. Move environment-specific deployment assets out of service repositories.
