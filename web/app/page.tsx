'use client';

import {useEffect, useState} from 'react';
import Link from 'next/link';
import {ArrowRight, ArrowUpRight, Check, FileText, Link2, LockKeyhole, Send} from 'lucide-react';
import s from './showcase.module.css';
import {SiteHeader, SiteFooter} from './site-chrome';

const examples = [
  {label:'ข้อความ', title:'ไอเดียดี ๆ ไปต่อได้ทุกเครื่อง', content:'เจอกันที่ร้านเดิม วันเสาร์ 10 โมงนะ ☕', icon:FileText},
  {label:'ลิงก์', title:'เจอในคอม เปิดต่อบนมือถือ', content:'https://example.com/weekend-plans', icon:Link2},
  {label:'ไฟล์', title:'ไฟล์ที่ต้องใช้ อยู่บนเครื่องที่ใช่', content:'weekend-plans.pdf', icon:FileText},
];

export default function Home(){
  const [example,setExample]=useState(0);
  const [sent,setSent]=useState(false);
  const item=examples[example];
  useEffect(()=>{if(new URLSearchParams(location.hash.slice(1)).has('s')) location.replace('/try'+location.hash);},[]);
  return <div className={s.site}>
    <SiteHeader/>
    <main className={s.main}>
      <section className={s.hero}>
        <div className={s.appIcon}><img src="/brand/sendviax.png" width={112} height={112} alt="Sendviax"/></div>
        <p className={s.eyebrow}>SENDVIAX</p>
        <h1>เครื่องเปลี่ยน<br/><span>งานไปต่อ.</span></h1>
        <p className={s.intro}>ส่งข้อความ ลิงก์ รูปภาพ และไฟล์ไปอีกเครื่อง<br className={s.desktopBreak}/> เปิดเว็บ เชื่อมต่อ แล้วส่งสิ่งที่ต้องใช้ต่อได้เลย</p>
        <div className={s.ctas}><Link className={s.primary} href="/try">ลองส่งข้อมูล <ArrowUpRight size={18}/></Link><Link className={s.textLink} href="/download">ดาวน์โหลดแอป <ArrowRight size={17}/></Link></div>
        <p className={s.fineprint}>เริ่มด้วยเว็บรุ่นทดสอบ · ไม่ต้องติดตั้งหรือลงชื่อเข้าใช้</p>
      </section>

      <section className={s.showcase} aria-label="ตัวอย่างการส่งข้อมูล">
        <div className={s.scene}>
          <div className={s.desktopWindow}>
            <div className={s.windowBar}><div className={s.traffic}><i/><i/><i/></div><span>Sendviax — เว็บบนเครื่องส่ง</span><LockKeyhole size={12}/></div>
            <div className={s.windowBody}><div className={s.windowHeading}><span className={s.miniIcon}><img src="/brand/sendviax.png" width={38} height={38} alt=""/></span><b>ส่งต่อสิ่งที่อยู่ตรงหน้า</b></div>
              <div className={s.tabs} aria-label="เลือกข้อมูลตัวอย่าง">{examples.map((e,i)=><button key={e.label} type="button" aria-pressed={i===example} onClick={()=>{setExample(i);setSent(false);}}>{e.label}</button>)}</div>
              <div className={s.previewPayload}><item.icon size={22}/><span>{item.content}</span></div>
              <div className={s.windowBottom}><span><LockKeyhole size={13}/> เข้ารหัสก่อนส่ง</span><button className={s.primary} onClick={()=>setSent(true)}>{sent?'ส่งตัวอย่างอีกครั้ง':'เล่นตัวอย่างการส่ง'} <Send size={14}/></button></div>
            </div>
          </div>
          <div className={s.phone}><div className={s.phoneIsland}/><div className={s.phoneTop}><img src="/brand/sendviax.png" width={28} height={28} alt=""/><b>Sendviax</b></div><p>เว็บบนเครื่องรับ</p><div className={`${s.receipt} ${sent?s.received:''}`} aria-live="polite"><span className={s.receiptIcon}>{sent?<Check size={25}/>:<ArrowRight size={25}/>}</span><h3>{sent?'มาถึงอีกเครื่องแล้ว':'รอสิ่งที่คุณส่งมา'}</h3><p>{sent?item.content:'กดเล่นตัวอย่างบนหน้าต่างด้านซ้าย'}</p>{sent&&<span className={s.receiptLabel}>พร้อมนำไปใช้ต่อ</span>}</div><div className={s.homeIndicator}/></div>
          <span className={s.sceneNote}>ภาพสาธิตบนหน้าเว็บ · ไม่มีการส่งข้อมูลจริง</span>
        </div>
        <div className={s.showcaseCaption}><span>จากจอใหญ่ สู่จอในมือ</span><p>{item.title}</p></div>
      </section>

      <section className={s.story} id="features"><p className={s.eyebrow}>เล็กน้อย แต่ใช้ทุกวัน</p><h2>ไม่ต้องส่งหาตัวเอง<br/>ในแชตอีกแล้ว.</h2><div className={s.storyColumns}><p>ลิงก์ที่เปิดค้างไว้ในคอม ข้อความที่พิมพ์บนมือถือ หรือไฟล์ที่ต้องใช้อีกเครื่อง ส่งผ่านห้องชั่วคราว แล้วคัดลอกหรือดาวน์โหลดที่ปลายทาง</p><p>เครื่องหนึ่งใช้ Wi-Fi อีกเครื่องใช้เน็ตมือถือ ก็ลองส่งผ่าน Relay ได้ เพียงเปิดเว็บเดียวกัน สแกน QR แล้วใช้รหัสจากเครื่องรับยืนยันการเชื่อมต่อ</p></div><div className={s.typeList}><span>ข้อความ</span><span>ลิงก์</span><span>รูปภาพ</span><span>ไฟล์เดี่ยว</span></div></section>

      <section className={s.how} id="how"><div><p className={s.eyebrow}>เริ่มจากสองเครื่อง</p><h2>สามขั้นตอน<br/>แล้วไปทำงานต่อ.</h2><Link className={s.textLink} href="/try">เปิดห้องทดสอบ <ArrowRight size={17}/></Link></div><ol>{[['สร้างห้อง','เปิดเว็บบนเครื่องแรก แล้วกดสร้างห้องชั่วคราวสำหรับเว็บ'],['ยืนยันอีกเครื่อง','สแกน QR หรือเปิดลิงก์เชิญ แล้วกรอกรหัสจากเครื่องรับเพื่อยืนยัน'],['เลือก แล้วส่ง','พิมพ์ข้อความหรือเลือกไฟล์ ยืนยันส่ง แล้วคัดลอกหรือดาวน์โหลดที่อีกเครื่อง']].map(([title,body],i)=><li key={title}><span>0{i+1}</span><div><h3>{title}</h3><p>{body}</p></div></li>)}</ol></section>

      <section className={s.privacy}><LockKeyhole size={32} strokeWidth={1.4}/><h2>เนื้อหาของคุณ<br/>เข้ารหัสจากเครื่องของคุณ.</h2><p>เว็บเข้ารหัสก่อนส่งผ่าน Relay และถอดรหัสบนเครื่องรับ<br/>ห้องมีอายุ 15 นาที ข้อมูลบน Relay เก็บชั่วคราว</p><div>รุ่นทดลอง · ใช้ข้อมูลสังเคราะห์ · ไฟล์สูงสุด 5 MiB</div></section>
      <section className={s.closing}><p className={s.eyebrow}>พร้อมลองหรือยัง</p><h2>หยิบอีกเครื่องขึ้นมา.</h2><Link className={s.primary} href="/try">ลองส่งข้อมูล <ArrowUpRight size={18}/></Link><p>เปิดผ่านเบราว์เซอร์ได้เลย</p></section>
    </main><SiteFooter/>
  </div>;
}
