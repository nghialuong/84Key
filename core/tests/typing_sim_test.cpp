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

static int charToKey(char c) {
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
        bool caps = (ch >= 'A' && ch <= 'Z');
        char lo = caps ? (char)(ch - 'A' + 'a') : ch;
        int kc = charToKey(lo);
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

static int g_pass = 0, g_fail = 0;
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

static void runFixtureFile(vKeyHookState* st, const string& path, const string& name) {
    FILE* f = fopen(path.c_str(), "rb");
    if (!f) return;
    string data; char b[65536]; size_t r;
    while ((r = fread(b, 1, sizeof b, f)) > 0) data.append(b, r);
    fclose(f);

    resetFixtureOptions();
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
        if (line[a] == '@') { applyDirective(line.substr(a + 1)); continue; }

        string keys, expected;
        size_t tab = line.find('\t');
        size_t arrow = line.find(" => ");
        if (tab != string::npos) { keys = line.substr(0, tab); expected = line.substr(tab + 1); }
        else if (arrow != string::npos) { keys = line.substr(0, arrow); expected = line.substr(arrow + 4); }
        else { keys = line; expected = line; }    // no delimiter: expect output == typed (English)

        string got = rstripWs(toUtf8(typeFresh(st, keys)));
        string exp = rstripWs(expected);
        bool ok = (got == exp);
        if (ok) { g_pass++; filePass++; }
        else {
            g_fail++; fileFail++;
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
    };
    for (auto& c : english) run(st, c);
    vAutoDetectEnglish = 0;

    // User-supplied articles / cases dropped into core/tests/cases/*.txt
    runFixtures(st, "cases");

    printf("\n%d passed, %d failed\n", g_pass, g_fail);
    return g_fail == 0 ? 0 : 1;
}
