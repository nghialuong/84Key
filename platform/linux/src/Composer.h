//
//  Composer.h
//  84Key — the Linux host's typing pipeline.
//
//  The macOS host (platform/macos/Input/InputController.mm) lets each key reach
//  the app and then corrects the text with synthetic backspaces and retyped
//  characters. That burst is what goes wrong in async apps: a backspace lands
//  after the insert and a letter is doubled. IBus offers a way around it, so the
//  Linux host never edits text the app already holds:
//
//    * the word being typed lives in the IBus preedit (composition), so every
//      engine correction — a tone moving, ươ forming, an English word restored —
//      replaces our own buffer, never the app's text;
//    * at the word break the finished word is committed in a single call,
//      together with the break character when there is one;
//    * keys the word does not need (shortcuts, navigation, anything typed while
//      no word is open) go to the app untouched.
//
//  Composer holds the engine host contract (vKeyHandleEvent + vKeyHookState) and
//  is deliberately free of IBus, so the same code is driven by the IBus engine
//  and by platform/linux/tests/host_test.cpp.
//

#ifndef KEY84_COMPOSER_H
#define KEY84_COMPOSER_H

#include <cstdint>
#include <string>
#include <vector>

namespace key84 {

struct KeyEvent {
    uint32_t keyval = 0;    // X11 keysym
    uint32_t unicode = 0;   // character the key types, 0 if none (ibus_keyval_to_unicode)
    uint32_t state = 0;     // X11/IBus modifier mask, see Keysyms.h
};

struct Output {
    // True when the key was handled here and the app must not see it. False
    // hands the key to the app after `commit` has been applied.
    bool consumed = false;
    // Text to commit, in front of whatever the preedit becomes.
    std::u32string commit;
    // The preedit after this key (empty = none). Only meaningful when
    // preeditChanged is set.
    bool preeditChanged = false;
    std::u32string preedit;
};

class Composer {
public:
    Composer();

    // Handle a key press. Releases never reach here.
    Output processKey(const KeyEvent& ev);

    // End the current word as a word break would (so an English word typed in
    // Telex is restored first) and commit it. Used before switching VI/EN.
    Output flush();

    // The input context changed under us: focus moved, the user clicked, or the
    // app reset the context. IBus commits the visible preedit itself (the engine
    // shows it in IBUS_ENGINE_PREEDIT_COMMIT mode), so committing here as well
    // would type the word twice — this only forgets it.
    void reset();

    // Pass every key straight through, e.g. in a password field.
    void setBypass(bool bypass) { bypass_ = bypass; }
    bool bypassed() const { return bypass_; }

    bool hasPreedit() const { return !units_.empty(); }
    std::u32string preeditText() const;

    // How many times the engine asked to rewrite more than the word holds (see
    // engineAgrees()). Logged by the IBus layer; tests use it to tell an engine
    // overreach apart from a host bug.
    unsigned overreaches() const { return overreaches_; }

private:
    // One entry per character the engine believes is on screen. A character is
    // one code point in Unicode and up to two in the double-byte code tables
    // (VNI Windows, Unicode Compound), so a single engine backspace removes a
    // whole unit — the bookkeeping the macOS host does with gSyncKey.
    std::vector<std::u32string> units_;
    bool bypass_ = false;
    unsigned overreaches_ = 0;

    Output backspace();
    Output wordKey(uint16_t code, uint8_t caps, char32_t literal);
    Output endWord(uint16_t code, uint8_t caps, bool otherControlKey,
                   char32_t literal, bool letKeyThrough);
    bool engineAgrees();
    bool applyEngineEdit(char32_t literal);
    void resetEngine();
    Output commitAll(Output out, char32_t trailing);
};

} // namespace key84

#endif // KEY84_COMPOSER_H
