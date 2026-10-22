//
//  SwitchKey.cpp
//  84Key — the VI/EN switch hotkey on Linux. See SwitchKey.h.
//

#include "SwitchKey.h"
#include "Keysyms.h"

#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <vector>

namespace key84 {

namespace {

constexpr uint32_t kCanonical = modmask::Shift | modmask::Control | modmask::Mod1 | modmask::Mod4;

// Fold the IBus/X11 state into the four modifiers a hotkey can name. Alt and
// Super each arrive under more than one bit depending on the session.
uint32_t canonicalMods(uint32_t state) {
    uint32_t mods = state & kCanonical;
    if (state & modmask::Meta)  mods |= modmask::Mod1;
    if (state & modmask::Super) mods |= modmask::Mod4;
    if (state & modmask::Hyper) mods |= modmask::Mod4;
    return mods;
}

uint32_t modifierOfKey(uint32_t keyval) {
    switch (keyval) {
        case keysym::Shift_L: case keysym::Shift_R:     return modmask::Shift;
        case keysym::Control_L: case keysym::Control_R: return modmask::Control;
        case keysym::Alt_L: case keysym::Alt_R:
        case keysym::Meta_L: case keysym::Meta_R:       return modmask::Mod1;
        case keysym::Super_L: case keysym::Super_R:
        case keysym::Hyper_L: case keysym::Hyper_R:     return modmask::Mod4;
        default:                                        return 0;
    }
}

uint32_t lowerKeyval(uint32_t keyval) {
    return (keyval >= 'A' && keyval <= 'Z') ? keyval + ('a' - 'A') : keyval;
}

std::string lower(std::string s) {
    for (char& c : s) c = (char)std::tolower((unsigned char)c);
    return s;
}

// The names most hotkeys use, so parsing works without IBus (and in tests).
uint32_t builtinKeyval(const std::string& name) {
    if (name.size() == 1 && std::isprint((unsigned char)name[0]))
        return lowerKeyval((unsigned char)name[0]);
    const std::string n = lower(name);
    if (n == "space") return keysym::space;
    if (n == "tab") return keysym::Tab;
    if (n == "grave" || n == "backquote") return '`';
    if (n.size() >= 2 && n[0] == 'f' && std::isdigit((unsigned char)n[1])) {
        int f = std::atoi(n.c_str() + 1);
        if (f >= 1 && f <= 12) return 0xffbe + (uint32_t)(f - 1);   // F1..F12
    }
    return 0;
}

std::string builtinName(uint32_t keyval) {
    if (keyval == keysym::space) return "space";
    if (keyval == keysym::Tab) return "Tab";
    if (keyval >= 0xffbe && keyval <= 0xffc9) return "F" + std::to_string(keyval - 0xffbe + 1);
    if (keyval > 0x20 && keyval < 0x7f) return std::string(1, (char)keyval);
    char buf[16];
    std::snprintf(buf, sizeof buf, "0x%x", keyval);
    return buf;
}

} // namespace

SwitchKey SwitchKey::parse(const std::string& text, const NameResolver& resolve) {
    SwitchKey key;
    // "+" separates the parts, so the plus key itself is written by name ("plus").
    std::vector<std::string> parts;
    std::string part;
    for (char c : text + "+") {
        if (c == '+') {
            if (!part.empty()) parts.push_back(part);
            part.clear();
        } else if (!std::isspace((unsigned char)c)) {
            part.push_back(c);
        }
    }
    for (size_t i = 0; i < parts.size(); i++) {
        const std::string n = lower(parts[i]);
        if (n == "control" || n == "ctrl" || n == "primary") key.modifiers |= modmask::Control;
        else if (n == "shift") key.modifiers |= modmask::Shift;
        else if (n == "alt" || n == "meta") key.modifiers |= modmask::Mod1;
        else if (n == "super" || n == "win" || n == "hyper") key.modifiers |= modmask::Mod4;
        else if (i + 1 == parts.size() && key.keyval == 0) {
            uint32_t kv = builtinKeyval(parts[i]);
            if (!kv && resolve) kv = lowerKeyval(resolve(parts[i]));
            if (!kv) return SwitchKey();
            key.keyval = kv;
        } else {
            return SwitchKey();
        }
    }
    const bool typesCharacter = key.keyval >= 0x20 && key.keyval < 0x7f;
    if (key.keyval && (key.modifiers & ~modmask::Shift) == 0 && (typesCharacter || !key.modifiers))
        return SwitchKey();
    return key;
}

std::string SwitchKey::toString(const NameWriter& name) const {
    std::string s;
    auto add = [&](const char* part) { if (!s.empty()) s += "+"; s += part; };
    if (modifiers & modmask::Control) add("Control");
    if (modifiers & modmask::Shift)   add("Shift");
    if (modifiers & modmask::Mod1)    add("Alt");
    if (modifiers & modmask::Mod4)    add("Super");
    if (keyval) {
        std::string k = name ? name(keyval) : std::string();
        if (k.empty()) k = builtinName(keyval);
        add(k.c_str());
    }
    return s;
}

SwitchKeyMatcher::Result SwitchKeyMatcher::feed(uint32_t keyval, uint32_t state, bool release) {
    if (key_.empty())
        return None;

    const uint32_t ownMod = modifierOfKey(keyval);
    if (key_.keyval == 0) {
        if (!ownMod) {
            // Another key pressed in between: it was a shortcut. Only a press
            // counts — the release of the letter typed just before the combo
            // often arrives while it is held.
            if (!release && !keysym::isModifier(keyval))
                armed_ = false;
            return None;
        }
        // The state IBus reports may or may not include this key's own change
        // yet (X11 reports the state before the event); work out the state after.
        uint32_t after = canonicalMods(state);
        after = release ? (after & ~ownMod) : (after | ownMod);
        if (!release) {
            armed_ = (after == key_.modifiers);
            return None;
        }
        if (armed_) {
            armed_ = false;
            if ((after & key_.modifiers) != key_.modifiers && (after & ~key_.modifiers) == 0)
                return TogglePassThrough;
        }
        return None;
    }

    if (release || ownMod)
        return None;
    if (lowerKeyval(keyval) == key_.keyval && canonicalMods(state) == key_.modifiers)
        return Toggle;
    return None;
}

} // namespace key84
