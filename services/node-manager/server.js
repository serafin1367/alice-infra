import http from 'node:http';
import amqp from 'amqplib';

const port = Number(process.env.PORT || 8097);
const thresholdMs = Math.max(30, Number(process.env.NODE_OFFLINE_SECONDS || 90)) * 1000;
const nodes = new Map();
let connected = false;

function upsert(id, update) {
  if (typeof id !== 'string' || !id.trim() || id.length > 150) return;
  const current = nodes.get(id) || { nodeId: id, firstSeenAt: new Date().toISOString(), status: 'OFFLINE' };
  nodes.set(id, { ...current, ...update, nodeId: id });
}
function statusOf(n) {
  return n.status === 'OFFLINE' || !n.lastHeartbeatAt || Date.now() - Date.parse(n.lastHeartbeatAt) > thresholdMs ? 'OFFLINE' : 'ONLINE';
}
function view(n) {
  return { ...n, status: statusOf(n) };
}
function parse(msg) {
  try { return JSON.parse(msg.content.toString('utf8')); } catch { return null; }
}
function eventReceived(event) {
  if (!event || !event.nodeId) return;
  const details = event.details?.node || {};
  if (event.type === 'NODE_ONLINE') {
    upsert(event.nodeId, { hostname: details.hostname ?? null, os: details.os ?? null, architecture: details.architecture ?? null,
      applicationVersion: details.applicationVersion ?? null, capabilities: details.capabilities ?? [], lastEventAt: new Date().toISOString(), eventType: event.type });
  } else if (event.type === 'NODE_OFFLINE') {
    upsert(event.nodeId, { status: 'OFFLINE', lastEventAt: new Date().toISOString(), eventType: event.type, lastHeartbeatAt: null });
  }
}
function heartbeatReceived(hb) {
  if (!hb || !hb.nodeId) return;
  upsert(hb.nodeId, { lastHeartbeatAt: new Date().toISOString(), heartbeatTimestamp: hb.timestamp ?? null,
    uptimeSeconds: hb.uptimeSeconds ?? null, cpuLoad: hb.cpuLoad ?? null,
    memoryUsedPercent: hb.memoryUsedPercent ?? null, status: 'ONLINE' });
}

async function connectForever() {
  const url = process.env.RABBITMQ_URL || ('amqp://' +
    encodeURIComponent(process.env.RABBITMQ_USERNAME || 'guest') + ':' +
    encodeURIComponent(process.env.RABBITMQ_PASSWORD || 'guest') + '@' +
    (process.env.RABBITMQ_HOST || 'rabbitmq') + ':' +
    (process.env.RABBITMQ_PORT || '5672') + '/' +
    encodeURIComponent(process.env.RABBITMQ_VHOST || 'alice'));
  for (;;) {
    try {
      const connection = await amqp.connect(url);
      connected = true;
      connection.on('error', error => console.error('RabbitMQ:', error.message));
      const done = new Promise(resolve => connection.once('close', resolve));
      const channel = await connection.createChannel();
      await channel.assertExchange('alice.node.event', 'topic', { durable: true });
      await channel.assertExchange('alice.node.telemetry', 'topic', { durable: true });
      // Durable queue preserves telemetry during restarts. A single consumer owns it.
      const queue = 'alice.node.manager.events';
      const telemetryQueue = 'alice.node.manager.telemetry';
      await channel.assertQueue(queue, { durable: true });
      await channel.assertQueue(telemetryQueue, { durable: true });
      await channel.bindQueue(queue, 'alice.node.event', 'node.*.event');
      await channel.bindQueue(telemetryQueue, 'alice.node.telemetry', 'node.*.telemetry');
      await channel.prefetch(50);
      await channel.consume(queue, msg => {
        if (!msg) return;
        eventReceived(parse(msg));
        channel.ack(msg);
      });
      await channel.consume(telemetryQueue, msg => {
        if (!msg) return;
        heartbeatReceived(parse(msg));
        channel.ack(msg);
      });
      console.log('Consuming Alice Node events and telemetry');
      await done;
    } catch (e) {
      console.error('RabbitMQ connection failed:', e.message);
    }
    connected = false;
    // Do not report stale nodes as online while disconnected.
    for (const n of nodes.values()) n.status = 'OFFLINE';
    await new Promise(resolve => setTimeout(resolve, 5000));
  }
}

const server = http.createServer((req, res) => {
  const respond = (code, body) => {
    res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff' });
    res.end(JSON.stringify(body));
  };
  if (req.method !== 'GET') return respond(405, { message: 'Method not allowed' });
  const pathname = new URL(req.url, 'http://localhost').pathname;
  if (pathname === '/health') return respond(connected ? 200 : 503, { status: connected ? 'UP' : 'DEGRADED', rabbitmqConnected: connected });
  if (pathname === '/api/nodes') {
    const items = [...nodes.values()].map(view).sort((a, b) => a.nodeId.localeCompare(b.nodeId));
    return respond(200, { nodes: items, total: items.length, online: items.filter(n => n.status === 'ONLINE').length, rabbitmqConnected: connected });
  }
  const match = pathname.match(/^\/api\/nodes\/([^/]+)$/);
  if (match) {
    let id;
    try { id = decodeURIComponent(match[1]); } catch { return respond(400, { message: 'Invalid node ID' }); }
    const node = nodes.get(id);
    return node ? respond(200, view(node)) : respond(404, { message: 'Node not found' });
  }
  return respond(404, { message: 'Not found' });
});
server.listen(port, '0.0.0.0', () => console.log('Alice Node Manager on', port));
connectForever().catch(e => { console.error(e); process.exitCode = 1; });
