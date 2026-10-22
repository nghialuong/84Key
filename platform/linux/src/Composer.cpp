//
//  Composer.cpp
//  84Key — the Linux host's typing pipeline. See Composer.h for the design.
//
//  The decode of the engine's output follows SendNewCharString / handleMacro in
//  platform/macos/Input/InputController.mm (itself ported from OpenKey,
//  tuyenvm/OpenKey, GPLv3), so both hosts turn the same vKeyHookState into the
//  same characters; platform/linux/tests/host_test.cpp holds the Linux
//  pipeline to the macOS one over the whole Telex dictionary.
//

#include "Composer.h"
#include "Keysyms.h"

#include "Engine.h"

// Engine internals the host decode needs (defined in core/engine). The macOS
// host reaches the same two arrays the same way.
extern Uint16 keyCodeToCharacter(const Uint32& keyCode);
extern Uint16 _unicodeCompoundMark[];
// The engine's own break-key test (Engine.cpp). Reused so that "does this key
// end the word" is decided by exactly the rule vKeyHandleEvent applies.
extern bool isWordBreak(const vKeyEvent& event, const vKeyEventState& state, const Uint16& data);

namespace key84 {

namespace {

vKeyHookState* hook() {
    static vKeyHookState* state = (vKeyHookState*)vKeyInit();
    return state;
}

// Printable ASCII -> the engine key that types it, and whether that takes
// Shift. Built from the keysym rather than the physical key, so the engine
// reads the character the active layout produced (AZERTY, Dvorak, ...).
bool asciiKey(char32_t ch, Uint16& code, Uint8& caps) {
    caps = 0;
    if (ch >= 'A' && ch <= 'Z') {
        caps = 1;
        ch = ch - 'A' + 'a';
    }
    switch (ch) {
        case 'a': code = KEY_A; return true; case 'b': code = KEY_B; return true;
        case 'c': code = KEY_C; return true; case 'd': code = KEY_D; return true;
        case 'e': code = KEY_E; return true; case 'f': code = KEY_F; return true;
        case 'g': code = KEY_G; return true; case 'h': code = KEY_H; return true;
        case 'i': code = KEY_I; return true; case 'j': code = KEY_J; return true;
        case 'k': code = KEY_K; return true; case 'l': code = KEY_L; return true;
        case 'm': code = KEY_M; return true; case 'n': code = KEY_N; return true;
        case 'o': code = KEY_O; return true; case 'p': code = KEY_P; return true;
        case 'q': code = KEY_Q; return true; case 'r': code = KEY_R; return true;
        case 's': code = KEY_S; return true; case 't': code = KEY_T; return true;
        case 'u': code = KEY_U; return true; case 'v': code = KEY_V; return true;
        case 'w': code = KEY_W; return true; case 'x': code = KEY_X; return true;
        case 'y': code = KEY_Y; return true; case 'z': code = KEY_Z; return true;
        case '0': code = KEY_0; return true; case '1': code = KEY_1; return true;
        case '2': code = KEY_2; return true; case '3': code = KEY_3; return true;
        case '4': code = KEY_4; return true; case '5': code = KEY_5; return true;
        case '6': code = KEY_6; return true; case '7': code = KEY_7; return true;
        case '8': code = KEY_8; return true; case '9': code = KEY_9; return true;
        case ' ': code = KEY_SPACE; return true;
        case '`': code = KEY_BACKQUOTE; return true;     case '-': code = KEY_MINUS; return true;
        case '=': code = KEY_EQUALS; return true;        case '[': code = KEY_LEFT_BRACKET; return true;
        case ']': code = KEY_RIGHT_BRACKET; return true; case '\\': code = KEY_BACK_SLASH; return true;
        case ';': code = KEY_SEMICOLON; return true;     case '\'': code = KEY_QUOTE; return true;
        case ',': code = KEY_COMMA; return true;         case '.': code = KEY_DOT; return true;
        case '/': code = KEY_SLASH; return true;
    }
    caps = 1;
    switch (ch) {
        case '~': code = KEY_BACKQUOTE; return true;     case '!': code = KEY_1; return true;
        case '@': code = KEY_2; return true;             case '#': code = KEY_3; return true;
        case '$': code = KEY_4; return true;             case '%': code = KEY_5; return true;
        case '^': code = KEY_6; return true;             case '&': code = KEY_7; return true;
        case '*': code = KEY_8; return true;             case '(': code = KEY_9; return true;
        case ')': code = KEY_0; return true;             case '_': code = KEY_MINUS; return true;
        case '+': code = KEY_EQUALS; return true;        case '{': code = KEY_LEFT_BRACKET; return true;
        case '}': code = KEY_RIGHT_BRACKET; return true; case '|': code = KEY_BACK_SLASH; return true;
        case ':': code = KEY_SEMICOLON; return true;     case '"': code = KEY_QUOTE; return true;
        case '<': code = KEY_COMMA; return true;         case '>': code = KEY_DOT; return true;
        case '?': code = KEY_SLASH; return true;
    }
    return false;
}

// One engine output entry -> the characters it stands for in the active code
// table. Mirrors the per-entry decode of SendNewCharString (InputController.mm).
std::u32string decodeUnit(Uint32 data) {
    std::u32string unit;
    if (data & PURE_CHARACTER_MASK) {
        unit.push_back((char32_t)(data & CHAR_MASK));
    } else if (!(data & CHAR_CODE_MASK)) {
        Uint16 ch = keyCodeToCharacter(data);
        if (ch)
            unit.push_back(ch);
    } else {
        Uint16 ch = (Uint16)data;
        if (vCodeTable == 0) {                                          // Unicode
            unit.push_back(ch);
        } else if (vCodeTable == 1 || vCodeTable == 2 || vCodeTable == 4) { // TCVN3, VNI Windows, CP1258
            Uint16 hi = HIBYTE(ch);
            unit.push_back(LOBYTE(ch));
            if (hi > 32)
                unit.push_back(hi);
        } else if (vCodeTable == 3) {                                   // Unicode Compound
            Uint16 mark = ch >> 13;
            unit.push_back(ch & 0x1FFF);
            if (mark > 0)
                unit.push_back(_unicodeCompoundMark[mark - 1]);
        }
    }
    return unit;
}

} // namespace

Composer::Composer() {
    hook();
}

std::u32string Composer::preeditText() const {
    std::u32string text;
    for (const std::u32string& unit : units_)
        text += unit;
    return text;
}

// Apply a vWillProcess / vRestore / vRestoreAndStartNewSession / vReplaceMaro
// verdict to the word: drop the characters the engine took back, append the
// ones it sends, and (for the restore codes) put the triggering key after them —
// the same three steps the macOS host performs with real backspaces. Returns
// whether `literal` was placed.
bool Composer::applyEngineEdit(char32_t literal) {
    vKeyHookState* st = hook();
    const bool macro = (st->code == vReplaceMaro);

    // Callers check engineAgrees() first; clamp regardless — taking characters
    // the app already holds is the one thing this host never does.
    size_t remove = st->backspaceCount;
    if (remove > units_.size())
        remove = units_.size();
    units_.resize(units_.size() - remove);

    if (macro) {
        for (size_t k = 0; k < st->macroData.size(); k++)
            units_.push_back(decodeUnit(st->macroData[k]));
    } else {
        for (int k = (int)st->newCharCount - 1; k >= 0; k--)  // charData is right-to-left
            units_.push_back(decodeUnit(st->charData[k]));
    }

    const bool placeLiteral = literal &&
        (macro || st->code == vRestore || st->code == vRestoreAndStartNewSession);
    if (placeLiteral)
        units_.push_back(std::u32string(1, literal));
    if (st->code == vRestoreAndStartNewSession)
        startNewSession();
    return placeLiteral;
}

// Does the engine's rewrite stay inside the word we hold? Every word starts with
// the engine's word empty (each commit starts a new one, and a Backspace with
// nothing composed resets it), so it should. One engine path does not: after a
// Backspace, a Telex w can count the key just pressed as already on screen —
// "ìu", Backspace, "w" asks to rewrite two characters while one is there. The
// macOS host sends those backspaces and deletes the space or punctuation in
// front of the word. Here the word is the whole of what may be rewritten, so the
// request is refused and the key starts a new word instead.
bool Composer::engineAgrees() {
    if (hook()->backspaceCount <= units_.size())
        return true;
    overreaches_++;
    return false;
}

// Forget the word, the engine's word history included. The macOS host does this
// on a mouse click (RequestNewSession). Here it also runs on a Backspace with
// nothing composed: the history is how the engine reopens the previous word on
// Backspace, and that word has been committed — it belongs to the app now.
void Composer::resetEngine() {
    vKeyHandleEvent(vKeyEvent::Mouse, vKeyEventState::MouseDown, KEY_EMPTY);
    // A mouse event is a word break, and a break may ask to restore an English
    // word; nothing is on screen to restore, so start clean either way.
    startNewSession();
}

void Composer::reset() {
    units_.clear();
    resetEngine();
}

Output Composer::commitAll(Output out, char32_t trailing) {
    out.commit = preeditText();
    if (trailing)
        out.commit.push_back(trailing);
    units_.clear();
    // Keep the engine's word in step with ours: nothing is being composed now.
    // (The space branch of vKeyHandleEvent leaves the finished word in place for
    // its own backspace-into-the-word feature; here that word is committed.)
    startNewSession();
    out.preeditChanged = true;
    out.preedit.clear();
    return out;
}

// A key that ends the word: space, punctuation, Enter, an arrow, a shortcut...
// `literal` is the character the key types (0 for a control key). With a word
// open, the word — corrected by the engine's break-time rules — and the literal
// are committed together and the key is consumed; a control key is let through
// after the commit. With no word open the key is the app's to handle.
Output Composer::endWord(uint16_t code, uint8_t caps, bool otherControlKey,
                         char32_t literal, bool letKeyThrough) {
    const bool hadWord = !units_.empty();
    vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, code, caps, otherControlKey);

    Output out;
    if (!hadWord) {
        // Nothing of ours is on screen, so there is nothing a break-time restore
        // could correct. Keep the engine's word empty to match.
        if (hook()->code != vDoNothing)
            startNewSession();
        out.consumed = false;
        return out;
    }

    bool literalPlaced = false;
    if (hook()->code != vDoNothing && engineAgrees())
        literalPlaced = applyEngineEdit(letKeyThrough ? 0 : literal);
    out.consumed = !letKeyThrough;
    return commitAll(out, (letKeyThrough || literalPlaced) ? 0 : literal);
}

// A key that belongs to the word: a letter, a digit inside a word, a Telex
// bracket. It always lands in the preedit.
Output Composer::wordKey(uint16_t code, uint8_t caps, char32_t literal) {
    vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, code, caps, false);
    if (hook()->code != vDoNothing && !engineAgrees()) {
        // Start the engine over on this key, as the first letter of a new word.
        resetEngine();
        vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, code, caps, false);
    }
    if (hook()->code == vDoNothing)
        units_.push_back(std::u32string(1, literal));
    else
        applyEngineEdit(literal);

    Output out;
    out.consumed = true;
    out.preeditChanged = true;
    out.preedit = preeditText();
    return out;
}

Output Composer::backspace() {
    Output out;
    if (units_.empty()) {
        // Deleting text the app holds: let the app do it, and make sure the
        // engine does not take it as a cue to reopen the previous word.
        resetEngine();
        out.consumed = false;
        return out;
    }

    vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, KEY_DELETE, 0, false);
    if (hook()->code == vDoNothing) {
        units_.pop_back();      // the macOS host lets the OS delete one character here
    } else if (engineAgrees()) {
        applyEngineEdit(0);     // a re-placed tone: backspaceCount covers the deleted character
    } else {
        resetEngine();
        units_.pop_back();
    }

    out.consumed = true;
    out.preeditChanged = true;
    out.preedit = preeditText();
    return out;
}

Output Composer::flush() {
    if (units_.empty()) {
        resetEngine();
        return Output();
    }
    return endWord(KEY_EMPTY, 0, true, 0, true);
}

Output Composer::processKey(const KeyEvent& ev) {
    if (bypass_ || !vLanguage || keysym::isModifier(ev.keyval))
        return Output();

    // A shortcut ends the word, as Cmd/Ctrl/Option combos do on macOS (the
    // engine's otherControlKey), and is always the app's.
    if (ev.state & modmask::Shortcut)
        return endWord(KEY_EMPTY, 0, true, 0, true);

    switch (ev.keyval) {
        case keysym::BackSpace:
            return backspace();
        case keysym::Return:
        case keysym::KP_Enter:
            return endWord(KEY_ENTER, 0, false, 0, true);
        case keysym::Tab:
        case keysym::ISO_Left_Tab:
            return endWord(KEY_TAB, 0, false, 0, true);
        case keysym::Escape:
            return endWord(KEY_ESC, 0, false, 0, true);
        case keysym::Left:
            return endWord(KEY_LEFT, 0, false, 0, true);
        case keysym::Right:
            return endWord(KEY_RIGHT, 0, false, 0, true);
        case keysym::Up:
            return endWord(KEY_UP, 0, false, 0, true);
        case keysym::Down:
            return endWord(KEY_DOWN, 0, false, 0, true);
    }

    // Keypad keys are a break on macOS too (kCGEventFlagMaskNumericPad); the rest
    // here type nothing (Home, F-keys, dead keys...). Delete has a character as
    // far as IBus is concerned (U+007F), like every C0/C1 control.
    const char32_t ch = ev.unicode;
    if (keysym::isKeypad(ev.keyval) || ch < 0x20 || (ch >= 0x7F && ch < 0xA0))
        return endWord(KEY_EMPTY, 0, true, 0, true);

    Uint16 code = 0;
    Uint8 caps = 0;
    if (!asciiKey(ch, code, caps)) {
        // A character the engine has no key for (é, ß, € from the layout): it
        // ends the word and is typed as it is.
        return endWord(KEY_EMPTY, 0, true, ch, false);
    }

    // The word-break condition at the top of vKeyHandleEvent, plus space (which
    // the engine handles in its own branch but which ends the word all the same).
    const bool breaks = code == KEY_SPACE ||
                        isWordBreak(vKeyEvent::Keyboard, vKeyEventState::KeyDown, code) ||
                        (IS_NUMBER_KEY(code) && caps == 1) ||
                        (units_.empty() && IS_NUMBER_KEY(code));
    if (breaks)
        return endWord(code, caps, false, ch, false);
    return wordKey(code, caps, ch);
}

} // namespace key84
