//
//  EngineGlobals.cpp
//  Definitions for the engine option globals declared `extern` in Engine.h.
//  The Linux host owns these; Settings.cpp loads the user's values over these
//  defaults at startup and whenever the settings file changes. The defaults
//  mirror the macOS app (platform/macos/App/AppSettings.swift) so both
//  platforms behave the same out of the box.
//

// 0: English, 1: Vietnamese
int vLanguage = 1;
// 0: Telex, 1: VNI, 2: Simple Telex 1, 3: Simple Telex 2
int vInputType = 0;
int vFreeMark = 0;
// 0: Unicode, 1: TCVN3, 2: VNI-Windows, 3: Unicode Compound, 4: CP1258
int vCodeTable = 0;
// Unused on Linux: the VI/EN hotkey is matched by SwitchKey.cpp from the
// SwitchKey setting, which can name keys this bitmask cannot.
int vSwitchKeyStatus = 0;
int vCheckSpelling = 1;
int vUseModernOrthography = 1;
int vQuickTelex = 0;
int vRestoreIfWrongSpelling = 0;
// The browser autocomplete workaround is part of the macOS send layer; the Linux
// host never sends synthetic backspaces, so it has nothing to fix.
int vFixRecommendBrowser = 0;
// No macro editor exists on either platform yet, so there are no macros to expand.
int vUseMacro = 0;
int vUseMacroInEnglishMode = 0;
int vAutoCapsMacro = 0;
int vUseSmartSwitchKey = 1;
int vUpperCaseFirstChar = 0;
int vTempOffSpelling = 0;
int vAllowConsonantZFWJ = 0;
int vQuickStartConsonant = 0;
int vQuickEndConsonant = 0;
int vRememberCode = 0;
// The macOS host reads the active keyboard layout for this. On Linux the
// keyboard layout decides the keysyms the engine is fed: a non-Latin layout
// produces no letters the engine knows, so those keys already pass through.
int vOtherLanguage = 0;
int vTempOffOpenKey = 0;
// Flagship: automatic English detection defaults ON, as on macOS.
int vAutoDetectEnglish = 1;
