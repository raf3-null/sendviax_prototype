import test from 'node:test';
import assert from 'node:assert/strict';
import {createCipheriv, hkdfSync} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {encrypt,decrypt,encode,decode,scan} from '../app/crypto.ts';
const secret=new Uint8Array(32).fill(7),sid='0123456789abcdef0123456789abcdef';
const p={type:'text',name:'ทดสอบ',mime:'text/plain',data:encode(new TextEncoder().encode('สวัสดีต่างเครือข่าย'))};
test('encrypted roundtrip and independent Node implementation',async()=>{
 const e=await encrypt(p,secret,sid,'owner',Math.floor(Date.now()/1000)+900);
 assert.deepEqual(await decrypt(e,secret,sid,'peer'),p);
 const k=hkdfSync('sha256',secret,decode(e.salt),'sendviax-test-v0/content',32);
 const cipher=createCipheriv('aes-256-gcm',k,decode(e.nonce));
 cipher.setAAD(Buffer.from(JSON.stringify([e.version,e.session_id,e.id,e.sender,e.expires_at])));
 const encrypted=Buffer.concat([cipher.update(JSON.stringify(p)),cipher.final(),cipher.getAuthTag()]);
 assert.equal(encode(encrypted),e.ciphertext);
});
test('reject wrong secret, tamper, expiry, recipient and AAD changes',async()=>{
 const e=await encrypt(p,secret,sid,'owner',Math.floor(Date.now()/1000)+900);
 await assert.rejects(decrypt(e,new Uint8Array(32),sid,'peer'));
 const c=decode(e.ciphertext);c[0]^=1;
 await assert.rejects(decrypt({...e,ciphertext:encode(c)},secret,sid,'peer'));
 await assert.rejects(decrypt({...e,expires_at:0},secret,sid,'peer'));
 await assert.rejects(decrypt(e,secret,sid,'owner'));
 await assert.rejects(decrypt({...e,id:crypto.randomUUID()},secret,sid,'peer'));
});
test('reject oversized content; flag synthetic sensitive data',async()=>{
 await assert.rejects(encrypt({...p,data:encode(new Uint8Array(5*1024*1024+1))},secret,sid,'owner',Date.now()/1000+900));
 assert.ok(scan('password=synthetic-test-only').includes('รหัสผ่าน'));
});
test('fixed interoperability vector uses approved primitives',()=>{
 const v=JSON.parse(readFileSync(new URL('../../test-vectors/test-v0.json',import.meta.url),'utf8'));
 const k=hkdfSync('sha256',Buffer.from(v.ikm_hex,'hex'),Buffer.from(v.salt_hex,'hex'),v.info,32);
 assert.equal(Buffer.from(k).toString('hex'),v.key_hex);
 const c=createCipheriv('aes-256-gcm',k,Buffer.from(v.nonce_hex,'hex'));
 c.setAAD(Buffer.from(v.aad));
 assert.equal(Buffer.concat([c.update(v.plaintext),c.final(),c.getAuthTag()]).toString('hex'),v.ciphertext_tag_hex);
});
