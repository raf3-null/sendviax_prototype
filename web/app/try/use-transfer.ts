'use client';
import {useCallback,useEffect,useRef,useState} from 'react';
import {decode,encode,random,encrypt,decrypt,digest,LIMIT,type Payload,type Envelope} from '../crypto';
import {RelayClock} from '../clock';
import {parseInvitation,retain,live,platform,type Session,type Item,type RoomState} from './model';

class ApiError extends Error {status:number;constructor(status:number,message:string){super(message);this.status=status;}}
type Created={owner_token:string;peer_token?:string;invite_token?:string;expires_at:number;invite_expires_at?:number};
type Joined={peer_token:string;expires_at:number;confirmation_code:string;invite_expires_at:number};
const hex=()=>Array.from(random(16),b=>b.toString(16).padStart(2,'0')).join('');
export function useTransfer(){
  const [session,setSession]=useState<Session|null>(null),[room,setRoom]=useState<RoomState|null>(null),[items,setItems]=useState<Item[]>([]);
  const [name,setName]=useState('เครื่องของฉัน'),[draft,setDraft]=useState(''),[kind,setKind]=useState<'text'|'url'>('text'),[file,setFile]=useState<Payload|null>(null);
  const [notice,setNotice]=useState(''),[error,setError]=useState(''),[busy,setBusy]=useState(''),[healthy,setHealthy]=useState(false),[tick,setTick]=useState(0),[joinedLink,setJoinedLink]=useState('');
  const current=useRef<Session|null>(null),clock=useRef(new RelayClock()),seen=useRef(new Set<string>()),itemsRef=useRef<Item[]>([]),busyRef=useRef(false),generation=useRef(0),fileGeneration=useRef(0);
  const claim=useRef<{raw:string;id:string}|null>(null),initialized=useRef(false),roomRef=useRef<RoomState|null>(null),lastContact=useRef(0);
  const changeItems=useCallback((fn:(old:Item[])=>Item[])=>{itemsRef.current=retain(fn(itemsRef.current));setItems(itemsRef.current);},[]);
  const install=useCallback((s:Session|null)=>{
    generation.current++;fileGeneration.current++;current.current=s;setSession(s);setRoom(null);roomRef.current=null;seen.current.clear();changeItems(()=>[]);setDraft('');setFile(null);setError('');setJoinedLink('');
  },[changeItems]);
  const api=useCallback(async <T,>(path:string,token?:string,method='GET',body?:unknown,signal?:AbortSignal):Promise<T>=>{
    const started=performance.now();
    const timeout=AbortSignal.timeout(15000);
    const response=await fetch(path,{method,cache:'no-store',redirect:'error',headers:{...(token?{Authorization:`Bearer ${token}`} : {}),...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,signal:signal?AbortSignal.any([signal,timeout]):timeout});
    clock.current.sync(response.headers.get('date'),started);
    if(!response.ok){
      const detail=await response.json().catch(()=>({error:''}));
      const specific:Record<string,string>={incorrect_code:'รหัสยืนยันไม่ตรง กรุณาดูรหัสบนอีกเครื่อง',confirmation_locked:'ใส่รหัสผิดครบ 5 ครั้ง ห้องถูกปิดแล้ว',pairing_required:'ยืนยันอีกเครื่องก่อนส่งข้อมูล',invitation_used:'ลิงก์นี้ถูกใช้แล้ว กรุณาขอลิงก์จากห้องใหม่',invalid_invitation:'ลิงก์หมดอายุหรือใช้ไม่ได้ กรุณาสร้างห้องใหม่'};
      const generic:Record<number,string>={400:'ข้อมูลไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง',401:'ห้องหมดอายุหรือถูกปิดแล้ว',403:'ไม่มีสิทธิ์ทำรายการนี้',404:'ไม่พบรายการ',409:'รายการซ้ำหรือคำเชิญถูกใช้แล้ว',413:'ข้อมูลเกินขนาดที่รองรับ',429:'ทำรายการถี่เกินไป กรุณารอสักครู่',503:'Relay เต็ม กรุณาลองใหม่'};
      throw new ApiError(response.status,specific[detail.error]||generic[response.status]||'เชื่อมต่อ Relay ไม่สำเร็จ');
    }
    return response.json();
  },[]);
  const failure=useCallback((e:unknown,s:Session|null)=>{
    if(s&&current.current!==s)return;
    if(s&&e instanceof ApiError&&e.status===401)install(null);
    setError(e instanceof ApiError||e instanceof Error&&!(e instanceof TypeError)?e.message:'เชื่อมต่อไม่สำเร็จ ตรวจอินเทอร์เน็ตแล้วลองใหม่');
  },[install]);
  function sessionFrom(data:{expires_at:number},base:Omit<Session,'expiry'|'deadline'|'wallDeadline'>):Session{
    const remaining=Math.max(0,Math.min(900,data.expires_at-clock.current.nowSeconds()))*1000;
    return {...base,expiry:data.expires_at,deadline:performance.now()+remaining,wallDeadline:Date.now()+remaining};
  }
  async function action(label:string,work:()=>Promise<void>){if(busyRef.current)return;busyRef.current=true;setBusy(label);setError('');const s=current.current;try{await work();}catch(e){failure(e,s);}finally{busyRef.current=false;setBusy('');}}
  function create(legacy=false){return action('กำลังสร้างห้อง',async()=>{
    if(current.current)throw Error('ออกจากห้องเดิมก่อนสร้างห้องใหม่');
    if(!crypto.subtle)throw Error('เปิดเว็บผ่าน HTTPS หรือ localhost ก่อนใช้งาน');
    const sid=hex(),g=generation.current;
    const data=await api<Created>(legacy?'/api/test/sessions':'/api/web/sessions',undefined,'POST',legacy?{session_id:sid}:{session_id:sid,name:name.trim(),platform:platform()});
    if(g!==generation.current)return;
    install(sessionFrom(data,{sid,secret:random(32),token:data.owner_token,role:'owner',mode:legacy?'legacy':'web1',inviteToken:legacy?data.peer_token:data.invite_token,inviteExpiry:data.invite_expires_at}));
    setHealthy(true);setNotice(legacy?'สร้างห้องสำหรับแอปรุ่นเดิมแล้ว':'สร้างห้องแล้ว ให้เครื่องรับสแกน QR หรือเปิดลิงก์เชิญ');
  });}
  function join(raw:string){return action('กำลังเข้าร่วม',async()=>{
    if(current.current)throw Error('ออกจากห้องเดิมก่อนเข้าห้องอื่น');
    const parsed=parseInvitation(raw,location.origin),g=generation.current;
    if(parsed.mode==='web1'){
      if(claim.current?.raw!==raw)claim.current={raw,id:hex()};
      const data=await api<Joined>('/api/web/join',undefined,'POST',{session_id:parsed.sid,invite_token:parsed.token,claim_id:claim.current.id,name:name.trim(),platform:platform()});
      if(g!==generation.current)return;
      install(sessionFrom(data,{sid:parsed.sid,secret:parsed.secret,token:data.peer_token,role:'peer',mode:'web1',code:data.confirmation_code,inviteExpiry:data.invite_expires_at}));
      claim.current=null;setNotice('บอกรหัส 6 หลักให้เจ้าของห้องเพื่อยืนยันเครื่องนี้');
    }else{
      const data=await api<{session_id:string;role:string;expires_at:number}>('/api/test/session',parsed.token);
      if(data.session_id!==parsed.sid||data.role!=='peer')throw Error('ลิงก์ไม่ตรงกับห้อง');
      if(g!==generation.current)return;
      install(sessionFrom(data,{sid:parsed.sid,secret:parsed.secret,token:parsed.token,role:'peer',mode:'legacy'}));setNotice('เข้าร่วมห้องรุ่นเดิมแล้ว');
    }
    setHealthy(true);
  });}
  useEffect(()=>{
    if(initialized.current)return;initialized.current=true;
    const raw=location.href;
    if(location.hash){history.replaceState(null,'',location.pathname);setJoinedLink(raw);setNotice('ได้รับลิงก์เชิญแล้ว ตั้งชื่อเครื่องแล้วกดเข้าร่วม');}
    void api<{protocol:string}>('/api/healthz').then(d=>setHealthy(d.protocol==='test-v0')).catch(()=>setHealthy(false));
  },[api]);
  useEffect(()=>{
    const expire=()=>{
      const s=current.current;
      if(s&&!live(s)){install(null);setNotice('ห้องหมดอายุแล้ว กรุณาสร้างห้องใหม่');}
      else changeItems(old=>old.filter(i=>live(i)));
      setTick(n=>n+1);
    };
    const timer=setInterval(expire,1000);window.addEventListener('focus',expire);document.addEventListener('visibilitychange',expire);
    return()=>{clearInterval(timer);window.removeEventListener('focus',expire);document.removeEventListener('visibilitychange',expire);};
  },[changeItems,install]);
  useEffect(()=>{
    if(!session)return;
    const s=session,controller=new AbortController();let timer:ReturnType<typeof setTimeout>;
    async function poll(){try{
      if(!live(s)){if(current.current===s)install(null);return;}
      let paired=s.mode==='legacy';
      if(s.mode==='web1'){
        const state=await api<RoomState>('/api/web/state',s.token,'GET',undefined,controller.signal);
        if(controller.signal.aborted||current.current!==s)return;
        roomRef.current=state;setRoom(state);lastContact.current=performance.now();
        paired=state.pairing==='confirmed';
        if(paired){s.code=undefined;s.inviteToken=undefined;}
        const receipts=new Map(state.receipts.map(r=>[r.id,r]));
        changeItems(old=>old.map(i=>i.direction==='sent'&&receipts.has(i.id)?{...i,status:receipts.get(i.id)!.status}:i));
      }
      if(paired){
        const data=await api<{items:Envelope[]}>('/api/test/transfers',s.token,'GET',undefined,controller.signal);
        if(controller.signal.aborted||current.current!==s)return;
        if(s.expiry<=clock.current.nowSeconds()){install(null);return;}
        const failures:string[]=[];
        for(const e of data.items){
          if(controller.signal.aborted||current.current!==s||!live(s))return;
          try{
            if(!seen.current.has(e.id)){
              const p=await decrypt(e,s.secret,s.sid,s.role,clock.current.nowSeconds()),hash=await digest(p);
              if(controller.signal.aborted||current.current!==s||!live(s))return;
              const ttl=Math.max(0,Math.min(e.expires_at,s.expiry)-clock.current.nowSeconds())*1000;
              if(ttl<=0)continue;
              const item:Item={id:e.id,payload:p,hash,direction:'received',time:Date.now(),expiry:e.expires_at,deadline:Math.min(s.deadline,performance.now()+ttl),wallDeadline:Math.min(s.wallDeadline,Date.now()+ttl),size:decode(p.data).length,status:'completed'};
              changeItems(old=>[item,...old]);seen.current.add(e.id);setNotice('ได้รับรายการใหม่แล้ว พร้อมนำไปใช้ต่อ');
            }
            await api(`/api/test/transfers/${e.id}/ack`,s.token,'POST',undefined,controller.signal);
          }catch(e){if(e instanceof ApiError&&e.status===401)throw e;if(e instanceof ApiError&&e.status===404)continue;failures.push((e as Error).message);}
        }
        if(failures.length)setError(`บางรายการรับไม่สำเร็จ: ${failures[0]}`);
      }
      if(current.current===s&&!controller.signal.aborted){setHealthy(true);lastContact.current=performance.now();}
    }catch(e){if(!controller.signal.aborted&&current.current===s){setHealthy(false);if(e instanceof ApiError&&e.status===401)failure(e,s);}}
    finally{if(!controller.signal.aborted&&current.current===s)timer=setTimeout(poll,2000);}}
    void poll();return()=>{controller.abort();clearTimeout(timer);};
  },[session,api,changeItems,install,failure]);
  function confirm(code:string){return action('กำลังยืนยัน',async()=>{const s=current.current;if(!s)return;await api('/api/web/confirm',s.token,'POST',{code});if(current.current===s)setNotice('ยืนยันเครื่องแล้ว กำลังเชื่อมต่อ');});}
  function rename(){return action('กำลังบันทึกชื่อ',async()=>{const s=current.current;if(!s)return;await api('/api/web/device',s.token,'PATCH',{name:name.trim()});if(current.current===s)setNotice('เปลี่ยนชื่อเครื่องแล้ว');});}
  function close(){return action('กำลังปิดห้อง',async()=>{const s=current.current;if(!s)return;if(s.mode==='web1'||s.role==='owner'){await api(s.mode==='web1'?'/api/web/session':'/api/test/session',s.token,'DELETE');}if(current.current===s){install(null);claim.current=null;setNotice('ออกจากห้องและล้างข้อมูลบนเครื่องแล้ว');}});}
  function localExit(){install(null);claim.current=null;setNotice('ล้างข้อมูลบนเครื่องแล้ว หากออฟไลน์ ห้องบน Relay จะอยู่จนหมดอายุ');}
  function clearReceived(){changeItems(old=>old.filter(i=>i.direction==='sent'));setNotice('ล้างรายการที่ได้รับแล้ว ห้องยังรับรายการใหม่ได้');}
  function removeFile(){fileGeneration.current++;setFile(null);}
  async function pick(f?:File){if(!f)return;const id=++fileGeneration.current;try{
    if(f.size>LIMIT)throw Error('ส่งได้ครั้งละหนึ่งไฟล์ ขนาดไม่เกิน 5 MiB');
    const bytes=new Uint8Array(await f.arrayBuffer());if(id!==fileGeneration.current)return;
    setFile({type:f.type.startsWith('image/')?'image':'file',name:f.name.slice(0,255),mime:(f.type||'application/octet-stream').slice(0,128),data:encode(bytes)});setError('');
  }catch(e){setError((e as Error).message);}}
  function payload():Payload{return file||{type:kind,name:kind==='url'?'ลิงก์':'ข้อความ',mime:'text/plain',data:encode(new TextEncoder().encode(draft))};}
  function send(){return action('กำลังเข้ารหัสและส่ง',async()=>{
    const s=current.current;if(!s||!live(s))throw Error('กรุณาเชื่อมต่อห้องก่อน');
    if(s.mode==='web1'&&roomRef.current?.pairing!=='confirmed')throw Error('ยืนยันเครื่องปลายทางก่อนส่ง');
    const p=payload();if(!file&&!draft.trim())throw Error('กรอกข้อความหรือเลือกไฟล์ก่อน');
    await api('/api/test/session',s.token);
    if(current.current!==s||!live(s))return;
    const e=await encrypt(p,s.secret,s.sid,s.role,s.expiry,clock.current.nowSeconds()),hash=await digest(p);
    if(current.current!==s||!live(s))return;
    const ttl=Math.max(0,e.expires_at-clock.current.nowSeconds())*1000;
    const item:Item={id:e.id,payload:p,hash,direction:'sent',time:Date.now(),expiry:e.expires_at,deadline:Math.min(s.deadline,performance.now()+ttl),wallDeadline:Math.min(s.wallDeadline,Date.now()+ttl),size:decode(p.data).length,status:'unknown'};
    changeItems(old=>[item,...old]);
    try{await api('/api/test/transfers',s.token,'POST',e);}catch(error){
      if(current.current===s){changeItems(old=>old.map(i=>i.id===e.id?{...i,status:error instanceof ApiError?'failed':'unknown'}:i));}
      if(!(error instanceof ApiError))throw Error('ยังยืนยันการอัปโหลดไม่ได้ ตรวจสถานะรายการก่อนส่งซ้ำ');throw error;
    }
    if(current.current!==s)return;
    changeItems(old=>old.map(i=>i.id===e.id?{...i,status:'available'}:i));setDraft('');removeFile();setNotice('อัปโหลดแล้ว รอเครื่องปลายทางรับข้อมูล');
  });}
  function available(id:string){const s=current.current,i=itemsRef.current.find(i=>i.id===id);if(!s||!live(s)||!i||!live(i)){setError('รายการหมดอายุหรือถูกล้างแล้ว');return null;}return i;}
  const connected=healthy&&(!session||performance.now()-lastContact.current<12000);
  const ready=!!session&&(session.mode==='legacy'||room?.pairing==='confirmed')&&live(session);
  return {session,room,items,name,setName,draft,setDraft,kind,setKind,file,pick,removeFile,payload,notice,setNotice,error,setError,busy,healthy:connected,tick,joinedLink,setJoinedLink,ready,create,join,confirm,rename,close,localExit,clearReceived,send,available};
}
