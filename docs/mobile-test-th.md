# Sendviax iOS / Android — รุ่นทดลอง test-v0

สถานะ 21 กันยายน 2026: SwiftUI และ Kotlin/Compose พร้อม source, build ผ่านทั้งสองแพลตฟอร์ม มี Keyboard และ Share Extension/Intent การทดสอบ core ไม่ใช่หลักฐานว่าทดสอบบนมือถือจริงหรือผ่าน App Store/Play Store แล้ว

## เริ่มทดลอง

1. เปิดเว็บและ Relay บน Mac: `sh scripts/run-relay-test.sh`
2. เปิด HTTPS Tunnel: `cloudflared tunnel --url http://127.0.0.1:3000 --no-autoupdate`
3. แอปอ่านเซิร์ฟเวอร์จากลิงก์เชิญอัตโนมัติ จึงไม่ต้องกรอก Relay URL ก่อนเข้าร่วม ใช้เฉพาะลิงก์จากเครื่องที่ไว้ใจ
4. ฝั่งหนึ่งสร้างห้อง แล้วคัดลอกลิงก์เชิญไปวางในแอปอีกเครื่อง หรือเปิดลิงก์ในเว็บ แอปใช้ค่าเซิร์ฟเวอร์ตอน build สำหรับปุ่มสร้างห้อง เปลี่ยนได้ใน “ตั้งค่าเซิร์ฟเวอร์” หาก Quick Tunnel เปลี่ยน URL
5. ส่งข้อความ ลิงก์ รูปภาพ หรือไฟล์เดี่ยวไม่เกิน 5 MiB ยืนยันส่ง เปิดแอปรับค้างไว้แล้วตรวจรายการ / SHA-256
6. ทดลองกลับทิศทาง และลองให้เครื่องหนึ่งใช้ Wi-Fi อีกเครื่องใช้เน็ตมือถือ จึงจะยืนยันต่างเครือข่ายจริงได้

ใช้ข้อมูลสังเคราะห์เท่านั้น ห้องมีอายุ 15 นาที รายการบน Relay 5 นาที Android ปิด process แล้วต้องเชื่อมต่อใหม่; iOS รุ่น 0.2 เก็บสิทธิ์ห้องชั่วคราวใน Keychain ของเครื่องจนหมดอายุหรือออกจากห้อง ไม่มี Google login / Trusted Device / P2P / R2 ในรุ่นนี้

## Android

ตั้ง Relay เริ่มต้นของแอปก่อน build ทั้ง Android/iOS (เป็น URL สาธารณะ ไม่มี secret):

```sh
SENDVIAX_RELAY_URL=https://ชื่อที่ได้.trycloudflare.com sh scripts/build-mobile.sh all
```

หากไม่กำหนดค่า ต้องตั้งเซิร์ฟเวอร์ก่อนสร้างห้อง แต่ยังวางลิงก์เชิญเพื่อเข้าร่วมได้ทันที ค่า Quick Tunnel ใช้ได้เฉพาะขณะที่ tunnel นั้นทำงาน; เมื่อมี hostname ถาวรที่ชี้มายัง Relay แล้ว ให้ใช้ hostname นั้นตอน build แทน

- เปิดโปรเจกต์ `android/` ใน Android Studio หรือ `sh scripts/build-mobile.sh android`
- ต้องใช้ JDK 17, Android SDK 35; Gradle wrapper ดาวน์โหลด dependencies จาก Google/Maven Central
- APK: `outputs/mobile/Sendviax-android-test.apk` หรือ `android/app/build/outputs/apk/debug/app-debug.apk`
- Package: `dev.sendviax.mobile`, minSdk 26 (Android 8); ยังไม่รับรองผลทดสอบ Android ทุกเวอร์ชัน
- เป็น debug APK สำหรับทดสอบ ไม่ใช่ release ที่เผยแพร่ใน Play Store
- ดาวน์โหลด APK บนมือถือ แล้วเลือกติดตั้ง หากเครื่องถามอนุญาตติดตั้งจากแหล่งนี้ ให้ผู้ใช้ตรวจชื่อและอนุญาตเอง
- หากใช้ ADB: `adb install -r outputs/mobile/Sendviax-android-test.apk`
- คีย์บอร์ด: หน้า “คีย์บอร์ด” → “เปิดใช้งานคีย์บอร์ด” → เปิด Sendviax → กลับมาเลือก Sendviax Keyboard
- รุ่น 0.2: สร้างหรือเข้าห้องครั้งเดียว แล้วสลับไปแอปปลายทางได้ บริการรับเบื้องหลังมีแจ้งเตือนพร้อมปุ่ม “หยุดรับ”; ข้อความ ลิงก์ และภาพ PNG/JPEG/WebP จะเข้ารายการ Keyboard อัตโนมัติ ไม่ต้องกด “ใช้ในคีย์บอร์ด” ในแอปหลัก
- อนุญาตการแจ้งเตือนเพื่อเห็นสถานะรับเบื้องหลังและปุ่มหยุด หากปฏิเสธ Android อาจแสดงบริการเฉพาะหน้าจัดการแอปที่ทำงานอยู่
- Keyboard แสดงจำนวนรายการและตัวอย่างรายการล่าสุดขณะพิมพ์ แตะ “รายการ” เพื่อเลือกแทรก ข้อความไม่เกิน 64 KiB; ภาพไม่เกิน 5 MiB และ 32 ล้านพิกเซล ด้านละไม่เกิน 8192 พิกเซล รูปใช้ commitContent เฉพาะช่องที่ประกาศรองรับ MIME นั้น ไม่รับประกันทุกแอป
- Inbox เก็บเฉพาะ RAM สูงสุด 20 รายการ/20 MiB decoded bytes อายุไม่เกิน 5 นาทีและไม่เลยอายุห้อง ปิดห้อง/หยุดรับ/ถูกเพิกถอนแล้วล้าง ไม่มีการอ่านคลิปบอร์ดหรือเครือข่ายจากตัว Keyboard
- รูปใช้ read-only content provider ใน RAM พร้อมสิทธิ์อ่านเฉพาะ URI ที่แทรก ไม่สร้างไฟล์ plaintext cache; ไฟล์ทั่วไปใช้ “บันทึกไฟล์” จากแอป
- บริการหยุดเมื่อห้องหมดอายุ 15 นาที หรือ Android ยุติ/timeout หาก process ถูกฆ่าหรือ force-stop ต้องเข้าห้องใหม่ ไม่เริ่มเองหลัง reboot และไม่อ้างว่ารับได้ตลอดเวลาเมื่อระบบจำกัดเครือข่าย
- Share Intent รับข้อความ/ลิงก์/รูป/ไฟล์เป็นร่าง ต้องยืนยันในแอปก่อนส่ง

## iOS / iPadOS

- เปิด `apple/mobile/Sendviax.xcodeproj` ใน Xcode
- มี 3 targets: Sendviax, SendviaxKeyboard, SendviaxShare
- Simulator: `sh scripts/build-mobile.sh ios`; build อยู่ที่ `apple/mobile/build/Build/Products/Debug-iphonesimulator/Sendviax.app`
- ลง iPhone จริง: เลือก Apple Development Team ใน Signing & Capabilities ของทั้งสาม targets แล้วเลือก iPhone กด Run ต้องมี provisioning ที่รองรับ App Groups
- ตั้ง App Group **เดียวกัน** ทั้งสาม targets และแก้ `SharedInbox.group` ใน Shared.swift ให้ตรง ปัจจุบันคือ `group.dev.sendviax.mobile`
- รุ่น 0.2 ต้องมี App Group และ Keychain Sharing ที่ใช้งานได้จึงเชื่อมต่อห้องได้ ไม่มี fallback เก็บ Secret ในไฟล์ หากบัญชี/ทีมไม่รองรับ ให้ใช้เว็บทดสอบก่อน
- ไม่ได้สร้าง IPA ที่ลงเครื่องได้ เพราะยังไม่มีทีม signing/provisioning ของผู้ใช้
- Settings → General → Keyboard → Keyboards → Add New Keyboard → Sendviax Keyboard
- เปิด Sendviax Keyboard → Allow Full Access เพื่อให้ Keyboard รับข้อมูลผ่าน Relay ขณะปรากฏบนหน้าจอ รุ่น 0.2 ตั้ง RequestsOpenAccess=true; หากไม่เปิดยังพิมพ์ได้ แต่ใช้รายการร่วมและเครือข่ายไม่ได้
- เพิ่ม Keychain Sharing ให้เฉพาะ Sendviax และ SendviaxKeyboard ใช้กลุ่ม `$(AppIdentifierPrefix)dev.sendviax.mobile.session` ตรงกัน และค่า SendviaxKeychainGroup ใน Info.plist ตรงกับ entitlement; Share Extension ไม่มีสิทธิ์กลุ่มนี้
- สร้าง/เข้าห้องในแอปครั้งเดียว แล้วสลับไป Keyboard → รายการ ข้อความ/ลิงก์แตะแทรกได้ รูป PNG/JPEG/WebP ที่ผ่านการตรวจแตะคัดลอกแล้ววางเองในแอปที่รองรับ
- ดูขั้นตอนและผลทดสอบ [iOS automatic keyboard](ios-auto-keyboard-validation.md)
- ช่องรหัสผ่าน/บางแอปใช้คีย์บอร์ดระบบแทนตามข้อจำกัด iOS
- รับเมื่อเปิดแอปหรือเปิด Keyboard เท่านั้น ไม่มี APNs/background push ไม่อ้างว่ารับได้ตลอดเวลาขณะทั้งสองปิด
- Share Extension รุ่นนี้รับ Text/URL ก่อน รูปและไฟล์ให้เลือกจากแอปหลัก
- ไฟล์ทั่วไปใช้ Share sheet เพื่อ Save/Open; รูปใน Keyboard ใช้ clipboard แบบ local-only มีวันหมดอายุ ไม่มีการอ่านคลิปบอร์ด

## คีย์บอร์ดทั้งสองระบบ

แป้นไทย/อังกฤษ, Shift, ตัวเลข/สัญลักษณ์, Backspace, Space, Newline, ปุ่มเปลี่ยนคีย์บอร์ด และแท็บรายการสำหรับแตะแทรก Text/URL รายการต้องไม่เกิน 64 KiB มีอายุไม่เกิน 5 นาที ไม่อ่าน host document/clipboard ไม่เก็บประวัติการพิมพ์ ไม่มี auto-correct, prediction, swipe typing หรือ dictation ในรุ่นนี้

ทั้ง Android และ iOS รุ่น 0.2 แสดงรายการที่รับในคีย์บอร์ดอัตโนมัติหลังเชื่อมต่อห้อง โดย iOS ต้องเปิด Keyboard และ Allow Full Access ปุ่ม Newline ไม่สั่งส่งข้อความในแอปแชตแทนผู้ใช้ ข้อมูลที่แทรกหรือถูกแอปปลายทางอ่านแล้วไม่สามารถเรียกคืนได้

iOS เก็บข้อมูลที่ได้รับใน App Group ด้วย complete file protection และ exclude from backup สูงสุด 20 รายการ/20 MiB ตรวจ continuous monotonic deadline ที่รวมเวลาหลับก่อนอ่าน/แทรก ข้อมูลห้องอยู่เฉพาะ shared Keychain แบบ WhenUnlockedThisDeviceOnly ไม่เข้าไฟล์หรือ iCloud เมื่อออกจากห้อง/พบ revoke/หมดอายุจะล้าง เมื่อ reboot ต้องเชื่อมต่อใหม่ หากทั้งแอปและ extension หยุดทำงาน การลบทางกายภาพรอการเปิดครั้งถัดไป แต่ข้อมูลที่หมดอายุจะใช้ไม่ได้

## การทดสอบที่ทำซ้ำได้

```sh
node --experimental-strip-types web/tests/mobile-conformance.mjs generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -module-cache-path apple/mobile/build/ModuleCache -parse-as-library \
  apple/mobile/Shared.swift apple/mobile/tests/Conformance.swift \
  -o apple/mobile/build/conformance
apple/mobile/build/conformance "$PWD" http://127.0.0.1:8000
# ต้องกำหนด JAVA_HOME เป็น JDK 17 และ ANDROID_HOME ก่อน
SENDVIAX_TEST_ORIGIN=http://127.0.0.1:8000 sh android/gradlew -p android testDebugUnitTest --rerun-tasks
node --experimental-strip-types web/tests/mobile-conformance.mjs verify
```

ตรวจ HKDF/AES-GCM/AAD กับ vector กลาง, wrong key, tamper, expiry, wrong recipient, oversized payload, base64 canonical; Web → Native → Web สี่ประเภท รวม 5 MiB; HTTP core ส่งแปดกรณีต่อแพลตฟอร์ม, ACK และ revoke. ไฟล์ใน outputs/mobile-tests เป็นข้อมูลสังเคราะห์ที่เปิดเผยได้ ไม่มีสิทธิ์ห้องจริง

Dependencies เพิ่ม: AndroidX Compose/Activity/Lifecycle สำหรับ native UI และ lifecycle; Tink Android ใช้ HKDF ที่ผ่านการใช้งาน AES-GCM ใช้ JCA ของระบบ ส่วน iOS ใช้ SwiftUI/UIKit/CryptoKit/Foundation ของ Apple ไม่มี third-party runtime
