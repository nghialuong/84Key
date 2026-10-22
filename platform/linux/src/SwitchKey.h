//
//  SwitchKey.h
//  84Key — the VI/EN switch hotkey on Linux.
//
//  Written in settings as modifiers and an optional key joined by "+":
//  "Control+Shift" (modifiers alone), "Control+Super+space", "Alt+z". A
//  modifier-only combo fires when it is released without any other key pressed
//  in between, so it never fires as part of a shortcut such as Ctrl+Shift+T —
//  the rule the macOS host applies to its modifier-only hotkeys.
//
//  Pure C++ like Composer: key names are resolved through a function the caller
//  may supply (the IBus layer passes ibus_keyval_from_name), with a built-in
//  table for the common names.
//

#ifndef KEY84_SWITCHKEY_H
#define KEY84_SWITCHKEY_H

#include <cstdint>
#include <functional>
#include <string>

namespace key84 {

struct SwitchKey {
    // Canonical modifier bits (modmask::Shift | Control | Mod1 | Mod4).
    uint32_t modifiers = 0;
    // The key to press with them; 0 for a modifier-only combo.
    uint32_t keyval = 0;

    bool empty() const { return modifiers == 0 && keyval == 0; }
    bool operator==(const SwitchKey& o) const { return modifiers == o.modifiers && keyval == o.keyval; }

    using NameResolver = std::function<uint32_t(const std::string&)>;
    using NameWriter = std::function<std::string(uint32_t)>;

    // An unknown name or an empty string gives an empty SwitchKey (no hotkey).
    // So does a character key with no modifier, or with Shift alone: the hotkey
    // would swallow every "a" (or "A") typed.
    static SwitchKey parse(const std::string& text, const NameResolver& resolve = nullptr);
    std::string toString(const NameWriter& name = nullptr) const;
};

class SwitchKeyMatcher {
public:
    enum Result {
        None,
        Toggle,          // switch, and swallow this event (the press of a keyed combo)
        TogglePassThrough // switch, and let this event through (a modifier released)
    };

    void set(const SwitchKey& key) { key_ = key; armed_ = false; }
    const SwitchKey& key() const { return key_; }

    // Something other than a key happened (a click, a focus change): a
    // modifier-only combo held across it was not meant as a switch.
    void cancel() { armed_ = false; }

    // Feed every key event, presses and releases, before anything else sees it.
    Result feed(uint32_t keyval, uint32_t state, bool release);

private:
    SwitchKey key_;
    bool armed_ = false;
};

} // namespace key84

#endif // KEY84_SWITCHKEY_H
