import test from 'node:test';
import assert from 'node:assert/strict';
import {RelayClock} from '../app/clock.ts';
import {encrypt,decrypt,encode} from '../app/crypto.ts';
test('HTTPS time tolerates device clocks behind/ahead without extending message expiry',async()=>{
 const wall=Date.now,server=1800000000000,clock=new RelayClock();
 clock.sync(new Date(server).toUTCString(),1000,1000);
 const secret=new Uint8Array(32).fill(9),sid='0123456789abcdef0123456789abcdef';
 const payload={type:'text',name:'test',mime:'text/plain',data:encode(new TextEncoder().encode('synthetic'))};
 try {
  for(const offset of [-600000,-10000,600000]){
   Date.now=()=>server+offset;
   const e=await encrypt(payload,secret,sid,'owner',server/1000+900,clock.nowSeconds(1000));
   assert.deepEqual(await decrypt(e,secret,sid,'peer',clock.nowSeconds(2000)),payload);
   await assert.rejects(decrypt(e,secret,sid,'peer',clock.nowSeconds(301000)),/หมดอายุ/);
  }
 }finally{Date.now=wall;}
});
test('clock fails closed without valid server time',()=>{
 const c=new RelayClock();assert.throws(()=>c.nowSeconds());
 assert.throws(()=>c.sync(null,0));assert.throws(()=>c.sync('invalid',0));
});
