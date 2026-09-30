import Link from 'next/link';
import {Apple, Monitor, Smartphone, Globe2, ArrowUpRight} from 'lucide-react';
import {SiteHeader,SiteFooter} from '../site-chrome';
import s from '../showcase.module.css';
const platforms: {name:string; detail:string; icon:typeof Apple; download?:string; status?:string}[]=[
  {name:'macOS',detail:'รุ่นทดลอง · macOS 13+ · Apple Silicon / Intel · ยังไม่ notarize',icon:Apple,download:'/downloads/Sendviax-macos-test.dmg'},
  {name:'Windows',detail:'แอปสำหรับ Windows',icon:Monitor},
  {name:'Linux',detail:'เป้าหมายแรก: Ubuntu 24.04 · GNOME X11',icon:Monitor},
  {name:'Android',detail:'รุ่นทดลอง · Android 8 ขึ้นไป · APK',icon:Smartphone,download:'/downloads/Sendviax-android-test.apk'},
  {name:'iOS / iPadOS',detail:'รุ่นทดลอง SwiftUI พร้อม Keyboard · ติดตั้งผ่าน Xcode',icon:Apple,status:'ต้องตั้งค่า Signing'},
  {name:'HarmonyOS',detail:'ต้นแบบบน Emulator',icon:Smartphone},
];
export default function Download(){return <div className={s.site}><SiteHeader/><main className={s.main}><section className={s.downloadHero}><p className={s.eyebrow}>SENDVIAX สำหรับอุปกรณ์ของคุณ</p><h1>ส่งต่อจากเว็บ.<br/>ไปต่อบนเครื่องของคุณ.</h1><p>ทดลองผ่านเว็บ หรือดาวน์โหลดแอป macOS และ Android พร้อมคีย์บอร์ด รุ่น iOS ติดตั้งผ่าน Xcode โดยตั้งค่า Signing ก่อน</p></section><section className={s.platforms} aria-label="แพลตฟอร์ม"><div className={s.webPlatform}><Globe2 size={38} strokeWidth={1.4}/><div><h2>Sendviax Web</h2><p>พร้อมทดลอง · ไม่ต้องติดตั้ง</p></div><Link className={s.primary} href="/try">เปิดเว็บแล้วลองส่ง <ArrowUpRight size={17}/></Link></div>{platforms.map(p=><div className={s.platformRow} key={p.name}><p.icon size={28} strokeWidth={1.4}/><div><h2>{p.name}</h2><p>{p.detail}</p></div>{p.download?<a className={s.textLink} href={p.download} download>{p.name==='macOS'?'ดาวน์โหลด DMG':'ดาวน์โหลด APK'} <ArrowUpRight size={14}/></a>:<span>{p.status||'ยังไม่มีตัวติดตั้ง'}</span>}</div>)}<p className={s.platformNote}>test-v0 · ทดสอบ core ของ iOS/Android ร่วมกับเว็บแล้ว ยังต้องตรวจบนมือถือจริง · ใช้ข้อมูลสังเคราะห์เท่านั้น</p></section></main><SiteFooter/></div>}
