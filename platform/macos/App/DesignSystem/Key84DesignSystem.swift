//
//  Key84DesignSystem.swift
//  84Key
//
//  A small, deliberately boring set of tokens and helpers that make 84Key look
//  like a real macOS System Settings pane. Native controls do the heavy lifting
//  (List(selection:) for the sidebar, Toggle/Picker/Button for rows); this file
//  only provides the grouped-surface chrome, compact row layout and type/space
//  tokens so every page shares the same native rhythm.
//
//  Design rule: when there's a choice, pick the more boring, more native option.
//  Surfaces use system colors (controlBackgroundColor / separatorColor), so the
//  result tracks light/dark and accessibility automatically. No third-party
//  dependencies and no private or non-existent APIs.
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

        // Text — system labels.
        public static let textPrimary   = SwiftUI.Color.primary
        public static let textSecondary = SwiftUI.Color.secondary

        // Structure — all system colors.
        public static let separator      = SwiftUI.Color(nsColor: .separatorColor)
        public static let groupBackground = SwiftUI.Color(nsColor: .controlBackgroundColor)

        // Status
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
    /// macOS-native hierarchy. Compact; nothing oversized.
    enum Typography {
        public static let pageTitle    = Font.system(size: 28, weight: .semibold)
        public static let pageSubtitle = Font.system(size: 13)
        public static let sectionLabel = Font.system(size: 13, weight: .semibold)
        public static let rowTitle     = Font.system(size: 13)
        public static let rowSubtitle  = Font.system(size: 12)
        public static let caption      = Font.system(size: 11)
        public static let monoValue    = Font.system(size: 13, design: .monospaced)
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

        public static let contentMaxWidth:   CGFloat = 640
        public static let detailTopPadding:        CGFloat = 42
        public static let detailHorizontalPadding: CGFloat = 40
        public static let detailBottomPadding:     CGFloat = 28
        public static let sectionSpacing:    CGFloat = 22

        // Rows
        public static let rowMinHeight:         CGFloat = 40
        public static let rowMinHeightSubtitle: CGFloat = 56
        public static let rowHPadding:          CGFloat = 14
        public static let rowVPadding:          CGFloat = 8
        public static let rowVPaddingSubtitle:  CGFloat = 10
        public static let dividerInset:         CGFloat = 14

        public static let groupCornerRadius: CGFloat = 10
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

// MARK: - Native grouped surface

public extension View {
    /// Native grouped-control surface: a barely-there `controlBackgroundColor`
    /// fill with a hairline separator border — the macOS System Settings group
    /// look (not a heavy material panel).
    ///
    /// This is the one place surface styling is decided, so it's also where
    /// Liquid Glass (`.glassEffect`) would slot in on macOS 26 behind a
    /// `if #available(macOS 26.0, *)` check — no call site would change.
    func key84CardSurface(cornerRadius: CGFloat = Key84DS.Layout.groupCornerRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(Key84DS.Color.groupBackground, in: shape)
            .overlay(shape.strokeBorder(Key84DS.Color.separator.opacity(0.35), lineWidth: 0.5))
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

// MARK: - Settings group (native grouped rows)

/// A group of rows rendered as a single native-looking grouped panel, with an
/// inset divider between rows. Optional title sits outside the panel; optional
/// footer is small secondary text below it.
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
        VStack(alignment: .leading, spacing: 6) {
            if let title { Key84SectionHeader(title) }
            _VariadicView.Tree(DividedRows()) { content }
                .key84CardSurface()
            if let footer {
                Text(footer)
                    .font(Key84DS.Typography.caption)
                    .foregroundStyle(Key84DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }

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

// MARK: - Rows

/// A compact native settings row: title, optional subtitle, trailing accessory.
/// No decorative icons.
public struct Key84SettingRow<Accessory: View>: View {
    private let title: String
    private let subtitle: String?
    private let isEnabled: Bool
    private let accessory: Accessory

    public init(
        _ title: String,
        subtitle: String? = nil,
        isEnabled: Bool = true,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isEnabled = isEnabled
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Key84DS.Layout.rowHPadding - 2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Key84DS.Typography.rowTitle)
                    .foregroundStyle(Key84DS.Color.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Key84DS.Typography.rowSubtitle)
                        .foregroundStyle(Key84DS.Color.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 16)
            accessory
        }
        .padding(.horizontal, Key84DS.Layout.rowHPadding)
        .padding(.vertical, subtitle == nil ? Key84DS.Layout.rowVPadding : Key84DS.Layout.rowVPaddingSubtitle)
        .frame(minHeight: subtitle == nil ? Key84DS.Layout.rowMinHeight : Key84DS.Layout.rowMinHeightSubtitle)
        .opacity(isEnabled ? 1 : 0.45)
        .allowsHitTesting(isEnabled)
    }
}

/// A row with a native switch. Default system tint.
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
                .disabled(!isEnabled)
        }
    }
}

/// A row with a native menu picker.
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

/// A read-only row with trailing informational text.
public struct Key84InfoRow: View {
    private let title: String
    private let subtitle: String?
    private let value: String
    private let monospaced: Bool

    public init(_ title: String, subtitle: String? = nil, value: String, monospaced: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.monospaced = monospaced
    }

    public var body: some View {
        Key84SettingRow(title, subtitle: subtitle) {
            Text(value)
                .font(monospaced ? Key84DS.Typography.monoValue : Key84DS.Typography.rowTitle)
                .foregroundStyle(Key84DS.Color.textSecondary)
        }
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

// MARK: - Previews

#if DEBUG
private struct Key84RowsPreview: View {
    @State private var on = true
    @State private var off = false
    @State private var pick = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Key84DS.Layout.sectionSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tổng quan").font(Key84DS.Typography.pageTitle)
                    Text("Trạng thái 84Key và các tuỳ chọn quan trọng nhất.")
                        .font(Key84DS.Typography.pageSubtitle)
                        .foregroundStyle(Key84DS.Color.textSecondary)
                }
                Key84SettingsGroup("Trạng thái") {
                    Key84SettingRow("84Key", subtitle: "Tiếng Việt đang bật") {
                        Button("Chuyển sang tiếng Anh") {}.buttonStyle(.bordered)
                    }
                    Key84InfoRow("Phím tắt chuyển ngôn ngữ", value: "⌥ Space", monospaced: true)
                }
                Key84SettingsGroup("Chính tả", footer: "Unicode phù hợp với hầu hết ứng dụng.") {
                    Key84ToggleRow("Kiểm tra chính tả", isOn: $on)
                    Key84ToggleRow("Tự động nhận diện tiếng Anh",
                                   subtitle: "Bỏ qua việc bỏ dấu khi gõ từ tiếng Anh trong kiểu Telex.", isOn: $off)
                    Key84PickerRow("Kiểu gõ", selection: $pick) {
                        Text("Telex").tag(0); Text("VNI").tag(1)
                    }
                }
            }
            .frame(maxWidth: Key84DS.Layout.contentMaxWidth, alignment: .leading)
            .padding(.top, Key84DS.Layout.detailTopPadding)
            .padding(.horizontal, Key84DS.Layout.detailHorizontalPadding)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(width: 720, height: 600)
    }
}

#Preview("Rows (light)") { Key84RowsPreview().preferredColorScheme(.light) }
#Preview("Rows (dark)") { Key84RowsPreview().preferredColorScheme(.dark) }
#endif
