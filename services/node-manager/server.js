import http from 'node:http';
import { randomUUID } from 'node:crypto';
import amqp from 'amqplib';

const port = Number(process.env.PORT || 8097);
const thresholdMs = Math.max(30, Number(process.env.NODE_OFFLINE_SECONDS || 90)) * 1000;
const nodes = new Map();
let connected = false;
let commandChannel = null;
const pendingCommands = new Map();

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
      await channel.assertExchange('alice.node.command', 'topic', { durable: true });
      await channel.assertExchange('alice.node.response', 'topic', { durable: true });
      // Durable queue preserves telemetry during restarts. A single consumer owns it.
      const queue = 'alice.node.manager.events';
      const telemetryQueue = 'alice.node.manager.telemetry';
      const responseQueue = 'alice.node.manager.response';
      await channel.assertQueue(queue, { durable: true });
      await channel.assertQueue(telemetryQueue, { durable: true });
      await channel.assertQueue(responseQueue, { durable: true });
      await channel.bindQueue(queue, 'alice.node.event', 'node.*.event');
      await channel.bindQueue(telemetryQueue, 'alice.node.telemetry', 'node.*.telemetry');
      await channel.bindQueue(responseQueue, 'alice.node.response', 'node.*.response');
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
      await channel.consume(responseQueue, msg => {
        if (!msg) return;
        const response = parse(msg);
        const wait = pendingCommands.get(response?.commandId);
        if (wait) wait.resolve(response);
        channel.ack(msg);
      });
      commandChannel = channel;
      console.log('Consuming Alice Node events, telemetry and command responses');
      await done;
    } catch (e) {
      console.error('RabbitMQ connection failed:', e.message);
    }
    connected = false;
    commandChannel = null;
    for (const waiter of pendingCommands.values()) waiter.reject(new Error('RabbitMQ disconnected'));
    pendingCommands.clear();
    // Do not report stale nodes as online while disconnected.
    for (const n of nodes.values()) n.status = 'OFFLINE';
    await new Promise(resolve => setTimeout(resolve, 5000));
  }
}

async function commandSystemInfo(nodeId) {
  if (!commandChannel || !connected) throw new Error('RabbitMQ not connected');
  const commandId = randomUUID();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 10000);
  const promise = new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      pendingCommands.delete(commandId);
      reject(new Error('Node did not respond within 10 seconds'));
    }, 10000);
    pendingCommands.set(commandId, {
      resolve: response => { clearTimeout(timeout); pendingCommands.delete(commandId); resolve(response); },
      reject: error => { clearTimeout(timeout); pendingCommands.delete(commandId); reject(error); }
    });
  });
  const payload = { commandId, nodeId, command: 'SYSTEM_INFO', createdAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(), parameters: {} };
  try {
    commandChannel.publish('alice.node.command', 'node.' + nodeId + '.command',
      Buffer.from(JSON.stringify(payload)), { contentType: 'application/json', persistent: true });
  } catch (error) {
    pendingCommands.get(commandId)?.reject(error);
    throw error;
  }
  return promise;
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
  const systemMatch = pathname.match(/^\\/api\\/nodes\\/([^/]+)\\/system-info$/);
  if (systemMatch) {
    let id;
    try { id = decodeURIComponent(systemMatch[1]); } catch { return respond(400, { message: 'Invalid node ID' }); }
    if (!nodes.has(id)) return respond(404, { message: 'Node not found' });
    if (!/^[A-Za-z0-9_-]{1,100}$/.test(id)) return respond(400, { message: 'Invalid node ID' });
    if (statusOf(nodes.get(id)) !== 'ONLINE') return respond(503, { message: 'Node is offline' });
    commandSystemInfo(id).then(result => respond(result.success ? 200 : 502, result))
      .catch(error => respond(503, { message: error.message }));
    return;
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
