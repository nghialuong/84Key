import Combine
import Sparkle

/// Drives 84Key's in-app auto-update via Sparkle.
///
/// `SPUStandardUpdaterController(startingUpdater: true)` starts the updater as
/// soon as the app launches, so Sparkle performs its scheduled background checks
/// (interval from `SUScheduledCheckInterval` in Info.plist) and uses its standard
/// UI for the "update available" / download / install flow. The menu's
/// "Kiểm tra cập nhật…" item drives a manual check through the same controller.
///
/// `canCheckForUpdates` mirrors the updater's own state so the menu item can
/// disable itself while a check is already in flight.
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    @Published private(set) var canCheckForUpdates = false

    private let controller: SPUStandardUpdaterController

    private init() {
        // No custom delegates: the standard updater + standard user driver give
        // the conventional macOS update experience (and the first run prompts the
        // user to allow automatic checks).
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    /// Trigger a user-initiated update check (shows "you're up to date" when none).
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
