// ServiceEnabler.swift
//
// อ่าน/เขียน com.apple.ServicesMenu.Services.plist โดยตรง
// เพื่อ enable "Copy to TextPaste" อัตโนมัติตอน app launch
//
import AppKit
import OSLog

private let logger = Logger(subsystem: "com.textpaste.mac", category: "ServiceEnabler")

enum ServiceEnabler {

    private static let prefsKey  = "com.apple.ServicesMenu.Services"
    private static let menuTitle = "Copy to TextPaste"

    // ─────────────────────────────────────────
    // MARK: - Public
    // ─────────────────────────────────────────

    /// Call once in applicationDidFinishLaunching.
    /// Writes the service entry into NSUserDefaults (ServicesMenu domain)
    /// then re-registers with pbs so the change takes effect immediately.
    static func enable() {
        guard let bundlePath = Bundle.main.bundlePath as String?,
              let bundleID   = Bundle.main.bundleIdentifier
        else { return }

        // Build the entry that macOS stores per-service
        let entry: [String: Any] = [
            "NSBundleIdentifier": bundleID,
            "NSBundlePath":       bundlePath,
            "NSMenuItem":         ["default": menuTitle],
            "NSMessage":          "performPaste",
            "NSKeyEquivalent":    ["default": ""],
            "NSSendTypes":        ["NSStringPboardType", "public.utf8-plain-text"],
            "NSIsEnabled":        true,
        ]

        let domain = UserDefaults(suiteName: prefsKey)

        // Read existing services array
        var services = domain?.array(forKey: "Services") as? [[String: Any]] ?? []

        // Check if already enabled with current bundle path
        let alreadyEnabled = services.contains {
            ($0["NSBundlePath"] as? String) == bundlePath &&
            (($0["NSIsEnabled"] as? Bool) == true)
        }

        if alreadyEnabled {
            logger.debug("ServiceEnabler: already enabled, skipping")
            return
        }

        // Remove stale entries for this bundle (different path / disabled)
        services.removeAll {
            ($0["NSBundleIdentifier"] as? String) == bundleID
        }

        // Insert fresh enabled entry
        services.append(entry)
        domain?.set(services, forKey: "Services")
        domain?.synchronize()

        logger.info("ServiceEnabler: wrote service entry to prefs")

        // Tell pbs to pick up the change
        refreshPBS()
    }

    // ─────────────────────────────────────────
    // MARK: - Private
    // ─────────────────────────────────────────

    private static func refreshPBS() {
        // pbs -update re-reads all NSServices registrations
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
        task.arguments = ["-update"]
        try? task.run()
        task.waitUntilExit()
        logger.debug("ServiceEnabler: pbs -update exited \(task.terminationStatus)")
    }
}
