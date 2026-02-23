# TextPaste macOS App

macOS helper app ที่เพิ่ม **"Copy to TextPaste"** เข้า Services menu (คลิกขวาบน selected text ใดก็ได้)

## วิธีทำงาน

1. คลุม text ใน app ใดก็ได้ (Safari, Notes, Terminal, …)
2. คลิกขวา → **Services → Copy to TextPaste**
3. Text จะถูก POST ไปที่ TextPaste server ทันที

## โครงสร้าง

```
TextPasteMac/
├── TextPasteMacApp.swift       — entry point (menu-bar only, no Dock icon)
├── AppDelegate.swift           — NSApplicationDelegate + login window
├── LoginWindowController.swift — หน้า login
├── StatusBarController.swift   — icon บน menu bar
├── ServiceHandler.swift        — รับ text จาก Services menu แล้วส่ง API
├── KeychainHelper.swift        — เก็บ/อ่าน token
├── APIClient.swift             — login / save
├── Config.swift                — baseURL
├── Info.plist
└── TextPasteMac.entitlements
```

## วิธี Build

1. เปิด `TextPasteMac.xcodeproj` ใน Xcode
2. ตั้ง Team ใน Signing & Capabilities
3. **Product → Build** แล้วรัน
4. ครั้งแรกให้ login ด้วยรหัสผ่าน server
5. macOS จะขึ้น prompt ขอ Accessibility permission ครั้งแรก

## Activate Services

หากเมนู Services ยังไม่ขึ้น ให้รัน:

```bash
/System/Library/CoreServices/pbs -update
```

แล้ว logout/login macOS ครั้งเดียว
