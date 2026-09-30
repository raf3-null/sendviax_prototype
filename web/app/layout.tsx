import type { Metadata } from 'next';
import '@fontsource/ibm-plex-sans-thai/400.css';
import '@fontsource/ibm-plex-sans-thai/500.css';
import '@fontsource/ibm-plex-sans-thai/600.css';
import './globals.css';
export const metadata: Metadata = { title: 'Sendviax • ส่งต่อได้ทุกอุปกรณ์', description: 'พื้นที่ทดสอบการส่งและรับข้อมูลข้ามอุปกรณ์ของ Sendviax' };
export default function RootLayout({ children }: Readonly<{children: React.ReactNode}>) {
  return <html lang="th"><body>{children}</body></html>;
}
