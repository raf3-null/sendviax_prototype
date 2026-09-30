// Public synthetic fixtures only; no real room capability is written.
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {encrypt,decrypt,encode} from '../app/crypto.ts';
const dir=new URL('../../outputs/mobile-tests/',import.meta.url);
const secret=new Uint8Array(32),sid='0123456789abcdef0123456789abcdef',now=1999999900;
if(process.argv[2]==='generate'){
 await mkdir(dir,{recursive:true});
 const envelopes=[];
 for(const type of ['text','url','image','file']){
  const bytes=type==='file'?new Uint8Array(5*1024*1024).fill(65):new TextEncoder().encode('synthetic mobile test สวัสดี');
  envelopes.push(await encrypt({type,name:'synthetic',mime:'application/octet-stream',data:encode(bytes)},secret,sid,'owner',2000000000,now));
 }
 await writeFile(new URL('web-fixtures.json',dir),JSON.stringify({envelopes}));
 console.log('Generated synthetic Web fixtures (four types including 5 MiB)');
}else{
 for(const platform of ['swift','android']){
  const envelopes=JSON.parse(await readFile(new URL(platform+'-fixtures.json',dir),'utf8'));
  assert.equal(envelopes.length,4);
  for(const envelope of envelopes){
   const p=await decrypt(envelope,secret,sid,'owner',now);
   const expected=p.type==='file'?new Uint8Array(5*1024*1024).fill(65):new TextEncoder().encode('synthetic mobile test สวัสดี');
   assert.equal(p.data,encode(expected));
  }
  console.log('PASS '+platform+' -> Web: text, URL, image, 5 MiB file bytes matched');
 }
}
