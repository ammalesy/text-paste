// ServiceHandler.swift
//
// NSServiceProvider — macOS เรียก performPaste(_:userData:error:)
// เมื่อผู้ใช้เลือก Services → "Copy to TextPaste"
//
import AppKit
import UserNotifications
import OSLog

private let logger = Logger(subsystem: "com.textpaste.mac", category: "ServiceHandler")

// ─────────────────────────────────────────────
// MARK: - Service Handler
// ─────────────────────────────────────────────

final class ServiceHandler: NSObject {

    /// macOS จะเรียก method นี้เมื่อผู้ใช้เลือก Services > "Copy to TextPaste"
    /// ชื่อ selector ต้องตรงกับ NSMessage ใน Info.plist
    @objc func performPaste(_ pboard: NSPasteboard,
                            userData: String?,
                            error: AutoreleasingUnsafeMutablePointer<NSString?>?) {
        logger.debug("▶︎ performPaste called")

        guard let text = pboard.string(forType: .string), !text.isEmpty else {
            logger.warning("⚠︎ no text on pasteboard")
            showNotification(title: "TextPaste", body: "ไม่พบข้อความที่เลือก")
            return
        }

        logger.debug("▶︎ text to save: \(text, privacy: .private)")

        Task {
            guard let token = KeychainHelper.load() else {
                logger.warning("⚠︎ no token — opening login")
                await MainActor.run { AppDelegate.shared?.showLoginWindow() }
                return
            }

            do {
                try await APIClient.shared.save(text: text, token: token)
                logger.info("✓ saved successfully")
                showNotification(title: "TextPaste ✓", body: "บันทึกสำเร็จ")
            } catch APIError.unauthorized {
                logger.warning("⚠︎ token expired — opening login")
                KeychainHelper.delete()
                await MainActor.run { AppDelegate.shared?.showLoginWindow() }
            } catch {
                logger.error("✗ save failed: \(error.localizedDescription)")
                showNotification(title: "TextPaste ✗", body: error.localizedDescription)
            }
        }
    }

    /// Debug helper — call from menu bar to test without selecting text
    func debugSendTestText() {
        logger.debug("▶︎ debugSendTestText called")
        let pboard = NSPasteboard.general
        pboard.clearContents()
        pboard.setString("🧪 Test from TextPaste debug \(Date())", forType: .string)
        performPaste(pboard, userData: nil, error: nil)
    }

    // ─────────────────────────────────────────
    // MARK: - Notification helper
    // ─────────────────────────────────────────

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}
