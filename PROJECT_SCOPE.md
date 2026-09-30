# Sendviax — ขอบเขตโครงงาน (Project Scope)

## Additional approval — 2026-09-23

The user approved the Android roadmap and cross-account groups: owner/member roles, invitation acceptance, selected recipients or all members, one selected receiving device per member, and per-recipient delivery status. Group membership may persist; transferred content remains temporary. New members receive no old content, and removal cannot recall copies already received. This supersedes the earlier undecided cross-account scope below, but is not evidence of implementation.

The user has no Google OAuth Client ID yet and requested setup instructions. Android web1 interoperability proceeds independently. Account verification, authenticated device-key enrollment, group envelopes, APIs and database migrations remain to be implemented and validated before group transfers can be enabled.

ปรับปรุง: 13 กันยายน 2569  
สถานะ: ขอบเขตที่ทีมเลือกใช้วางแผนในช่วงเสนอ ไม่ใช่หลักฐานว่าพัฒนาเสร็จหรืออาจารย์อนุมัติทุกข้อ

## 1. เป้าหมาย

ส่งต่อข้อมูลข้ามอุปกรณ์อย่างปลอดภัยเพื่อใช้งานชั่วคราว ไม่ใช่ Cloud Drive, Chat, Remote Desktop หรือคลังไฟล์ถาวร ทีม 2 คน มีกรอบเวลาทำโครงงาน 1 ปี การเพิ่มฟังก์ชันต้องพิจารณาทั้งการพัฒนาและการทดสอบจริง

เอกสารนี้กำหนด **จะทำอะไร** ส่วน [protocol](protocol/README.md) กำหนด **ทำงานร่วมกันอย่างไร** ห้ามแก้ protocol หรือเปลี่ยนวิธีเข้ารหัสเพื่อให้ทำงานง่ายขึ้นโดยไม่ได้รับอนุมัติ

## 2. รูปแบบผู้ใช้

### Trusted Device

- ติดตั้ง Native App และลงชื่อเข้าใช้ด้วย Google Account
- ลงทะเบียน แสดงรายการ เลือกปลายทาง และเพิกถอนอุปกรณ์ของบัญชีเดียวกัน
- กำหนดปลายทางและเลือกส่งอัตโนมัติหลังสั่งคัดลอกด้วยคีย์ลัด หรือให้ยืนยันก่อนส่ง
- การส่งอัตโนมัติไม่ได้หมายถึงเฝ้าอ่าน Clipboard ทุกอย่างโดยไม่สั่ง และไม่ข้ามคำเตือนข้อมูลอ่อนไหว
- การยืนยันตัวตนบัญชีไม่ทดแทนการตรวจสอบความน่าเชื่อถือของ Public Key ซึ่งยังต้องออกแบบใน protocol

### Temporary Web

- เปิด Session ผ่าน QR Code หรือลิงก์ ไม่ต้องล็อกอินบัญชีส่วนตัวบนเครื่องชั่วคราว
- ส่งและรับ Text/URL/Image/Single File ได้ตามสิทธิ์ของ Session
- ใช้ Random Session ID 128 บิต และ Random Session Secret 256 บิต
- Secret อยู่เฉพาะฝั่ง Client ที่ร่วม Session ไม่ส่งไป Backend และไม่เก็บใน LocalStorage/SessionStorage
- Session มีอายุจำกัดและเพิกถอนได้
- เส้นทาง Native ↔ Native และ Native ↔ Temporary Web อยู่ในแผน; Web ↔ Web และการส่งข้ามบัญชียังไม่สรุป

## 3. ชนิดข้อมูล

ขอบเขตแรก: ข้อความรวม Code snippet, URL, รูปภาพ และไฟล์เดี่ยว

- รูปภาพต้องแยกข้อมูลภาพจริงออกจากข้อความ path
- ไฟล์ต้องส่ง bytes ให้ครบและสร้างสำเนาในเครื่องรับก่อนนำไปวาง ไม่ใช่ส่ง file URI ของเครื่องต้นทางอย่างเดียว
- PDF/เสียงสามารถเป็นไฟล์เดี่ยวได้ แต่ไม่หมายถึงมีตัวอ่าน PDF, OCR หรือระบบอัดเสียงเฉพาะ
- วางได้เฉพาะแอป/ช่อง/ตัวจัดการไฟล์ที่รองรับชนิดข้อมูลนั้น มี Open/Save/Share เป็นทางเลือก
- หลายไฟล์ โฟลเดอร์ ZIP/TAR, Rich text/HTML และ Chunk/Resume ยังไม่รวมใน milestone แรก
- ขนาดสูงสุด เวลา Timeout และค่า TTL ตัวเลขยังต้องกำหนด ไม่ถือว่า 50 MB เป็นข้อยุติ

## 4. การใช้งานแยกตาม OS

| แพลตฟอร์ม | ส่ง | รับและนำไปใช้ | ข้อจำกัด/สถานะ |
| --- | --- | --- | --- |
| Windows 11 Native | Ctrl+Alt+C คัดลอกข้อมูลที่เลือกเพื่อส่ง หรือส่งจากแอป | Ctrl+Alt+V เตรียม Clipboard แล้ววาง Text/URL/รูป/ไฟล์ในแอปที่รองรับ | คีย์ลัดปรับได้ ต้องไม่ชนคีย์ระบบและไม่ส่ง Clipboard เก่า |
| macOS Native | Option+C คัดลอกเพื่อส่ง หรือส่งจากแอป | Option+V วางรายการที่รับ | ต้องได้รับสิทธิ์ที่จำเป็นจากผู้ใช้; รูป/ไฟล์ขึ้นกับแอปปลายทาง |
| Ubuntu 24.04 GNOME X11/Xorg Native | คีย์ลัด Sendviax เช่น Ctrl+Alt+C คัดลอกเพื่อส่ง | Ctrl+Alt+V เตรียม Clipboard และวาง | เลือก X11 เป็นเป้าหมายแรก ไม่อ้างผล Wayland ว่าเป็นผล X11 |
| Android Native | Share Intent, แอป หรือร่างข้อความใน Sendviax Keyboard | Keyboard แทรก Text/URL; รูป/ไฟล์ผ่านแอป | แทรกรูปผ่าน IME เป็นกรณีมีเงื่อนไข ต้องทดสอบแอปเป้าหมาย ไม่รับประกันทุกช่อง |
| iOS/iPadOS Native | Share Extension หรือแอป | Keyboard แทรก Text/URL; รูป Copy จากแอปโดยไม่จำเป็นต้องบันทึก Photos; ไฟล์ Open/Save/Share | Shared inbox, สิทธิ์ และ lifecycle ต้องทดสอบ; การส่งผ่าน iOS Keyboard ยังต้องออกแบบเพิ่ม |
| HarmonyOS | ต้นแบบ Share/แอปและ Pasteboard บน Emulator | ต้นแบบคีย์บอร์ดแทรก Text/URL และ Copy ในแอป | มี Native Probe; ผู้ใช้รายงานว่าเปิด Keyboard ได้เมื่อใช้ Full Mode ยังไม่อ้างรองรับมือถือจริง |
| Temporary Web | กดส่งข้อความ/URL หรือเลือกภาพ/ไฟล์ | กด Copy/Open/Download ตาม Browser | ไม่มี Global shortcut หรือ unrestricted background clipboard |

คีย์ลัดของ Sendviax แยกจาก Ctrl+C/V และ Command+C/V ของระบบ ผู้ใช้ยังเลือกปลายทางที่จะวางเอง ระบบไม่กดส่งข้อความในแอปแชตแทนผู้ใช้

Keyboard เป็น UI สำหรับเข้าถึงรายการ ไม่ใช่หลักฐานว่าแอปรับข้อมูลเบื้องหลังได้ตลอดเวลา ต้องออกแบบการรับรายการ การใช้ข้อมูลร่วมกัน และการรีเฟรชเมื่อเปิด Keyboard โดยเคารพข้อจำกัด OS

## 5. ตรวจข้อมูลอ่อนไหว

- ใช้ Local Rule-based Scanner: รูปแบบ/Regex และการตรวจตามกฎที่กำหนด ก่อนเข้ารหัสและก่อนอัปโหลด
- 7 ประเภทหลัก: Password, Token, API Key, Private Key, Email, เบอร์โทรศัพท์ไทย และเลขบัตรประชาชนไทย
- ตรวจ Text/URL และไฟล์ที่อ่านเป็นข้อความได้ตามรายการรองรับ เช่น TXT, MD, CSV, JSON, XML, YAML และ source code
- ไม่ทำ OCR ไม่ตรวจเนื้อหาไฟล์ binary/PDF ทุกชนิด และต้องระบุ “ไม่ได้ตรวจ” เมื่อไม่รองรับ ไม่แสดงว่า “ปลอดภัย”
- พบความเสี่ยงให้เลือกยกเลิกหรือดำเนินการต่อ ไม่รับประกันตรวจพบความลับทุกแบบ
- OTP, บล็อกด้วยนโยบาย, PIN/Biometric/MFA เป็นข้อเสนออาจารย์ที่ยังไม่เพิ่มเข้าขอบเขตแรก
- ทดสอบด้วยข้อมูลสังเคราะห์ วัด Precision, Recall และ F1 แยกประเภท

## 6. สถาปัตยกรรมและเส้นทางข้อมูล

1. ผู้ส่งเลือกข้อมูล → ตรวจความเสี่ยง → ยืนยันตามนโยบาย → เข้ารหัสในเครื่อง
2. ทดลอง P2P เมื่อเชื่อมต่อโดยตรงใน LAN ได้ ทั้ง Wi-Fi หรือสาย LAN; อยู่ LAN เดียวกันไม่ได้รับประกันว่าจะเชื่อมได้
3. หากเชื่อมตรงไม่ได้ ใช้เส้นทางสำรองแบบเก็บและส่งต่อ Ciphertext ชั่วคราว
4. ผู้รับรับข้อมูล ถอดรหัสพร้อมตรวจ Authentication Tag และเปิดใช้เฉพาะข้อมูลที่ผ่าน
5. ลบสำเนาชั่วคราวตามเงื่อนไขรับสำเร็จ หมดอายุ หรือเพิกถอน

| องค์ประกอบที่เลือก | หน้าที่ |
| --- | --- |
| DigitalOcean VPS | เครื่องรัน Backend; ยังไม่ล็อก tier/ราคาในเอกสารนี้ |
| FastAPI / Python | REST API สำหรับบัญชี อุปกรณ์ รายการส่ง Session และสิทธิ์ |
| WebSocket ผ่าน WSS | แจ้ง presence/รายการใหม่/ความคืบหน้า/สถานะ ไม่ถือว่าเป็นช่องส่ง payload ทั้งหมด |
| PostgreSQL | Metadata ถาวร: users, devices, transfers, transfer_recipients, temporary_sessions |
| Redis | Presence, mapping การเชื่อมต่อ, queue/state ชั่วคราว, TTL และ rate limit; ไม่เก็บ socket object หรือ secret |
| Cloudflare R2 | เก็บ Ciphertext ชั่วคราวในเส้นทาง Relay ไม่ใช่บริการจับคู่หรือ Backend เอง |
| Cleanup worker | ตรวจเงื่อนไขและลบ object พร้อมติดตามการลบ; Redis TTL ไม่ลบ R2 แทน |

เส้นทางสำรองที่ออกแบบ: Client ขอสิทธิ์จาก FastAPI → อัปโหลด Ciphertext ไป R2 → แจ้งสถานะ → ผู้รับขอสิทธิ์ → ดาวน์โหลดจาก R2

ต้องกำหนดสิทธิ์ upload/download, อายุ signed URL และผลของ revoke ก่อนลงมือ ไม่อ้างว่าเพิกถอนลิงก์ที่ออกไปแล้วมีผลทันทีโดยยังไม่ออกแบบ

P2P transport/discovery ที่ Native และ Browser ใช้ร่วมกันยังต้องอนุมัติใน protocol การทดลอง Manual IP/PING-PONG เป็นเพียง connectivity probe ไม่ใช่ข้อยุติว่า Web เปิด raw TCP ได้

## 7. ความปลอดภัยที่ต้องรักษา

- Payload: AES-256-GCM
- Trusted Device: P-256 ECDH + HKDF-SHA-256 เพื่อสร้างกุญแจสำหรับปกป้อง Content Key
- SHA-256 ตาม baseline ใน protocol
- ใช้ crypto library ที่ผ่านการใช้งาน ไม่พัฒนา algorithm เอง
- Private Key อยู่ในอุปกรณ์เสมอ; Backend ไม่รับ plaintext, Secret หรือ Content Key ที่ยังไม่ปกป้อง
- ออกแบบ nonce ไม่ให้ซ้ำภายใต้กุญแจเดียวกัน และกำหนด AAD/encoding/key lifecycle/test vectors ใน protocol ก่อน implementation
- ตรวจ tag เป็นส่วนของ authenticated decryption; ไม่ปล่อย plaintext ที่ไม่ผ่านการรับรอง
- ป้องกัน replay, wrong secret, tampering, session invalid/expired/revoked ตาม protocol ที่ต้องกำหนด
- การเข้ารหัสไม่ทดแทนการรับรอง Public Key และไม่ได้ปกป้องเครื่องปลายทางที่ถูกยึด
- Revoke จำกัดการเข้าถึงในอนาคต ไม่สามารถเรียกคืนข้อมูลที่ผู้รับคัดลอกหรือบันทึกไปแล้ว
- ห้าม log plaintext, credential, access/refresh token, private key, Content Key หรือ Session Secret

## 8. Lifecycle และฐานข้อมูล

สถานะที่วางแผน: pending, available, transferring, completed, failed, expired, revoked

- ต้องกำหนด transition, ACK, timeout, retry และการลบให้ชัดใน protocol
- Upload สำเร็จไม่เท่ากับผู้รับรับครบ และไม่เท่ากับผู้ใช้วางแล้ว
- แบบจำลองนำเสนอมี 5 ตารางตาม [SQL สำหรับ Workbench](docs/database/sendviax_conceptual_schema.sql)
- SQL ดังกล่าวเป็น MySQL สำหรับทำ EER ไม่ใช่ PostgreSQL migration ที่ใช้จริง
- ยังต้องออกแบบ constraint ผู้ส่ง/ผู้รับให้เป็น Device หรือ Session อย่างใดอย่างหนึ่ง, สิทธิ์ session owner, key metadata และ retention
- แบบจำลองยังไม่กำหนดจำนวนผู้รับใน milestone แรก การแยก recipients ไม่ได้ยืนยันว่า multicast พร้อมใช้แล้ว

## 9. Stack และการทำงานร่วมกัน

- Windows: C#/.NET; Apple: Swift/SwiftUI/CryptoKit/Keychain
- Android: Kotlin/Jetpack Compose/Keystore; Probe Java ไม่ใช่ข้อสรุปว่า product เปลี่ยน stack
- Linux: Native client สำหรับ X11; toolkit product ยังต้องเลือก
- HarmonyOS: ArkTS/ArkUI/DevEco Studio
- Web: Next.js/TypeScript/Web Crypto API
- Backend: Python/FastAPI/PostgreSQL/Redis/WSS, Docker สำหรับ environment
- Git monorepo เดียว; /protocol เป็น source of truth; test vectors กลางและ cross-platform tests
- ไม่เพิ่ม dependency/endpoint/schema โดยไม่มีเหตุผล เอกสาร และ migration ตามกรณี

## 10. หลักฐานและการยอมรับงาน

มีเอกสาร เว็บจำลอง และ Native OS probes อยู่แล้ว ไม่ใช่ repository ที่มีแต่เอกสาร แต่ยังไม่ใช้ผลของ probe ยืนยันว่า E2E ส่งข้ามเครื่องเสร็จ

แยกสถานะทุกกรณี: planned / source exists / build verified / emulator observed / physical-device observed / end-to-end verified

- ผลทดสอบเก่าเก็บวัน OS รุ่นเครื่อง แอปปลายทาง และ test ID เดิม ไม่เปลี่ยน FAIL/BLOCKED เป็น PASS จากการคาดการณ์
- HarmonyOS จำกัดข้ออ้างเฉพาะ Emulator ที่ทดสอบ
- ต้องทดสอบส่งข้ามเครื่องจริงทั้ง P2P และ R2 fallback พร้อม Copy/Paste/Open/Save ในแอปปลายทาง
- ทดสอบ Text/URL/Image/File, สิทธิ์, คีย์ชน, stale clipboard, session expiry/revoke/tamper/replay และ cleanup
- Functional, security lifecycle, performance, usability, scanner metrics และ interoperability
- ใช้ synthetic test data เท่านั้น; จำลอง UI/build สำเร็จไม่แทนผล native หรือ network
- เป้าหมายตัวเลข performance/จำนวนรอบ/ชุดแอปต้องตกลงก่อนสรุป PASS ระดับผลิตภัณฑ์

## 11. ข้อเสนออาจารย์ที่ยังไม่รับเป็น milestone แรก

อ้างอิง [รายการอาจารย์](docs/presentation/Teacher_Function_Scope_Reference.md) ไม่ใช่การอ้างว่าอาจารย์ยอมลดรายการแล้ว:

- Accountless trusted pairing, trusted QR invitation/verification, เปลี่ยนชื่อ และจับคู่ใหม่เมื่อ key เปลี่ยน
- Rich text/HTML, หลายไฟล์, โฟลเดอร์, UI audio/voice
- mDNS/DNS-SD discovery, offline encrypted queue
- Chunk/ACK/retry/resume, network switching, progress รายไฟล์, partial success
- History แบบ opt-in, Pin, policy รายรายการ, OTP, PIN/Biometric/MFA
- Context menu, drag/drop, continuous clipboard monitor
- Linux desktop อื่น/Wayland และ HarmonyOS มือถือจริง

ข้อเสนออาจารย์กว้างกว่า milestone แรก โดยเฉพาะ offline/resume/multi-file ต้องแจ้งความต่าง ไม่เรียกรวมว่าเป็น “ส่วนเสริมที่อาจารย์ไม่บังคับ” โดยไม่มีการยืนยัน

## 12. ไม่อยู่ในขอบเขต

Cloud Drive/เก็บถาวร, Chat, Remote Desktop, unrestricted background clipboard ทุก OS, malware scanning, OCR, custom crypto และทดสอบด้วยความลับจริง

รายการอนาคตไม่ใช่การอนุมัติให้ implement โดยอัตโนมัติ การแก้เอกสารนี้ไม่ใช่การอนุมัติเปลี่ยน protocol หรือรับรองความปลอดภัยของระบบที่ยังไม่ทดสอบ
