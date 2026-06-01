//
//  Key84DesignSystem.swift
//  84Key
//
//  A deliberately tiny token set. The Settings UI is built from *native* SwiftUI
//  controls — `NavigationSplitView` + `List(selection:)` for the sidebar and
//  `Form { Section } .formStyle(.grouped)` for detail panes — because that is
//  literally what macOS System Settings uses, and it adopts the system look
//  (including Liquid Glass on macOS 26) for free. This file only carries the
//  brand accent, window geometry and a small app badge; it intentionally does
//  NOT wrap native rows/groups in custom chrome.
//
//  No third-party dependencies; no private or non-existent APIs.
//

import SwiftUI
import AppKit
import AppKit

// MARK: - Namespace

public enum Key84DS {}

// MARK: - Color tokens

public extension Key84DS {
    enum Color {
        /// Refined 84Key pink. Used only for the small app badge.
        public static let accent = SwiftUI.Color(
            light: NSColor(srgbRed: 0.78, green: 0.16, blue: 0.49, alpha: 1.0),
            dark:  NSColor(srgbRed: 0.93, green: 0.38, blue: 0.65, alpha: 1.0)
        )

        public static let textPrimary   = SwiftUI.Color.primary
        public static let textSecondary = SwiftUI.Color.secondary

        public static let success = SwiftUI.Color(nsColor: .systemGreen)
        public static let warning = SwiftUI.Color(nsColor: .systemOrange)

        /// NSColor bridge for AppKit-side use (status item, etc.).
        public static let accentNSColor = NSColor(
            name: nil,
            dynamicProvider: { appearance in
                appearance.isDark
                    ? NSColor(srgbRed: 0.93, green: 0.38, blue: 0.65, alpha: 1.0)
                    : NSColor(srgbRed: 0.78, green: 0.16, blue: 0.49, alpha: 1.0)
            }
        )
    }
}

// MARK: - Typography tokens

public extension Key84DS {
    enum Typography {
        public static let caption = Font.system(size: 11)
        public static let mono    = Font.system(.body, design: .monospaced)
    }
}

// MARK: - Layout tokens

public extension Key84DS {
    enum Layout {
        /// The window is a fixed size — the user can only resize the sidebar
        /// (the split divider), never the window itself. Paired with
        /// `.windowResizability(.contentSize)` on the Settings scene.
        public static let windowWidth:  CGFloat = 960
        public static let windowHeight: CGFloat = 680

        public static let sidebarMinWidth:   CGFloat = 220
        public static let sidebarIdealWidth: CGFloat = 260
        public static let sidebarMaxWidth:   CGFloat = 320

        /// Leading inset for the large detail title so it lines up with the
        /// grouped `Form` content margin (section headers / rows below it).
        public static let detailTitleLeading: CGFloat = 20
    }
}

// MARK: - AppKit helpers

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

extension Color {
    /// Build a dynamic Color from explicit light/dark `NSColor`s.
    init(light: NSColor, dark: NSColor) {
        self = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.isDark ? dark : light
        }))
    }
}

// NOTE: There is intentionally no custom sidebar-material wrapper here. The
// sidebar is a `List(.sidebar)` inside a `NavigationSplitView`, so macOS renders
// the real translucent sidebar material itself. Adding an `NSVisualEffectView`
// background only fought the system material and produced a flat off-white panel
// on the opaque Settings window — so it was removed in favor of the native one.

// MARK: - App badge (small)

/// The small 84Key badge. Used only for quiet identity (≤28pt), never as a hero.
public struct Key84AppBadge: View {
    private let size: CGFloat
    public init(size: CGFloat = 20) { self.size = size }

    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(Key84DS.Color.accent)
            .overlay {
                Text("84")
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
    }
}

// MARK: - App icon (real bundle icon)

/// The real 84Key app icon (`Assets.xcassets/AppIcon`), rendered at `size`.
/// Read live from the running bundle so it always matches the shipped icon; no
/// duplicate image asset. Falls back to the drawn badge if the icon image isn't
/// available yet (e.g. very early launch). The image is rendered raw — macOS app
/// icons already bake in the rounded-square shape and padding, so clipping would
/// cut the built-in shadow.
public struct Key84AppIcon: View {
    private let size: CGFloat
    public init(size: CGFloat = 72) { self.size = size }

    public var body: some View {
        if let icon = NSApplication.shared.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Key84AppBadge(size: size)
        }
    }
}
