# Relay ขั้นที่ 1: ชุดบริการในเครื่อง

## เปิดและปิด

เปิด Docker Desktop ให้ Engine พร้อม แล้วใช้:

```sh
cd /Users/raf3/SeniorProject
sh scripts/relay-stack.sh init
sh scripts/relay-stack.sh check
sh scripts/relay-stack.sh up
sh scripts/relay-stack.sh status
curl http://127.0.0.1:8000/healthz
sh scripts/relay-stack.sh logs
sh scripts/relay-stack.sh down
```

## เปิดผ่าน Cloudflare Tunnel

หลังจากตั้ง Named Tunnel `sendviax-test` และ DNS ของ `test.sendviax.com` ใน Cloudflare เรียบร้อย ให้ใช้ Terminal เดียว:

```sh
cd /Users/raf3/SeniorProject
sh scripts/run-cloudflare-relay.sh
```

สคริปต์จะเปิด Docker Relay, เว็บพอร์ต 3000 ซึ่ง proxy `/api/*` ไป Relay และ Named Tunnel ตามลำดับ API พอร์ต 8000 ยังคงเปิดเฉพาะ localhost. กด `Ctrl+C` เพื่อปิดเว็บและ Tunnel; Docker services ยังคงทำงานจนกว่าจะรัน `sh scripts/relay-stack.sh down`.

ถ้า `test.sendviax.com` ยังไม่ได้ตั้ง Named Tunnel ใช้ URL ชั่วคราวแทนได้:

```sh
sh scripts/run-cloudflare-relay.sh quick
```

Quick Tunnel ให้ URL `trycloudflare.com` ใหม่ทุกครั้ง จึงต้องนำ URL ที่แสดงไปใส่ในแอปทดสอบ และไม่ใช้ร่วมกับ `cloudflared tunnel run sendviax-test` ในคำสั่งเดียวกัน.

`init` สร้าง infra/relay/.env พร้อมรหัสผ่านสุ่ม permission 600 ไม่พิมพ์รหัสผ่าน และไม่ทับไฟล์เดิม ไฟล์นี้ถูก Git ignore แล้ว ดูชื่อค่าที่ปรับได้จาก infra/relay/.env.example

`up` เปิด FastAPI, PostgreSQL และ Redis และรอ health check ผ่าน ครั้งแรกต้องมีอินเทอร์เน็ตเพื่อดาวน์โหลด image/dependency หากพอร์ต 8000 ถูกใช้ ให้หยุด Relay เดิมด้วยตนเอง หรือเปลี่ยน RELAY_PORT ใน .env เป็น 8001 (แล้วปรับปลายทางที่เรียกใช้ตามนั้น)

`down` หยุดและลบ containers/network แต่เก็บ volume PostgreSQL ไว้ ไม่ใช้ down -v หากต้องการรักษาข้อมูล การเปลี่ยน POSTGRES_PASSWORD ใน .env ไม่ได้เปลี่ยนรหัสผ่านฐานข้อมูลที่สร้างไว้แล้ว

## สิ่งที่พร้อม และข้อจำกัด

- API เปิดเฉพาะ loopback 127.0.0.1 ไม่เปิดฐานข้อมูลหรือ Redis ออก host
- PostgreSQL มี named volume; Redis ตั้งใจเก็บใน RAM ยังไม่ใช่ durable queue
- API ยังใช้ RAM และ worker เดียวตาม protocol เดิม การ restart API ทำให้ห้องหาย **ยังไม่ได้ต่อ PostgreSQL/Redis เข้ากับข้อมูลห้อง**
- ยังไม่มี schema ใหม่ จึงยังไม่มี migration หรือข้อมูลห้องถาวร ไม่เปลี่ยน API/crypto
- งาน cleanup ของ RAM ยังรันใน API เดิมทุกวินาที
- บริการ cleanup แยกอยู่ใน profile `future-storage` และยังไม่เปิดใช้งาน entry point จะหยุดพร้อมข้อความหากสั่งรัน เพราะยังไม่มี storage adapter การนำ app.cleanup ไปรันอีก process จะล้าง RAM คนละชุดและไม่ใช่การแก้ที่ถูกต้อง
- ขั้นเชื่อมฐานข้อมูล/R2 ต้องกำหนด persistence, revoke, ACK และ cleanup contract ให้ครบก่อนเปิด worker จริง
- ชุดนี้ไม่มีเว็บหรือ Cloudflare Tunnel ใช้คู่กับเว็บเดิมได้ แต่ห้ามเปิด Backend อีกตัวชนพอร์ตเดิม
- ไม่ใช่การ deploy production และยังไม่ต้องใส่ R2 credentials

## ตรวจสอบที่ทำแล้ว

Compose config และ shell syntax ผ่าน; backend unittest ผ่าน 14 รายการ; .env ถูก ignore และมี permission 600 ไม่มีการแก้แพลตฟอร์มมือถือหรือ Mac

หาก Docker Engine ไม่พร้อม การตรวจ config ยังผ่านได้ แต่ยังไม่ยืนยัน image build/container health ต้องรัน up และ health check เมื่อ Engine พร้อม

อ้างอิง: https://docs.docker.com/compose/how-tos/startup-order/

ผลรันจริง 2026-09-29: image API build สำเร็จ; FastAPI, PostgreSQL และ Redis healthy ทั้งหมด; GET http://127.0.0.1:8000/healthz ตอบ 200 พร้อม storage=memory ทิ้งชุดบริการเปิดไว้เพื่อใช้งานต่อ ปิดได้ด้วยคำสั่ง down ด้านบน ไม่มีการเชื่อม R2 หรือเปลี่ยน Cloudflare/DNS ในขั้นนี้
