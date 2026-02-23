# TextPaste iOS App

SwiftUI app that connects to your local TextPaste server, displays all saved records, and lets you **copy + auto-delete** entries — same behaviour as the web app.

## Setup

### 1. Get an auth token

Start the server, then run:

```bash
curl -s -X POST http://localhost:3000/api/login \
  -H "Content-Type: application/json" \
  -d '{"password":"YOUR_APP_PASSWORD"}' | jq -r .token
```

Copy the token that is printed.

### 2. Paste the token into the app

Open `TextPaste/ContentView.swift` and replace the placeholder on this line:

```swift
static let authToken = "REPLACE_WITH_YOUR_TOKEN"
```

You can also change `baseURL` if your server runs on a different host/port.

### 3. Open in Xcode

```bash
open ios-app/TextPaste/TextPaste.xcodeproj
```

Select a simulator or device and press **⌘R** to run.

> **Note:** The `Info.plist` already includes `NSAppTransportSecurity` exceptions for `localhost` so HTTP requests to the local server work in the simulator.

## Features

| Feature | Detail |
|---|---|
| Records list | Grouped by date, newest first |
| Copy text | Taps copy the content to the iOS clipboard |
| Auto-delete | After copying, the record is deleted from the server |
| Pagination | 10 records per page with prev / next controls |
| Pull-to-refresh | Tap the ↻ button in the nav bar |
| Token auth | `x-auth-token` header sent on every request |
