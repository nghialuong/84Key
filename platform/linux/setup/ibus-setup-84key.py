#!/usr/bin/env python3
#
# ibus-setup-84key — the 84Key settings window on Linux.
#
# GNOME opens it from Settings > Keyboard > Input Sources > 84Key > Preferences,
# and the engine's input-source menu from "Cài đặt 84Key…". It edits the same
# file the engine reads (~/.config/84key/settings.ini, see
# platform/linux/src/Settings.h); the engine picks every change up as soon as
# the file is written, so there is no Apply button.
#
# The sections and labels follow the macOS app (platform/macos/App/Settings) so
# the two read the same. Uses libadwaita widgets that exist since 1.0, so it runs
# on Ubuntu 22.04 as well as current releases.
#
# Copyright (C) 2026 84Key contributors. Licensed under the GNU GPL v3 or later.

import os
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, Gio, GLib, Gtk  # noqa: E402

APP_ID = "io.github.nghialuong.Key84.Setup"
GROUP = "84Key"
ENGINE = ("ibus", "84key")

# Keep in step with platform/linux/src/EngineGlobals.cpp.
DEFAULTS = {
    "vLanguage": 1,
    "vInputType": 0,
    "vCodeTable": 0,
    "vFreeMark": 0,
    "vCheckSpelling": 1,
    "vUseModernOrthography": 1,
    "vQuickTelex": 0,
    "vRestoreIfWrongSpelling": 0,
    "vUseSmartSwitchKey": 1,
    "vUpperCaseFirstChar": 0,
    "vAllowConsonantZFWJ": 0,
    "vQuickStartConsonant": 0,
    "vQuickEndConsonant": 0,
    "vAutoDetectEnglish": 1,
}
DEFAULT_SWITCH_KEY = "Control+Shift"

# Other Vietnamese engines that would fight 84Key over the same keys.
OTHER_VIETNAMESE = ("Unikey", "Bamboo", "bamboo", "unikey", "m17n:vi:telex", "m17n:vi:vni",
                    "m17n:vi:tcvn", "m17n:vi:viqr")


def settings_path():
    return os.path.join(GLib.get_user_config_dir(), "84key", "settings.ini")


class SettingsFile:
    """The engine's settings file. Every write starts from what is on disk, so a
    change the engine made meanwhile (VI/EN from the menu) is kept — and a file
    that cannot be parsed (a hand edit in progress) is never written over."""

    def __init__(self):
        self.path = settings_path()
        self.broken = False

    def _load(self):
        """The parsed file (empty if there is none), or None if it cannot be parsed."""
        kf = GLib.KeyFile()
        try:
            kf.load_from_file(self.path, GLib.KeyFileFlags.KEEP_COMMENTS)
        except GLib.Error as e:
            if not e.matches(GLib.file_error_quark(), GLib.FileError.NOENT):
                self.broken = True
                return None
        self.broken = False
        return kf

    def get(self, key):
        kf = self._load()
        try:
            return kf.get_integer(GROUP, key) if kf else DEFAULTS[key]
        except GLib.Error:
            return DEFAULTS[key]

    def get_switch_key(self):
        kf = self._load()
        try:
            return kf.get_string(GROUP, "SwitchKey") if kf else DEFAULT_SWITCH_KEY
        except GLib.Error:
            return DEFAULT_SWITCH_KEY

    def set(self, key, value):
        """Write one value; False (and nothing written) if the file cannot be parsed."""
        kf = self._load()
        if kf is None:
            return False
        if isinstance(value, str):
            kf.set_string(GROUP, key, value)
        else:
            kf.set_integer(GROUP, key, int(value))
        os.makedirs(os.path.dirname(self.path), mode=0o700, exist_ok=True)
        kf.save_to_file(self.path)
        return True


# ---- The switch hotkey, as text and as the recorder sees it -------------------------

MODIFIER_KEYS = {
    "Control_L": "Control", "Control_R": "Control",
    "Shift_L": "Shift", "Shift_R": "Shift",
    "Alt_L": "Alt", "Alt_R": "Alt", "Meta_L": "Alt", "Meta_R": "Alt",
    "Super_L": "Super", "Super_R": "Super", "Hyper_L": "Super", "Hyper_R": "Super",
}
MODIFIER_ORDER = ("Control", "Shift", "Alt", "Super")


def modifiers_of_state(state):
    mods = set()
    if state & Gdk.ModifierType.CONTROL_MASK:
        mods.add("Control")
    if state & Gdk.ModifierType.SHIFT_MASK:
        mods.add("Shift")
    # Folded as the engine does (SwitchKey.cpp): Meta is Alt, Hyper is Super.
    if state & (Gdk.ModifierType.ALT_MASK | Gdk.ModifierType.META_MASK):
        mods.add("Alt")
    if state & (Gdk.ModifierType.SUPER_MASK | Gdk.ModifierType.HYPER_MASK):
        mods.add("Super")
    return mods


def join_combo(mods, key=None):
    parts = [m for m in MODIFIER_ORDER if m in mods]
    if key:
        parts.append(key)
    return "+".join(parts)


def display_combo(combo):
    if not combo:
        return "Không dùng"
    names = {"Control": "Ctrl", "Super": "Super", "space": "Space"}
    return " + ".join(names.get(p, p.upper() if len(p) == 1 else p) for p in combo.split("+"))


class ShortcutButton(Gtk.Button):
    """Click, then press the new shortcut. Modifiers alone (Ctrl+Shift) are taken
    when released; a key needs a modifier other than Shift (Shift+A would swallow
    every capital A). Esc cancels, Backspace removes the shortcut."""

    def __init__(self, combo, on_changed):
        super().__init__(valign=Gtk.Align.CENTER)
        self.combo = combo
        self.on_changed = on_changed
        self.recording = False
        self.held = set()
        self.peak = set()
        self.used_key = False
        self.connect("clicked", self._start)
        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", self._pressed)
        keys.connect("key-released", self._released)
        self.add_controller(keys)
        self._refresh()

    def _refresh(self):
        self.set_label("Nhấn phím tắt mới…" if self.recording else display_combo(self.combo))

    def _start(self, _button):
        self.recording = True
        self.held, self.peak, self.used_key = set(), set(), False
        self._refresh()

    def _finish(self, combo=None, changed=False):
        self.recording = False
        if changed:
            self.combo = combo
            self.on_changed(combo)
        self._refresh()

    def _pressed(self, _controller, keyval, _keycode, state):
        if not self.recording:
            return False
        name = Gdk.keyval_name(keyval) or ""
        if name in MODIFIER_KEYS:
            self.held = modifiers_of_state(state) | {MODIFIER_KEYS[name]}
            self.peak |= self.held
            return True
        mods = modifiers_of_state(state)
        if keyval == Gdk.KEY_Escape and not mods:
            self._finish()
        elif keyval == Gdk.KEY_BackSpace and not mods:
            self._finish("", changed=True)
        elif mods - {"Shift"}:
            self.used_key = True
            self._finish(join_combo(mods, Gdk.keyval_name(Gdk.keyval_to_lower(keyval))), changed=True)
        return True

    def _released(self, _controller, keyval, _keycode, state):
        if not self.recording:
            return
        name = Gdk.keyval_name(keyval) or ""
        if name not in MODIFIER_KEYS or self.used_key:
            return
        if len(self.peak) >= 2:
            self._finish(join_combo(self.peak), changed=True)
        elif not (modifiers_of_state(state) - {MODIFIER_KEYS[name]}):
            self.peak = set()   # a lone modifier came and went: start over


# ---- The window ------------------------------------------------------------------------

class SetupWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Cài đặt 84Key", default_width=560, default_height=720)
        self.file = SettingsFile()
        self.widgets = {}
        self.updating = False

        page = Adw.PreferencesPage()
        page.add(self._status_group())
        page.add(self._input_group())
        page.add(self._auto_group())
        page.add(self._spelling_group())
        page.add(self._quick_group())
        page.add(self._switch_group())

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box.append(Adw.HeaderBar())
        page.set_vexpand(True)
        box.append(page)
        self.set_content(box)

        # The engine also writes the file (VI/EN, the input-source menu): follow it.
        self.monitor = Gio.File.new_for_path(self.file.path).monitor_file(Gio.FileMonitorFlags.WATCH_MOVES, None)
        self.monitor.connect("changed", lambda *_: GLib.timeout_add(100, self._reload))

    # -- rows

    def _switch_row(self, key, title, subtitle=None):
        row = Adw.ActionRow(title=title)
        if subtitle:
            row.set_subtitle(subtitle)
        switch = Gtk.Switch(valign=Gtk.Align.CENTER, active=bool(self.file.get(key)))
        switch.connect("notify::active", lambda s, _p: self._set(key, 1 if s.get_active() else 0))
        row.add_suffix(switch)
        row.set_activatable_widget(switch)
        self.widgets[key] = switch
        return row

    def _choice_row(self, key, title, choices, subtitle=None):
        row = Adw.ComboRow(title=title, model=Gtk.StringList.new(choices))
        if subtitle:
            row.set_subtitle(subtitle)
        row.set_selected(max(0, min(len(choices) - 1, self.file.get(key))))
        row.connect("notify::selected", lambda r, _p: self._set(key, r.get_selected()))
        self.widgets[key] = row
        return row

    def _set(self, key, value):
        if not self.updating and not self.file.set(key, value):
            self._refresh_status()

    def _set_switch_key(self, combo):
        if not self.file.set("SwitchKey", combo):
            self._refresh_status()

    def _reload(self):
        self._refresh_status()
        self.updating = True
        for key, widget in self.widgets.items():
            value = self.file.get(key)
            if isinstance(widget, Gtk.Switch):
                widget.set_active(bool(value))
            else:
                widget.set_selected(value)
        self.updating = False
        return GLib.SOURCE_REMOVE

    # -- groups

    def _status_group(self):
        group = Adw.PreferencesGroup(title="Trạng thái")
        self.status_row = Adw.ActionRow()
        self.status_button = Gtk.Button(valign=Gtk.Align.CENTER)
        self.status_button.connect("clicked", self._fix_sources)
        self.status_row.add_suffix(self.status_button)
        group.add(self.status_row)
        self._refresh_status()
        return group

    def _input_sources(self):
        schema = Gio.SettingsSchemaSource.get_default().lookup("org.gnome.desktop.input-sources", True)
        if schema is None:
            return None
        return Gio.Settings.new("org.gnome.desktop.input-sources")

    def _refresh_status(self):
        settings = self._input_sources()
        self.status_button.set_visible(False)
        self.file.get("vLanguage")   # re-reads the file, updating .broken
        if self.file.broken:
            self.status_row.set_title("Không đọc được tệp cài đặt")
            self.status_row.set_subtitle("Sửa lỗi trong %s; thay đổi sẽ chưa được lưu cho tới khi đó."
                                         % self.file.path)
            return
        if settings is None:
            self.status_row.set_title("84Key")
            self.status_row.set_subtitle("Thêm 84Key trong phần cài đặt bộ gõ IBus của môi trường làm việc.")
            return
        sources = settings.get_value("sources").unpack()
        others = [s for s in sources if s[0] == "ibus" and s[1] in OTHER_VIETNAMESE]
        if tuple(ENGINE) not in [tuple(s) for s in sources]:
            self.status_row.set_title("84Key chưa có trong Nguồn nhập liệu")
            self.status_row.set_subtitle("Thêm 84Key để gõ tiếng Việt. Chuyển bộ gõ bằng Super + Space.")
            self.status_button.set_label("Thêm 84Key")
            self.status_button.set_visible(True)
        elif others:
            self.status_row.set_title("Tắt các bộ gõ tiếng Việt khác")
            self.status_row.set_subtitle(
                "Đang bật: %s. Hai bộ gõ tiếng Việt cùng lúc sẽ gây lặp ký tự hoặc sai chữ."
                % ", ".join(s[1] for s in others))
            self.status_button.set_label("Gỡ khỏi Nguồn nhập liệu")
            self.status_button.set_visible(True)
        else:
            self.status_row.set_title("84Key đã sẵn sàng")
            self.status_row.set_subtitle("Chọn 84Key trên thanh trên cùng (hoặc Super + Space) để gõ tiếng Việt.")

    def _fix_sources(self, _button):
        # One thing per click, matching the label: add 84Key, or — once it is
        # there — remove the other Vietnamese engines.
        settings = self._input_sources()
        sources = [tuple(s) for s in settings.get_value("sources").unpack()]
        if ENGINE not in sources:
            sources.append(ENGINE)
        else:
            sources = [s for s in sources if not (s[0] == "ibus" and s[1] in OTHER_VIETNAMESE)]
        settings.set_value("sources", GLib.Variant("a(ss)", sources))
        self._refresh_status()

    def _input_group(self):
        group = Adw.PreferencesGroup(title="Bộ gõ")
        group.add(self._choice_row("vInputType", "Kiểu gõ", ["Telex", "VNI", "Simple Telex 1", "Simple Telex 2"]))
        group.add(self._choice_row("vCodeTable", "Bảng mã",
                                   ["Unicode", "TCVN3 (ABC)", "VNI Windows", "Unicode tổ hợp", "Vietnamese CP1258"],
                                   "Unicode phù hợp với hầu hết ứng dụng hiện đại."))
        return group

    def _auto_group(self):
        group = Adw.PreferencesGroup(title="Tự động")
        group.add(self._switch_row("vAutoDetectEnglish", "Tự động nhận diện tiếng Anh",
                                   "Bỏ qua việc bỏ dấu khi gõ từ tiếng Anh trong kiểu Telex, "
                                   "không cần chuyển chế độ."))
        group.add(self._switch_row("vUseSmartSwitchKey", "Phím chuyển thông minh",
                                   "Ghi nhớ VI/EN theo từng ứng dụng."))
        return group

    def _spelling_group(self):
        group = Adw.PreferencesGroup(title="Chính tả")
        group.add(self._switch_row("vCheckSpelling", "Kiểm tra chính tả"))
        group.add(self._switch_row("vUseModernOrthography", "Chính tả hiện đại (oà, uý)"))
        group.add(self._switch_row("vFreeMark", "Bỏ dấu tự do"))
        group.add(self._switch_row("vRestoreIfWrongSpelling", "Khôi phục từ nếu sai chính tả"))
        return group

    def _quick_group(self):
        group = Adw.PreferencesGroup(title="Telex nhanh")
        group.add(self._switch_row("vQuickTelex", "Telex nhanh (cc→ch, gg→gi…)"))
        group.add(self._switch_row("vQuickStartConsonant", "Phụ âm đầu nhanh (f→ph, j→gi, w→qu)"))
        group.add(self._switch_row("vQuickEndConsonant", "Phụ âm cuối nhanh (g→ng, h→nh, k→ch)"))
        group.add(self._switch_row("vAllowConsonantZFWJ", "Cho phép Z / F / W / J là chữ cái"))
        group.add(self._switch_row("vUpperCaseFirstChar", "Viết hoa chữ cái đầu"))
        return group

    def _switch_group(self):
        group = Adw.PreferencesGroup(title="Chuyển ngôn ngữ")
        row = Adw.ActionRow(title="Phím tắt chuyển Việt / Anh",
                            subtitle="Bấm rồi nhấn tổ hợp phím mới. Esc để hủy, Backspace để bỏ phím tắt.")
        button = ShortcutButton(self.file.get_switch_key(), self._set_switch_key)
        row.add_suffix(button)
        group.add(row)
        return group


class SetupApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.FLAGS_NONE)

    def do_activate(self):
        window = self.get_active_window() or SetupWindow(self)
        window.present()


if __name__ == "__main__":
    sys.exit(SetupApp().run(sys.argv))
