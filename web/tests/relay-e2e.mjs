// Exercises the actual HTTP relay, with independent in-memory sender/receiver clients.
// Never print invite URLs, capabilities, keys, or payloads.
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {encrypt,decrypt,encode,decode,digest,random} from '../app/crypto.ts';
import {RelayClock} from '../app/clock.ts';
const clock=new RelayClock();
const wallNow=Date.now;
if(process.env.SENDVIAX_TEST_CLOCK_OFFSET_MS) Date.now=()=>wallNow()+Number(process.env.SENDVIAX_TEST_CLOCK_OFFSET_MS);
const origin=process.argv[2]||'http://127.0.0.1:3000';
async function call(path, token, method='GET', value){
 const started=performance.now();
 const r=await fetch(origin+path,{method,headers:{...(token?{Authorization:`Bearer ${token}`} : {}),...(value?{'Content-Type':'application/json'}:{})},body:value?JSON.stringify(value):undefined,signal:AbortSignal.timeout(30000)});
 clock.sync(r.headers.get('date'),started);
 assert.ok(r.ok,`HTTP ${r.status} at ${path}`);return r.json();
}
const sid=encode(random(16));
const sessionId=Array.from(decode(sid),b=>b.toString(16).padStart(2,'0')).join('');
const secret=random(32);
const room=await call('/api/test/sessions',null,'POST',{session_id:sessionId});
try{
 for(const [sender,receiver,sendToken,receiveToken] of [['owner','peer',room.owner_token,room.peer_token],['peer','owner',room.peer_token,room.owner_token]]){
  for(const type of ['text','url','image','file']){
   const data=type==='text'?new TextEncoder().encode('synthetic Thai test สวัสดี'):type==='url'?new TextEncoder().encode('https://example.com/test'):randomBytes(type==='file'?5*1024*1024:1024);
   const p={type,name:`synthetic-${type}`,mime:'application/octet-stream',data:encode(data)};
   const e=await encrypt(p,secret,sessionId,sender,room.expires_at,clock.nowSeconds());
   await call('/api/test/transfers',sendToken,'POST',e);
   const list=await call('/api/test/transfers',receiveToken);
   const received=list.items.find(i=>i.id===e.id);assert.ok(received);
   const out=await decrypt(received,secret,sessionId,receiver,clock.nowSeconds());
   assert.equal(await digest(out),await digest(p));
   await call(`/api/test/transfers/${e.id}/ack`,receiveToken,'POST');
   assert.equal((await call('/api/test/transfers',receiveToken)).items.length,0);
   console.log(`PASS ${sender} -> ${receiver}: ${type}; ${data.length} bytes; SHA-256 matched; ACK removed ciphertext`);
  }
 }
}finally{await call('/api/test/session',room.owner_token,'DELETE');}
console.log('PASS revoked test room; no live test credentials retained');
