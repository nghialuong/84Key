#!/usr/bin/env python3
#
# A text field for tests/e2e.py: a GTK window (GTK 3 or 4) with a multi-line
# text view and a password entry, typed into through the real IBus stack.
#
#   e2e_app.py <gtk-version> <dir>
#
# <dir>/text      the text view's contents, rewritten whenever they change
# <dir>/password  the password entry's contents
# <dir>/ready     created once the window is up
# <dir>/clear     created by the harness: empty both fields, then remove it
# <dir>/focus     created by the harness: "text" or "password" — focus that field
#

import os
import sys

import gi

version = sys.argv[1]
gi.require_version("Gtk", version)
from gi.repository import GLib, Gtk  # noqa: E402

out = sys.argv[2]
GTK4 = version == "4.0"


def write(name, value):
    tmp = os.path.join(out, name + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(value)
    os.replace(tmp, os.path.join(out, name))


def text_of(buffer):
    return buffer.get_text(buffer.get_start_iter(), buffer.get_end_iter(), True)


view = Gtk.TextView()
password = Gtk.Entry()
password.set_visibility(False)
password.set_input_purpose(Gtk.InputPurpose.PASSWORD)

box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
if GTK4:
    view.set_vexpand(True)
    box.append(view)
    box.append(password)
    window = Gtk.Window(title="key84-e2e")
    window.set_child(box)
    window.set_default_size(600, 300)
else:
    box.pack_start(view, True, True, 0)
    box.pack_start(password, False, False, 0)
    window = Gtk.Window(title="key84-e2e")
    window.add(box)
    window.set_default_size(600, 300)

view.get_buffer().connect("changed", lambda b: write("text", text_of(b)))
password.connect("changed", lambda e: write("password", e.get_text()))


def poll():
    clear = os.path.join(out, "clear")
    if os.path.exists(clear):
        view.get_buffer().set_text("")
        password.set_text("")
        write("text", "")
        write("password", "")
        os.remove(clear)
    focus = os.path.join(out, "focus")
    if os.path.exists(focus):
        with open(focus) as f:
            target = f.read().strip()
        os.remove(focus)
        (password if target == "password" else view).grab_focus()
        write("focused", target)
    return True


def ready():
    view.grab_focus()
    write("text", "")
    write("password", "")
    write("ready", "1")
    return False


GLib.timeout_add(20, poll)
GLib.timeout_add(300, ready)

if GTK4:
    loop = GLib.MainLoop()
    window.connect("close-request", lambda *_: loop.quit() or False)
    window.present()
    loop.run()
else:
    window.connect("destroy", Gtk.main_quit)
    window.show_all()
    Gtk.main()
