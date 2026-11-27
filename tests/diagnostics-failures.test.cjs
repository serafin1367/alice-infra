'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const net = require('node:net');
const {check,tcp,rabbit,server} = require('../services/diagnostics/server.js');

async function localHttp(handler, fn) {
  const s=http.createServer(handler);
  await new Promise(resolve=>s.listen(0,'127.0.0.1',resolve));
  try {return await fn('http://127.0.0.1:'+s.address().port)}
  finally {await new Promise(resolve=>s.close(resolve))}
}

test('healthy HTTP microservice is available',async()=>{
  await localHttp((req,res)=>{res.writeHead(200);res.end('OK')},async url=>{
    const result=await check({name:'mock',url});
    assert.equal(result.ok,true);
    assert.equal(result.name,'mock');
    assert.ok(result.latencyMs>=0);
  });
});

test('HTTP 503 microservice is unavailable',async()=>{
  await localHttp((req,res)=>{res.writeHead(503);res.end()},async url=>{
    assert.equal((await check({name:'mock',url})).ok,false);
  });
});

test('connection refusal is unavailable',async()=>{
  const listener=net.createServer();
  await new Promise(resolve=>listener.listen(0,'127.0.0.1',resolve));
  const port=listener.address().port;
  await new Promise(resolve=>listener.close(resolve));
  assert.equal((await check({name:'offline',url:'http://127.0.0.1:'+port})).ok,false);
  assert.equal(await tcp('127.0.0.1',port),false);
});

test('TCP probe distinguishes listening socket from closed port',async()=>{
  const listener=net.createServer(socket=>socket.end());
  await new Promise(resolve=>listener.listen(0,'127.0.0.1',resolve));
  try{assert.equal(await tcp('127.0.0.1',listener.address().port),true)}
  finally{await new Promise(resolve=>listener.close(resolve))}
});

test('RabbitMQ without credentials is unknown, not healthy',async()=>{
  const user=process.env.RABBITMQ_USERNAME, pass=process.env.RABBITMQ_PASSWORD;
  delete process.env.RABBITMQ_USERNAME;delete process.env.RABBITMQ_PASSWORD;
  try{const result=await rabbit();assert.equal(result.ok,null);assert.deepEqual(result.queues,[])}
  finally{if(user!==undefined)process.env.RABBITMQ_USERNAME=user;if(pass!==undefined)process.env.RABBITMQ_PASSWORD=pass}
});

test('API rejects writes and unknown routes',async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base='http://127.0.0.1:'+server.address().port;
  try{
    let response=await fetch(base+'/health');assert.equal(response.status,200);
    response=await fetch(base+'/api/diagnostics/status',{method:'POST'});
    assert.equal(response.status,405);
    response=await fetch(base+'/unknown');
    assert.equal(response.status,404);
  }finally{await new Promise(resolve=>server.close(resolve))}
});
