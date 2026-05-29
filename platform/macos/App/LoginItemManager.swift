import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` (macOS 13+) that registers /
/// unregisters 84Key as a Login Item so the menu-bar agent can start at login.
/// Failures are logged rather than thrown to the caller — a login item that
/// can't register should never crash the app or block the settings toggle.
enum LoginItemManager {
    /// Whether the app is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// The raw service status (useful for diagnostics / UI hints).
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    /// Register or unregister the main app as a login item to match `enabled`.
    /// No-ops when the requested state already matches the current status.
    static func sync(enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                // Only tear down when actually enabled. Trying to unregister a
                // not-registered / requires-approval service (common for an
                // ad-hoc dev build not in /Applications) errors with "not
                // permitted", so skip it.
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            NSLog("84Key login item %@ failed: %@",
                  enabled ? "register" : "unregister",
                  error.localizedDescription)
        }
    }
}
