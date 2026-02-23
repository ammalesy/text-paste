// AppDelegate.swift
import AppKit
import UserNotifications

// ─────────────────────────────────────────────
// MARK: - App Delegate
// ─────────────────────────────────────────────

final class AppDelegate: NSObject, NSApplicationDelegate {

    // Strong singleton — retained for entire app lifetime
    static var shared: AppDelegate?

    let serviceHandler            = ServiceHandler()
    private let statusBarCtrl     = StatusBarController()
    private var loginWindowCtrl: LoginWindowController?

    // ─────────────────────────────────────────
    // MARK: - App Lifecycle
    // ─────────────────────────────────────────

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        // Must be set here (before run loop starts) for NSServices to work
        NSApp.servicesProvider = serviceHandler
    }

    func applicationDidFinishLaunching(_ notification: Notification) {

        // Build the menu-bar icon
        statusBarCtrl.setup()

        // Request notification permission (for save feedback)
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // If no saved token, open login right away
        if KeychainHelper.load() == nil {
            showLoginWindow()
        } else {
            // Verify token in background; show login if expired
            Task {
                guard let token = KeychainHelper.load() else { return }
                let valid = await APIClient.shared.verifyToken(token)
                if !valid {
                    KeychainHelper.delete()
                    await MainActor.run { self.showLoginWindow() }
                }
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: - Login / Logout
    // ─────────────────────────────────────────

    func showLoginWindow() {
        if loginWindowCtrl == nil {
            loginWindowCtrl = LoginWindowController()
        }
        loginWindowCtrl?.showWindow(nil)
    }

    func onLoginSuccess() {
        loginWindowCtrl = nil
        statusBarCtrl.refresh()
    }

    // Called from menu bar "เข้าสู่ระบบ…"
    @objc func showLogin() {
        showLoginWindow()
    }

    // Called from menu bar "ออกจากระบบ"
    @objc func logout() {
        KeychainHelper.delete()
        statusBarCtrl.refresh()
    }
}
