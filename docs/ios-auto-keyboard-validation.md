# iOS automatic keyboard — 22 กันยายน 2026

ผู้ใช้อนุมัติการรับผ่าน Keyboard ขณะเปิด และ shared Keychain ชั่วคราว ตาม `protocol/test-v0.md` ส่วน iOS automatic keyboard inbox ไม่รวม APNs/background push ไม่เปลี่ยน wire format หรือ crypto และไม่ใช่รุ่น production-ready

## สิ่งที่ทำ

- สร้าง/เข้าห้องในแอปครั้งเดียว App และ Keyboard ใช้ห้องเดียวกันผ่าน Keychain access group แบบ WhenUnlockedThisDeviceOnly ไม่ sync และไม่เก็บ Secret/capability ใน App Group
- Keyboard ขอ Full Access สำหรับเครือข่าย/ข้อมูลร่วม รับทุกประมาณ 2 วินาทีขณะเปิด หยุดและยกเลิก request เมื่อซ่อน; ไม่อนุญาต Full Access ก็ยังพิมพ์ได้
- Shared inbox protected/backup-excluded สูงสุด 20 รายการ/20 MiB ถอดรหัสตรวจ tag ก่อนบันทึกและ ACK มี file lock, generation และ replay IDs ป้องกันสอง process รับซ้ำ Clear inbox ไม่ล้าง replay IDs
- อายุรายการไม่เกิน 5 นาที ไม่เลย envelope/ห้อง ใช้ continuous monotonic time ที่รวมเวลาหลับ ตรวจใหม่ก่อนใช้ Reboot ล้างห้องในการเข้าถึงครั้งถัดไป ไม่กล่าวอ้างว่าระบบลบไฟล์ได้ขณะ iOS suspend ทุก process
- Keyboard แสดงจำนวนรายการ ตัวอย่างข้อความ และ thumbnail รูป ข้อความ/URL ไม่เกิน 64 KiB แตะแทรกได้ ภาพ PNG/JPEG/WebP ไม่เกิน 5 MiB, ด้านละ 8192 พิกเซลและ 32 ล้านพิกเซล แตะคัดลอกแบบ local-only มี expiry แล้ววางเองในแอปที่รองรับ ไฟล์ทั่วไปใช้แอปหลัก
- จำกัด HTTP response ของ Keyboard 12 MiB ตั้งแต่รับ chunk; คิวใหญ่กว่านี้ให้เปิดแอปเพื่อรับ ไม่ ACK ข้อมูลที่ยังไม่ได้บันทึก ข้อความที่พิมพ์ในแอปอื่น/clipboard ไม่ถูกอ่านหรือส่ง

## ลงบน iPhone

1. เปิด `apple/mobile/Sendviax.xcodeproj` ใน Xcode เลือก iPhone และ Development Team ของผู้ใช้ทั้ง 3 targets
2. Signing & Capabilities: App Groups เดียวกันทั้ง Sendviax, SendviaxKeyboard และ SendviaxShare (`group.dev.sendviax.mobile`) ถ้าทีมต้องเปลี่ยนชื่อให้แก้ entitlements ทั้งสามและ `SharedInbox.group` ให้ตรง
3. เพิ่ม Keychain Sharing เฉพาะ Sendviax และ SendviaxKeyboard กลุ่ม `$(AppIdentifierPrefix)dev.sendviax.mobile.session` และ Info.plist ค่า `SendviaxKeychainGroup` ตรงกัน โปรเจกต์มีค่าเหล่านี้แล้ว แต่ทีมต้อง provision สิทธิ์จริง ไม่เพิ่มให้ Share target
4. Run ลงเครื่อง ไป Settings → General → Keyboard → Keyboards → Add New Keyboard → Sendviax Keyboard จากนั้นเปิด Allow Full Access
5. เปิดเว็บที่ Relay ใช้งานอยู่ สร้างห้อง คัดลอกลิงก์เชิญ วางในแอป iPhone เพื่อเข้าร่วม ไม่ต้องกรอก URL อีกครั้ง
6. สลับไป Notes หรือแอปปลายทาง เลือก Sendviax Keyboard จากปุ่มโลก แล้วส่งข้อความ/รูปจากเว็บ รายการควรปรากฏโดยไม่กลับเข้าแอปหลัก ข้อความแตะแทรก รูปแตะคัดลอกแล้วแตะค้างเลือกวาง

โปรเจกต์ยังไม่มี DEVELOPMENT_TEAM จึงยังไม่มี signed IPA และยังไม่ได้ยืนยันการใช้ App Group/Keychain บน iPhone จริง ผล build แบบ CODE_SIGNING_ALLOWED=NO ไม่แทนผล provisioning หรือการติดตั้งบนเครื่อง

## ตรวจซ้ำ

```sh
sh scripts/build-mobile.sh ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
  -module-cache-path apple/mobile/build/ModuleCache -parse-as-library \
  apple/mobile/Shared.swift apple/mobile/tests/SharedChannelTests.swift \
  -o apple/mobile/build/shared-channel-tests
# รัน Relay แยก terminal (ไม่มี public tunnel)
backend/.venv/bin/python -m uvicorn backend.app:app --host 127.0.0.1 --port 8017 --no-access-log
# รัน HTTP fixture อีก terminal
backend/.venv/bin/python apple/mobile/tests/network_fixture.py
# ใช้ synthetic data / test vault ใน RAM ไม่แตะ Keychain ส่วนตัว
apple/mobile/build/shared-channel-tests http://127.0.0.1:8017 http://127.0.0.1:8018
```

Host tests ใช้ SharedChannel/SharedReceiver/Wire/Relay ตัวเดียวกับ iOS แต่จำลอง Keychain และเวลา ทดสอบ two-client shared bytes, duplicate/clear/replay, expiry/reboot, stale response/401, record/byte quota, credential isolation, orphan cleanup, file-lock contention, image validation, HTTP text/image→inbox→ACK/revoke, response cap, redirect และ cancellation ไม่ถือเป็นผล iOS UI หรือ physical-device E2E

## ต้องตรวจบนเครื่องจริง

ผลรอบนี้: **PASS** build ทั้ง 3 targets บน iOS Simulator SDK 27.0 แบบไม่เซ็น, shared-inbox/HTTP/network-boundary tests บน macOS host, Swift crypto vectors และ 8 HTTP transfers รวมไฟล์ 5 MiB สองทิศทาง, Swift → Web fixtures สี่ชนิด ข้อจำกัด: fake Keychain ใน host tests; ยังไม่ได้ทดสอบ keyboard UI/Full Access, Keychain provisioning หรือ copy/paste ในแอปปลายทางบน iPhone จริง

- Signed App Group/Keychain ใช้ร่วมกันได้ทั้ง app/extension; ไม่เปิด Full Access ยังพิมพ์ได้และไม่รับข้อมูล
- ส่งจากเว็บผ่านต่างเครือข่ายขณะที่เปิด Keyboard ใน Notes/แอปแชต โดย app หลักอยู่เบื้องหลัง
- ข้อความไทย/URL แทรกถูกต้อง รูป copy/paste ทำงานในแต่ละแอป ไม่อ้างรองรับทุกช่อง
- เปลี่ยนคีย์บอร์ด/ซ่อน/ล็อกเครื่อง/force-quit/reboot/ปิด Full Access หยุดรับตาม lifecycle; ข้อมูลหมดอายุหรือห้องถูกปิดไม่กลับมาใช้ซ้ำ
- ทดสอบหน่วยความจำ Keyboard สำหรับภาพ 5 MiB และคิวหลายรายการบนอุปกรณ์จริง iOS อาจยุติ extension ที่ใช้หน่วยความจำมาก

อ้างอิง Apple: [Open Access](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard), [Keychain Sharing](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps), [WhenUnlockedThisDeviceOnly](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly).
