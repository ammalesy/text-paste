// StatusBarController.swift
import AppKit
import OSLog

private let logger = Logger(subsystem: "com.textpaste.mac", category: "StatusBar")

// ─────────────────────────────────────────────
// MARK: - Status Bar Controller
// ─────────────────────────────────────────────

final class StatusBarController: NSObject {   // ← NSObject เพื่อให้ target/action ทำงานได้
    private var statusItem: NSStatusItem!

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "TextPaste")
            button.image?.isTemplate = true  // adapts to dark/light menu bar
        }

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        // Status item (logged-in or not)
        let statusMenuItem = NSMenuItem(title: statusTitle(), action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        // 🧪 Debug: Send test text
        #if DEBUG
        let debugItem = NSMenuItem(title: "🧪 Debug: Send test text",
                                   action: #selector(debugSend),
                                   keyEquivalent: "t")
        debugItem.target = self
        menu.addItem(debugItem)
        menu.addItem(.separator())
        #endif

        // Login / Logout
        if KeychainHelper.load() != nil {
            menu.addItem(withTitle: "ออกจากระบบ",
                         action: #selector(AppDelegate.logout),
                         keyEquivalent: "")
                .target = NSApp.delegate
        } else {
            menu.addItem(withTitle: "เข้าสู่ระบบ…",
                         action: #selector(AppDelegate.showLogin),
                         keyEquivalent: "")
                .target = NSApp.delegate
        }

        menu.addItem(.separator())

        menu.addItem(withTitle: "ออกจาก TextPaste",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")

        statusItem.menu = menu
    }

    #if DEBUG
    @objc private func debugSend() {
        logger.debug("▶︎ Debug menu: debugSend tapped")
        AppDelegate.shared?.serviceHandler.debugSendTestText()
    }
    #endif

    /// Call this to rebuild the menu (e.g. after login/logout)
    func refresh() {
        buildMenu()
    }

    private func statusTitle() -> String {
        if KeychainHelper.load() != nil {
            return "✓ เชื่อมต่อแล้ว"
        }
        return "⚠ ยังไม่ได้เข้าสู่ระบบ"
    }
}
