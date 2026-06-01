//
//  ShortcutRecorder.swift
//  84Key
//
//  A small, native macOS keyboard-shortcut recorder for the VI/EN switch hotkey,
//  plus the encode/decode/format helpers that bridge between an `NSEvent` combo
//  and the engine's `vSwitchKeyStatus` bitmask (see core/engine/Engine.h):
//
//      low byte = virtual keycode, bit8 ⌃, bit9 ⌥, bit10 ⌘, bit11 ⇧.
//
//  The recorder requires at least one modifier so a bare key can never become a
//  global toggle that swallows normal typing.
//

import SwiftUI
import AppKit
import Carbon.HIToolbox   // kVK_* virtual key codes

// MARK: - Encoding / formatting

enum Key84Shortcut {
    // Modifier bits in the engine bitmask.
    private static let controlBit = 0x100
    private static let optionBit  = 0x200
    private static let commandBit = 0x400
    private static let shiftBit   = 0x800

    /// Encode a recorded combo into the `vSwitchKeyStatus` bitmask.
    static func encode(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Int {
        var v = Int(keyCode) & 0xFF
        if modifiers.contains(.control) { v |= controlBit }
        if modifiers.contains(.option)  { v |= optionBit }
        if modifiers.contains(.command) { v |= commandBit }
        if modifiers.contains(.shift)   { v |= shiftBit }
        return v
    }

    static func keyCode(_ value: Int) -> UInt16 { UInt16(value & 0xFF) }

    /// Translate the `vSwitchKeyStatus` bitmask into a SwiftUI `KeyboardShortcut`
    /// so the menu-bar item can show the *configured* toggle combo instead of a
    /// hard-coded one. Returns `nil` when no key is set or the keycode can't be
    /// expressed as a `KeyEquivalent` (e.g. function keys) — the menu then shows
    /// no shortcut hint but still toggles when clicked. The engine's global tap
    /// consumes the combo before it reaches the app, so this never double-fires.
    static func keyboardShortcut(_ value: Int) -> KeyboardShortcut? {
        guard value != 0, let key = keyEquivalent(for: keyCode(value)) else { return nil }
        var mods: SwiftUI.EventModifiers = []
        if value & controlBit != 0 { mods.insert(.control) }
        if value & optionBit  != 0 { mods.insert(.option) }
        if value & commandBit != 0 { mods.insert(.command) }
        if value & shiftBit   != 0 { mods.insert(.shift) }
        return KeyboardShortcut(key, modifiers: mods)
    }

    private static func keyEquivalent(for code: UInt16) -> KeyEquivalent? {
        if let ch = characterKeys[Int(code)] { return KeyEquivalent(ch) }
        return namedKeyEquivalents[Int(code)]
    }

    /// Human-readable combo, e.g. "⌃⌘Space". Empty value → "Chưa đặt".
    static func displayString(_ value: Int) -> String {
        guard value != 0 else { return "Chưa đặt" }
        var s = ""
        if value & controlBit != 0 { s += "⌃" }
        if value & optionBit  != 0 { s += "⌥" }
        if value & shiftBit   != 0 { s += "⇧" }   // Apple's canonical order: ⌃⌥⇧⌘
        if value & commandBit != 0 { s += "⌘" }
        s += keyLabel(for: keyCode(value))
        return s
    }

    /// Label for a virtual keycode (ANSI layout) — letters, digits, punctuation
    /// and the common named keys. Falls back to a numeric tag.
    static func keyLabel(for code: UInt16) -> String {
        if let named = namedKeys[Int(code)] { return named }
        return "Key \(code)"
    }

    private static let namedKeys: [Int: String] = [
        // Letters
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        // Digits
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        // Punctuation
        kVK_ANSI_Equal: "=", kVK_ANSI_Minus: "-", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_LeftBracket: "[", kVK_ANSI_Quote: "'", kVK_ANSI_Semicolon: ";",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Comma: ",", kVK_ANSI_Slash: "/",
        kVK_ANSI_Period: ".", kVK_ANSI_Grave: "`",
        // Named keys
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        // Function keys
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12",
    ]

    /// Keycodes that map to a literal `KeyEquivalent` character (ANSI layout).
    /// Mirrors the letters/digits/punctuation in `namedKeys`.
    private static let characterKeys: [Int: Character] = [
        kVK_ANSI_A: "a", kVK_ANSI_B: "b", kVK_ANSI_C: "c", kVK_ANSI_D: "d",
        kVK_ANSI_E: "e", kVK_ANSI_F: "f", kVK_ANSI_G: "g", kVK_ANSI_H: "h",
        kVK_ANSI_I: "i", kVK_ANSI_J: "j", kVK_ANSI_K: "k", kVK_ANSI_L: "l",
        kVK_ANSI_M: "m", kVK_ANSI_N: "n", kVK_ANSI_O: "o", kVK_ANSI_P: "p",
        kVK_ANSI_Q: "q", kVK_ANSI_R: "r", kVK_ANSI_S: "s", kVK_ANSI_T: "t",
        kVK_ANSI_U: "u", kVK_ANSI_V: "v", kVK_ANSI_W: "w", kVK_ANSI_X: "x",
        kVK_ANSI_Y: "y", kVK_ANSI_Z: "z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Equal: "=", kVK_ANSI_Minus: "-", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_LeftBracket: "[", kVK_ANSI_Quote: "'", kVK_ANSI_Semicolon: ";",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Comma: ",", kVK_ANSI_Slash: "/",
        kVK_ANSI_Period: ".", kVK_ANSI_Grave: "`",
    ]

    /// Named keys SwiftUI can express as a `KeyEquivalent`. Function keys are
    /// intentionally absent — SwiftUI has no `KeyEquivalent` for them.
    private static let namedKeyEquivalents: [Int: KeyEquivalent] = [
        kVK_Space: .space, kVK_Return: .return, kVK_Tab: .tab, kVK_Escape: .escape,
        kVK_Delete: .delete, kVK_ForwardDelete: .deleteForward,
        kVK_LeftArrow: .leftArrow, kVK_RightArrow: .rightArrow,
        kVK_DownArrow: .downArrow, kVK_UpArrow: .upArrow,
        kVK_Home: .home, kVK_End: .end, kVK_PageUp: .pageUp, kVK_PageDown: .pageDown,
    ]
}

// MARK: - Recorder field

/// A native-feeling key-recorder bound to the engine bitmask in `AppSettings`.
/// Click to record; press a modifier+key combo to set it; Esc cancels; the small
/// ✕ clears it. Requires at least one modifier.
struct ShortcutRecorderField: View {
    @Binding var value: Int

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var hint = false   // briefly true when a no-modifier key is rejected

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggleRecording) {
                Text(label)
                    .font(Key84DS.Typography.mono)
                    .foregroundStyle(labelColor)
                    .frame(minWidth: 64)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(isRecording ? "Nhấn tổ hợp phím (kèm ⌘/⌥/⌃/⇧)" : "Bấm để đặt phím tắt")

            if value != 0 && !isRecording {
                Button {
                    value = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Xoá phím tắt")
            }
        }
        .onDisappear { stopRecording() }
    }

    private var label: String {
        if isRecording { return hint ? "Cần kèm ⌘/⌥/⌃/⇧" : "Nhấn tổ hợp phím…" }
        return Key84Shortcut.displayString(value)
    }

    private var labelColor: Color {
        if isRecording { return hint ? Key84DS.Color.warning : Key84DS.Color.accent }
        return value == 0 ? Color.secondary : Color.primary
    }

    private var borderColor: Color {
        isRecording ? Key84DS.Color.accent : Color(nsColor: .separatorColor)
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        hint = false
        // Suspend the global tap's matching so the combo we're about to press
        // doesn't also toggle the language while we record it.
        AppController.shared.input.setSwitchKeyCaptureActive(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handle(event)
            return nil   // swallow while recording
        }
    }

    private func stopRecording() {
        isRecording = false
        hint = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        AppController.shared.input.setSwitchKeyCaptureActive(false)
    }

    private func handle(_ event: NSEvent) {
        // Esc with no modifiers cancels.
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == UInt16(kVK_Escape) && mods.isEmpty {
            stopRecording()
            return
        }
        // Require at least one modifier (keyDown never fires for bare modifiers).
        guard !mods.isEmpty else {
            hint = true
            return
        }
        value = Key84Shortcut.encode(keyCode: event.keyCode, modifiers: mods)
        stopRecording()
    }
}

#if DEBUG
#Preview("Recorder") {
    @Previewable @State var v = 0x531
    Form {
        LabeledContent("Phím tắt chuyển nhanh") {
            ShortcutRecorderField(value: $v)
        }
    }
    .formStyle(.grouped)
    .frame(width: 420, height: 160)
}
#endif
