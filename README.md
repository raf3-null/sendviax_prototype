# Sendviax Prototype — Relay / Web / iOS

ชุด source code สำหรับส่ง prototype และนำขึ้น GitHub แยกจากโปรเจกต์หลัก

## ส่วนประกอบ

- `backend/`: FastAPI Relay เก็บ ciphertext ชั่วคราวใน RAM
- `web/`: Next.js เว็บภาษาไทย หน้าส่ง/รับ จับคู่ และดาวน์โหลด
- `apple/mobile/`: iOS/iPadOS app, Keyboard และ Share Extension
- `protocol/`, `test-vectors/`: ข้อกำหนดและเวกเตอร์สำหรับตรวจความเข้ากันได้
- `infra/relay/`: Docker stack; PostgreSQL/Redis เตรียมไว้ แต่ Relay ยังไม่ได้ใช้เก็บข้อมูลถาวร
- `scripts/`, `docs/`: เครื่องมือรันและรายละเอียดข้อจำกัด

## รันเว็บและ Relay บน Mac

ต้องมี Python 3.12 และ Node.js ที่รองรับ Next.js 16 (แนะนำ Node.js 22)

```sh
python3 -m venv backend/.venv
backend/.venv/bin/python -m pip install -r backend/requirements.txt
npm --prefix web ci
sh scripts/run-relay-test.sh
```

เปิด `http://127.0.0.1:3000` และตรวจ `http://127.0.0.1:8000/healthz`
ทดสอบข้ามเครือข่ายโดยเปิดอีก Terminal:

```sh
cloudflared tunnel --url http://127.0.0.1:3000 --no-autoupdate
```

นำ HTTPS URL ที่ได้ไปใช้บนมือถือ คู่มือ Cloudflare อยู่ใน `docs/cloudflare-relay-test-th.md` ไม่รวม credentials ของ Tunnel ในชุดนี้

## ทางเลือก Docker

เปิด Docker แล้วรัน:

```sh
npm --prefix web ci
sh scripts/relay-stack.sh init
sh scripts/run-cloudflare-relay.sh quick
```

ห้ามเปิดพร้อม `run-relay-test.sh` เพราะใช้พอร์ตเดียวกัน โหมด `named` ต้องตั้ง Cloudflare Tunnel ของผู้ใช้เองก่อน หยุด Docker ด้วย `sh scripts/relay-stack.sh down`

## iOS

เปิด `apple/mobile/Sendviax.xcodeproj` ใน Xcode เลือก Team ของผู้ติดตั้งทั้ง 3 targets และจัด App Groups / Keychain Sharing ให้ตรงกัน ตาม `docs/mobile-test-th.md` และ `docs/ios-auto-keyboard-validation.md`

สำหรับ Simulator:

```sh
sh scripts/build-ios.sh
```

iOS รุ่นนี้ใช้ legacy test-v0 จึงเลือกโหมดสำหรับแอปรุ่นเดิมในเว็บเมื่อจับคู่ รับข้อมูลเมื่อเปิดแอปหรือ Keyboard ที่อนุญาต Full Access; ยังไม่มี APNs push บัญชี หรือกลุ่มที่พร้อมใช้งาน ไม่รวม signed IPA และไฟล์ signing ส่วนตัว

## ตรวจสอบ

```sh
backend/.venv/bin/python -m unittest discover -s backend -p 'test_*.py'
npm --prefix web run typecheck
node --experimental-strip-types web/tests/crypto.test.mjs
```

## สถานะและการส่ง GitHub

นี่คือ prototype ไม่ใช่ production release ห้อง/เนื้อหามีอายุจำกัด และข้อมูล Relay หายเมื่อ restart ต้องสร้างห้องใหม่ PostgreSQL/Redis/R2 ไม่ใช่หลักฐานว่า durable Relay พร้อมแล้ว ไฟล์ติดตั้ง Android/macOS ถูกตัดออก ลิงก์ดาวน์โหลดแพลตฟอร์มเหล่านั้นจึงไม่มี binary ในชุดนี้

อัปโหลดเฉพาะเนื้อหาโฟลเดอร์นี้เป็น repository ใหม่ ตรวจ `git status` ก่อน commit ห้ามเพิ่ม `.env`, token, certificate, private key หรือ Session Secret ไม่รวม `node_modules`, `.next`, Python venv และ Xcode build
# sendviax_prototype
