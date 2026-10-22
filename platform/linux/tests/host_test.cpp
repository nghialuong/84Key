//
//  host_test.cpp
//  84Key — tests of the Linux host's pure C++ layer: the typing pipeline
//  (platform/linux/src/Composer.cpp), held against a model of what an IBus
//  client does with its output, and the VI/EN hotkey (SwitchKey.cpp).
//
//  The macOS host has already been held to a large body of cases by
//  core/tests/typing_sim_test.cpp, so the strongest statement this file can make
//  is "the Linux host shows the same text the macOS host would". It checks that
//  directly, by typing the same keys through both pipelines:
//    * every Telex spelling in the Vietnamese dictionary, English detection off
//      and on, ended by a word break;
//    * a seeded random fuzz of keystrokes (letters weighted to the Telex/VNI
//      keys, digits, punctuation, space, Backspace) across input methods and
//      options;
//  plus the cases that only exist on Linux — the preedit protocol, shortcuts,
//  password fields, the legacy code tables — and the drop-in fixtures in
//  core/tests/cases/*.txt (backspace_restore.txt gates, the rest report).
//
//  Pure C++: no IBus, no display. Build and run with platform/linux/tests/
//  run_tests.sh (also called from core/tests/run_tests.sh); pass --trace to
//  see one script typed key by key on both hosts, or --type to see what the
//  Linux host shows for one.
//

#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include <random>
#include <algorithm>
#include <dirent.h>

#include "../src/Composer.h"
#include "../src/Keysyms.h"
#include "../src/SwitchKey.h"
#include "Engine.h"
#include "EnglishDetect.h"
#include "ConvertTool.h"

using namespace std;
using namespace key84;

extern Uint16 keyCodeToCharacter(const Uint32& keyCode);

static const char* gDataDir = "../../../core/data";
static const char* gCasesDir = "../../../core/tests/cases";

static int g_pass = 0, g_fail = 0;
static int g_fixPass = 0, g_fixFail = 0;

static void check(bool ok, const string& label, const string& detail = "") {
    if (ok) {
        g_pass++;
        printf("  [PASS] %s\n", label.c_str());
    } else {
        g_fail++;
        printf("  [FAIL] %s%s%s\n", label.c_str(), detail.empty() ? "" : "  ", detail.c_str());
    }
}

static string toUtf8(const u32string& s) {
    string o;
    for (char32_t c : s) {
        if (c < 0x80) o.push_back((char)c);
        else if (c < 0x800) { o.push_back((char)(0xC0 | (c >> 6))); o.push_back((char)(0x80 | (c & 0x3F))); }
        else if (c < 0x10000) { o.push_back((char)(0xE0 | (c >> 12))); o.push_back((char)(0x80 | ((c >> 6) & 0x3F))); o.push_back((char)(0x80 | (c & 0x3F))); }
        else { o.push_back((char)(0xF0 | (c >> 18))); o.push_back((char)(0x80 | ((c >> 12) & 0x3F))); o.push_back((char)(0x80 | ((c >> 6) & 0x3F))); o.push_back((char)(0x80 | (c & 0x3F))); }
    }
    return o;
}

static u32string fromUtf8(const string& s) {
    u32string out;
    size_t i = 0;
    while (i < s.size()) {
        unsigned char c = (unsigned char)s[i];
        char32_t cp; int n;
        if (c < 0x80) { cp = c; n = 1; }
        else if ((c >> 5) == 0x6) { cp = c & 0x1F; n = 2; }
        else if ((c >> 4) == 0xE) { cp = c & 0x0F; n = 3; }
        else if ((c >> 3) == 0x1E) { cp = c & 0x07; n = 4; }
        else { cp = 0xFFFD; n = 1; }
        for (int k = 1; k < n && i + k < s.size(); k++) cp = (cp << 6) | ((unsigned char)s[i + k] & 0x3F);
        out.push_back(cp);
        i += n;
    }
    return out;
}

// ---- Keys -------------------------------------------------------------------
//
// A key script is plain text plus tokens for keys that type nothing:
//   {BS} Backspace   {ENTER}   {TAB}   {ESC}   {LEFT}   {DEL} Delete
//   {HOME}   {KP1} keypad 1   {C-x} Ctrl+x   {CLICK} the user clicks in the
//   field (the client resets the context and, in PREEDIT_COMMIT mode, IBus
//   commits the visible preedit on the engine's behalf).

struct Key {
    KeyEvent ev;
    bool click = false;
};

static vector<Key> parseKeys(const string& script) {
    vector<Key> keys;
    u32string text = fromUtf8(script);
    for (size_t i = 0; i < text.size(); i++) {
        Key k;
        if (text[i] == '{') {
            size_t end = text.find('}', i);
            string tok = toUtf8(text.substr(i + 1, end - i - 1));
            i = end;
            if (tok == "BS")         k.ev = {keysym::BackSpace, 0x08, 0};
            else if (tok == "ENTER") k.ev = {keysym::Return, 0x0D, 0};
            else if (tok == "TAB")   k.ev = {keysym::Tab, 0x09, 0};
            else if (tok == "ESC")   k.ev = {keysym::Escape, 0x1B, 0};
            else if (tok == "LEFT")  k.ev = {keysym::Left, 0, 0};
            else if (tok == "DEL")   k.ev = {keysym::Delete, 0x7F, 0};
            else if (tok == "HOME")  k.ev = {keysym::Home, 0, 0};
            else if (tok == "KP1")   k.ev = {0xffb1, '1', 0};
            else if (tok == "CLICK") k.click = true;
            else if (tok.size() == 3 && tok[0] == 'C' && tok[1] == '-')
                k.ev = {(uint32_t)tok[2], (uint32_t)tok[2], modmask::Control};
            else { fprintf(stderr, "bad key token {%s}\n", tok.c_str()); continue; }
        } else {
            char32_t c = text[i];
            // Printable characters have keysyms equal to their code point in
            // ASCII/Latin-1, and 0x01000000 | code point beyond.
            uint32_t keyval = (c < 0x100) ? (uint32_t)c : (0x01000000u | (uint32_t)c);
            bool shifted = (c >= 'A' && c <= 'Z') || (c < 0x80 && strchr("~!@#$%^&*()_+{}|:\"<>?", (int)c));
            k.ev = {keyval, (uint32_t)c, shifted ? modmask::Shift : 0u};
        }
        keys.push_back(k);
    }
    return keys;
}

// ---- The client side of IBus -------------------------------------------------
//
// What a text field does with the engine's messages: commit inserts at the
// cursor, the preedit is drawn after it, and a key the engine returns FALSE for
// is handled by the field itself. The protocol rule the Composer must keep: a
// key is only ever given back with the preedit empty — otherwise it would land
// in front of a word the user has not finished.

struct Field {
    u32string text, preedit;
    int protocolErrors = 0;

    void apply(const Output& out, const KeyEvent& ev) {
        text += out.commit;
        if (out.preeditChanged)
            preedit = out.preedit;
        if (out.consumed)
            return;
        if (!preedit.empty())
            protocolErrors++;
        if (ev.state & modmask::Shortcut)
            return;                                  // the app runs the shortcut
        if (ev.keyval == keysym::BackSpace) {
            if (!text.empty()) text.pop_back();
        } else if (ev.keyval == keysym::Return) {
            text.push_back('\n');
        } else if (ev.keyval == keysym::Tab) {
            text.push_back('\t');
        } else if (ev.unicode >= 0x20 && ev.unicode != 0x7F) {
            text.push_back(ev.unicode);
        }
    }
    void click() {                                   // PREEDIT_COMMIT: IBus commits it
        text += preedit;
        preedit.clear();
    }
    u32string visible() const { return text + preedit; }
};

// Clear everything vKeyInit() leaves behind (space count, pending special
// characters, the word history), so each run starts from the same state no
// matter what the previous one typed.
static void hermeticReset() {
    vKeyInit();
    vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, KEY_A, 0, false);
    vKeyHandleEvent(vKeyEvent::Mouse, vKeyEventState::MouseDown, KEY_EMPTY);
    startNewSession();
    vKeyInit();
}

static Composer* gComposer = nullptr;

static Field typeLinux(const vector<Key>& keys) {
    hermeticReset();
    gComposer->reset();
    Field f;
    for (const Key& k : keys) {
        if (k.click) {
            f.click();
            gComposer->reset();
            continue;
        }
        f.apply(gComposer->processKey(k.ev), k.ev);
    }
    return f;
}

static string linuxText(const string& script) {
    return toUtf8(typeLinux(parseKeys(script)).visible());
}

// ---- The macOS host, for reference -------------------------------------------
//
// The buffer effect of InputController.mm's keyDown handler for the Unicode code
// table, as core/tests/typing_sim_test.cpp models it: vDoNothing lets the key
// through, the rewrite codes become backspaces + characters (+ the trigger key
// for a restore), and a Backspace the engine does nothing with is the OS's.
// Only letters, digits, punctuation, space and Backspace are modelled — the keys
// both hosts treat the same way.
//
// One difference is by design and is applied to the model: the Linux host
// starts a new engine word at every commit, while the macOS host leaves the
// word a space finished inside the engine until the next key. On macOS that
// makes a digit typed straight after a space part of the next word ("abc 4Us"
// stays "4Us") although the same digit at the start of a line is a break
// ("4Us" -> "4Ú"); on Linux it is a break in both places. The model starts a new
// word after a space, so everything else is still held to the macOS host.

static int asciiToKey(char32_t c, bool& caps) {
    caps = false;
    if (c >= 'A' && c <= 'Z') { caps = true; c = c - 'A' + 'a'; }
    switch (c) {
        case 'a': return KEY_A; case 'b': return KEY_B; case 'c': return KEY_C; case 'd': return KEY_D;
        case 'e': return KEY_E; case 'f': return KEY_F; case 'g': return KEY_G; case 'h': return KEY_H;
        case 'i': return KEY_I; case 'j': return KEY_J; case 'k': return KEY_K; case 'l': return KEY_L;
        case 'm': return KEY_M; case 'n': return KEY_N; case 'o': return KEY_O; case 'p': return KEY_P;
        case 'q': return KEY_Q; case 'r': return KEY_R; case 's': return KEY_S; case 't': return KEY_T;
        case 'u': return KEY_U; case 'v': return KEY_V; case 'w': return KEY_W; case 'x': return KEY_X;
        case 'y': return KEY_Y; case 'z': return KEY_Z;
        case '0': return KEY_0; case '1': return KEY_1; case '2': return KEY_2; case '3': return KEY_3;
        case '4': return KEY_4; case '5': return KEY_5; case '6': return KEY_6; case '7': return KEY_7;
        case '8': return KEY_8; case '9': return KEY_9; case ' ': return KEY_SPACE;
        case '`': return KEY_BACKQUOTE; case '-': return KEY_MINUS; case '=': return KEY_EQUALS;
        case '[': return KEY_LEFT_BRACKET; case ']': return KEY_RIGHT_BRACKET; case '\\': return KEY_BACK_SLASH;
        case ';': return KEY_SEMICOLON; case '\'': return KEY_QUOTE; case ',': return KEY_COMMA;
        case '.': return KEY_DOT; case '/': return KEY_SLASH;
        case '~': caps = true; return KEY_BACKQUOTE; case '!': caps = true; return KEY_1;
        case '@': caps = true; return KEY_2; case '#': caps = true; return KEY_3; case '$': caps = true; return KEY_4;
        case '%': caps = true; return KEY_5; case '^': caps = true; return KEY_6; case '&': caps = true; return KEY_7;
        case '*': caps = true; return KEY_8; case '(': caps = true; return KEY_9; case ')': caps = true; return KEY_0;
        case '_': caps = true; return KEY_MINUS; case '+': caps = true; return KEY_EQUALS;
        case '{': caps = true; return KEY_LEFT_BRACKET; case '}': caps = true; return KEY_RIGHT_BRACKET;
        case '|': caps = true; return KEY_BACK_SLASH; case ':': caps = true; return KEY_SEMICOLON;
        case '"': caps = true; return KEY_QUOTE; case '<': caps = true; return KEY_COMMA;
        case '>': caps = true; return KEY_DOT; case '?': caps = true; return KEY_SLASH;
        default: return -1;
    }
}

static void macApply(u32string& buf, vKeyHookState* st, char32_t trigger) {
    if (st->code == vDoNothing) {
        if (trigger) buf.push_back(trigger);
        return;
    }
    if (!(st->code == vWillProcess || st->code == vRestore || st->code == vRestoreAndStartNewSession))
        return;
    for (int i = 0; i < st->backspaceCount; i++)
        if (!buf.empty()) buf.pop_back();
    for (int k = (int)st->newCharCount - 1; k >= 0; k--) {
        uint32_t t = st->charData[k];
        char32_t ch;
        if (t & PURE_CHARACTER_MASK)    ch = (char32_t)(t & CHAR_MASK);
        else if (!(t & CHAR_CODE_MASK)) ch = (char32_t)keyCodeToCharacter(t);
        else                            ch = (char32_t)(t & CHAR_MASK);
        // An entry with no character (keyCodeToCharacter() of a key it does not
        // know) reaches the macOS app as U+0000: invisible, but still a character
        // the next backspace deletes. The Linux decode keeps the slot and drops
        // the character. visibleMac() compares what the user sees.
        buf.push_back(ch);
    }
    if ((st->code == vRestore || st->code == vRestoreAndStartNewSession) && trigger)
        buf.push_back(trigger);
    if (st->code == vRestoreAndStartNewSession)
        startNewSession();
}

static u32string visibleMac(u32string buf) {
    buf.erase(remove(buf.begin(), buf.end(), U'\0'), buf.end());
    return buf;
}

static u32string typeMac(const vector<Key>& keys) {
    hermeticReset();
    vKeyHookState* st = (vKeyHookState*)vKeyInit();
    u32string buf;
    for (const Key& k : keys) {
        if (k.ev.keyval == keysym::BackSpace) {
            vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, (Uint16)KEY_DELETE, 0, false);
            if (st->code == vDoNothing) { if (!buf.empty()) buf.pop_back(); }
            else macApply(buf, st, 0);
            continue;
        }
        bool caps = false;
        int kc = asciiToKey(k.ev.unicode, caps);
        if (kc < 0) continue;
        vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, (Uint16)kc, caps ? 1 : 0, false);
        macApply(buf, st, k.ev.unicode);
        if (kc == KEY_SPACE)
            startNewSession();
    }
    return visibleMac(buf);
}

// ---- Options -------------------------------------------------------------------

struct Options {
    int input = 0, detect = 0, modern = 1, spell = 1, quickTelex = 0, restoreWrong = 0,
        freeMark = 0, zfwj = 0, quickStart = 0, quickEnd = 0, upperFirst = 0, codeTable = 0;
};

static void setOptions(const Options& o) {
    vLanguage = 1; vInputType = o.input; vAutoDetectEnglish = o.detect;
    vUseModernOrthography = o.modern; vCheckSpelling = o.spell; vQuickTelex = o.quickTelex;
    vRestoreIfWrongSpelling = o.restoreWrong; vFreeMark = o.freeMark; vAllowConsonantZFWJ = o.zfwj;
    vQuickStartConsonant = o.quickStart; vQuickEndConsonant = o.quickEnd;
    vUpperCaseFirstChar = o.upperFirst; vCodeTable = o.codeTable;
    vUseMacro = 0; vFixRecommendBrowser = 0;
    vSetCheckSpelling();
}

// ---- Expectation cases -------------------------------------------------------

struct Case { const char* id; const char* keys; const char* expect; };

static void runCases(const char* title, const Case* cases, size_t n) {
    printf("\n== %s ==\n", title);
    for (size_t i = 0; i < n; i++) {
        Field f = typeLinux(parseKeys(cases[i].keys));
        string got = toUtf8(f.visible());
        bool ok = (got == cases[i].expect) && f.protocolErrors == 0;
        string detail = "\"" + string(cases[i].keys) + "\" -> \"" + got + "\" (expect \"" + cases[i].expect + "\")";
        if (f.protocolErrors) detail += " — a key reached the app while a word was open";
        check(ok, string(cases[i].id) + " " + (ok ? "\"" + got + "\"" : ""), ok ? "" : detail);
    }
}

// The preedit protocol itself: what is committed when, and what the app sees.
static void checkProtocol() {
    printf("\n== Preedit protocol ==\n");
    setOptions(Options());

    // Letters compose; nothing reaches the app until the break.
    {
        hermeticReset(); gComposer->reset();
        Field f;
        for (const Key& k : parseKeys("tieesng")) f.apply(gComposer->processKey(k.ev), k.ev);
        check(f.text.empty() && toUtf8(f.preedit) == "tiếng", "P1 a word stays in the preedit until it ends",
              "text=\"" + toUtf8(f.text) + "\" preedit=\"" + toUtf8(f.preedit) + "\"");
        Output out = gComposer->processKey(parseKeys(" ")[0].ev);
        check(out.consumed && toUtf8(out.commit) == "tiếng " && out.preeditChanged && out.preedit.empty(),
              "P2 space commits the word and the space in one commit",
              "commit=\"" + toUtf8(out.commit) + "\" consumed=" + to_string(out.consumed));
    }
    // With no word open, keys go to the app untouched: space, punctuation, a
    // digit, Backspace, Enter.
    {
        hermeticReset(); gComposer->reset();
        bool allThrough = true;
        for (const Key& k : parseKeys(" .1{BS}{ENTER}-"))
            allThrough &= !gComposer->processKey(k.ev).consumed;
        check(allThrough, "P3 with no word open every key reaches the app as a real key event");
    }
    // Enter commits the word, then the app gets the Enter itself.
    {
        hermeticReset(); gComposer->reset();
        for (const Key& k : parseKeys("Vieejt")) gComposer->processKey(k.ev);
        Output out = gComposer->processKey(parseKeys("{ENTER}")[0].ev);
        check(!out.consumed && toUtf8(out.commit) == "Việt", "P4 Enter commits the word and is then given to the app",
              "commit=\"" + toUtf8(out.commit) + "\" consumed=" + to_string(out.consumed));
    }
    // A shortcut commits the word first, so Ctrl+A / Ctrl+C act on real text.
    {
        hermeticReset(); gComposer->reset();
        for (const Key& k : parseKeys("dduwowngf")) gComposer->processKey(k.ev);
        Output out = gComposer->processKey(parseKeys("{C-c}")[0].ev);
        check(!out.consumed && toUtf8(out.commit) == "đường", "P5 Ctrl+C commits the word, then the shortcut runs");
    }
    // Shift / Caps Lock / Ctrl pressed on their own never end the word.
    {
        hermeticReset(); gComposer->reset();
        for (const Key& k : parseKeys("tieen")) gComposer->processKey(k.ev);
        bool untouched = true;
        for (uint32_t mod : {keysym::Shift_L, keysym::Caps_Lock, keysym::Control_L, keysym::ISO_Level3_Shift}) {
            Output out = gComposer->processKey({mod, 0, 0});
            untouched &= !out.consumed && out.commit.empty() && !out.preeditChanged;
        }
        check(untouched && toUtf8(gComposer->preeditText()) == "tiên",
              "P6 modifier keys alone leave the word open");
    }
    // Language EN and password fields: the engine is not consulted at all.
    {
        hermeticReset(); gComposer->reset();
        vLanguage = 0;
        Field f = Field();
        for (const Key& k : parseKeys("tieesng vieejt")) f.apply(gComposer->processKey(k.ev), k.ev);
        vLanguage = 1;
        check(toUtf8(f.visible()) == "tieesng vieejt", "P7 English mode passes every key through");

        hermeticReset(); gComposer->reset();
        gComposer->setBypass(true);
        Field g;
        for (const Key& k : parseKeys("matkhaau123")) g.apply(gComposer->processKey(k.ev), k.ev);
        gComposer->setBypass(false);
        check(toUtf8(g.visible()) == "matkhaau123" && g.preedit.empty(),
              "P8 a password field gets the raw keys, nothing composed");
    }
    // flush() — used when switching VI/EN mid-word — ends the word like a break,
    // so an English word typed in Telex comes out restored.
    {
        setOptions(Options{0, 1});
        hermeticReset(); gComposer->reset();
        for (const Key& k : parseKeys("google")) gComposer->processKey(k.ev);
        Output out = gComposer->flush();
        check(toUtf8(out.commit) == "google" && !gComposer->hasPreedit(),
              "P9 switching language mid-word commits the finished word", "commit=\"" + toUtf8(out.commit) + "\"");
        setOptions(Options());
    }
}

// ---- Differential: the Linux pipeline shows what the macOS pipeline shows -----

static vector<string> loadDictionary() {
    vector<string> words;
    FILE* f = fopen((string(gDataDir) + "/viet_telex.dat").c_str(), "rb");
    if (!f) return words;
    char line[128];
    while (fgets(line, sizeof line, f)) {
        string w(line);
        while (!w.empty() && (w.back() == '\n' || w.back() == '\r')) w.pop_back();
        if (!w.empty()) words.push_back(w);
    }
    fclose(f);
    return words;
}

static void checkDictionaryMatchesMac(const vector<string>& words) {
    printf("\n== Differential: every Telex dictionary word, Linux vs macOS ==\n");
    for (int detect = 0; detect <= 1; detect++) {
        Options o; o.detect = detect;
        setOptions(o);
        int typed = 0, diff = 0;
        string first;
        for (const string& w : words) {
            // Capitalised too, so the caps path is exercised along with the word.
            for (const string& keys : {w + " ", string(1, (char)toupper(w[0])) + w.substr(1) + ". "}) {
                vector<Key> k = parseKeys(keys);
                Field lin = typeLinux(k);
                u32string mac = typeMac(k);
                typed++;
                if (lin.visible() != mac || lin.protocolErrors) {
                    if (diff++ == 0)
                        first = "\"" + keys + "\" linux=\"" + toUtf8(lin.visible()) + "\" mac=\"" + toUtf8(mac) + "\"";
                }
            }
        }
        check(diff == 0 && typed > 50000,
              "D-dict " + to_string(typed) + " words typed with detection " + (detect ? "on" : "off") +
              " — identical on both hosts",
              diff ? to_string(diff) + " differ, first: " + first : "too few words — is viet_telex.dat missing?");
    }
}

// Random typing, both hosts, same keys. Backspace is only pressed while a word
// is open on Linux: past that point the hosts differ by design (the macOS host
// reopens the committed word; this one leaves committed text to the app — see
// checkBackspaceIntoCommittedWord).
static void checkFuzzMatchesMac() {
    printf("\n== Differential: random typing, Linux vs macOS ==\n");
    const char* letters = "aaaeeeooouuuiiywwddsfrxjzngchtmklbpqv";
    const char* vniKeys = "aaeeoouuiyddngchtm1234567890";
    const char* punct = ".,;'-/?!\"";
    struct Mode { const char* name; Options o; };
    Mode modes[] = {
        {"telex",            Options{0, 0}},
        {"telex+detect",     Options{0, 1}},
        {"telex+detect+old", Options{0, 1, 0}},
        {"telex+quick",      Options{0, 1, 1, 1, 1, 0, 0, 0, 1, 1}},
        {"telex+restore",    Options{0, 0, 1, 1, 0, 1}},
        {"telex+nospell",    Options{0, 1, 1, 0}},
        {"telex+freemark",   Options{0, 0, 1, 1, 0, 0, 1, 1}},
        {"vni",              Options{1, 0}},
        {"vni+restore",      Options{1, 0, 1, 1, 0, 1}},
        {"simple1+detect",   Options{2, 1}},
        {"simple2",          Options{3, 0}},
        {"telex+upperfirst", Options{0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1}},
    };
    for (Mode& m : modes) {
        setOptions(m.o);
        mt19937 rng(0x84 + (unsigned)(&m - modes));
        int runs = 3000, diff = 0, overreached = 0;
        string first;
        for (int r = 0; r < runs; r++) {
            // Build the key sequence while typing it on Linux, so a Backspace is
            // only generated while a word is open there.
            hermeticReset();
            gComposer->reset();
            const unsigned overreachesBefore = gComposer->overreaches();
            Field lin;
            vector<Key> keys;
            int len = 4 + (int)(rng() % 40);
            for (int i = 0; i < len; i++) {
                unsigned roll = rng() % 100;
                string ch;
                if (roll < 12) ch = " ";
                else if (roll < 18) ch = string(1, punct[rng() % strlen(punct)]);
                else if (roll < 26 && gComposer->hasPreedit()) ch = "{BS}";
                else if (roll < 30) ch = string(1, (char)('0' + rng() % 10));
                else {
                    const char* pool = (m.o.input == 1) ? vniKeys : letters;
                    char c = pool[rng() % strlen(pool)];
                    if (rng() % 9 == 0 && c >= 'a' && c <= 'z') c = (char)toupper(c);
                    ch = string(1, c);
                }
                Key k = parseKeys(ch)[0];
                keys.push_back(k);
                lin.apply(gComposer->processKey(k.ev), k.ev);
            }
            if (gComposer->overreaches() != overreachesBefore) {
                // The engine asked to rewrite past the word (see engineAgrees()):
                // the macOS host deletes a character it does not own there, so
                // it is no reference. Linux only has to stay protocol-clean.
                overreached++;
                if (lin.protocolErrors) diff++;
                continue;
            }
            u32string mac = typeMac(keys);
            if (lin.visible() != mac || lin.protocolErrors) {
                if (diff++ == 0) {
                    string script;
                    for (const Key& k : keys)
                        script += (k.ev.keyval == keysym::BackSpace) ? string("{BS}") : toUtf8(u32string(1, k.ev.unicode));
                    first = "\"" + script + "\" linux=\"" + toUtf8(lin.visible()) + "\" mac=\"" + toUtf8(mac) + "\"";
                }
            }
        }
        check(diff == 0 && overreached < runs / 20,
              string("D-fuzz ") + m.name + ": " + to_string(runs - overreached) +
              " random sequences identical on both hosts (" + to_string(overreached) + " engine overreaches refused)",
              to_string(diff) + " differ, first: " + first);
    }
    setOptions(Options());
}

// Backspace into a word that has already been committed: the macOS host edits
// it in place with more backspaces, which is the burst async apps drop. Here the
// committed word belongs to the app: Backspace deletes characters and the next
// key starts a new word, so nothing the app holds is ever rewritten.
static void checkBackspaceIntoCommittedWord() {
    printf("\n== Backspace into committed text ==\n");
    setOptions(Options());
    string got = linuxText("tieng {BS}s");
    check(got == "tiengs", "B1 a tone key after backspacing into a committed word starts a new word",
          "got \"" + got + "\"");
    got = linuxText("vieejt nam{BS}{BS}{BS}{BS}{BS}");
    check(got == "việ", "B2 backspacing through a word and a space deletes characters only", "got \"" + got + "\"");

    // The engine overreach engineAgrees() refuses: after "ìu" and Backspace, the
    // w asks to rewrite two characters with one on screen. The macOS host would
    // delete the space in front of the word ("aiừ"); here the space survives.
    vAutoDetectEnglish = 1;
    unsigned before = gComposer->overreaches();
    got = linuxText("a ijfu{BS}w");
    check(got == "a ìư" && gComposer->overreaches() == before + 1,
          "B3 an engine rewrite reaching past the word never touches committed text", "got \"" + got + "\"");
    vAutoDetectEnglish = 0;
}

// The legacy code tables. ConvertTool, which converts finished text between the
// tables, is the oracle: typing in a table must give the conversion of what
// Unicode typing gives — including after a Backspace, which has to remove both
// halves of a two-part character.
//
// Two ConvertTool limits shape the inputs: it lowercases text unless told to
// change case, so the words stay lowercase (case is covered by the Unicode
// differential above); and it does not split a two-part character that ends the
// string (that path pushes the combined value, e.g. U+DEF5 for "ỡ" in VNI
// Windows), so a newline is converted along and removed again.
static void checkCodeTables(const vector<string>& words) {
    printf("\n== Legacy code tables (vs ConvertTool) ==\n");
    const char* names[] = {"", "TCVN3", "VNI Windows", "Unicode Compound", "CP1258"};
    for (int table = 1; table <= 4; table++) {
        int typed = 0, diff = 0;
        string first;
        for (size_t i = 0; i < words.size(); i += 37) {
            for (const string& keys : {words[i] + " ", words[i] + "{BS}", "x" + words[i] + "{BS}{BS} "}) {
                Options o; setOptions(o);
                string unicode = linuxText(keys);
                o.codeTable = table; setOptions(o);
                u32string got = typeLinux(parseKeys(keys)).visible();
                convertToolFromCode = 0; convertToolToCode = (Uint8)table;
                u32string want = fromUtf8(convertUtil(unicode + "\n"));
                if (!want.empty() && want.back() == U'\n') want.pop_back();
                typed++;
                if (got != want && diff++ == 0)
                    first = "\"" + keys + "\" (unicode \"" + unicode + "\")";
            }
        }
        check(diff == 0 && typed > 1000,
              string("T") + to_string(table) + " " + names[table] + ": " + to_string(typed) + " sequences match the conversion",
              to_string(diff) + " differ, first: " + first);
    }
    setOptions(Options());
}

// ---- The VI/EN hotkey ----------------------------------------------------------

static void checkSwitchKey() {
    printf("\n== VI/EN hotkey ==\n");
    using M = SwitchKeyMatcher;
    const uint32_t ctrl = modmask::Control, shift = modmask::Shift;
    auto press = [](M& m, uint32_t kv, uint32_t st) { return m.feed(kv, st, false); };
    auto release = [](M& m, uint32_t kv, uint32_t st) { return m.feed(kv, st | modmask::Release, true); };

    SwitchKey cs = SwitchKey::parse("Control+Shift");
    check(cs.modifiers == (ctrl | shift) && cs.keyval == 0 && cs.toString() == "Control+Shift",
          "K1 \"Control+Shift\" parses as a modifier-only combo");
    SwitchKey cSpace = SwitchKey::parse("ctrl + super + space");
    check(cSpace.modifiers == (ctrl | modmask::Mod4) && cSpace.keyval == keysym::space &&
          cSpace.toString() == "Control+Super+space", "K2 names are case- and space-insensitive");
    check(SwitchKey::parse("z").empty() && SwitchKey::parse("Control+Nope").empty() && SwitchKey::parse("").empty(),
          "K3 a bare key, an unknown name or an empty string means no hotkey");
    check(SwitchKey::parse("Alt+Z").keyval == 'z', "K4 letter keys match in either case");
    check(SwitchKey::parse("Shift+a").empty() && SwitchKey::parse("Shift+space").empty() &&
          !SwitchKey::parse("Shift+F1").empty(),
          "K4b Shift alone cannot make a character key a hotkey (it would eat capitals)");

    M m;
    m.set(cs);
    // X11 reports the state before each event: Ctrl down, Shift down (Ctrl held),
    // Shift up (both held), Ctrl up.
    bool fired = press(m, keysym::Control_L, 0) == M::None &&
                 press(m, keysym::Shift_L, ctrl) == M::None &&
                 release(m, keysym::Shift_L, ctrl | shift) == M::TogglePassThrough;
    release(m, keysym::Control_L, ctrl);
    check(fired, "K5 Ctrl+Shift pressed and released on its own switches the language");

    bool shortcut = press(m, keysym::Control_L, 0) == M::None &&
                    press(m, keysym::Shift_L, ctrl) == M::None &&
                    press(m, 'T', ctrl | shift) == M::None &&
                    release(m, 'T', ctrl | shift) == M::None &&
                    release(m, keysym::Shift_L, ctrl | shift) == M::None;
    release(m, keysym::Control_L, ctrl);
    check(shortcut, "K6 Ctrl+Shift+T is a shortcut, not a switch");

    bool extra = press(m, keysym::Control_L, 0) == M::None &&
                 press(m, keysym::Shift_L, ctrl) == M::None &&
                 press(m, keysym::Alt_L, ctrl | shift) == M::None &&
                 release(m, keysym::Alt_L, ctrl | shift | modmask::Mod1) == M::None &&
                 release(m, keysym::Shift_L, ctrl | shift) == M::None;
    release(m, keysym::Control_L, ctrl);
    check(extra, "K7 adding a third modifier cancels the switch");

    // Rollover: the release of the letter typed just before the combo arrives
    // while Ctrl+Shift is held. It is not a key pressed in between.
    bool rollover = press(m, 'a', 0) == M::None &&
                    press(m, keysym::Control_L, 0) == M::None &&
                    press(m, keysym::Shift_L, ctrl) == M::None &&
                    release(m, 'a', ctrl | shift) == M::None &&
                    release(m, keysym::Shift_L, ctrl | shift) == M::TogglePassThrough;
    release(m, keysym::Control_L, ctrl);
    check(rollover, "K7b a late release of the previous letter does not cancel the switch");

    press(m, keysym::Control_L, 0);
    press(m, keysym::Shift_L, ctrl);
    m.cancel();                                    // e.g. a click while holding them
    check(release(m, keysym::Shift_L, ctrl | shift) == M::None, "K7c a click while holding them cancels the switch");
    release(m, keysym::Control_L, ctrl);

    // Some sessions report the state after the event; the result must not change.
    bool after = press(m, keysym::Control_L, ctrl) == M::None &&
                 press(m, keysym::Shift_L, ctrl | shift) == M::None &&
                 release(m, keysym::Shift_L, ctrl) == M::TogglePassThrough;
    check(after, "K8 the same switch when the session reports post-event state");

    m.set(cSpace);
    check(press(m, ' ', ctrl | modmask::Mod4) == M::Toggle &&
          press(m, ' ', ctrl) == M::None && press(m, ' ', ctrl | modmask::Mod4 | shift) == M::None &&
          press(m, ' ', ctrl | modmask::Super) == M::Toggle,
          "K9 a keyed combo needs exactly its modifiers (Super under either bit)");
}

// ---- Fixtures: core/tests/cases/*.txt ----------------------------------------
//
// Same format and directives as typing_sim_test.cpp. Lines without a delimiter
// (round-trip lines) need its Telex encoder; this harness only runs the
// explicit "keys => expected" lines, which is what the gating file uses.

static string rstripWs(const string& s) {
    size_t b = s.find_last_not_of(" \t\r\n");
    return (b == string::npos) ? string() : s.substr(0, b + 1);
}

static void runFixtures() {
    DIR* d = opendir(gCasesDir);
    if (!d) return;
    vector<string> files;
    struct dirent* e;
    while ((e = readdir(d)) != NULL) {
        string n = e->d_name;
        if (n.size() > 4 && n.compare(n.size() - 4, 4, ".txt") == 0) files.push_back(n);
    }
    closedir(d);
    sort(files.begin(), files.end());
    printf("\n== Fixtures (%s/*.txt, explicit cases) ==\n", gCasesDir);
    for (const string& name : files) {
        bool gated = (name == "backspace_restore.txt");
        FILE* f = fopen((string(gCasesDir) + "/" + name).c_str(), "rb");
        if (!f) continue;
        string data; char b[65536]; size_t r;
        while ((r = fread(b, 1, sizeof b, f)) > 0) data.append(b, r);
        fclose(f);
        Options o; setOptions(o);
        int filePass = 0, fileFail = 0, lineNo = 0;
        size_t pos = 0;
        while (pos <= data.size()) {
            size_t nl = data.find('\n', pos);
            string line = data.substr(pos, nl == string::npos ? string::npos : nl - pos);
            pos = (nl == string::npos) ? data.size() + 1 : nl + 1;
            lineNo++;
            size_t a = line.find_first_not_of(" \t\r\n");
            if (a == string::npos || line[a] == '#') continue;
            if (line[a] == '@') {
                string body = rstripWs(line.substr(a + 1));
                size_t eq = body.find('=');
                string key = body.substr(0, eq), val = eq == string::npos ? "" : body.substr(eq + 1);
                bool on = (val == "on" || val == "1" || val == "true");
                if (key == "reset") o = Options();
                else if (key == "input") o.input = (val == "vni") ? 1 : (val == "simple1") ? 2 : (val == "simple2") ? 3 : 0;
                else if (key == "detect") o.detect = on;
                else if (key == "modern") o.modern = on;
                else if (key == "spell") o.spell = on;
                setOptions(o);
                continue;
            }
            string keys, expected;
            size_t tab = line.find('\t'), arrow = line.find(" => ");
            if (tab != string::npos) { keys = line.substr(0, tab); expected = line.substr(tab + 1); }
            else if (arrow != string::npos) { keys = line.substr(0, arrow); expected = line.substr(arrow + 4); }
            else continue;
            string got = rstripWs(linuxText(rstripWs(keys)));
            bool ok = (got == rstripWs(expected));
            if (ok) { (gated ? g_pass : g_fixPass)++; filePass++; }
            else {
                (gated ? g_fail : g_fixFail)++; fileFail++;
                printf("    [FAIL] %s:%d  \"%s\" -> \"%s\"  (expect \"%s\")\n", name.c_str(), lineNo,
                       rstripWs(keys).c_str(), got.c_str(), rstripWs(expected).c_str());
            }
        }
        printf("  %-24s %d/%d passed%s\n", name.c_str(), filePass, filePass + fileFail, gated ? "  (gating)" : "");
    }
    printf("  fixtures total: %d passed, %d failed (report-only unless marked gating)\n", g_fixPass, g_fixFail);
    setOptions(Options());
}

// --trace "<keys>" [input] [detect]: type one script on both hosts and print
// what the engine decided at each key — the first thing to look at when a
// differential check fails.
static void trace(const string& script, int input, int detect) {
    Options o; o.input = input; o.detect = detect;
    setOptions(o);
    vector<Key> keys = parseKeys(script);
    vKeyHookState* st = (vKeyHookState*)vKeyInit();
    printf("linux:\n");
    hermeticReset();
    gComposer->reset();
    Field f;
    for (const Key& k : keys) {
        Output out = gComposer->processKey(k.ev);
        f.apply(out, k.ev);
        printf("  key %-6s code=%d bsp=%d ncc=%d ext=%d  commit=\"%s\" preedit=\"%s\" %s  => \"%s\"\n",
               k.ev.keyval == keysym::BackSpace ? "{BS}" : toUtf8(u32string(1, k.ev.unicode)).c_str(),
               st->code, st->backspaceCount, st->newCharCount, st->extCode, toUtf8(out.commit).c_str(),
               toUtf8(out.preedit).c_str(), out.consumed ? "consumed" : "passed", toUtf8(f.visible()).c_str());
    }
    printf("mac:\n");
    u32string acc;
    for (size_t i = 0; i < keys.size(); i++) {
        vector<Key> prefix(keys.begin(), keys.begin() + i + 1);
        acc = typeMac(prefix);
        printf("  key %-6s code=%d bsp=%d ncc=%d ext=%d  => \"%s\"\n",
               keys[i].ev.keyval == keysym::BackSpace ? "{BS}" : toUtf8(u32string(1, keys[i].ev.unicode)).c_str(),
               st->code, st->backspaceCount, st->newCharCount, st->extCode, toUtf8(acc).c_str());
    }
}

int main(int argc, char** argv) {
    bool traceMode = argc > 2 && string(argv[1]) == "--trace";
    bool typeMode = argc > 2 && string(argv[1]) == "--type";
    if (!traceMode && !typeMode && argc > 1) gDataDir = argv[1];
    if (!traceMode && !typeMode && argc > 2) gCasesDir = argv[2];

    string eng, viet;
    for (auto& pair : {make_pair(string("english_words.dat"), &eng), make_pair(string("viet_telex.dat"), &viet)}) {
        FILE* f = fopen((string(gDataDir) + "/" + pair.first).c_str(), "rb");
        if (!f) { printf("cannot open %s/%s\n", gDataDir, pair.first.c_str()); return 1; }
        char b[65536]; size_t r;
        while ((r = fread(b, 1, sizeof b, f)) > 0) pair.second->append(b, r);
        fclose(f);
    }
    initEnglishDict((const Byte*)eng.data(), (int)eng.size());
    initVietByTelexDict((const Byte*)viet.data(), (int)viet.size());

    Composer composer;
    gComposer = &composer;
    setOptions(Options());
    if (traceMode) {
        trace(argv[2], argc > 3 ? atoi(argv[3]) : 0, argc > 4 ? atoi(argv[4]) : 0);
        return 0;
    }
    if (typeMode) {
        // --type "<keys>": what the Linux host shows for these keys with the
        // shipped defaults (English detection on) — for writing expectations.
        Options o; o.detect = 1;
        setOptions(o);
        printf("%s\n", linuxText(argv[2]).c_str());
        return 0;
    }

    Case telex[] = {
        {"W1", "dd", "đ"},                 {"W2", "ddi", "đi"},
        {"W3", "dduwowngf", "đường"},      {"W4", "tieesng", "tiếng"},
        {"W5", "Vieejt", "Việt"},          {"W6", "nam", "nam"},
        {"W8", "ddaays", "đấy"},           {"W9", "suwowngs", "sướng"},
        {"W10", "suowngs", "sướng"},       {"W11", "suongws", "sướng"},
        {"W12", "trieenr", "triển"},       {"W13", "truwowngs", "trướng"},
        {"R1", "garr", "gar"},             {"R2", "aaa", "aa"},
        {"R3", "ww", "w"},                 {"R4", "uww", "uw"},
        {"S1", "toi ddi hocj.", "toi đi học."},
        {"S2", "Xin chaof, thees gioiws!", "Xin chào, thế giới!"},
        {"C1", "TIEESNG VIEEJT", "TIẾNG VIỆT"},
    };
    runCases("Telex through the preedit", telex, sizeof telex / sizeof *telex);

    vInputType = 1;
    Case vni[] = {
        {"V1", "Tie61ng Vie65t", "Tiếng Việt"},
        {"V2", "d9u7o7ng2", "đường"},
        {"V3", "2024 la2 na8m", "2024 là năm"},     // digits at a word start stay digits
        {"V4", "abc123", "abc123"},
        {"V5", "a1 b", "á b"},
    };
    runCases("VNI through the preedit", vni, sizeof vni / sizeof *vni);
    vInputType = 0;

    vAutoDetectEnglish = 1;
    Case linuxOnly[] = {
        {"L1", "tieesng{ENTER}vieejt", "tiếng\nviệt"},
        {"L2", "tieesng{TAB}x", "tiếng\tx"},
        {"L3", "dduwowngf{CLICK}s", "đườngs"},         // click: IBus commits; next key starts a word
        {"L4", "Vieejt{LEFT}", "Việt"},
        {"L5", "ddi{KP1}", "đi1"},                     // keypad digit: a break, typed by the app
        {"L6", "ddi{DEL}x", "đix"},                    // Delete ends the word, types nothing
        {"L7", "ab\xc3\xa9 ok", "abé ok"},             // é from the layout ends the word, kept as is
        {"L7b", "caf\xc3\xa9", "càé"},                 // ... after the engine had its say ("caf" is "cà")
        {"L8", "google ", "google "},                  // English restored at the break
        {"L9", "google{ENTER}", "google\n"},           // ... at Enter too
        {"L10", "google{C-s}", "google"},              // ... and before a shortcut
        {"L11", "project.", "project."},
        {"L12", "ddoongf{BS}s ok", "đốn ok"},          // Backspace inside the word keeps composing
        {"L13", "tieesng{BS}{BS}{BS}{BS}{BS}{BS}{BS}ok", "ok"},
        {"L14", "abc 4Us", "abc 4Ú"},                 // a digit after a space starts no word...
        {"L15", "4Us", "4Ú"},                         // ... exactly as at the start of a line
        {"L16", "9i{BS}w", "9ư"},                     // Backspace keeps the engine's context:
        {"L16b", "9w", "9ư"},                         // ... the same as never typing the i
    };
    runCases("Linux host behaviour", linuxOnly, sizeof linuxOnly / sizeof *linuxOnly);
    vAutoDetectEnglish = 0;

    checkProtocol();
    checkBackspaceIntoCommittedWord();
    checkSwitchKey();

    vector<string> words = loadDictionary();
    checkDictionaryMatchesMac(words);
    checkFuzzMatchesMac();
    checkCodeTables(words);
    runFixtures();

    printf("\n%d passed, %d failed\n", g_pass, g_fail);
    return g_fail == 0 ? 0 : 1;
}
