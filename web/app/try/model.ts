import {decode, scan, type Payload, type Role} from '../crypto.ts';

export type Session={sid:string;secret:Uint8Array<ArrayBuffer>;token:string;role:Role;expiry:number;mode:'web1'|'legacy';inviteToken?:string;inviteExpiry?:number;code?:string;deadline:number;wallDeadline:number};
export type Receipt={id:string;sender:Role;status:'available'|'completed'|'expired';expires_at:number;completed_at:number|null};
export type Device={role:Role;name:string;platform:string;last_seen:number;online:boolean};
export type RoomState={session_id:string;role:Role;expires_at:number;pairing:'waiting'|'pending'|'confirmed';invite_expires_at:number;devices:Device[];receipts:Receipt[]};
export type Item={id:string;payload:Payload;hash:string;direction:'sent'|'received';time:number;expiry:number;deadline:number;wallDeadline:number;size:number;status:'available'|'completed'|'expired'|'unknown'|'failed'};
export const labels={text:'ข้อความ',url:'ลิงก์',image:'รูปภาพ',file:'ไฟล์'};
export const statuses={available:'รอผู้รับ',completed:'ผู้รับรับแล้ว',expired:'หมดอายุ',unknown:'ยังยืนยันการส่งไม่ได้',failed:'ส่งไม่สำเร็จ'};
export const size=(n:number)=>n<1024?`${n} B`:n<1048576?`${(n/1024).toFixed(1)} KB`:`${(n/1048576).toFixed(1)} MiB`;
export function parseInvitation(raw:string,origin:string){
  const url=new URL(raw.trim());
  if(url.origin!==origin||url.username||url.password||url.search||!['/','/try'].includes(url.pathname))throw Error('ใช้ลิงก์เชิญจากเว็บไซต์นี้เท่านั้น');
  const p=new URLSearchParams(url.hash.slice(1)),mode=p.get('v')==='web1'?'web1':'legacy';
  const expected=mode==='web1'?['v','s','k','t']:['s','k','t'];
  if([...p.keys()].length!==expected.length||expected.some(k=>!p.has(k)))throw Error('ลิงก์เชิญไม่ถูกต้อง');
  const sid=p.get('s')||'',secret=decode(p.get('k')||''),token=p.get('t')||'';
  if(!/^[a-f0-9]{32}$/.test(sid)||secret.length!==32||!/^[A-Za-z0-9_-]{43}$/.test(token))throw Error('ลิงก์เชิญไม่ถูกต้อง');
  return {sid,secret,token,mode} as const;
}
export function retain(items:Item[]){let total=0;return items.filter((i,index)=>{if(index>=20||total+i.size>20*1024*1024)return false;total+=i.size;return true;});}
export function live(item:{deadline:number;wallDeadline:number},mono=performance.now(),wall=Date.now()){return item.deadline>mono&&item.wallDeadline>wall;}
export function scanPayload(p:Payload){
  const textual=p.type==='text'||p.type==='url'||/\.(txt|md|csv|json|xml|ya?ml|js|ts|py|cs|java|swift|kt|css|html|rs|go)$/i.test(p.name);
  if(!textual)return {checked:false,findings:[],message:'ไม่ได้ตรวจเนื้อหาไฟล์ชนิดนี้ กรุณาตรวจสอบด้วยตนเอง'};
  let text:string;try{text=new TextDecoder('utf-8',{fatal:true}).decode(decode(p.data));}catch{return {checked:false,findings:[],message:'ไฟล์นี้ไม่ใช่ข้อความ UTF-8 จึงไม่ได้ตรวจเนื้อหา'};}
  const findings=scan(text);return {checked:true,findings,message:findings.length?`อาจมีข้อมูลอ่อนไหว: ${findings.join(', ')}`:'ไม่พบรูปแบบที่รู้จัก ไม่ได้หมายความว่าปลอดภัยแน่นอน'};
}
export function safeLink(p:Payload){if(p.type!=='url')return null;try{const u=new URL(new TextDecoder().decode(decode(p.data)).trim());return ['https:','http:'].includes(u.protocol)&&!u.username&&!u.password?u.href:null;}catch{return null;}}
export function platform(){const ua=navigator.userAgent;if(/Android/i.test(ua))return 'Android';if(/iPhone|iPad/i.test(ua)||navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1)return 'iOS/iPadOS';if(/Win/i.test(ua))return 'Windows';if(/Mac/i.test(ua))return 'macOS';if(/Linux/i.test(ua))return 'Linux';return 'Web';}
