//
//  typing_sim_test.cpp
//  84Key — keystroke-level simulation of the macOS app's typing pipeline.
//
//  Unlike engine_test.cpp (which uses its own reference decoder), this harness
//  reproduces the EXACT buffer effect of the macOS host's keyDown handler in
//  platform/macos/Input/InputController.mm for the Unicode code table:
//    * vDoNothing            -> the OS types the literal key
//    * vWillProcess/vRestore -> (optional empty char) + N backspaces + new chars
//  so it catches host-side output bugs the engine harness cannot. It types
//  continuously (no per-keystroke engine reset) like a real person typing a
//  passage. No AppKit / CGEvent / Accessibility needed — pure and automatable.
//

#include <cstdio>
#include <cstring>
#include <string>
#include <cstdint>
#include <vector>
#include <algorithm>
#include <dirent.h>
#include <map>

#include "../engine/Engine.h"
#include "../engine/EnglishDetect.h"

using namespace std;

// keycode -> ascii, provided by the engine (Vietnamese.cpp)
extern Uint16 keyCodeToCharacter(const Uint32& keyCode);

// ---- Option globals -------------------------------------------------------
int vLanguage = 1, vInputType = 0, vFreeMark = 0, vCodeTable = 0, vSwitchKeyStatus = 0;
int vCheckSpelling = 1, vUseModernOrthography = 1, vQuickTelex = 0, vRestoreIfWrongSpelling = 0;
int vFixRecommendBrowser = 1, vUseMacro = 0, vUseMacroInEnglishMode = 0, vAutoCapsMacro = 0;
int vUseSmartSwitchKey = 0, vUpperCaseFirstChar = 0, vTempOffSpelling = 0, vAllowConsonantZFWJ = 0;
int vQuickStartConsonant = 0, vQuickEndConsonant = 0, vRememberCode = 0, vOtherLanguage = 0;
int vTempOffOpenKey = 0, vAutoDetectEnglish = 0;

// ASCII char -> engine keycode; sets `caps` when Shift is needed. Covers letters,
// digits, space and common punctuation (so article round-trips can be typed).
static int asciiToKey(char ch, bool& caps) {
    caps = false;
    unsigned char c = (unsigned char)ch;
    if (c >= 'A' && c <= 'Z') { caps = true; c = (unsigned char)(c - 'A' + 'a'); }
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

// Reproduce InputController.mm SendNewCharString's per-entry decode (Unicode,
// vCodeTable==0) + the keyDown vWillProcess/vRestore buffer effect.
static void applyAppOutput(u32string& buf, vKeyHookState* st, uint16_t triggerChar) {
    if (st->code == vDoNothing) {
        if (triggerChar) buf.push_back((char32_t)triggerChar);
        return;
    }
    if (!(st->code == vWillProcess || st->code == vRestore || st->code == vRestoreAndStartNewSession))
        return;

    int bsp = st->backspaceCount;
    // fix-autocomplete dance (InputController.mm ~676): empty char then +1 backspace
    if (vFixRecommendBrowser && st->extCode != 4) {
        buf.push_back((char32_t)0x202F); // empty char
        bsp += 1;
    }
    for (int i = 0; i < bsp; i++)
        if (!buf.empty()) buf.pop_back();

    // SendNewCharString decode, charData is right-to-left -> emit high..low index
    for (int k = (int)st->newCharCount - 1; k >= 0; k--) {
        uint32_t t = st->charData[k];
        uint16_t ch;
        if (t & PURE_CHARACTER_MASK)       ch = (uint16_t)(t & CHAR_MASK);
        else if (!(t & CHAR_CODE_MASK))    ch = keyCodeToCharacter(t);
        else                               ch = (uint16_t)(t & CHAR_MASK);
        buf.push_back((char32_t)ch);
    }
    if ((st->code == vRestore || st->code == vRestoreAndStartNewSession) && triggerChar)
        buf.push_back((char32_t)triggerChar);
}

// Type `keys` from a clean engine state; return the visible text. Uppercase = Shift.
static u32string typeFresh(vKeyHookState* st, const string& keys) {
    vKeyInit();
    u32string buf;
    for (char ch : keys) {
        bool caps = false;
        int kc = asciiToKey(ch, caps);
        if (kc < 0) continue; // unsupported character
        vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, (Uint16)kc, caps ? 1 : 0, false);
        uint16_t literal = (uint16_t)(unsigned char)ch; // doNothing / restore trigger
        applyAppOutput(buf, st, literal);
    }
    return buf;
}

static string toUtf8(const u32string& s) {
    string o;
    for (char32_t c : s) {
        if (c < 0x80) o.push_back((char)c);
        else if (c < 0x800) { o.push_back((char)(0xC0 | (c >> 6))); o.push_back((char)(0x80 | (c & 0x3F))); }
        else { o.push_back((char)(0xE0 | (c >> 12))); o.push_back((char)(0x80 | ((c >> 6) & 0x3F))); o.push_back((char)(0x80 | (c & 0x3F))); }
    }
    return o;
}

static int g_pass = 0, g_fail = 0;        // gating: built-in cases + engine
static int g_fixPass = 0, g_fixFail = 0;  // report-only: cases/*.txt fixtures
struct Case { const char* id; const char* keys; const char* expect; };

static void run(vKeyHookState* st, const Case& c) {
    string got = toUtf8(typeFresh(st, c.keys));
    bool ok = (got == c.expect);
    printf("  [%s] %-6s \"%s\" -> \"%s\" (expect \"%s\")\n",
           ok ? "PASS" : "FAIL", c.id, c.keys, got.c_str(), c.expect);
    ok ? g_pass++ : g_fail++;
}

// ---- File fixtures: load articles/cases from core/tests/cases/*.txt ----------
//
// Each line is a case "<keys> => <expected>" (or tab-separated). Lines starting
// with '#' are comments; blank lines are ignored. Directives set the mode for
// subsequent lines in that file (reset to Telex/no-detect at the start of each):
//   @input=telex|vni|simple1|simple2   @detect=on|off
//   @modern=on|off   @spell=on|off     @reset
// Trailing whitespace is ignored on both sides.

static string rstripWs(const string& s) {
    size_t b = s.find_last_not_of(" \t\r\n");
    return (b == string::npos) ? string() : s.substr(0, b + 1);
}

static void resetFixtureOptions() {
    vInputType = 0; vAutoDetectEnglish = 0; vUseModernOrthography = 1; vCheckSpelling = 1;
}

static void applyDirective(const string& body) {
    size_t eq = body.find('=');
    string key = rstripWs(eq == string::npos ? body : body.substr(0, eq));
    string val = rstripWs(eq == string::npos ? "" : body.substr(eq + 1));
    size_t a = key.find_first_not_of(" \t"); if (a != string::npos) key = key.substr(a);
    bool on = (val == "on" || val == "1" || val == "true");
    if (key == "reset") resetFixtureOptions();
    else if (key == "input")
        vInputType = (val == "vni") ? 1 : (val == "simple1") ? 2 : (val == "simple2") ? 3 : 0;
    else if (key == "detect") vAutoDetectEnglish = on ? 1 : 0;
    else if (key == "modern") vUseModernOrthography = on ? 1 : 0;
    else if (key == "spell")  vCheckSpelling = on ? 1 : 0;
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

// Reverse of the engine: turn a precomposed Vietnamese string into the Telex
// keystrokes that produce it. Diacritic letters map to base + tone key (the tone
// key right after the vowel, which Telex accepts); ASCII passes through. Used by
// @roundtrip fixtures so you can paste correct Vietnamese and have it re-typed.
// codepoint -> (base telex letters, tone key). Tone is kept separate so it can be
// deferred to the end of the word (the canonical Telex spelling, e.g. bản->"banr").
static const std::map<char32_t, std::pair<string, string>>& vietToTelexMap() {
    static std::map<char32_t, std::pair<string, string>> m;
    if (!m.empty()) return m;
    static const char* tone[6] = {"", "s", "f", "r", "x", "j"}; // none,sắc,huyền,hỏi,ngã,nặng
    struct Row { const char* lo; const char* up; char32_t loCp[6]; char32_t upCp[6]; };
    static const Row rows[] = {
        {"a","A",  {0x61,0xE1,0xE0,0x1EA3,0xE3,0x1EA1},   {0x41,0xC1,0xC0,0x1EA2,0xC3,0x1EA0}},
        {"aw","Aw",{0x103,0x1EAF,0x1EB1,0x1EB3,0x1EB5,0x1EB7},{0x102,0x1EAE,0x1EB0,0x1EB2,0x1EB4,0x1EB6}},
        {"aa","Aa",{0xE2,0x1EA5,0x1EA7,0x1EA9,0x1EAB,0x1EAD},{0xC2,0x1EA4,0x1EA6,0x1EA8,0x1EAA,0x1EAC}},
        {"e","E",  {0x65,0xE9,0xE8,0x1EBB,0x1EBD,0x1EB9},   {0x45,0xC9,0xC8,0x1EBA,0x1EBC,0x1EB8}},
        {"ee","Ee",{0xEA,0x1EBF,0x1EC1,0x1EC3,0x1EC5,0x1EC7},{0xCA,0x1EBE,0x1EC0,0x1EC2,0x1EC4,0x1EC6}},
        {"i","I",  {0x69,0xED,0xEC,0x1EC9,0x129,0x1ECB},    {0x49,0xCD,0xCC,0x1EC8,0x128,0x1ECA}},
        {"o","O",  {0x6F,0xF3,0xF2,0x1ECF,0xF5,0x1ECD},     {0x4F,0xD3,0xD2,0x1ECE,0xD5,0x1ECC}},
        {"oo","Oo",{0xF4,0x1ED1,0x1ED3,0x1ED5,0x1ED7,0x1ED9},{0xD4,0x1ED0,0x1ED2,0x1ED4,0x1ED6,0x1ED8}},
        {"ow","Ow",{0x1A1,0x1EDB,0x1EDD,0x1EDF,0x1EE1,0x1EE3},{0x1A0,0x1EDA,0x1EDC,0x1EDE,0x1EE0,0x1EE2}},
        {"u","U",  {0x75,0xFA,0xF9,0x1EE7,0x169,0x1EE5},    {0x55,0xDA,0xD9,0x1EE6,0x168,0x1EE4}},
        {"uw","Uw",{0x1B0,0x1EE9,0x1EEB,0x1EED,0x1EEF,0x1EF1},{0x1AF,0x1EE8,0x1EEA,0x1EEC,0x1EEE,0x1EF0}},
        {"y","Y",  {0x79,0xFD,0x1EF3,0x1EF7,0x1EF9,0x1EF5}, {0x59,0xDD,0x1EF2,0x1EF6,0x1EF8,0x1EF4}},
    };
    for (const Row& r : rows)
        for (int t = 0; t < 6; t++) {
            m[r.loCp[t]] = {r.lo, tone[t]};
            m[r.upCp[t]] = {r.up, tone[t]};
        }
    m[0x111] = {"dd", ""}; m[0x110] = {"Dd", ""}; // đ / Đ
    return m;
}

static string vietToTelex(const u32string& s) {
    const auto& m = vietToTelexMap();
    string out, run, tone;
    auto flush = [&]() { out += run + tone; run.clear(); tone.clear(); };
    for (char32_t c : s) {
        auto it = m.find(c);
        if (it != m.end()) {                        // Vietnamese letter
            run += it->second.first;
            if (!it->second.second.empty()) tone = it->second.second;
        } else if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
            run += (char)c;                          // ASCII letter: part of the word
        } else {                                     // word boundary
            flush();
            if (c < 0x80) out.push_back((char)c);
        }
    }
    flush();
    return out;
}

static void runFixtureFile(vKeyHookState* st, const string& path, const string& name) {
    FILE* f = fopen(path.c_str(), "rb");
    if (!f) return;
    string data; char b[65536]; size_t r;
    while ((r = fread(b, 1, sizeof b, f)) > 0) data.append(b, r);
    fclose(f);

    resetFixtureOptions();
    bool roundtrip = false;
    int filePass = 0, fileFail = 0, lineNo = 0;
    size_t pos = 0;
    while (pos <= data.size()) {
        size_t nl = data.find('\n', pos);
        string line = data.substr(pos, nl == string::npos ? string::npos : nl - pos);
        pos = (nl == string::npos) ? data.size() + 1 : nl + 1;
        lineNo++;

        size_t a = line.find_first_not_of(" \t\r\n");
        if (a == string::npos) continue;          // blank
        if (line[a] == '#') continue;             // comment
        if (line[a] == '@') {                     // directive
            string dk = rstripWs(line.substr(a + 1));
            size_t ds = dk.find_first_not_of(" \t");
            if (ds != string::npos) dk = dk.substr(ds);
            if (dk == "roundtrip" || dk == "roundtrip=on") { roundtrip = true; vAutoDetectEnglish = 1; }
            else if (dk == "roundtrip=off") roundtrip = false;
            else applyDirective(line.substr(a + 1));
            continue;
        }

        string keys, expected;
        bool rt = roundtrip;
        if (!rt) {
            size_t tab = line.find('\t');
            size_t arrow = line.find(" => ");
            if (tab != string::npos) { keys = line.substr(0, tab); expected = line.substr(tab + 1); }
            else if (arrow != string::npos) { keys = line.substr(0, arrow); expected = line.substr(arrow + 4); }
            else rt = true;   // no delimiter -> auto round-trip the (correct) text
        }
        if (rt) {
            // The line IS the correct Vietnamese; derive the keystrokes that type it.
            expected = rstripWs(line);
            keys = vietToTelex(fromUtf8(expected));
        }

        // Round-tripping real text: English-detection ON so embedded English words
        // survive, and traditional orthography (òa/úy) which is what most prose
        // uses (the engine default "modern" oà/uý would mismatch).
        int savedDetect = vAutoDetectEnglish, savedModern = vUseModernOrthography;
        if (rt) { vAutoDetectEnglish = 1; vUseModernOrthography = 0; }
        string got = rstripWs(toUtf8(typeFresh(st, keys)));
        vAutoDetectEnglish = savedDetect; vUseModernOrthography = savedModern;
        string exp = rstripWs(expected);
        bool ok = (got == exp);
        if (ok) { g_fixPass++; filePass++; }
        else {
            g_fixFail++; fileFail++;
            printf("    [FAIL] %s:%d  \"%s\" -> \"%s\"  (expect \"%s\")\n",
                   name.c_str(), lineNo, rstripWs(keys).c_str(), got.c_str(), exp.c_str());
        }
    }
    printf("  %-24s %d/%d passed\n", name.c_str(), filePass, filePass + fileFail);
}

static void runFixtures(vKeyHookState* st, const char* dir) {
    DIR* d = opendir(dir);
    if (!d) return;
    vector<string> files;
    struct dirent* e;
    while ((e = readdir(d)) != NULL) {
        string n = e->d_name;
        if (n.size() > 4 && n.compare(n.size() - 4, 4, ".txt") == 0) files.push_back(n);
    }
    closedir(d);
    if (files.empty()) return;
    sort(files.begin(), files.end());
    printf("\n== Article fixtures (%s/*.txt) ==\n", dir);
    for (const string& n : files) runFixtureFile(st, string(dir) + "/" + n, n);
    resetFixtureOptions();
    printf("  fixtures total: %d passed, %d failed (report-only — not part of the gate)\n",
           g_fixPass, g_fixFail);
}

// ---- Contract checks for the compound splitter -----------------------------
//
// Property: recognising compounds must never be what decides a Vietnamese word.
// A 3-letter piece floor keeps the overlap tiny (43 of 29644 Telex spellings at
// the time of writing), but "tiny" is not the guarantee — the guarantee is that
// every overlapping spelling is itself in the Vietnamese dictionary, so
// shouldTreatAsEnglish()/restoreEnglishAtBreak() bail on it via isVietByTelex().
// Counting instead would need the threshold retuned whenever a dictionary grows;
// this holds regardless of size. Fails the gate if a dictionary change breaks it.
static void checkCompoundNeverOverridesVietnamese() {
    FILE* f = fopen("../data/viet_telex.dat", "rb");
    if (!f) { printf("  [FAIL] C-prop  cannot open viet_telex.dat\n"); g_fail++; return; }
    char line[128];
    int checked = 0, leaked = 0;
    string firstLeak;
    while (fgets(line, sizeof line, f)) {
        string w(line);
        while (!w.empty() && (w.back() == '\n' || w.back() == '\r')) w.pop_back();
        if (w.empty()) continue;
        checked++;
        if (!isEnglishCompound(w)) continue;
        if (isVietByTelex(w) || isVietByTelexPrefix(w)) continue;
        if (leaked++ == 0) firstLeak = w;
    }
    fclose(f);
    bool ok = (leaked == 0);
    printf("  [%s] C-prop %d Telex spellings: none read as English-only%s\n",
           ok ? "PASS" : "FAIL", checked,
           ok ? "" : (" (e.g. \"" + firstLeak + "\")").c_str());
    ok ? g_pass++ : g_fail++;
}

// A compound with no transform key inside it ("imagegen") is now restore-eligible,
// but nothing about it changed on screen — so the engine must emit ZERO events for
// it. restoreEnglishAtBreak()'s `differs` check is what guarantees that; without it
// every clean compound would fire a pointless backspace+retype burst at each word
// break, and that burst is exactly what misbehaves in browsers and Spotlight.
static void checkCleanCompoundEmitsNothing(vKeyHookState* st) {
    vKeyInit();
    const char* keys = "imagegen ";
    int events = 0;
    for (const char* p = keys; *p; p++) {
        bool caps = false;
        int kc = asciiToKey(*p, caps);
        vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, (Uint16)kc, caps ? 1 : 0, false);
        if (st->code != vDoNothing || st->backspaceCount != 0)
            events++;
    }
    bool ok = (events == 0);
    printf("  [%s] C-noop \"imagegen \" emits no backspace/rewrite (%d keystroke(s) did)\n",
           ok ? "PASS" : "FAIL", events);
    ok ? g_pass++ : g_fail++;
}

int main() {
    string eng, viet;
    { FILE* f = fopen("../data/english_words.dat", "rb"); if (f) { char b[65536]; size_t r; while ((r = fread(b,1,sizeof b,f))>0) eng.append(b,r); fclose(f);} }
    { FILE* f = fopen("../data/viet_telex.dat", "rb"); if (f) { char b[65536]; size_t r; while ((r = fread(b,1,sizeof b,f))>0) viet.append(b,r); fclose(f);} }
    initEnglishDict((const Byte*)eng.data(), (int)eng.size());
    initVietByTelexDict((const Byte*)viet.data(), (int)viet.size());
    vKeyHookState* st = (vKeyHookState*)vKeyInit();

    printf("== App-decode simulation: reported failing cases ==\n");
    Case reported[] = {
        {"dd",   "dd",     "đ"},
        {"ddd",  "ddd",    "dd"},      // đ then d restores to dd
        {"w",    "w",      "ư"},       // standalone w -> ư
        {"ww",   "ww",     "w"},       // double w -> literal w
        {"uw",   "uw",     "ư"},
        {"uww",  "uww",    "uw"},      // ư then w -> uw
        {"ow",   "ow",     "ơ"},
        {"oww",  "oww",    "ow"},
        {"aa",   "aa",     "â"},
        {"aaa",  "aaa",    "aa"},
        // Doubled tone key restores the literal letter mid-word (no break):
        // r = hỏi, so "garr" = g,a,r(->gả),r(restore) -> "gar". Same shape as
        // the "iss"/"uss" cases but resolved at the keystroke, not the break.
        // Regression for the Google Docs "garr" -> "gảar" report.
        {"garr", "garr",   "gar"},
        {"barr", "barr",   "bar"},
        {"arr",  "arr",    "ar"},
        {"Garr", "Garr",   "Gar"},     // capitalized base consonant
    };
    for (auto& c : reported) run(st, c);

    printf("\n== Telex words (continuous-typing sanity) ==\n");
    Case words[] = {
        {"W1", "dd",        "đ"},
        {"W2", "ddi",       "đi"},
        {"W3", "dduwowngf", "đường"},
        {"W4", "tieesng",   "tiếng"},
        {"W5", "Vieejt",    "Việt"},
        {"W6", "nam",       "nam"},
        {"W7", "ddays",     "đáy"},
        {"W8", "ddaays",    "đấy"},     // â needs doubled a
    };
    for (auto& c : words) run(st, c);

    printf("\n== English auto-detection (app decode, restore at break) ==\n");
    vAutoDetectEnglish = 1;
    Case english[] = {
        {"E-prj", "project ", "project "},
        {"E-gun", "guns ",    "guns "},
        {"E-ggl", "google ",  "google "},
        {"E-as",  "as",       "á"},        // English word but valid VN -> keep VN
        // Regression: "dd" is an English-dict word AND the đ digraph; with detect
        // ON it must still form đ-words (it is a valid Vietnamese prefix).
        {"E-dd",  "dd",        "đ"},
        {"E-ddi", "ddi",       "đi"},
        {"E-dduo","dduwowngf", "đường"},
        {"E-ddv", "ddi Vieejt Nam", "đi Việt Nam"},
        {"E-dds", "dd hocj",   "đ học"},   // bare đ at a word break must not revert
        // Leading-w English word restores at a word break, incl. "!" (a shifted
        // number key, which isn't in the engine's break-code set).
        {"E-wow1", "wow ok",  "wow ok"},
        {"E-wow2", "wow!",    "wow!"},
        {"E-wow3", "wow.",    "wow."},
        // Double-w escape: a 2nd w turns the standalone ư back into a literal w.
        // Must win over English-detect even though "ww" is an English-dict word,
        // and the escape must survive the word break (not revert to raw "ww").
        {"E-ww",   "ww",       "w"},
        {"E-ww2",  "ww done",  "w done"},
        {"E-win",  "window ",  "window "},  // leading-w English: ư restored at break
        // Double-tone-key escape: "is"->í (prefer VN), but a repeated tone key
        // ("iss") drops the mark to give the literal English "is" — now at the
        // keystroke (E-iss-now/E-ass-now), so the accent never lingers, as well as
        // at any later word break (E-iss/E-iss2). Only for non-dictionary strings —
        // real English words (miss/class/issue/assign) come out whole via detection
        // + the word-break restore, proving the early drop doesn't corrupt recovery.
        {"E-iss-now", "iss",     "is"},         // no break: accent dropped immediately
        {"E-ass-now", "ass",     "as"},
        {"E-iss",  "iss done",  "is done"},
        {"E-iss2", "iss. ok",   "is. ok"},
        {"E-ass",  "ass ",      "as "},
        {"E-miss", "miss ",     "miss "},
        {"E-clas", "class ",    "class "},
        {"E-isu",  "issue ",    "issue "},
        {"E-asg",  "assign ",   "assign "},
        {"E-is",   "is ",       "í "},        // single tone key still prefers VN
    };
    for (auto& c : english) run(st, c);

    printf("\n== Compound English (dictionary holds simple words only) ==\n");
    Case compound[] = {
        {"C-dash", "dashboard ok", "dashboard ok"},   // dash + board
        {"C-air",  "airdrop ok",   "airdrop ok"},     // air + drop; r ate a letter before
        {"C-test", "testgen ok",   "testgen ok"},     // test + gen
        {"C-conf", "confusing ok", "confusing ok"},   // conf + using
        {"C-mark", "markdown ok",  "markdown ok"},
        {"C-suf",  "dashboards ok", "dashboards ok"}, // plural form
        // Vietnamese wins: these Telex spellings do split into English pieces,
        // and the isVietByTelex() guard is the only thing keeping them Vietnamese.
        {"C-vn1",  "chinhs ok",    "chính ok"},
        {"C-vn2",  "choair ok",    "choải ok"},
        // Telex accepts the tone and vowel-modifier keys in several orders, but
        // the dictionary stores one canonical spelling per word, so these are
        // invisible to isVietByTelexPrefix() and split into English pieces
        // ("chiseem" -> "chi"+"seem", "thuana" -> "thu"+"ana"). renderedIsViet(),
        // which looks up the word the engine actually produced, is what keeps
        // them Vietnamese.
        {"C-tone1", "chiseem ok",  "chiếm ok"},   // tone key right after the vowel
        {"C-tone2", "chiseen ok",  "chiến ok"},
        {"C-tone3", "chofan ok",   "choàn ok"},
        {"C-mod1",  "thuana ok",   "thuân ok"},   // vowel modifier at the end
        {"C-mod2",  "chorio ok",   "chổi ok"},
        {"C-mod3",  "dieuse ok",   "diếu ok"},
        // Neither dictionary: a drawn-out "quáaaa" must be left alone, not
        // reverted to its raw keystrokes.
        {"C-none", "quasaaa ok",   "quaaá ok"},
    };
    for (auto& c : compound) run(st, c);

    checkCompoundNeverOverridesVietnamese();
    checkCleanCompoundEmitsNothing(st);
    vAutoDetectEnglish = 0;

    // User-supplied articles / cases dropped into core/tests/cases/*.txt
    runFixtures(st, "cases");

    printf("\n%d passed, %d failed\n", g_pass, g_fail);
    return g_fail == 0 ? 0 : 1;
}
