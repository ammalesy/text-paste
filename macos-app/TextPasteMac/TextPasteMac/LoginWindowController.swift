// LoginWindowController.swift
import AppKit

// ─────────────────────────────────────────────
// MARK: - Login Window Controller
// ─────────────────────────────────────────────

final class LoginWindowController: NSWindowController {

    // UI elements
    private let passwordField = NSSecureTextField()
    private let loginButton   = NSButton()
    private let statusLabel   = NSTextField()
    private let spinner       = NSProgressIndicator()

    convenience init() {
        // Create window programmatically (no XIB needed)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
            styleMask:   [.titled, .closable, .miniaturizable],
            backing:     .buffered,
            defer:       false
        )
        window.title = "TextPaste — เข้าสู่ระบบ"
        window.center()
        self.init(window: window)
        buildUI()
    }

    // ─────────────────────────────────────────
    // MARK: - Build UI
    // ─────────────────────────────────────────

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        // App icon label
        let iconLabel = NSTextField(labelWithString: "📋")
        iconLabel.font = .systemFont(ofSize: 48)
        iconLabel.alignment = .center
        iconLabel.frame = NSRect(x: 130, y: 190, width: 100, height: 56)
        contentView.addSubview(iconLabel)

        // Title
        let titleLabel = NSTextField(labelWithString: "TextPaste")
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 80, y: 165, width: 200, height: 24)
        contentView.addSubview(titleLabel)

        // Subtitle
        let subtitle = NSTextField(labelWithString: "กรอกรหัสผ่านเพื่อเข้าใช้งาน")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.frame = NSRect(x: 40, y: 142, width: 280, height: 18)
        contentView.addSubview(subtitle)

        // Password field
        passwordField.placeholderString = "รหัสผ่าน"
        passwordField.frame = NSRect(x: 40, y: 104, width: 280, height: 28)
        passwordField.target = self
        passwordField.action = #selector(doLogin)
        contentView.addSubview(passwordField)

        // Status label (error message)
        statusLabel.isEditable = false
        statusLabel.isBezeled  = false
        statusLabel.drawsBackground = false
        statusLabel.textColor  = .systemRed
        statusLabel.font       = .systemFont(ofSize: 11)
        statusLabel.alignment  = .center
        statusLabel.frame = NSRect(x: 40, y: 80, width: 280, height: 18)
        contentView.addSubview(statusLabel)

        // Spinner
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.frame = NSRect(x: 30, y: 44, width: 20, height: 20)
        contentView.addSubview(spinner)

        // Login button
        loginButton.title  = "เข้าสู่ระบบ"
        loginButton.bezelStyle = .rounded
        loginButton.keyEquivalent = "\r"
        loginButton.frame  = NSRect(x: 56, y: 40, width: 248, height: 32)
        loginButton.target = self
        loginButton.action = #selector(doLogin)
        contentView.addSubview(loginButton)
    }

    // ─────────────────────────────────────────
    // MARK: - Actions
    // ─────────────────────────────────────────

    @objc private func doLogin() {
        let pw = passwordField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !pw.isEmpty else { return }

        setLoading(true)
        statusLabel.stringValue = ""

        Task {
            do {
                let token = try await APIClient.shared.login(password: pw)
                KeychainHelper.save(token)
                await MainActor.run {
                    self.setLoading(false)
                    self.close()
                    // แจ้งว่า login สำเร็จ
                    AppDelegate.shared?.onLoginSuccess()
                }
            } catch {
                await MainActor.run {
                    self.setLoading(false)
                    self.statusLabel.stringValue = error.localizedDescription
                    self.passwordField.stringValue = ""
                    self.window?.makeFirstResponder(self.passwordField)
                }
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        loginButton.isEnabled = !loading
        passwordField.isEnabled = !loading
        loading ? spinner.startAnimation(nil) : spinner.stopAnimation(nil)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(passwordField)
    }
}
