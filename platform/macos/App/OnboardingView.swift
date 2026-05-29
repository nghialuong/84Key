import SwiftUI
import AppKit

/// First-run onboarding shown when 84Key cannot yet process typing (Accessibility
/// permission missing or not yet effective). 84Key is a menu-bar agent
/// (LSUIElement), so this is presented imperatively by `OnboardingController`.
/// `AppController` polls in the background and dismisses it once the tap starts.
struct OnboardingView: View {
    let onOpenSettings: () -> Void
    let onRelaunch: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chào mừng đến với 84Key").font(.title2).bold()
                    Text("Bộ gõ tiếng Việt cho macOS")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("84Key cần quyền Trợ năng (Accessibility) để xử lý bàn phím.")
                    .font(.headline)
                Text("Để đặt dấu tiếng Việt, 84Key đọc và thay thế văn bản trong ô bạn đang gõ. macOS yêu cầu quyền Trợ năng (Accessibility) cho kiểu xử lý nhập liệu này. 84Key không gửi văn bản của bạn đi đâu cả.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Hai bước", systemImage: "list.number")
                        .font(.subheadline).bold()
                    Text("1. Bấm “Mở cài đặt Trợ năng” và bật 84Key.\n2. Bấm “Khởi động lại 84Key” để áp dụng quyền mới. (Bản dựng phát triển cần bước này; bản phát hành đã ký thì không.)")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Tắt các bộ gõ tiếng Việt khác", systemImage: "exclamationmark.triangle")
                        .font(.subheadline).bold()
                    Text("OpenKey, EVKey, hoặc bộ gõ tiếng Việt tích hợp sẵn của macOS chạy cùng lúc sẽ gây lặp ký tự hoặc sai chữ.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Đang chờ cấp quyền… 84Key sẽ tự khởi động ngay khi quyền có hiệu lực.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Button("Để sau", action: onSkip)
                Spacer()
                Button("Khởi động lại 84Key", action: onRelaunch)
                Button("Mở cài đặt Trợ năng", action: onOpenSettings)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480, height: 520, alignment: .topLeading)
    }
}

/// Owns the onboarding NSWindow. Polling/permission logic lives in AppController.
@MainActor
final class OnboardingController: NSObject, NSWindowDelegate {
    private weak var app: AppController?
    private var window: NSWindow?

    init(controller: AppController) {
        self.app = controller
        super.init()
    }

    func present() {
        if window == nil {
            let view = OnboardingView(
                onOpenSettings: { [weak self] in self?.app?.openAccessibilitySettings() },
                onRelaunch: { [weak self] in self?.app?.relaunch() },
                onSkip: { [weak self] in self?.dismiss() }
            )
            let hosting = NSHostingController(rootView: view)
            // Don't let SwiftUI drive the window size (a flexible-height root makes
            // NSHostingController ping-pong the Update Constraints pass until AppKit
            // throws and the app crashes). Fix the window size instead.
            hosting.sizingOptions = []
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.contentViewController = hosting
            win.title = "Chào mừng đến với 84Key"
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.center()
            window = win
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        window?.orderOut(nil)
        window?.delegate = nil
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
