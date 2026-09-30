import Link from 'next/link';
import {ArrowUpRight} from 'lucide-react';
import s from './showcase.module.css';
export function SiteHeader(){return <header className={s.header}><Link href="/" className={s.logo}><img src="/brand/sendviax.png" width={44} height={44} alt=""/>Sendviax</Link><nav className={s.nav} aria-label="เมนูเว็บไซต์"><Link href="/#features">รู้จัก Sendviax</Link><Link href="/download">ดาวน์โหลด</Link><Link className={s.navCta} href="/try">ลองใช้งาน <ArrowUpRight size={14}/></Link></nav></header>}
export function SiteFooter(){return <footer className={s.footer}><Link href="/" className={s.logo}><img src="/brand/sendviax.png" width={40} height={40} alt=""/>Sendviax</Link><span>ส่งต่อ แล้วไปต่อ.</span><Link href="/download">แอปและแพลตฟอร์ม <ArrowUpRight size={14}/></Link><small>โครงงาน Sendviax · รุ่นทดลอง</small></footer>}
