# เปิด Sendviax จากต่างเครือข่าย

## รุ่นที่ทำให้

เว็บ Next.js ภาษาไทยตามภาพ + FastAPI test-v0 บน Mac นี้ เข้ารหัสด้วย Web Crypto ก่อนอัปโหลด และถอดรหัสเฉพาะเบราว์เซอร์ปลายทาง เก็บ ciphertext ใน RAM ตามข้อเสนอที่อนุมัติ **ยังไม่ได้ใช้ R2 และยังไม่ใช่ Native App** ข้อความ/URL/รูป/ไฟล์เดี่ยวไม่เกิน 5 MiB ห้องอายุ 15 นาที รายการบน Relay อายุ 5 นาที

## เปิดระบบในเครื่อง

ติดตั้ง dependency ครั้งแรก (เครื่องนี้ติดตั้งแล้ว):

```sh
cd /Users/raf3/SeniorProject
python3 -m venv backend/.venv
backend/.venv/bin/python -m pip install -r backend/requirements.txt
cd web
npm ci
npm run build
```

ทุกครั้งที่ต้องการเปิดระบบ:

```sh
cd /Users/raf3/SeniorProject
sh scripts/run-relay-test.sh
```

เปิด http://127.0.0.1:3000 บน Mac เท่านั้น อีกเครื่องใช้ localhost นี้ไม่ได้ ให้ใช้ HTTPS Tunnel ด้านล่าง ต้องมีข้อความ “Relay พร้อมเชื่อมต่อ” ปิด process ด้วย Ctrl+C เมื่อเลิกทดสอบ ห้ามรัน backend หลาย workers เพราะ state อยู่ใน RAM

## ทดลองทันทีด้วย URL ชั่วคราว

เปิด Terminal อีกหน้าต่าง:

```sh
cloudflared tunnel --url http://127.0.0.1:3000 --no-autoupdate
```

ใช้ URL `https://....trycloudflare.com` ที่โปรแกรมแสดง ทั้งสองเครื่องต้องเปิด URL เดียวกัน ไม่ต้องตั้ง DNS หรือเปิดพอร์ตเราเตอร์ URL เปลี่ยนเมื่อเริ่ม Tunnel ใหม่ และไม่มี uptime guarantee ตาม [Cloudflare Quick Tunnels](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/)

## ผูก test.sendviax.com

ไม่ต้องแก้เว็บไซต์ที่โดเมนหลัก `sendviax.com` ให้ใช้ subdomain `test` โดยเฉพาะ ตรวจว่าไม่มี DNS record `test` เดิมที่ใช้งานอยู่ก่อน ห้ามลบทับ record ของบริการอื่น

1. เปิด Terminal แล้วรัน `cloudflared tunnel login` เบราว์เซอร์จะให้ล็อกอิน Cloudflare และเลือก zone `sendviax.com` ขั้นตอนนี้คุณทำเอง ไม่ต้องส่ง token หรือไฟล์ cert มาในแชต
2. รัน `cloudflared tunnel create sendviax-test` เก็บ UUID ที่แสดงไว้ ไฟล์ credential จะอยู่ใน `.cloudflared` ของบัญชีผู้ใช้ ห้าม commit
3. สร้าง DNS สำหรับ Tunnel ด้วย `cloudflared tunnel route dns sendviax-test test.sendviax.com` หากชื่อซ้ำให้ตรวจ record เดิมก่อน ไม่ใช้ overwrite
4. รัน Tunnel ชื่อนี้:

```sh
cloudflared tunnel --url http://127.0.0.1:3000 --no-autoupdate run sendviax-test
```

5. เปิด `https://test.sendviax.com` และตรวจสถานะ Relay หน้าเว็บกับ API ใช้โดเมนเดียวกัน Next.js ส่ง `/api/test/*` ไป FastAPI ที่ `127.0.0.1:8000` จึงไม่ต้องเปิด API port ต่ออินเทอร์เน็ต ไม่ต้องเพิ่ม CORS แบบ `*`

อ้างอิง [Create a locally-managed tunnel](https://developers.cloudflare.com/tunnel/features/locally-managed-tunnels/create-local-tunnel/). Tunnel ออกไปเชื่อม Cloudflare จากเครื่องนี้; อย่าสร้าง A record ชี้ private IP เช่น 192.168.x.x หรือเปิดพอร์ต 8000 สู่สาธารณะ

หากใช้ Dashboard: สร้าง Cloudflare Tunnel ชื่อ sendviax-test → เลือก macOS → ทำตามคำสั่ง connector ที่ Cloudflare แสดงใน Terminal ส่วนตัว → เพิ่ม Published application route เป็น hostname `test.sendviax.com`, service `HTTP`, URL `localhost:3000`. ใช้วิธี CLI หรือ Dashboard วิธีใดวิธีหนึ่ง ไม่ต้องสร้างสอง Tunnel

## ทดสอบข้ามเครือข่ายจริง

1. Mac ต่อ Wi-Fi และเปิด URL HTTPS (ไม่ใช้ localhost เพื่อสร้าง invite)
2. มือถือปิด Wi-Fi และใช้ 4G/5G
3. Mac กด “สร้างห้องทดสอบ” → “สร้างลิงก์เชิญ” → “คัดลอกลิงก์” ส่งลิงก์ให้อุปกรณ์ที่ไว้ใจ ลิงก์มีกุญแจและสิทธิ์ของห้อง ห้ามเผยแพร่สาธารณะ
4. มือถือเปิดลิงก์ หรือวางในช่อง “ลิงก์เชิญ” แล้วเข้าร่วม เมื่อเข้าแล้วส่วน fragment จะหายจาก address bar
5. Mac ไป “ส่งข้อมูล” → พิมพ์ข้อความสังเคราะห์ → “ตรวจสอบและส่งข้อมูล” → “ยืนยันการส่ง”
6. มือถือเปิด “รายการที่ได้รับ” ควรแสดงเนื้อหาภายในรอบ polling ประมาณ 2 วินาทีบวกเวลาถ่ายโอน กดคัดลอกแล้วนำไปวางใน Notes/ช่องข้อความ
7. ส่งกลับจากมือถือไป Mac ทำซ้ำด้วย URL รูปภาพ และไฟล์เดี่ยว เทียบ SHA-256 ที่หน้ารายละเอียดทั้งสองฝั่ง ไฟล์/รูปดาวน์โหลดแล้วเปิดด้วยแอปที่รองรับ
8. ทดสอบปิดห้องจาก Mac แล้วส่งจากมือถือ ต้องไม่ได้รับสิทธิ์เข้าห้องอีก

อัปโหลดแล้วไม่ได้แปลว่าผู้รับรับแล้วหรือวางแล้ว ในรุ่นนี้ฝั่งผู้รับเห็น “ถอดรหัสแล้ว” เท่านั้นที่ยืนยันว่า client นั้นรับได้ ประวัติเก็บสูงสุด 20 รายการใน RAM ของแท็บ ไม่ใช่คลังถาวร รีเฟรชต้องเข้าห้องใหม่ อย่า refresh ฝั่ง owner ถ้ายังต้องการใช้สิทธิ์ปิดห้อง

## ข้อจำกัดและแก้ปัญหา

- เครื่อง Mac ต้องเปิดอยู่และไม่ sleep; อย่าปิดหน้าต่าง Terminal ที่รันเว็บ/Relay/Tunnel
- 502: ตรวจว่าเว็บพอร์ต 3000 และ FastAPI 8000 ยังรัน แล้วตรวจ URL service ของ Tunnel
- ห้องไม่เข้า/401: ลิงก์ผิด ห้องหมดอายุ ปิดห้อง หรือ backend restart ให้สร้างห้องใหม่
- คัดลอกไม่ได้: เปิด HTTPS กดปุ่มด้วยตนเอง หรือเลือกข้อความแล้วคัดลอก; iOS/Android background tabs อาจหยุด polling ให้เปิดหน้าเว็บค้างไว้
- รูป/ไฟล์ใช้ Download/Open ไม่ได้อ้างว่ารองรับ native image clipboard หรือ global shortcut
- เต็ม/429: รอหนึ่งนาทีหรือให้ห้องหมดอายุ; ทดสอบทีละห้อง ไม่มี persistent queue/retry/resume
- ขั้นตอนทดสอบเครื่องจริงต้องบันทึกเอง ไม่ถือว่า localhost automated tests ยืนยันมือถือคนละเครือข่ายแล้ว

## คำสั่งตรวจสอบ

```sh
cd /Users/raf3/SeniorProject/backend
.venv/bin/python -m unittest -v test_relay.py
cd ../web
node --experimental-strip-types --test tests/crypto.test.mjs
node --experimental-strip-types tests/relay-e2e.mjs http://127.0.0.1:3000
```

คำสั่งสุดท้ายสร้างห้องทดสอบชั่วคราว ส่งสองทิศทาง และ revoke ตอนจบ ใช้ URL HTTPS แทนเพื่อทดสอบเส้นทางผ่าน Cloudflare ได้ ไม่พิมพ์ secret/token/payload ลง log
