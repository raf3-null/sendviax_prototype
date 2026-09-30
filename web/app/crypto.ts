export const LIMIT = 5 * 1024 * 1024;
export type Role = 'owner' | 'peer';
export type Envelope = { version: 'test-v0'; id: string; session_id: string; sender: Role; expires_at: number; salt: string; nonce: string; ciphertext: string };
export type Payload = { type: 'text' | 'url' | 'image' | 'file'; name: string; mime: string; data: string };
export const encode = (a: Uint8Array): string => { let s = ''; for (let i = 0; i < a.length; i += 8192) s += String.fromCharCode(...a.subarray(i, i + 8192)); return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''); };
export function decode(s: string): Uint8Array<ArrayBuffer> {
  if (typeof s !== 'string' || !/^[A-Za-z0-9_-]*$/.test(s)) throw Error('รูปแบบข้อมูลไม่ถูกต้อง');
  const raw = Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));
  if (encode(raw) !== s) throw Error('รูปแบบข้อมูลไม่ถูกต้อง'); return raw;
}
export const random = (n: number) => crypto.getRandomValues(new Uint8Array(n));
const utf8 = new TextEncoder();
export const aad = (e: Envelope) => utf8.encode(JSON.stringify([e.version, e.session_id, e.id, e.sender, e.expires_at]));
async function key(secret: Uint8Array<ArrayBuffer>, salt: Uint8Array<ArrayBuffer>) {
  if (secret.length !== 32 || salt.length !== 32) throw Error('กุญแจไม่ถูกต้อง');
  const ikm = await crypto.subtle.importKey('raw', secret, 'HKDF', false, ['deriveKey']);
  return crypto.subtle.deriveKey({name: 'HKDF', hash: 'SHA-256', salt, info: utf8.encode('sendviax-test-v0/content')}, ikm, {name: 'AES-GCM', length: 256}, false, ['encrypt', 'decrypt']);
}
export async function encrypt(payload: Payload, secret: Uint8Array<ArrayBuffer>, sid: string, role: Role, expiry: number, nowSeconds = Date.now()/1000): Promise<Envelope> {
  if (decode(payload.data).length > LIMIT) throw Error('ขนาดต้องไม่เกิน 5 MiB');
  const salt = random(32), nonce = random(12);
  const e: Envelope = {version: 'test-v0', id: crypto.randomUUID(), session_id: sid, sender: role, expires_at: Math.min(expiry, Math.floor(nowSeconds) + 295), salt: encode(salt), nonce: encode(nonce), ciphertext: ''};
  e.ciphertext = encode(new Uint8Array(await crypto.subtle.encrypt({name: 'AES-GCM', iv: nonce, additionalData: aad(e), tagLength: 128}, await key(secret, salt), utf8.encode(JSON.stringify(payload))))); return e;
}
export async function decrypt(e: Envelope, secret: Uint8Array<ArrayBuffer>, sid: string, role: Role, nowSeconds = Date.now()/1000): Promise<Payload> {
  if (!e || e.version !== 'test-v0' || !['owner','peer'].includes(e.sender) || typeof e.id !== 'string' || !/^[0-9a-f-]{36}$/.test(e.id) || !Number.isInteger(e.expires_at) || typeof e.ciphertext !== 'string' || e.ciphertext.length > 10*1024*1024) throw Error('รูปแบบรายการไม่ถูกต้อง');
  if (e.session_id !== sid || e.sender === role) throw Error('รายการนี้ไม่ตรงกับห้องหรือฝั่งผู้รับ');
  if (e.expires_at <= nowSeconds) throw Error('รายการนี้หมดอายุแล้ว กรุณาให้ผู้ส่งส่งใหม่');
  if (e.expires_at > nowSeconds + 300) throw Error('เวลาของรายการเกินอายุที่อนุญาต กรุณาตรวจเวลาเครื่องผู้ส่ง');
  const nonce = decode(e.nonce); if (nonce.length !== 12) throw Error('nonce ไม่ถูกต้อง');
  let plain: ArrayBuffer;
  try { plain = await crypto.subtle.decrypt({name: 'AES-GCM', iv: nonce, additionalData: aad(e), tagLength: 128}, await key(secret, decode(e.salt)), decode(e.ciphertext)); }
  catch { throw Error('ถอดรหัสไม่ได้: กุญแจไม่ตรงหรือข้อมูลถูกแก้ไข กรุณาเข้าห้องด้วยลิงก์ล่าสุด'); }
  const p = JSON.parse(new TextDecoder('utf-8', {fatal:true}).decode(plain));
  if (!p || !['text','url','image','file'].includes(p.type) || typeof p.name !== 'string' || p.name.length > 255 || typeof p.mime !== 'string' || p.mime.length > 128 || typeof p.data !== 'string' || p.data.length > Math.ceil(LIMIT*4/3)+4 || decode(p.data).length > LIMIT) throw Error('เนื้อหาไม่ถูกต้อง');
  return p;
}
export async function digest(p: Payload) { return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', decode(p.data))), b => b.toString(16).padStart(2,'0')).join(''); }
export function scan(text: string): string[] {
  const rules: [string, RegExp][] = [ ['รหัสผ่าน', /(?:password|passwd|รหัสผ่าน)\s*[:=]\s*\S+/i], ['Token', /(?:bearer\s+[\w.-]+|token\s*[:=]\s*\S+)/i], ['API Key', /(?:api[_-]?key\s*[:=]\s*\S+|sk-[\w-]{12,})/i], ['Private Key', /-----BEGIN (?:\w+ )?PRIVATE KEY-----/], ['อีเมล', /[\w.+-]+@[\w.-]+\.[a-z]{2,}/i], ['เบอร์โทรศัพท์ไทย', /(?:\+66|0)[2689][\d -]{7,11}/], ['เลขบัตรประชาชนที่อาจเป็นไปได้', /\b\d(?:[ -]?\d){12}\b/] ];
  return rules.filter(([,r]) => r.test(text)).map(([name]) => name);
}
