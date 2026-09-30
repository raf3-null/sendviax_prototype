import test from 'node:test';
import assert from 'node:assert/strict';
import {parseInvitation,retain,live,scanPayload,safeLink} from '../app/try/model.ts';
import {encode} from '../app/crypto.ts';
const text=s=>({type:'text',name:'synthetic.txt',mime:'text/plain',data:encode(new TextEncoder().encode(s))});
const fragment=`s=${'a'.repeat(32)}&k=${encode(new Uint8Array(32))}&t=${'t'.repeat(43)}`;
test('strict web/legacy invitations reject ambiguous fields, origins and injected URL paths',()=>{
  assert.equal(parseInvitation(`https://relay.example/try#v=web1&${fragment}`,'https://relay.example').mode,'web1');
  assert.equal(parseInvitation(`https://relay.example/try#${fragment}`,'https://relay.example').mode,'legacy');
  for(const raw of [`https://evil.example/try#${fragment}`,`https://relay.example/try#${fragment}&s=x`,`https://relay.example/try?v=web1#${fragment}`,`https://u:p@relay.example/try#${fragment}`,`https://relay.example/other#${fragment}`,`https://relay.example/try#v=other&${fragment}`])assert.throws(()=>parseInvitation(raw,'https://relay.example'));
});
test('in-memory content quotas and expiry include wall time during browser suspension',()=>{
  const items=Array.from({length:25},(_,id)=>({id,size:1024}));assert.equal(retain(items).length,20);
  assert.equal(retain(items.map(i=>({...i,size:5*1024*1024}))).length,4);
  assert.equal(live({deadline:100,wallDeadline:200},50,150),true);
  assert.equal(live({deadline:100,wallDeadline:200},50,201),false);
  assert.equal(live({deadline:100,wallDeadline:200},101,150),false);
});
test('scanner covers seven declared categories and reports unscanned binary/invalid UTF8',()=>{
  for(const sample of ['password=synthetic','Bearer synthetic.token','api_key=synthetic','-----BEGIN PRIVATE KEY-----','test@example.com','0891234567','1234567890123'])assert.ok(scanPayload(text(sample)).findings.length);
  for(const sample of ['hello world','const total = 12;','เจอกันที่ห้องเรียน','https://example.com/help'])assert.equal(scanPayload(text(sample)).findings.length,0);
  assert.equal(scanPayload({...text('synthetic'),type:'file',name:'document.pdf',mime:'application/pdf'}).checked,false);
  assert.equal(scanPayload({...text(''),data:encode(new Uint8Array([255]))}).checked,false);
});
test('received links cannot execute scripts or embed credentials',()=>{
  for(const raw of ['javascript:alert(1)','data:text/html,hello','https://user:password@example.com','file:///tmp/x'])assert.equal(safeLink({...text(raw),type:'url'}),null);
  assert.equal(safeLink({...text('https://example.com/test'),type:'url'}),'https://example.com/test');
});
