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
        public static let windowMinWidth:    CGFloat = 900
        public static let windowMinHeight:   CGFloat = 620
        public static let windowIdealWidth:  CGFloat = 960
        public static let windowIdealHeight: CGFloat = 680

        public static let sidebarMinWidth:   CGFloat = 220
        public static let sidebarIdealWidth: CGFloat = 240
        public static let sidebarMaxWidth:   CGFloat = 260
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
