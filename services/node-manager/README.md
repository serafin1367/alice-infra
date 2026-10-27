# Alice Node Manager

Independent Node.js service subscribing to existing Alice Node RabbitMQ topics:
- `alice.node.event` / `node.*.event`: NODE_ONLINE, NODE_OFFLINE (host metadata)
- `alice.node.telemetry` / `node.*.telemetry`: Heartbeat every 30 seconds

REST API:
- `GET /api/nodes` — overview with online count
- `GET /api/nodes/{nodeId}` — last known details and heartbeat
- `GET /health` — RabbitMQ connectivity

Online means heartbeat received within `NODE_OFFLINE_SECONDS` (default 90 seconds).
The manager keeps its in-memory registry; after restart the connected Nodes populate it after their next heartbeat. Host details (OS, hostname) are received at Node startup. **This MVP does not persist history or execute arbitrary remote commands.**

Configuration: `RABBITMQ_URL` (AMQP URL with percent-encoded username/password and vhost), `PORT` default 8097, `NODE_OFFLINE_SECONDS` default 90.

Production: restrict /api/nodes via your reverse proxy/authentication and use TLS for remote RabbitMQ connections.
