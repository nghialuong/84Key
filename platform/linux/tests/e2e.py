#!/usr/bin/env python3
#
# End-to-end test of ibus-engine-84key: real keystrokes (XTEST, via xdotool)
# into real GTK 3 / GTK 4 text fields, through the GTK IBus module, a real
# ibus-daemon and the engine binary. It checks what host_test.cpp cannot — that
# the preedit protocol behaves in a real toolkit: a click mid-word commits the
# word once, Enter and shortcuts land after the word, fast typing loses nothing,
# a password field is left alone, settings and the VI/EN hotkey apply live.
#
#   python3 platform/linux/tests/e2e.py --engine build/linux/ibus-engine-84key
#
# Everything runs privately — its own D-Bus session, X server (Xvfb), IBus
# daemon and config directory — so it never types into the desktop you are
# using and never changes your settings. Needs Xvfb, xdotool, ibus, and
# python3-gi with the GTK 3/4 typelibs and the ibus-gtk3/ibus-gtk4 IM modules.
#

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))

# (name, keys, expected text). Keys use the notation of host_test.cpp:
#   {BS} {ENTER} {TAB} {LEFT} {ESC}   {C-a} Ctrl+a
#   {CLICK}   click into the text, after its end
#   {SWITCH}  press and release Ctrl+Shift (the default VI/EN hotkey)
#   {PAUSE}   wait 60 ms
CASES = [
    ("telex", "tieesng vieejt ", "tiếng việt "),
    ("sentence", "Xin chaof, tooi laf nguwowfi Vieejt Nam!", "Xin chào, tôi là người Việt Nam!"),
    ("uow", "dduwowngf truwowngf suwowngs ", "đường trường sướng "),
    ("english", "google project window ", "google project window "),
    ("enter", "vieejt{ENTER}nam", "việt\nnam"),
    ("tab", "vieejt{TAB}nam", "việt\tnam"),
    # The duplication bug of other engines: a click mid-word must commit the
    # word exactly once.
    ("click-commits-once", "dduwowngf{CLICK}xa", "đườngxa"),
    ("backspace", "tieesng{BS}{BS}{BS}nh", "tinh"),
    ("backspace-word", "toi an{BS}{BS}{BS}{BS} ddi", "to đi"),
    ("shortcut", "vieejt{C-a}xin", "xin"),
    ("arrow", "abc{LEFT}d", "abdc"),
    ("digits", "2024 nawm 12 thangs", "2024 năm 12 tháng"),
    ("caps", "TIEESNG VIEEJT", "TIẾNG VIỆT"),
    ("switch", "{SWITCH}tieesng {SWITCH}vieejt", "tieesng việt"),
    # Switching saves the settings, and the engine sees its own save 100 ms
    # later; a word typed across that moment must stay one word. (The pause is
    # between the vowel and its tone key: split there, the word would come out
    # "tiêsng".)
    ("switch-then-type", "{SWITCH}{SWITCH}tiee{PAUSE}{PAUSE}{PAUSE}sng", "tiếng"),
]

PASSAGE = (
    "Tieesng Vieejt laf ngoon ngwx cuar daan toojc Kinh vaf laf ngoon ngwx chinhs thuwcs "
    "taji Vieejt Nam. Hoom nay trowif ddepj, chungs tooi ddi hocj sowms vaf ddowji xe buyst. "
    "Muaf thu Haf Nooji, cos nhuwngx con dduwowngf nhor ddaafy las vangf. "
)
PASSAGE_TEXT = (
    "Tiếng Việt là ngôn ngữ của dân tộc Kinh và là ngôn ngữ chính thức "
    "tại Việt Nam. Hôm nay trời đẹp, chúng tôi đi học sớm và đợi xe buýt. "
    "Mùa thu Hà Nội, có những con đường nhỏ đầy lá vàng. "
)


class Stack:
    def __init__(self, args, work):
        self.args = args
        self.work = work
        self.procs = []
        self.env = dict(os.environ)
        self.env.update({
            "XDG_CONFIG_HOME": os.path.join(work, "config"),
            "XDG_CACHE_HOME": os.path.join(work, "cache"),
            "GSETTINGS_BACKEND": "memory",
            "KEY84_DATA_DIR": os.path.join(ROOT, "core", "data"),
            "IBUS_ADDRESS": "unix:abstract=key84-e2e-%d" % os.getpid(),
            "NO_AT_BRIDGE": "1",
            "GTK_A11Y": "none",
        })

    def spawn(self, argv, **kw):
        log = open(os.path.join(self.work, os.path.basename(argv[0]) + ".log"), "ab")
        p = subprocess.Popen(argv, env=self.env, stdout=log, stderr=log, **kw)
        self.procs.append(p)
        return p

    def run(self, argv, check=True):
        return subprocess.run(argv, env=self.env, capture_output=True, text=True, check=check)

    def wait(self, what, predicate, timeout=10.0):
        end = time.time() + timeout
        while time.time() < end:
            if predicate():
                return
            time.sleep(0.05)
        raise RuntimeError("timed out waiting for " + what)

    def start(self):
        display = next(n for n in range(90, 200) if not os.path.exists("/tmp/.X11-unix/X%d" % n))
        self.env["DISPLAY"] = ":%d" % display
        self.spawn([self.args.xvfb, ":%d" % display, "-screen", "0", "1280x800x24", "-nolisten", "tcp"])
        self.wait("Xvfb", lambda: os.path.exists("/tmp/.X11-unix/X%d" % display))

        # Install the engine the way a package does, but privately: a component
        # file pointing at the binary under test, in a directory only this
        # daemon reads. The daemon then runs it exactly as on a real system —
        # `--xml` for the description, `--ibus` when the engine is first needed.
        components = os.path.join(self.work, "component")
        os.makedirs(components)
        with open(os.path.join(HERE, "..", "data", "84key.xml.in")) as f:
            xml = f.read()
        xml = xml.replace("@CMAKE_INSTALL_FULL_LIBEXECDIR@", os.path.dirname(self.args.engine))
        xml = xml.replace("@KEY84_VERSION@", "e2e")
        with open(os.path.join(components, "84key.xml"), "w") as f:
            f.write(xml)
        self.env["IBUS_COMPONENT_PATH"] = components

        self.spawn(["ibus-daemon", "--address=" + self.env["IBUS_ADDRESS"], "--config=disable",
                    "--panel=disable", "--emoji-extension=disable", "--xim", "--verbose"])
        self.wait("ibus-daemon", lambda: self.run(["ibus", "list-engine"], check=False).returncode == 0)
        listed = self.run(["ibus", "list-engine"]).stdout
        if "84key" not in listed:
            raise RuntimeError("ibus-daemon did not take the engine description (--xml):\n" + listed)
        # `ibus engine NAME` also applies the engine's keyboard layout with
        # setxkbmap, which fails on Xvfb and makes it exit non-zero after
        # selecting the engine; read the selection back instead.
        self.run(["ibus", "engine", "84key"], check=False)
        self.wait("the 84key engine", lambda: self.run(["ibus", "engine"], check=False).stdout.strip() == "84key")
        self.wait("the daemon to start the engine",
                  lambda: self.run(["pgrep", "-f", self.args.engine + " --ibus"], check=False).returncode == 0)

    def stop(self):
        for p in reversed(self.procs):
            p.terminate()
        for p in self.procs:
            try:
                p.wait(timeout=3)
            except subprocess.TimeoutExpired:
                p.kill()


class Field:
    def __init__(self, stack, gtk):
        self.stack = stack
        self.dir = os.path.join(stack.work, "gtk" + gtk)
        os.makedirs(self.dir)
        env = dict(stack.env, GTK_IM_MODULE="ibus")
        log = open(os.path.join(self.dir, "app.log"), "ab")
        stack.procs.append(subprocess.Popen([sys.executable, os.path.join(HERE, "e2e_app.py"), gtk, self.dir],
                                            env=env, stdout=log, stderr=log))
        stack.wait("the GTK %s window" % gtk, lambda: os.path.exists(os.path.join(self.dir, "ready")))
        self.window = stack.run([stack.args.xdotool, "search", "--name", "key84-e2e"]).stdout.split()[-1]
        stack.run([stack.args.xdotool, "windowfocus", "--sync", self.window])
        time.sleep(0.3)

    def read(self, name="text"):
        try:
            with open(os.path.join(self.dir, name), encoding="utf-8") as f:
                return f.read()
        except FileNotFoundError:
            return ""

    def clear(self):
        open(os.path.join(self.dir, "clear"), "w").close()
        self.stack.wait("the field to clear", lambda: not os.path.exists(os.path.join(self.dir, "clear")))
        # GTK 4 resets the input context a little after the text is replaced
        # under it; let that happen before typing, not in the middle of a word.
        time.sleep(0.4)

    def click(self, x=300, y=200):
        # Inside the text view, below the text: the caret goes to the end.
        self.xdo("mousemove", "--window", self.window, str(x), str(y), "click", "1")

    def commit(self):
        # A word still being composed is in the preedit, not in the text. Click,
        # as a user would: IBus commits the word — once. Somewhere other than
        # {CLICK} clicks: two clicks on one spot in quick succession are a
        # double-click, which selects a word for the next commit to replace.
        self.click(480, 240)
        time.sleep(0.1)

    def focus(self, target):
        with open(os.path.join(self.dir, "focus"), "w") as f:
            f.write(target)
        self.stack.wait("focus", lambda: self.read("focused") == target)
        time.sleep(0.2)

    def xdo(self, *args):
        self.stack.run([self.stack.args.xdotool] + list(args))

    def type(self, script, delay):
        i = 0
        while i < len(script):
            if script[i] == "{":
                end = script.index("}", i)
                token = script[i + 1:end]
                i = end + 1
                keys = {"BS": "BackSpace", "ENTER": "Return", "TAB": "Tab", "LEFT": "Left", "ESC": "Escape"}
                if token in keys:
                    self.xdo("key", "--delay", str(delay), keys[token])
                elif token.startswith("C-"):
                    self.xdo("key", "ctrl+" + token[2:])
                elif token == "CLICK":
                    self.click()
                elif token == "SWITCH":
                    self.xdo("keydown", "Control_L", "keydown", "Shift_L", "keyup", "Shift_L", "keyup", "Control_L")
                elif token == "PAUSE":
                    time.sleep(0.06)
                else:
                    raise ValueError("unknown token {%s}" % token)
                time.sleep(0.05)
            else:
                end = script.find("{", i)
                end = len(script) if end < 0 else end
                self.xdo("type", "--delay", str(delay), "--", script[i:end])
                i = end

    def settle(self, name="text", expect=None, timeout=4.0):
        """Wait until the field stops changing (or shows `expect`)."""
        last, stable_since, end = None, time.time(), time.time() + timeout
        while time.time() < end:
            now = self.read(name)
            if expect is not None and now == expect:
                return now
            if now != last:
                last, stable_since = now, time.time()
            elif time.time() - stable_since > 0.4:
                return now
            time.sleep(0.05)
        return self.read(name)


def read_settings(stack):
    path = os.path.join(stack.env["XDG_CONFIG_HOME"], "84key", "settings.ini")
    values = {}
    try:
        with open(path) as f:
            for line in f:
                key, _, value = line.strip().partition("=")
                if value:
                    values[key] = value
    except FileNotFoundError:
        pass
    return values


def check_menu(stack, report):
    """Drive the input-source menu the way GNOME Shell does: activate the
    engine's properties through an IBus input context of our own."""
    code = r'''
import sys, time, gi
gi.require_version("IBus", "1.0")
from gi.repository import IBus, GLib
IBus.init()
bus = IBus.Bus()
ic = bus.create_input_context("key84-e2e-menu")
ic.set_capabilities(IBus.Capabilite.PREEDIT_TEXT | IBus.Capabilite.FOCUS | IBus.Capabilite.PROPERTY)
ic.focus_in()
ic.set_engine("84key")
time.sleep(0.3)
for name, state in [a.split(":") for a in sys.argv[1:]]:
    ic.property_activate(name, int(state))
    time.sleep(0.3)
ic.focus_out()
'''
    def activate(*props):
        stack.run([sys.executable, "-c", code] + ["%s:%d" % p for p in props])
        time.sleep(0.3)

    # GNOME Shell activates every item of a radio group: UNCHECKED (0) for the
    # others, CHECKED (1) for the chosen one.
    activate(("InputType.0", 0), ("InputType.1", 1))
    report(read_settings(stack).get("vInputType") == "1", "menu: choosing VNI is saved",
           "settings: %r" % read_settings(stack))
    activate(("InputType.1", 0), ("InputType.0", 1))
    report(read_settings(stack).get("vInputType") == "0", "menu: back to Telex", "settings: %r" % read_settings(stack))
    activate(("vAutoDetectEnglish", 0))
    report(read_settings(stack).get("vAutoDetectEnglish") == "0", "menu: a toggle is saved",
           "settings: %r" % read_settings(stack))
    activate(("vAutoDetectEnglish", 1))
    activate(("InputMode", 0))
    lang = read_settings(stack).get("vLanguage")
    activate(("InputMode", 0))
    report(lang == "0" and read_settings(stack).get("vLanguage") == "1", "menu: VI/EN switches and is saved",
           "after one switch vLanguage=%r, after two %r" % (lang, read_settings(stack).get("vLanguage")))


def check_traced_restart(stack, field, report):
    """The bug-report procedure in docs/LINUX.md: stop the engine IBus started,
    start it by hand with KEY84_TRACE=1 and --ibus, and the daemon adopts it."""
    stack.run(["pkill", "-f", stack.args.engine + " --ibus"], check=False)
    time.sleep(0.5)
    log = os.path.join(stack.work, "traced-engine.log")
    with open(log, "ab") as out:
        stack.procs.append(subprocess.Popen([stack.args.engine, "--ibus"], env=dict(stack.env, KEY84_TRACE="1"),
                                            stdout=out, stderr=out))
    time.sleep(0.5)
    stack.run(["ibus", "engine", "84key"], check=False)
    field.focus("text")
    field.clear()
    field.type("Vieejt ", 12)
    got = field.settle(expect="Việt ")
    with open(log, encoding="utf-8", errors="replace") as f:
        traced = "key V state=" in f.read()
    report(got == "Việt " and traced, "an engine started by hand with KEY84_TRACE=1 is adopted and traces",
           "typed %r, trace %s" % (got, "found" if traced else "missing"))


def write_settings(stack, values):
    path = os.path.join(stack.env["XDG_CONFIG_HOME"], "84key", "settings.ini")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".tmp", "w") as f:
        f.write("[84Key]\n" + "".join("%s=%s\n" % kv for kv in values.items()))
    os.replace(path + ".tmp", path)
    time.sleep(0.5)   # the engine reloads 100 ms after the file settles


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True, help="path to ibus-engine-84key")
    parser.add_argument("--gtk", default="3.0,4.0", help="GTK versions to test (comma-separated)")
    parser.add_argument("--xvfb", default=shutil.which("Xvfb") or "Xvfb")
    parser.add_argument("--xdotool", default=shutil.which("xdotool") or "xdotool")
    parser.add_argument("--delay", type=int, default=12, help="ms between keystrokes")
    parser.add_argument("--keep", action="store_true", help="keep the work directory (logs)")
    args = parser.parse_args()
    args.engine = os.path.abspath(args.engine)

    if "KEY84_E2E_INNER" not in os.environ:
        # A private session bus, so nothing here can reach the desktop's.
        env = dict(os.environ, KEY84_E2E_INNER="1")
        os.execvpe("dbus-run-session", ["dbus-run-session", "--", sys.executable] + sys.argv, env)

    work = tempfile.mkdtemp(prefix="key84-e2e-")
    stack = Stack(args, work)
    passed = failed = 0

    def report(ok, label, detail=""):
        nonlocal passed, failed
        passed, failed = passed + ok, failed + (not ok)
        print("  [%s] %s%s" % ("PASS" if ok else "FAIL", label, "" if ok else "  " + detail), flush=True)

    crashed = True
    try:
        stack.start()
        for gtk in args.gtk.split(","):
            print("\n== GTK %s ==" % gtk, flush=True)
            field = Field(stack, gtk)
            for name, keys, expect in CASES:
                field.clear()
                field.type(keys, args.delay)
                field.commit()
                got = field.settle(expect=expect)
                report(got == expect, name, "%r -> %r (expect %r)" % (keys, got, expect))

            # 500 keys a second — several times any typist, or key repeat. With
            # no delay at all, GTK 3's asynchronous IBus client reorders the keys
            # an engine hands back, whichever engine it is; IBUS_ENABLE_SYNC_MODE=1
            # in the application's environment avoids that (docs/LINUX.md).
            field.clear()
            field.type(PASSAGE, 2)
            field.commit()
            got = field.settle(expect=PASSAGE_TEXT, timeout=15)
            report(got == PASSAGE_TEXT, "fast typing, %d keys at 500 keys/s" % len(PASSAGE),
                   "got %r" % got)

            field.clear()
            field.focus("password")
            field.type("matkhaau123", args.delay)
            got = field.settle("password", expect="matkhaau123")
            report(got == "matkhaau123", "password field gets the raw keys", "got %r" % got)
            field.focus("text")

            field.clear()
            write_settings(stack, {"vInputType": 1})
            field.type("Vie65t Nam ", args.delay)
            field.commit()
            got = field.settle(expect="Việt Nam ")
            report(got == "Việt Nam ", "settings file change applies live (VNI)", "got %r" % got)
            write_settings(stack, {"vInputType": 0})

        # A hand edit that does not parse (yet) changes nothing, and the
        # engine's own saves leave it alone instead of writing over it.
        path = os.path.join(stack.env["XDG_CONFIG_HOME"], "84key", "settings.ini")
        broken = "[84Key\nvInputType=1\n"
        with open(path, "w") as f:
            f.write(broken)
        time.sleep(0.5)
        field.clear()
        field.type("{SWITCH}{SWITCH}vieejt ", args.delay)
        got = field.settle(expect="việt ")
        with open(path) as f:
            kept = f.read() == broken
        report(got == "việt " and kept, "a settings file that does not parse is ignored and left alone",
               "typed %r, file %s" % (got, "kept" if kept else "overwritten"))
        write_settings(stack, {"vInputType": 0})

        print("\n== Input-source menu ==", flush=True)
        check_menu(stack, report)

        print("\n== Diagnostics ==", flush=True)
        check_traced_restart(stack, field, report)
        crashed = False
    finally:
        stack.stop()
        if args.keep or failed or crashed:
            print("\nlogs: " + work)
        else:
            shutil.rmtree(work, ignore_errors=True)

    print("\n%d passed, %d failed" % (passed, failed))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
