# ข้อเสนอ Relay ทดสอบข้ามเครือข่าย v0

สถานะ: ผู้ใช้อนุมัติในบทสนทนาแล้ว อนุญาต implementation ทดลอง test-v0 เท่านั้น ไม่ใช่โปรโตคอลหลักที่ผ่านการทบทวน

## สิ่งที่ขออนุมัติ

ทดลอง Web ↔ Web ผ่าน FastAPI บน Mac เครื่องนี้และ Cloudflare Tunnel ที่ test.sendviax.com ก่อน โดยใช้ RAM เก็บ ciphertext ชั่วคราวแทน R2/PostgreSQL/Redis เพื่อทดสอบเส้นทางเครือข่าย ไม่ใช่การทดสอบ R2 หรือ Native client เมื่อปิดเซิร์ฟเวอร์ข้อมูลหายทั้งหมด

- ห้องทดสอบ 2 ฝั่ง อายุ 15 นาที; รายการอายุ 5 นาที; ไฟล์เดี่ยวไม่เกิน 5 MiB; รวมไม่เกิน 32 MiB ต่อห้องและ 128 MiB ต่อ process; จำกัด 32 ห้องพร้อมกัน
- Client สร้าง Session ID สุ่ม 128 บิต และ Secret สุ่ม 256 บิต; ใช้ Secret เฉพาะในหน่วยความจำ ส่งให้คู่ผ่าน URL fragment ซึ่งลบทันทีหลังอ่าน ไม่ใช้ localStorage/sessionStorage ไม่ส่ง Secret ไป Backend
- สิทธิ์ API ใช้ bearer capability สุ่ม 256 บิตที่ Backend ออกให้ แยก owner และ peer; capability ไม่ใช่ Secret เข้ารหัส; token เก็บเฉพาะ RAM; ผู้มีลิงก์เชิญถือเป็นผู้มีสิทธิ์เข้าห้อง ห้ามแชร์กับบุคคลอื่น
- ลิงก์เชิญบรรจุ Session ID, Secret และ peer capability ใน fragment; สร้างผ่านการกดปุ่มเท่านั้น ไม่มี third-party scripts/analytics
- Payload ใช้ Web Crypto AES-256-GCM tag 128 บิต; สร้าง salt สุ่ม 32 bytes ใหม่ต่อรายการ; HKDF-SHA-256 ใช้ Secret เป็น IKM, salt ดังกล่าว, info เป็น UTF-8 `sendviax-test-v0/content`; derived key 256 บิต; nonce สุ่ม 12 bytes ต่อรายการ
- Envelope JSON: version="test-v0", id=UUIDv4, session_id=hex lowercase 32 ตัว, sender="owner" หรือ "peer", expires_at=Unix seconds integer, salt/nonce/ciphertext=base64url ไม่เติม padding
- AAD คือ UTF-8 ของ JSON.stringify(["test-v0", session_id, id, sender, expires_at]); ciphertext รวม GCM tag; plaintext JSON มี type (text/url/image/file), name, mime, data(base64url) ชื่อไฟล์และเนื้อหาไม่อยู่ใน metadata ฝั่ง server
- Client ตรวจรูปแบบ/ขนาด/เวลาหมดอายุและ authentication tag ก่อนแสดง; ข้อความที่หมดอายุหรือ tag ผิดไม่ถูกนำไปใช้; MIME ไฟล์ไม่ถูกแสดงเป็น HTML; ดาวน์โหลดผ่าน Blob เท่านั้น
- Replay: Backend ปฏิเสธ id ซ้ำตลอดอายุห้อง; Client จำ id ที่รับแล้วใน RAM ตลอดอายุห้อง; ACK หลังถอดรหัสสำเร็จทำให้ server ลบ ciphertext (ไม่ถือว่าผู้ใช้วางข้อมูลแล้ว)
- Revoke โดย owner: ปิดห้องและลบรายการ/สิทธิ์ทั้งหมด; ไม่เรียกคืนสิ่งที่ผู้รับดาวน์โหลดแล้ว; restart ไม่มี resume
- Poll HTTPS ทุก 2 วินาทีแทน WSS ในการทดลองนี้; ไม่อ้างว่าเป็น protocol WSS ที่อนุมัติแล้ว
- ตรวจข้อมูลอ่อนไหว Text/URL และไฟล์ข้อความในเครื่องก่อนส่ง พร้อมให้ยกเลิก/ยืนยัน; binary/PDF ระบุว่าไม่ได้ตรวจ; ไม่รับประกัน scanner ครบ 7 ประเภทระดับผลิตภัณฑ์
- ไม่บันทึก payload, secret, token, URL fragment ลง log; ปิด access log ของแอป; API คืนข้อผิดพลาดทั่วไป; ห้ามส่งข้อมูลลับจริงระหว่างทดสอบ

## API ที่เสนอ (ยังไม่ implement)

POST /api/test/sessions {session_id} → owner_token, peer_token, expires_at

GET /api/test/session → session_id, role, expires_at (Bearer)

POST /api/test/transfers → ส่ง envelope จากฝั่งที่ล็อกอินอยู่; server ตรวจ schema/role/TTL/size

GET /api/test/transfers → envelope ที่ส่งมาหาฝั่งนี้เท่านั้น (Bearer)

POST /api/test/transfers/{id}/ack → ผู้รับยืนยันรับและลบ ciphertext

DELETE /api/test/session → owner revoke

GET /healthz → สถานะ process เท่านั้น ไม่ถือเป็นผล E2E

Rate limit สร้างห้องต่อ process, ส่งต่อ capability, และจำกัด body ก่อน parse; ไม่ใช้ IP header ที่ client ปลอมได้เป็นหลักฐานยืนยันตัวตน ข้อผิดพลาดใช้ 400 invalid_request, 401 unauthorized, 403 forbidden, 404 not_found, 409 duplicate, 410 expired, 413 too_large, 429 rate_limited, 503 capacity

## การรับงาน

ก่อนทดสอบอินเทอร์เน็ตต้องมี test vectors ด้วยข้อมูลสังเคราะห์สำหรับ HKDF/AES-GCM/AAD และ tests สำหรับ wrong secret, tampering, replay, expiry, revoke, ACK, authorization, oversize และ cleanup

ทดสอบจริง: เครื่องหนึ่ง Wi-Fi อีกเครื่องใช้ mobile data; เปิด HTTPS domain เดียวกัน; join ผ่านลิงก์; ส่ง text/url/image/file ทั้งสองทิศทาง; เทียบ SHA-256 bytes ฝั่งส่งและรับ; ทดสอบ copy/download; บันทึกผลจริงแยกจาก automated localhost tests

การอนุมัติข้อเสนอนี้อนุญาตให้เพิ่ม protocol ทดลองแยกชื่อ test-v0 และ test vectors โดยไม่เปลี่ยน primitive หรืออ้างความเข้ากันได้กับ Native ซึ่งยังไม่ทดสอบ
