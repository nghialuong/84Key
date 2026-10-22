//
//  Keysyms.h
//  84Key — the X11 keysym and modifier values the Linux host needs.
//
//  IBus hands the engine X11 keysyms and an X11 modifier mask (plus a few IBus
//  bits above them). These are protocol constants, spelled out here so the
//  typing pipeline (Composer, SwitchKey) builds and tests without IBus headers;
//  the IBus layer passes the values through untouched.
//

#ifndef KEY84_KEYSYMS_H
#define KEY84_KEYSYMS_H

#include <cstdint>

namespace key84 {
namespace keysym {

constexpr uint32_t BackSpace   = 0xff08;
constexpr uint32_t Tab         = 0xff09;
constexpr uint32_t Return      = 0xff0d;
constexpr uint32_t Escape      = 0xff1b;
constexpr uint32_t Delete      = 0xffff;
constexpr uint32_t Home        = 0xff50;
constexpr uint32_t Left        = 0xff51;
constexpr uint32_t Up          = 0xff52;
constexpr uint32_t Right       = 0xff53;
constexpr uint32_t Down        = 0xff54;
constexpr uint32_t ISO_Left_Tab = 0xfe20;
constexpr uint32_t KP_Space    = 0xff80;   // first keypad keysym
constexpr uint32_t KP_Enter    = 0xff8d;
constexpr uint32_t KP_Equal    = 0xffbd;   // last keypad keysym
constexpr uint32_t space       = 0x0020;

// Modifier keys: pressing one alone must never end a word.
constexpr uint32_t Shift_L     = 0xffe1;
constexpr uint32_t Shift_R     = 0xffe2;
constexpr uint32_t Control_L   = 0xffe3;
constexpr uint32_t Control_R   = 0xffe4;
constexpr uint32_t Caps_Lock   = 0xffe5;
constexpr uint32_t Shift_Lock  = 0xffe6;
constexpr uint32_t Meta_L      = 0xffe7;
constexpr uint32_t Meta_R      = 0xffe8;
constexpr uint32_t Alt_L       = 0xffe9;
constexpr uint32_t Alt_R       = 0xffea;
constexpr uint32_t Super_L     = 0xffeb;
constexpr uint32_t Super_R     = 0xffec;
constexpr uint32_t Hyper_L     = 0xffed;
constexpr uint32_t Hyper_R     = 0xffee;
constexpr uint32_t Num_Lock    = 0xff7f;
constexpr uint32_t Scroll_Lock = 0xff14;
constexpr uint32_t Mode_switch = 0xff7e;
constexpr uint32_t ISO_Level3_Shift = 0xfe03;
// ISO_Lock .. ISO_Level5_Lock: level and group shifts, latches and locks.
constexpr uint32_t ISO_First_Modifier = 0xfe01;
constexpr uint32_t ISO_Last_Modifier  = 0xfe13;

inline bool isModifier(uint32_t k) {
    return (k >= Shift_L && k <= Hyper_R) || k == Num_Lock || k == Scroll_Lock ||
           k == Mode_switch || (k >= ISO_First_Modifier && k <= ISO_Last_Modifier);
}

inline bool isKeypad(uint32_t k) {
    return k >= KP_Space && k <= KP_Equal;
}

} // namespace keysym

namespace modmask {

constexpr uint32_t Shift   = 1u << 0;
constexpr uint32_t Lock    = 1u << 1;   // Caps Lock
constexpr uint32_t Control = 1u << 2;
constexpr uint32_t Mod1    = 1u << 3;   // Alt
constexpr uint32_t Mod4    = 1u << 6;   // Super
constexpr uint32_t Super   = 1u << 26;  // IBUS_SUPER_MASK
constexpr uint32_t Hyper   = 1u << 27;  // IBUS_HYPER_MASK
constexpr uint32_t Meta    = 1u << 28;  // IBUS_META_MASK
constexpr uint32_t Release = 1u << 30;  // IBUS_RELEASE_MASK

// Modifiers that turn a key into a shortcut. AltGr (Mod5) is deliberately not
// here: on many layouts it is how ordinary characters are typed.
constexpr uint32_t Shortcut = Control | Mod1 | Mod4 | Super | Hyper | Meta;

} // namespace modmask
} // namespace key84

#endif // KEY84_KEYSYMS_H
