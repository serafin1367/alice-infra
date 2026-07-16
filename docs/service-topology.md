# Service Topology

Use this document to map:
- which services run on which hosts
- which databases belong to which services
- which shared components stay on the main server

Initial assumption:
- RabbitMQ runs on the main server
- individual microservices may run on different hosts
- each microservice owns its own database or schema
