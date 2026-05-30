//
//  Key84DesignSystem.swift
//  84Key
//
//  The official 84Key design system: design tokens (color, type, spacing,
//  radius, material, layout, animation) plus a small set of reusable, native
//  feeling SwiftUI components for Settings, the menu-bar popover, onboarding
//  and the permission flow.
//
//  Goals
//  - Feel like a real macOS-native app (System Settings-style), not a web app.
//  - Lean on system controls (Toggle, Picker, Button) wherever they are good
//    enough; only wrap them for consistent rows, spacing and chrome.
//  - Be "Liquid Glass-ready" for macOS 26 through a single surface abstraction
//    that today falls back to standard materials and keeps building on the
//    project's current SDK / deployment target (macOS 14).
//  - Use a refined pink/magenta accent, applied sparingly.
//
//  This file is intentionally self-contained and has no third-party
//  dependencies. It does not touch the engine, InputController or AppSettings.
//

import SwiftUI
import AppKit

// MARK: - Namespace

/// Root namespace for all 84Key design tokens.
///
/// Usage:
/// ```swift
/// Text("Tổng quan").font(Key84DS.Typography.sectionTitle)
/// someView.padding(Key84DS.Spacing.cardPadding)
/// ```
public enum Key84DS {}

// MARK: - Color tokens

public extension Key84DS {
    /// Semantic colors. Every token resolves correctly in light and dark mode.
    ///
    /// Prefer these over hardcoded values. Where a system semantic color is the
    /// right answer (e.g. primary/secondary label), we forward to it so 84Key
    /// inherits macOS behaviour (increase-contrast, accessibility, etc.).
    enum Color {
        // Accent — refined 84Key pink/magenta, used sparingly.
        /// Primary accent (selected sidebar item, primary action, status, tint).
        public static let accent = SwiftUI.Color(
            light: NSColor(srgbRed: 0.78, green: 0.16, blue: 0.49, alpha: 1.0),   // #C72A7D-ish
            dark:  NSColor(srgbRed: 0.93, green: 0.38, blue: 0.65, alpha: 1.0)    // brighter for dark
        )
        /// Soft accent wash for selection backgrounds / hover fills.
        public static let accentSoft = SwiftUI.Color(
            light: NSColor(srgbRed: 0.78, green: 0.16, blue: 0.49, alpha: 0.12),
            dark:  NSColor(srgbRed: 0.93, green: 0.38, blue: 0.65, alpha: 0.20)
        )
        /// Desaturated accent for subtle borders / muted chips.
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

        /// Card / grouped-row background. Sits on top of a material surface, so
        /// it is deliberately faint and translucent.
        public static let cardBackground = SwiftUI.Color(
            light: NSColor.white.withAlphaComponent(0.55),
            dark:  NSColor.white.withAlphaComponent(0.06)
        )

        /// Selected sidebar row fill (uses the soft accent wash).
        public static let sidebarSelection = accentSoft

        // Status
        public static let success = SwiftUI.Color(nsColor: .systemGreen)
        public static let warning = SwiftUI.Color(nsColor: .systemOrange)
        public static let danger  = SwiftUI.Color(nsColor: .systemRed)

        // MARK: NSColor bridges (for AppKit-side use: status item, etc.)
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
    /// Semantic text styles built on the system font. No custom fonts.
    enum Typography {
        public static let largeTitle    = Font.system(.largeTitle, design: .default).weight(.bold)
        public static let title         = Font.system(.title2, design: .default).weight(.semibold)
        public static let sectionTitle  = Font.system(.subheadline, design: .default).weight(.semibold)
        public static let rowTitle      = Font.system(.body, design: .default)
        public static let rowSubtitle   = Font.system(.callout, design: .default)
        public static let caption       = Font.system(.caption, design: .default)
        public static let badge         = Font.system(.caption2, design: .default).weight(.semibold)
        public static let sidebarItem   = Font.system(.body, design: .default)
        /// Monospaced style for keyboard shortcuts (e.g. ⌥ Space).
        public static let monoShortcut  = Font.system(.callout, design: .monospaced).weight(.medium)
    }
}

// MARK: - Spacing tokens

public extension Key84DS {
    /// Spacing scale (points). Keep usage on the scale for visual rhythm.
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
        public static let chip:  CGFloat = 6
        public static let row:   CGFloat = 8
        public static let card:  CGFloat = 12
        public static let hero:  CGFloat = 16
    }
}

// MARK: - Shadow tokens

public extension Key84DS {
    /// Subtle elevation. macOS prefers borders over heavy shadows, so these are
    /// deliberately soft.
    struct Shadow {
        public let color: SwiftUI.Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat

        public static let card = Shadow(
            color: SwiftUI.Color.black.opacity(0.06), radius: 6, x: 0, y: 1
        )
        public static let hero = Shadow(
            color: SwiftUI.Color.black.opacity(0.10), radius: 14, x: 0, y: 3
        )
    }
}

// MARK: - Layout tokens

public extension Key84DS {
    /// Window / pane geometry. Tuned to feel spacious, like System Settings.
    enum Layout {
        public static let windowMinWidth:  CGFloat = 760
        public static let windowMinHeight: CGFloat = 560
        public static let sidebarWidth:    CGFloat = 220
        public static let sidebarMinWidth: CGFloat = 200
        public static let contentMaxWidth: CGFloat = 640

        public static let cardPadding:     CGFloat = 16
        public static let rowMinHeight:    CGFloat = 44
        public static let rowVPadding:     CGFloat = 8
        public static let sectionSpacing:  CGFloat = 24
        public static let controlSpacing:  CGFloat = 10

        // Icon sizes
        public static let iconSmall:   CGFloat = 14
        public static let iconRow:     CGFloat = 18
        public static let iconSidebar: CGFloat = 16
        public static let iconHero:    CGFloat = 28
    }
}

// MARK: - Animation tokens

public extension Key84DS {
    enum Animation {
        public static let hover: SwiftUI.Animation  = .easeOut(duration: 0.12)
        public static let toggle: SwiftUI.Animation = .spring(response: 0.3, dampingFraction: 0.8)
        public static let select: SwiftUI.Animation = .easeInOut(duration: 0.15)
    }
}

// MARK: - Material / surface tokens

public extension Key84DS {
    /// Surface roles, mapped to system materials. This is the single place where
    /// translucency is decided — components reference roles, not raw materials.
    enum Surface {
        /// The window content background.
        public static let window: Material = .regularMaterial
        /// Sidebar background (slightly more translucent).
        public static let sidebar: Material = .ultraThinMaterial
        /// Grouped settings cards.
        public static let card: Material = .regularMaterial
        /// Chips / small floating elements.
        public static let chip: Material = .thinMaterial
        /// Top bar / hero backing.
        public static let bar: Material = .bar
    }
}

// MARK: - AppKit helpers

extension NSAppearance {
    /// True when the effective appearance is one of the dark variants.
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

extension Color {
    /// Build a dynamic Color from explicit light/dark `NSColor`s. Resolves at
    /// draw time, so it tracks appearance changes without manual refresh.
    init(light: NSColor, dark: NSColor) {
        self = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.isDark ? dark : light
        }))
    }
}

// MARK: - Liquid Glass-ready surface modifier

public extension Key84DS {
    /// Surface treatment for a rounded container.
    ///
    /// On macOS 26 this is where Liquid Glass (`.glassEffect`) would be applied;
    /// today, and on the project's current SDK, it renders a standard material
    /// with a hairline border so the code builds and looks native everywhere.
    /// When the build SDK gains the macOS 26 glass APIs, add a
    /// `if #available(macOS 26.0, *)` branch here — no call site needs to change.
    struct LiquidGlassSurface: ViewModifier {
        var material: Material
        var cornerRadius: CGFloat
        var showBorder: Bool

        public func body(content: Content) -> some View {
            content
                .background(material, in: shape)
                .overlay {
                    if showBorder {
                        shape.strokeBorder(Key84DS.Color.separator.opacity(0.6), lineWidth: 1)
                    }
                }
        }

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        }
    }
}

public extension View {
    /// Apply a Liquid Glass-ready surface (material today, glass on macOS 26).
    func liquidGlassSurface(
        _ material: Material = Key84DS.Surface.card,
        cornerRadius: CGFloat = Key84DS.Radius.card,
        border: Bool = true
    ) -> some View {
        modifier(Key84DS.LiquidGlassSurface(
            material: material, cornerRadius: cornerRadius, showBorder: border
        ))
    }
}

// MARK: - Card / group surfaces

/// A rounded, material-backed card. The lowest-level surface component.
public struct Key84GlassCard<Content: View>: View {
    private var padding: CGFloat
    private var cornerRadius: CGFloat
    private var content: Content

    public init(
        padding: CGFloat = Key84DS.Layout.cardPadding,
        cornerRadius: CGFloat = Key84DS.Radius.card,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .liquidGlassSurface(Key84DS.Surface.card, cornerRadius: cornerRadius)
    }
}

/// A titled group of setting rows rendered as a single card, with dividers
/// automatically inserted between rows (last divider omitted). Mirrors the
/// grouped look of macOS System Settings.
public struct Key84SettingsGroup<Content: View>: View {
    private var title: String?
    private var footer: String?
    private var content: Content

    public init(
        _ title: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Key84DS.Spacing.sm) {
            if let title {
                Key84SectionHeader(title)
            }
            _VariadicView.Tree(DividedRows()) {
                content
            }
            .liquidGlassSurface(Key84DS.Surface.card, cornerRadius: Key84DS.Radius.card)
            if let footer {
                Text(footer)
                    .font(Key84DS.Typography.caption)
                    .foregroundStyle(Key84DS.Color.textSecondary)
                    .padding(.horizontal, Key84DS.Spacing.xs)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Lays rows out vertically and inserts an inset divider between them.
    private struct DividedRows: _VariadicView_MultiViewRoot {
        @ViewBuilder
        func body(children: _VariadicView.Children) -> some View {
            let last = children.last?.id
            VStack(spacing: 0) {
                ForEach(children) { child in
                    child
                    if child.id != last {
                        Divider()
                            .padding(.leading, Key84DS.Layout.cardPadding)
                    }
                }
            }
        }
    }
}

/// A section header label, e.g. "Tổng quan".
public struct Key84SectionHeader: View {
    private let title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        Text(title)
            .font(Key84DS.Typography.sectionTitle)
            .foregroundStyle(Key84DS.Color.textSecondary)
            .textCase(nil)
    }
}

// MARK: - Setting rows

/// The base setting row: optional icon, title, optional subtitle and a trailing
/// control. All higher-level rows compose this for a consistent height/layout.
public struct Key84SettingRow<Control: View>: View {
    private let title: String
    private let subtitle: String?
    private let systemIcon: String?
    private let isEnabled: Bool
    private let control: Control

    public init(
        _ title: String,
        subtitle: String? = nil,
        systemIcon: String? = nil,
        isEnabled: Bool = true,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemIcon = systemIcon
        self.isEnabled = isEnabled
        self.control = control()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Key84DS.Spacing.md) {
            if let systemIcon {
                Image(systemName: systemIcon)
                    .font(.system(size: Key84DS.Layout.iconRow))
                    .foregroundStyle(Key84DS.Color.accent)
                    .frame(width: Key84DS.Layout.iconRow + 6)
            }
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
            Spacer(minLength: Key84DS.Spacing.md)
            control
        }
        .padding(.horizontal, Key84DS.Layout.cardPadding)
        .padding(.vertical, Key84DS.Layout.rowVPadding)
        .frame(minHeight: Key84DS.Layout.rowMinHeight)
        .opacity(isEnabled ? 1 : 0.45)
        .allowsHitTesting(isEnabled)
        .contentShape(Rectangle())
    }
}

/// A row with a native toggle, accent-tinted.
public struct Key84ToggleRow: View {
    private let title: String
    private let subtitle: String?
    private let systemIcon: String?
    @Binding private var isOn: Bool
    private let isEnabled: Bool

    public init(
        _ title: String,
        subtitle: String? = nil,
        systemIcon: String? = nil,
        isOn: Binding<Bool>,
        isEnabled: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemIcon = systemIcon
        self._isOn = isOn
        self.isEnabled = isEnabled
    }

    public var body: some View {
        Key84SettingRow(title, subtitle: subtitle, systemIcon: systemIcon, isEnabled: isEnabled) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Key84DS.Color.accent)
                .disabled(!isEnabled)
        }
    }
}

/// A row hosting a native menu-style `Picker`. The picker content is supplied by
/// the caller (e.g. a set of `Text(...).tag(...)`).
public struct Key84PickerRow<SelectionValue: Hashable, Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let systemIcon: String?
    @Binding private var selection: SelectionValue
    private let content: Content

    public init(
        _ title: String,
        subtitle: String? = nil,
        systemIcon: String? = nil,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemIcon = systemIcon
        self._selection = selection
        self.content = content()
    }

    public var body: some View {
        Key84SettingRow(title, subtitle: subtitle, systemIcon: systemIcon) {
            Picker("", selection: $selection) { content }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(Key84DS.Color.accent)
                .fixedSize()
        }
    }
}

/// A read-only row that shows trailing informational text.
public struct Key84InfoRow: View {
    private let title: String
    private let subtitle: String?
    private let systemIcon: String?
    private let value: String

    public init(
        _ title: String,
        subtitle: String? = nil,
        systemIcon: String? = nil,
        value: String
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemIcon = systemIcon
        self.value = value
    }

    public var body: some View {
        Key84SettingRow(title, subtitle: subtitle, systemIcon: systemIcon) {
            Text(value)
                .font(Key84DS.Typography.rowTitle)
                .foregroundStyle(Key84DS.Color.textSecondary)
        }
    }
}

/// A tappable navigation row with a trailing chevron and hover highlight.
public struct Key84NavigationRow: View {
    private let title: String
    private let subtitle: String?
    private let systemIcon: String?
    private let action: () -> Void
    @State private var isHovering = false

    public init(
        _ title: String,
        subtitle: String? = nil,
        systemIcon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemIcon = systemIcon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Key84SettingRow(title, subtitle: subtitle, systemIcon: systemIcon) {
                Image(systemName: "chevron.right")
                    .font(.system(size: Key84DS.Layout.iconSmall, weight: .semibold))
                    .foregroundStyle(Key84DS.Color.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .background(isHovering ? Key84DS.Color.accentSoft : SwiftUI.Color.clear)
        .onHover { hovering in
            withAnimation(Key84DS.Animation.hover) { isHovering = hovering }
        }
    }
}

// MARK: - Sidebar

/// Model describing one sidebar destination.
public struct Key84SidebarItemModel: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let systemIcon: String
    public var badge: String?

    public init(id: String, title: String, systemIcon: String, badge: String? = nil) {
        self.id = id
        self.title = title
        self.systemIcon = systemIcon
        self.badge = badge
    }
}

/// A native-feeling sidebar row with icon, title, optional badge, selection and
/// hover states.
public struct Key84SidebarItem: View {
    private let model: Key84SidebarItemModel
    private let isSelected: Bool
    private let action: () -> Void
    @State private var isHovering = false

    public init(
        _ model: Key84SidebarItemModel,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.model = model
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Key84DS.Spacing.md) {
                Image(systemName: model.systemIcon)
                    .font(.system(size: Key84DS.Layout.iconSidebar))
                    .foregroundStyle(isSelected ? Key84DS.Color.accent : Key84DS.Color.textSecondary)
                    .frame(width: Key84DS.Layout.iconSidebar + 6)
                Text(model.title)
                    .font(Key84DS.Typography.sidebarItem)
                    .foregroundStyle(Key84DS.Color.textPrimary)
                Spacer(minLength: 0)
                if let badge = model.badge {
                    Text(badge)
                        .font(Key84DS.Typography.badge)
                        .foregroundStyle(Key84DS.Color.accent)
                        .padding(.horizontal, Key84DS.Spacing.sm)
                        .padding(.vertical, Key84DS.Spacing.xxs)
                        .background(Key84DS.Color.accentSoft, in: Capsule())
                }
            }
            .padding(.horizontal, Key84DS.Spacing.md)
            .padding(.vertical, Key84DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(rowBackground)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Key84DS.Animation.hover) { isHovering = hovering }
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        let shape = RoundedRectangle(cornerRadius: Key84DS.Radius.row, style: .continuous)
        if isSelected {
            shape.fill(Key84DS.Color.sidebarSelection)
        } else if isHovering {
            shape.fill(Key84DS.Color.accentSoft.opacity(0.5))
        } else {
            shape.fill(SwiftUI.Color.clear)
        }
    }
}

/// Bottom-of-sidebar app identity area: small 84 badge + name + version.
public struct Key84SidebarFooter: View {
    private let version: String
    public init(version: String) { self.version = version }

    public var body: some View {
        HStack(spacing: Key84DS.Spacing.sm) {
            Key84AppBadge(size: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text("84Key")
                    .font(Key84DS.Typography.rowTitle.weight(.semibold))
                Text("Phiên bản \(version)")
                    .font(Key84DS.Typography.caption)
                    .foregroundStyle(Key84DS.Color.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Key84DS.Spacing.md)
        .padding(.vertical, Key84DS.Spacing.sm)
    }
}

// MARK: - Status / Hero

/// The square 84Key badge used in the sidebar footer and hero card.
public struct Key84AppBadge: View {
    private let size: CGFloat
    public init(size: CGFloat = 36) { self.size = size }

    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Key84DS.Color.accent, Key84DS.Color.accent.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Text("84")
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .shadow(color: Key84DS.Color.accent.opacity(0.30), radius: 4, y: 1)
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

/// A compact status chip, e.g. "Tiếng Việt: Bật" or a shortcut "⌥ Space".
public struct Key84StatusChip: View {
    private let title: String
    private let systemIcon: String?
    private let style: Key84ChipStyle
    private let monospaced: Bool

    public init(
        _ title: String,
        systemIcon: String? = nil,
        style: Key84ChipStyle = .neutral,
        monospaced: Bool = false
    ) {
        self.title = title
        self.systemIcon = systemIcon
        self.style = style
        self.monospaced = monospaced
    }

    public var body: some View {
        HStack(spacing: Key84DS.Spacing.xs) {
            if let systemIcon {
                Image(systemName: systemIcon)
                    .font(.system(size: Key84DS.Layout.iconSmall, weight: .semibold))
            }
            Text(title)
                .font(monospaced ? Key84DS.Typography.monoShortcut : Key84DS.Typography.badge)
        }
        .foregroundStyle(style.tint)
        .padding(.horizontal, Key84DS.Spacing.sm)
        .padding(.vertical, Key84DS.Spacing.xs)
        .background(Key84DS.Surface.chip, in: Capsule())
        .overlay(Capsule().strokeBorder(style.tint.opacity(0.25), lineWidth: 1))
    }
}

/// The top hero status card: 84Key badge, headline, status + shortcut chips and
/// a primary action. Logic is left to the caller; this is presentation only.
public struct Key84HeroStatusCard: View {
    private let isVietnamese: Bool
    private let shortcut: String
    private let primaryActionTitle: String
    private let primaryAction: () -> Void

    public init(
        isVietnamese: Bool,
        shortcut: String = "⌥ Space",
        primaryActionTitle: String = "Mở thanh menu",
        primaryAction: @escaping () -> Void
    ) {
        self.isVietnamese = isVietnamese
        self.shortcut = shortcut
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Key84DS.Spacing.lg) {
            Key84AppBadge(size: 52)

            VStack(alignment: .leading, spacing: Key84DS.Spacing.sm) {
                Text("84Key")
                    .font(Key84DS.Typography.title)
                HStack(spacing: Key84DS.Spacing.sm) {
                    Key84StatusChip(
                        isVietnamese ? "Tiếng Việt: Bật" : "Tiếng Việt: Tắt",
                        systemIcon: isVietnamese ? "checkmark.circle.fill" : "circle",
                        style: isVietnamese ? .success : .neutral
                    )
                    Key84StatusChip("Phím tắt: \(shortcut)", systemIcon: "command", style: .neutral, monospaced: true)
                }
            }

            Spacer(minLength: Key84DS.Spacing.md)

            Button(action: primaryAction) {
                Text(primaryActionTitle)
            }
            .buttonStyle(.borderedProminent)
            .tint(Key84DS.Color.accent)
            .controlSize(.large)
        }
        .padding(Key84DS.Spacing.lg)
        .liquidGlassSurface(Key84DS.Surface.bar, cornerRadius: Key84DS.Radius.hero)
    }
}

// MARK: - Search field

/// A native-style search field wrapper (used by the future Settings search).
public struct Key84SearchField: View {
    private let placeholder: String
    @Binding private var text: String

    public init(_ placeholder: String = "Tìm kiếm", text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    public var body: some View {
        HStack(spacing: Key84DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Key84DS.Color.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Key84DS.Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Key84DS.Spacing.sm)
        .padding(.vertical, Key84DS.Spacing.xs)
        .liquidGlassSurface(Key84DS.Surface.chip, cornerRadius: Key84DS.Radius.row)
    }
}

// MARK: - Previews

#if DEBUG
private struct Key84DesignSystemPreview: View {
    @State private var telex = 0
    @State private var autoDetect = true
    @State private var fixSpotlight = true
    @State private var smartSwitch = false
    @State private var search = ""
    @State private var selectedSidebar = "overview"

    private let sidebarItems: [Key84SidebarItemModel] = [
        .init(id: "overview", title: "Tổng quan", systemIcon: "square.grid.2x2"),
        .init(id: "input", title: "Nhập liệu", systemIcon: "keyboard"),
        .init(id: "vietnamese", title: "Gõ tiếng Việt", systemIcon: "character.book.closed"),
        .init(id: "smart", title: "Tính năng thông minh", systemIcon: "wand.and.stars", badge: "Mới"),
        .init(id: "compat", title: "Tương thích", systemIcon: "puzzlepiece.extension"),
        .init(id: "system", title: "Hệ thống", systemIcon: "gearshape"),
        .init(id: "shortcuts", title: "Phím tắt", systemIcon: "command"),
        .init(id: "advanced", title: "Nâng cao", systemIcon: "slider.horizontal.3"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: Key84DS.Spacing.xs) {
                Key84SearchField(text: $search)
                    .padding(.horizontal, Key84DS.Spacing.sm)
                    .padding(.top, Key84DS.Spacing.sm)
                ScrollView {
                    VStack(spacing: Key84DS.Spacing.xxs) {
                        ForEach(sidebarItems) { item in
                            Key84SidebarItem(item, isSelected: selectedSidebar == item.id) {
                                selectedSidebar = item.id
                            }
                        }
                    }
                    .padding(.horizontal, Key84DS.Spacing.sm)
                    .padding(.top, Key84DS.Spacing.sm)
                }
                Divider()
                Key84SidebarFooter(version: "0.1.0")
            }
            .frame(width: Key84DS.Layout.sidebarWidth)
            .background(Key84DS.Surface.sidebar)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: Key84DS.Layout.sectionSpacing) {
                    Key84HeroStatusCard(isVietnamese: true) {}

                    Key84SettingsGroup("Nhập liệu") {
                        Key84PickerRow("Kiểu gõ", systemIcon: "keyboard", selection: $telex) {
                            Text("Telex").tag(0)
                            Text("VNI").tag(1)
                            Text("Simple Telex").tag(2)
                        }
                        Key84InfoRow("Bảng mã", systemIcon: "textformat", value: "Unicode")
                    }

                    Key84SettingsGroup(
                        "Tính năng thông minh",
                        footer: "Tự động bỏ qua bỏ dấu khi gõ một từ tiếng Anh, không cần chuyển chế độ."
                    ) {
                        Key84ToggleRow("Tự động nhận diện tiếng Anh",
                                       subtitle: "Gõ tiếng Anh tự nhiên trong khi vẫn bật tiếng Việt.",
                                       systemIcon: "character.cursor.ibeam",
                                       isOn: $autoDetect)
                        Key84ToggleRow("Sửa lỗi bỏ dấu trong Spotlight",
                                       systemIcon: "magnifyingglass",
                                       isOn: $fixSpotlight)
                        Key84ToggleRow("Phím chuyển thông minh",
                                       subtitle: "Nhớ ngôn ngữ theo từng ứng dụng.",
                                       systemIcon: "rectangle.2.swap",
                                       isOn: $smartSwitch)
                    }

                    Key84SettingsGroup("Hệ thống") {
                        Key84NavigationRow("Quyền Trợ năng", subtitle: "Đã cấp quyền", systemIcon: "lock.shield") {}
                        Key84InfoRow("Chuyển ngôn ngữ", systemIcon: "globe", value: "⌥ Space")
                    }
                }
                .padding(Key84DS.Spacing.xl)
                .frame(maxWidth: Key84DS.Layout.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Key84DS.Surface.window)
        }
        .frame(width: Key84DS.Layout.windowMinWidth, height: Key84DS.Layout.windowMinHeight)
    }
}

#Preview("Mock Settings Pane") {
    Key84DesignSystemPreview()
}

#Preview("Components") {
    @Previewable @State var on = true
    @Previewable @State var pick = 0
    return VStack(alignment: .leading, spacing: Key84DS.Spacing.lg) {
        Key84HeroStatusCard(isVietnamese: false) {}
        Key84SettingsGroup("Ví dụ") {
            Key84ToggleRow("Toggle row", subtitle: "Có phụ đề", isOn: $on)
            Key84PickerRow("Picker row", selection: $pick) {
                Text("Một").tag(0); Text("Hai").tag(1)
            }
            Key84InfoRow("Info row", value: "Giá trị")
            Key84NavigationRow("Navigation row") {}
        }
        HStack {
            Key84StatusChip("Tiếng Việt: Bật", systemIcon: "checkmark.circle.fill", style: .success)
            Key84StatusChip("⌥ Space", style: .neutral, monospaced: true)
        }
    }
    .padding(Key84DS.Spacing.xl)
    .frame(width: 560)
    .background(Key84DS.Surface.window)
}
#endif
