import SwiftUI

@main
struct Key84App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var app = AppController.shared
    // Starts Sparkle's updater at launch so scheduled background checks run; also
    // backs the menu's "Kiểm tra cập nhật…" item.
    @StateObject private var updater = UpdaterController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(settings: settings, app: app, updater: updater)
        } label: {
            // Reflect real state: VI/EN when active, a warning when 84Key can't
            // process typing yet (Accessibility permission needed).
            if app.isRunning {
                // Colored brand glyphs (pink V / blue E), 18pt — drawn in their
                // own colors via .original so the menu bar doesn't tint them.
                Image(settings.language == 1 ? "MenubarV" : "MenubarE")
                    .renderingMode(.original)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
            }
        }

        Settings {
            SettingsView()
        }
        // Window follows the content's fixed size → not user-resizable; only the
        // sidebar divider can move.
        .windowResizability(.contentSize)
    }
}

private struct MenuContent: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var app: AppController
    @ObservedObject var updater: UpdaterController
    @Environment(\.openSettings) private var openSettings

    /// Radio-style binding for a language mode: turning a row on selects that
    /// mode; turning the active row off is ignored (one mode is always on).
    private func languageBinding(_ lang: Int) -> Binding<Bool> {
        Binding(
            get: { settings.language == lang },
            set: { isOn in if isOn { settings.language = lang } }
        )
    }

    var body: some View {
        if app.isRunning {
            // Show both modes with a native checkmark on the active one (like the
            // macOS Input Source menu) — clearer than a "Chuyển sang…" toggle and
            // lets the user pick a mode directly. The configured switch hotkey
            // (default ⌃⌘Space) is surfaced on the *inactive* row, where pressing
            // it takes you, so it still reads as a toggle and stays in sync with
            // Settings. The engine's global tap consumes the combo before it
            // reaches the app, so this shortcut is hint-only and can't double-fire.
            Toggle("Tiếng Việt", isOn: languageBinding(1))
                .keyboardShortcut(settings.language == 1 ? nil : Key84Shortcut.keyboardShortcut(settings.switchKey))
            Toggle("English", isOn: languageBinding(0))
                .keyboardShortcut(settings.language == 0 ? nil : Key84Shortcut.keyboardShortcut(settings.switchKey))
        } else {
            Text(app.hasPermission
                 ? "Đã cấp quyền — bấm Khởi động lại để kích hoạt"
                 : "⚠︎ Cần quyền Trợ năng (Accessibility)")
            Button("Mở cài đặt Trợ năng…") { app.openAccessibilitySettings() }
            Button("Khởi động lại 84Key") { app.relaunch() }
        }

        Divider()
        Button("Kiểm tra cập nhật…") { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)
        Button("Cài đặt…") { openSettingsWindow() }
            .keyboardShortcut(",")
        Button("Thoát 84Key") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// Open Settings and bring it to the front. The `SettingsWindowActivator`
    /// also promotes 84Key to a regular app while the window is up — see its doc
    /// comment for why that's required to render correctly.
    private func openSettingsWindow() {
        openSettings()
        SettingsWindowActivator.shared.activate()
    }
}

/// Promotes 84Key to a `.regular` app while the SwiftUI Settings window is open,
/// then reverts to `.accessory` (menu-bar only) when it closes.
///
/// Why: 84Key is an `LSUIElement` accessory app, so it's never the *active* app
/// on its own. AppKit then renders the Settings window's `NavigationSplitView`
/// and native sidebar vibrancy in their inactive/opaque state, which — with
/// macOS wallpaper tinting — looks washed-out and "legacy" (a warm beige panel).
/// Running from Xcode hid the bug because the debugger activates the launched
/// app. Briefly going `.regular` (the same trick `OnboardingController` uses)
/// makes the window render in its normal, active appearance. A Dock icon shows
/// only while Settings is open.
@MainActor
final class SettingsWindowActivator {
    static let shared = SettingsWindowActivator()

    /// Identifier SwiftUI assigns to the window backing the `Settings` scene.
    private static let settingsWindowID = "com_apple_SwiftUI_Settings_window"
    private var closeObserver: NSObjectProtocol?
    /// Keeps the open Settings window's vibrancy pinned active for its lifetime.
    private var pinner: Key84VibrancyPinner?

    private init() {}

    /// Call right after `openSettings()`. Promotes the app, fronts the window,
    /// and arms a one-shot revert for when the user closes Settings.
    func activate() {
        NSApp.setActivationPolicy(.regular)
        // Defer to the next runloop turn: the `.regular` policy change must
        // register *before* we activate, or macOS refuses the activation
        // request and the window renders in its washed-out inactive appearance
        // (the original bug).
        DispatchQueue.main.async { [weak self] in
            // Cooperative activation (macOS 14+). `NSApp.activate(ignoringOtherApps:)`
            // is deprecated and routinely refused from a background/accessory state;
            // `NSRunningApplication.current.activate` is the API Apple steers you to
            // and is what actually brings an LSUIElement app forward here.
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            self?.frontSettingsWindow(retriesLeft: 12)
        }
    }

    /// Front + activate the Settings window once it exists. On the very first
    /// `openSettings()` the window isn't created until a later runloop turn, so
    /// retry briefly rather than giving up after a single look.
    private func frontSettingsWindow(retriesLeft: Int) {
        guard let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == Self.settingsWindowID
        }) else {
            guard retriesLeft > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.frontSettingsWindow(retriesLeft: retriesLeft - 1)
            }
            return
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        // Keep the content's NSVisualEffectView materials pinned active for the
        // window's lifetime — a one-shot pin loses the race against SwiftUI
        // rebuilding the subtree. The Settings window is reused across opens, so
        // detach any prior pinner before installing a fresh one.
        pinner?.detach()
        pinner = Key84VibrancyPinner(window: window)
        armRevert(for: window)
    }

    /// Revert to a menu-bar-only accessory app once this Settings window closes.
    /// Re-arms on every open (the SwiftUI Settings window is reused, not freed),
    /// removing any prior observer so we never double-register.
    private func armRevert(for window: NSWindow) {
        if let token = closeObserver {
            NotificationCenter.default.removeObserver(token)
            closeObserver = nil
        }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                NSApp.setActivationPolicy(.accessory)
                self?.pinner?.detach()
                self?.pinner = nil
                if let token = self?.closeObserver {
                    NotificationCenter.default.removeObserver(token)
                    self?.closeObserver = nil
                }
            }
        }
    }
}

/// Forces AppKit vibrancy (`NSVisualEffectView`) to render in its *active* look
/// regardless of whether the owning window is key.
///
/// Why: 84Key is an `LSUIElement` accessory app, so its windows are frequently
/// not the key window of the active app. The default `.followsWindowActiveState`
/// then renders the `NavigationSplitView` sidebar material in its inactive,
/// opaque state — a washed-out "legacy" beige (made worse by wallpaper tinting).
/// Promoting/activating the app is racy (cooperative activation on macOS 14+ can
/// refuse it), so instead of betting on activation we pin the material to
/// `.active`. This is deterministic and survives the app losing focus.
@MainActor
enum Key84Vibrancy {
    /// Recursively pin every `NSVisualEffectView` under `window`'s content view
    /// to the active state. SwiftUI owns these views, so call this after the
    /// window is shown (and again if its content is rebuilt). Prefer
    /// `Key84VibrancyPinner`, which keeps re-applying this as SwiftUI rebuilds.
    static func forceActive(in window: NSWindow) {
        guard let root = window.contentView else { return }
        pinActive(root)
    }

    /// Recursively set every `NSVisualEffectView` in the subtree to `.active`.
    /// Idempotent and cheap (AppKit no-ops an unchanged `state`).
    static func pinActive(_ view: NSView) {
        if let effect = view as? NSVisualEffectView {
            effect.state = .active
        }
        for sub in view.subviews { pinActive(sub) }
    }
}

/// Keeps a single window's `NSVisualEffectView` materials pinned to `.active` for
/// the window's whole lifetime — not just once.
///
/// Why a retained object instead of a one-shot pin: SwiftUI owns the effect views
/// inside `NavigationSplitView`/`Form`, and it builds and *replaces* that subtree
/// on runloop turns *after* the window first appears. A single pin (the previous
/// approach) walks an empty/partial tree, or gets overwritten by fresh views in
/// the default `.followsWindowActiveState` — so a standalone (inactive) launch
/// still rendered washed-out. This object re-pins:
///   - in a short burst right after present (covers the construction race), and
///   - on every `didUpdate`/key-state/expose notification (covers later rebuilds).
/// Pinning is cheap and idempotent, so re-running it freely is safe. `detach()`
/// (or `deinit`) removes the observers; the Settings window is reused across
/// opens, so its activator must `detach()` the old pinner before making a new one.
@MainActor
final class Key84VibrancyPinner {
    private weak var window: NSWindow?
    private var observers: [NSObjectProtocol] = []

    init(window: NSWindow) {
        self.window = window
        let center = NotificationCenter.default
        // didUpdate fires whenever the window refreshes its views — the hook that
        // catches SwiftUI swapping in fresh effect views. The others cover focus
        // transitions and re-exposure, where `.followsWindowActiveState` would
        // otherwise desaturate.
        for name: NSNotification.Name in [
            NSWindow.didUpdateNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didExposeNotification,
        ] {
            observers.append(center.addObserver(
                forName: name, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.pinNow() }
            })
        }
        // Burst across the next few runloop turns: the window object exists now,
        // but SwiftUI populates its effect-view subtree a few turns later.
        for delay in [0.0, 0.05, 0.15, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.pinNow()
            }
        }
    }

    deinit {
        let tokens = observers
        for token in tokens { NotificationCenter.default.removeObserver(token) }
    }

    /// Stop observing. Call before discarding the pinner (e.g. on window close,
    /// or before replacing it for a reused window) so we never double-register.
    func detach() {
        for token in observers { NotificationCenter.default.removeObserver(token) }
        observers.removeAll()
    }

    private func pinNow() {
        guard let root = window?.contentView else { return }
        Key84Vibrancy.pinActive(root)
    }
}
