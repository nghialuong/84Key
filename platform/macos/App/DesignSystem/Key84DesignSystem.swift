//
//  Key84DesignSystem.swift
//  84Key
//
//  The official 84Key design system: design tokens (color, type, spacing,
//  radius, material, layout, animation) plus a small set of reusable components
//  for Settings, the menu-bar popover, onboarding and the permission flow.
//
//  Design rule: when in doubt, look like macOS System Settings, not a custom
//  dashboard. Native controls, restrained accent, subtle materials, quiet
//  sidebar, grouped forms, consistent row rhythm.
//
//  Liquid Glass-ready: surfaces flow through a single material abstraction
//  (`key84CardSurface` / `key84SidebarSurface`) that uses `.regularMaterial` /
//  `.bar` today and keeps building on the current SDK / macOS 14 deployment
//  target. No third-party dependencies; no private or non-existent APIs.
//

import SwiftUI
import AppKit

// MARK: - Namespace

/// Root namespace for all 84Key design tokens.
public enum Key84DS {}

// MARK: - Color tokens

public extension Key84DS {
    /// Semantic colors. Every token resolves correctly in light and dark mode.
    /// Accent is used sparingly — app badge, selected sidebar icon, status chips.
    enum Color {
        /// Refined 84Key pink/magenta. Restrained: not for every icon/button.
        public static let accent = SwiftUI.Color(
            light: NSColor(srgbRed: 0.78, green: 0.16, blue: 0.49, alpha: 1.0),
            dark:  NSColor(srgbRed: 0.93, green: 0.38, blue: 0.65, alpha: 1.0)
        )
        /// Soft accent wash (rarely used; prefer neutral highlights).
        public static let accentSoft = SwiftUI.Color(
            light: NSColor(srgbRed: 0.78, green: 0.16, blue: 0.49, alpha: 0.12),
            dark:  NSColor(srgbRed: 0.93, green: 0.38, blue: 0.65, alpha: 0.20)
        )
        /// Desaturated accent for muted accents.
        public static let accentMuted = SwiftUI.Color(
            light: NSColor(srgbRed: 0.62, green: 0.36, blue: 0.50, alpha: 0.55),
            dark:  NSColor(srgbRed: 0.80, green: 0.55, blue: 0.68, alpha: 0.55)
        )

        // Text — forwarded to system labels so accessibility behaves natively.
        public static let textPrimary   = SwiftUI.Color.primary
        public static let textSecondary = SwiftUI.Color.secondary
        public static let textTertiary  = SwiftUI.Color(nsColor: .tertiaryLabelColor)

        // Structure
        public static let separator = SwiftUI.Color(nsColor: .separatorColor)

        /// Quiet, neutral selection/hover fill (System Settings-style). Resolves
        /// to a faint primary tint that reads well in both appearances.
        public static func neutralFill(_ scheme: ColorScheme, selected: Bool) -> SwiftUI.Color {
            if selected {
                return SwiftUI.Color.primary.opacity(scheme == .dark ? 0.12 : 0.08)
            } else {
                return SwiftUI.Color.primary.opacity(scheme == .dark ? 0.06 : 0.05)
            }
        }

        // Status
        public static let success = SwiftUI.Color(nsColor: .systemGreen)
        public static let warning = SwiftUI.Color(nsColor: .systemOrange)
        public static let danger  = SwiftUI.Color(nsColor: .systemRed)

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
    /// Semantic text styles built on the system font. macOS-like hierarchy with
    /// restrained sizes — no oversized text.
    enum Typography {
        public static let pageTitle    = Font.system(size: 28, weight: .semibold)
        public static let pageSubtitle = Font.system(size: 13)
        public static let cardTitle    = Font.system(size: 15, weight: .semibold)
        public static let sectionLabel = Font.system(size: 13, weight: .semibold)
        public static let rowTitle     = Font.system(size: 13)
        public static let rowSubtitle  = Font.system(size: 12)
        public static let caption      = Font.system(size: 11)
        public static let badge        = Font.system(size: 11, weight: .medium)
        public static let sidebarItem  = Font.system(size: 14)
        public static let monoShortcut = Font.system(size: 12, design: .monospaced).weight(.medium)
    }
}

// MARK: - Spacing tokens

public extension Key84DS {
    /// Spacing scale (points).
    enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs:  CGFloat = 4
        public static let sm:  CGFloat = 8
        public static let md:  CGFloat = 12
        public static let lg:  CGFloat = 16
        public static let xl:  CGFloat = 24
        public static let xxl: CGFloat = 32
    }
}

// MARK: - Radius tokens

public extension Key84DS {
    enum Radius {
        public static let chip:    CGFloat = 6
        public static let sidebar: CGFloat = 8
        public static let card:    CGFloat = 12
    }
}

// MARK: - Layout tokens

public extension Key84DS {
    /// Window / pane geometry, tuned to native System Settings proportions.
    enum Layout {
        public static let windowMinWidth:    CGFloat = 920
        public static let windowMinHeight:   CGFloat = 640
        public static let windowIdealWidth:  CGFloat = 1000
        public static let windowIdealHeight: CGFloat = 700

        public static let sidebarWidth:      CGFloat = 240
        public static let contentMaxWidth:   CGFloat = 680
        public static let detailTopPadding:      CGFloat = 56
        public static let detailHorizontalPadding: CGFloat = 48
        public static let detailBottomPadding:    CGFloat = 32

        // Rows
        public static let rowMinHeight:         CGFloat = 44
        public static let rowMinHeightSubtitle: CGFloat = 58
        public static let rowHPadding:          CGFloat = 14
        public static let dividerInset:         CGFloat = 16

        // Sidebar
        public static let sidebarRowHeight:  CGFloat = 36
        public static let sidebarIconSize:   CGFloat = 16
        public static let sidebarIconWidth:  CGFloat = 20
        public static let sidebarRowInset:   CGFloat = 8

        public static let cardPadding: CGFloat = 14
    }
}

// MARK: - Animation tokens

public extension Key84DS {
    enum Animation {
        public static let hover: SwiftUI.Animation  = .easeOut(duration: 0.12)
        public static let select: SwiftUI.Animation = .easeInOut(duration: 0.15)
    }
}

// MARK: - Material / surface tokens

public extension Key84DS {
    /// Surface roles mapped to system materials. Components reference roles,
    /// not raw materials, so translucency is decided in one place.
    enum Surface {
        public static let card: Material = .regularMaterial
        public static let sidebar: Material = .bar
    }
}

// MARK: - AppKit helpers

extension NSAppearance {
    /// True when the effective appearance is one of the dark variants.
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

// MARK: - Liquid Glass-ready surfaces

public extension View {
    /// Grouped card surface: subtle material + hairline separator border.
    ///
    /// This is where Liquid Glass (`.glassEffect`) would be applied on macOS 26;
    /// today it renders `.regularMaterial` so the code builds and looks native
    /// everywhere. When the build SDK gains the glass APIs, add a
    /// `if #available(macOS 26.0, *)` branch here — no call site changes.
    func key84CardSurface(cornerRadius: CGFloat = Key84DS.Radius.card) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(Key84DS.Surface.card, in: shape)
            .overlay(shape.strokeBorder(Key84DS.Color.separator.opacity(0.35), lineWidth: 0.5))
    }

    /// Translucent sidebar background.
    func key84SidebarSurface() -> some View {
        background(Key84DS.Surface.sidebar)
    }
}

// MARK: - Card container

/// A rounded, material-backed card. The lowest-level surface component.
public struct Key84GlassCard<Content: View>: View {
    private var padding: CGFloat
    private var content: Content

    public init(padding: CGFloat = Key84DS.Layout.cardPadding, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, padding)
            .padding(.vertical, padding - 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .key84CardSurface()
    }
}

// MARK: - Section header

/// A small, quiet section label shown above a group (outside the card).
public struct Key84SectionHeader: View {
    private let title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        Text(title)
            .font(Key84DS.Typography.sectionLabel)
            .foregroundStyle(Key84DS.Color.textSecondary)
    }
}

// MARK: - Settings group (native grouped list)

/// A titled group of setting rows rendered as a single native-looking card,
/// with inset dividers between rows. The title sits outside the card.
public struct Key84SettingsGroup<Content: View>: View {
    private var title: String?
    private var footer: String?
    private var content: Content

    public init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Key84DS.Spacing.sm) {
            if let title { Key84SectionHeader(title) }
            _VariadicView.Tree(DividedRows()) { content }
                .key84CardSurface()
            if let footer {
                Text(footer)
                    .font(Key84DS.Typography.caption)
                    .foregroundStyle(Key84DS.Color.textSecondary)
                    .padding(.horizontal, Key84DS.Spacing.xs)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Lays rows out vertically with an inset divider between them.
    private struct DividedRows: _VariadicView_MultiViewRoot {
        @ViewBuilder
        func body(children: _VariadicView.Children) -> some View {
            let last = children.last?.id
            VStack(spacing: 0) {
                ForEach(children) { child in
                    child
                    if child.id != last {
                        Divider().padding(.leading, Key84DS.Layout.dividerInset)
                    }
                }
            }
        }
    }
}

// MARK: - Setting rows

/// The base setting row: title, optional subtitle and a trailing control.
/// No decorative icons — native System Settings relies on text + control.
public struct Key84SettingRow<Control: View>: View {
    private let title: String
    private let subtitle: String?
    private let isEnabled: Bool
    private let control: Control

    public init(
        _ title: String,
        subtitle: String? = nil,
        isEnabled: Bool = true,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isEnabled = isEnabled
        self.control = control()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Key84DS.Spacing.md) {
            VStack(alignment: .leading, spacing: Key84DS.Spacing.xxs) {
                Text(title)
                    .font(Key84DS.Typography.rowTitle)
                    .foregroundStyle(Key84DS.Color.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Key84DS.Typography.rowSubtitle)
                        .foregroundStyle(Key84DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Key84DS.Spacing.lg)
            control
        }
        .padding(.horizontal, Key84DS.Layout.rowHPadding)
        .frame(minHeight: subtitle == nil ? Key84DS.Layout.rowMinHeight : Key84DS.Layout.rowMinHeightSubtitle)
        .opacity(isEnabled ? 1 : 0.45)
        .allowsHitTesting(isEnabled)
    }
}

/// A row with a native toggle. Default system tint (no forced accent).
public struct Key84ToggleRow: View {
    private let title: String
    private let subtitle: String?
    @Binding private var isOn: Bool
    private let isEnabled: Bool

    public init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>, isEnabled: Bool = true) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.isEnabled = isEnabled
    }

    public var body: some View {
        Key84SettingRow(title, subtitle: subtitle, isEnabled: isEnabled) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!isEnabled)
        }
    }
}

/// A row hosting a native menu-style `Picker`.
public struct Key84PickerRow<SelectionValue: Hashable, Content: View>: View {
    private let title: String
    private let subtitle: String?
    @Binding private var selection: SelectionValue
    private let content: Content

    public init(
        _ title: String,
        subtitle: String? = nil,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self._selection = selection
        self.content = content()
    }

    public var body: some View {
        Key84SettingRow(title, subtitle: subtitle) {
            Picker("", selection: $selection) { content }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
        }
    }
}

/// A read-only row that shows trailing informational text.
public struct Key84InfoRow: View {
    private let title: String
    private let subtitle: String?
    private let value: String

    public init(_ title: String, subtitle: String? = nil, value: String) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
    }

    public var body: some View {
        Key84SettingRow(title, subtitle: subtitle) {
            Text(value)
                .font(Key84DS.Typography.rowTitle)
                .foregroundStyle(Key84DS.Color.textSecondary)
        }
    }
}

/// A tappable navigation row with a trailing chevron and quiet hover.
public struct Key84NavigationRow: View {
    private let title: String
    private let subtitle: String?
    private let action: () -> Void
    @State private var isHovering = false
    @Environment(\.colorScheme) private var scheme

    public init(_ title: String, subtitle: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Key84SettingRow(title, subtitle: subtitle) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Key84DS.Color.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Key84DS.Color.neutralFill(scheme, selected: false) : SwiftUI.Color.clear)
        .onHover { hovering in withAnimation(Key84DS.Animation.hover) { isHovering = hovering } }
    }
}

// MARK: - Sidebar

/// Model describing one sidebar destination.
public struct Key84SidebarItemModel: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let systemIcon: String

    public init(id: String, title: String, systemIcon: String) {
        self.id = id
        self.title = title
        self.systemIcon = systemIcon
    }
}

/// A quiet, native sidebar row: monochrome icon, title, neutral selection
/// highlight. Selected icon uses the accent (the one restrained accent cue).
public struct Key84SidebarItem: View {
    private let model: Key84SidebarItemModel
    private let isSelected: Bool
    private let action: () -> Void
    @State private var isHovering = false
    @Environment(\.colorScheme) private var scheme

    public init(_ model: Key84SidebarItemModel, isSelected: Bool, action: @escaping () -> Void) {
        self.model = model
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: model.systemIcon)
                    .font(.system(size: Key84DS.Layout.sidebarIconSize))
                    .foregroundStyle(isSelected ? Key84DS.Color.accent : Key84DS.Color.textSecondary)
                    .frame(width: Key84DS.Layout.sidebarIconWidth, alignment: .center)
                Text(model.title)
                    .font(Key84DS.Typography.sidebarItem)
                    .foregroundStyle(Key84DS.Color.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Key84DS.Spacing.md)
            .frame(height: Key84DS.Layout.sidebarRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(rowBackground)
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Key84DS.Animation.hover) { isHovering = hovering } }
    }

    @ViewBuilder
    private var rowBackground: some View {
        let shape = RoundedRectangle(cornerRadius: Key84DS.Radius.sidebar, style: .continuous)
        if isSelected {
            shape.fill(Key84DS.Color.neutralFill(scheme, selected: true))
        } else if isHovering {
            shape.fill(Key84DS.Color.neutralFill(scheme, selected: false))
        } else {
            shape.fill(SwiftUI.Color.clear)
        }
    }
}

/// Bottom-of-sidebar app identity area: small badge + name + version.
public struct Key84SidebarFooter: View {
    private let version: String
    public init(version: String) { self.version = version }

    public var body: some View {
        HStack(spacing: Key84DS.Spacing.sm) {
            Key84AppBadge(size: 18)
            Text("84Key")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Key84DS.Color.textPrimary)
            Text("·")
                .foregroundStyle(Key84DS.Color.textTertiary)
            Text("phiên bản \(version)")
                .font(Key84DS.Typography.caption)
                .foregroundStyle(Key84DS.Color.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Key84DS.Spacing.lg)
        .padding(.vertical, Key84DS.Spacing.md)
    }
}

// MARK: - Status / badge

/// The square 84Key badge. The app badge is the primary place accent appears.
public struct Key84AppBadge: View {
    private let size: CGFloat
    public init(size: CGFloat = 36) { self.size = size }

    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(Key84DS.Color.accent)
            .overlay {
                Text("84")
                    .font(.system(size: size * 0.40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
    }
}

/// Style of a status chip.
public enum Key84ChipStyle {
    case accent, success, warning, neutral

    var tint: SwiftUI.Color {
        switch self {
        case .accent:  return Key84DS.Color.accent
        case .success: return Key84DS.Color.success
        case .warning: return Key84DS.Color.warning
        case .neutral: return Key84DS.Color.textSecondary
        }
    }
}

/// A compact, quiet status chip (e.g. "Tiếng Việt: Bật" or a shortcut "⌘E").
public struct Key84StatusChip: View {
    private let title: String
    private let systemIcon: String?
    private let style: Key84ChipStyle
    private let monospaced: Bool

    public init(_ title: String, systemIcon: String? = nil, style: Key84ChipStyle = .neutral, monospaced: Bool = false) {
        self.title = title
        self.systemIcon = systemIcon
        self.style = style
        self.monospaced = monospaced
    }

    public var body: some View {
        HStack(spacing: 5) {
            if let systemIcon {
                Image(systemName: systemIcon).font(.system(size: 11, weight: .semibold))
            }
            Text(title).font(monospaced ? Key84DS.Typography.monoShortcut : Key84DS.Typography.badge)
        }
        .foregroundStyle(style.tint)
        .padding(.horizontal, Key84DS.Spacing.sm)
        .padding(.vertical, 3)
        .background(style.tint.opacity(0.12), in: Capsule())
    }
}

/// Top status summary for the Overview page: small badge, name, status chips
/// and a restrained bordered action. Presentation only.
public struct Key84HeroStatusCard: View {
    private let isVietnamese: Bool
    private let shortcut: String
    private let primaryActionTitle: String
    private let primaryAction: () -> Void

    public init(
        isVietnamese: Bool,
        shortcut: String = "⌘E",
        primaryActionTitle: String,
        primaryAction: @escaping () -> Void
    ) {
        self.isVietnamese = isVietnamese
        self.shortcut = shortcut
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Key84DS.Spacing.md) {
            Key84AppBadge(size: 40)

            VStack(alignment: .leading, spacing: Key84DS.Spacing.sm) {
                Text("84Key").font(Key84DS.Typography.cardTitle)
                HStack(spacing: Key84DS.Spacing.sm) {
                    Key84StatusChip(
                        isVietnamese ? "Tiếng Việt: Bật" : "Tiếng Việt: Tắt",
                        systemIcon: isVietnamese ? "checkmark.circle.fill" : "circle",
                        style: isVietnamese ? .success : .neutral
                    )
                    Key84StatusChip("Phím tắt: \(shortcut)", style: .neutral, monospaced: true)
                }
            }

            Spacer(minLength: Key84DS.Spacing.lg)

            Button(primaryActionTitle, action: primaryAction)
                .buttonStyle(.bordered)
                .controlSize(.regular)
        }
        .padding(Key84DS.Spacing.lg)
        .key84CardSurface()
    }
}

// MARK: - Previews

#if DEBUG
private struct Key84ComponentsPreview: View {
    @State private var pick = 0
    @State private var on = true
    @State private var off = false
    @State private var selected = "overview"

    private let items: [Key84SidebarItemModel] = [
        .init(id: "overview", title: "Tổng quan", systemIcon: "house"),
        .init(id: "input", title: "Nhập liệu", systemIcon: "keyboard"),
        .init(id: "vietnamese", title: "Gõ tiếng Việt", systemIcon: "character.cursor.ibeam"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                ForEach(items) { item in
                    Key84SidebarItem(item, isSelected: selected == item.id) { selected = item.id }
                }
                Spacer()
                Key84SidebarFooter(version: "0.1.0")
            }
            .padding(.horizontal, Key84DS.Layout.sidebarRowInset)
            .padding(.top, Key84DS.Spacing.sm)
            .frame(width: Key84DS.Layout.sidebarWidth)
            .key84SidebarSurface()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Key84DS.Spacing.xl) {
                    VStack(alignment: .leading, spacing: Key84DS.Spacing.xs) {
                        Text("Tổng quan").font(Key84DS.Typography.pageTitle)
                        Text("Trạng thái 84Key và các tuỳ chọn quan trọng nhất.")
                            .font(Key84DS.Typography.pageSubtitle)
                            .foregroundStyle(Key84DS.Color.textSecondary)
                    }
                    Key84HeroStatusCard(isVietnamese: true, primaryActionTitle: "Chuyển sang tiếng Anh") {}
                    Key84SettingsGroup("Cài đặt nhanh") {
                        Key84ToggleRow("Tự động nhận diện tiếng Anh", isOn: $on)
                        Key84ToggleRow("Sửa lỗi bỏ dấu trong Spotlight",
                                       subtitle: "Xử lý riêng Spotlight để tránh lỗi mất backspace.", isOn: $off)
                        Key84PickerRow("Kiểu gõ", selection: $pick) {
                            Text("Telex").tag(0); Text("VNI").tag(1)
                        }
                        Key84InfoRow("Phím tắt chuyển nhanh", value: "⌘E")
                    }
                }
                .frame(maxWidth: Key84DS.Layout.contentMaxWidth, alignment: .leading)
                .padding(.top, Key84DS.Layout.detailTopPadding)
                .padding(.horizontal, Key84DS.Layout.detailHorizontalPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: Key84DS.Layout.windowIdealWidth, height: Key84DS.Layout.windowIdealHeight)
    }
}

#Preview("Settings (light)") {
    Key84ComponentsPreview().preferredColorScheme(.light)
}

#Preview("Settings (dark)") {
    Key84ComponentsPreview().preferredColorScheme(.dark)
}
#endif
