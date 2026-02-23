// TextPasteMacApp.swift
import AppKit

// ─────────────────────────────────────────────
// MARK: - Entry Point
// ─────────────────────────────────────────────

// Keep a strong reference at file scope so AppDelegate is never deallocated
private let appDelegate = AppDelegate()

@main
struct TextPasteMacApp {
    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.run()
    }
}
