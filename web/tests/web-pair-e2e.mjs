// Public synthetic data only. Never log invitation, code, capability or secret.
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {encrypt,decrypt,encode,digest,random} from '../app/crypto.ts';
import {RelayClock} from '../app/clock.ts';
const origin=process.argv[2]||'http://127.0.0.1:3000',clock=new RelayClock(),sid=randomBytes(16).toString('hex'),secret=random(32);
async function call(path,token,method='GET',value,expected=200){
  const started=performance.now(),r=await fetch(origin+path,{method,headers:{...(token?{Authorization:`Bearer ${token}`} : {}),...(value?{'Content-Type':'application/json'}:{})},body:value?JSON.stringify(value):undefined,signal:AbortSignal.timeout(30000)});
  clock.sync(r.headers.get('date'),started);assert.equal(r.status,expected,`${method} ${path}`);assert.equal(r.headers.get('cache-control'),'no-store');return r.json();
}
const owner=await call('/api/web/sessions',null,'POST',{session_id:sid,name:'Synthetic browser A',platform:'Web'},201);
try{
 const request={session_id:sid,invite_token:owner.invite_token,claim_id:randomBytes(16).toString('hex'),name:'Synthetic browser B',platform:'Web'};
 const peer=await call('/api/web/join',null,'POST',request);
 assert.equal((await call('/api/web/join',null,'POST',request)).peer_token,peer.peer_token);
 await call('/api/web/join',null,'POST',{...request,claim_id:randomBytes(16).toString('hex')},409);
 await call('/api/test/transfers',peer.peer_token,'GET',undefined,403);
 await call('/api/web/confirm',owner.owner_token,'POST',{code:peer.confirmation_code});
 const state=await call('/api/web/state',owner.owner_token);assert.equal(state.pairing,'confirmed');assert.equal(state.devices.length,2);
 for(const [sender,receiver,sendToken,receiveToken] of [['owner','peer',owner.owner_token,peer.peer_token],['peer','owner',peer.peer_token,owner.owner_token]]){
  for(const type of ['text','url','image','file']){
   const bytes=type==='file'?randomBytes(5*1024*1024):type==='image'?Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j9ZkAAAAASUVORK5CYII=','base64'):new TextEncoder().encode(type==='url'?'https://example.com/test':'ข้อความสังเคราะห์สำหรับทดสอบ');
   const p={type,name:`synthetic-${type}`,mime:type==='image'?'image/png':'application/octet-stream',data:encode(bytes)};
   const e=await encrypt(p,secret,sid,sender,owner.expires_at,clock.nowSeconds());await call('/api/test/transfers',sendToken,'POST',e,201);
   assert.equal((await call('/api/web/state',sendToken)).receipts.find(r=>r.id===e.id).status,'available');
   const incoming=(await call('/api/test/transfers',receiveToken)).items.find(i=>i.id===e.id);
   const result=await decrypt(incoming,secret,sid,receiver,clock.nowSeconds());assert.equal(await digest(result),await digest(p));
   await call(`/api/test/transfers/${e.id}/ack`,receiveToken,'POST');await call(`/api/test/transfers/${e.id}/ack`,receiveToken,'POST');
   assert.equal((await call('/api/web/state',sendToken)).receipts.find(r=>r.id===e.id).status,'completed');
   console.log(`PASS paired ${sender} -> ${receiver}: ${type}, ${bytes.length} bytes, digest, receipt and repeated ACK`);
  }
 }
 await call('/api/web/device',peer.peer_token,'PATCH',{name:'Renamed browser'});
 assert.equal((await call('/api/web/state',owner.owner_token)).devices.find(d=>d.role==='peer').name,'Renamed browser');
}finally{await call('/api/web/session',owner.owner_token,'DELETE');}
await call('/api/web/state',owner.owner_token,'GET',undefined,401);
console.log('PASS one-time pairing, confirmation gate, device metadata, close and native-compatible envelope');
