//
//  EngineGlobals.cpp
//  Definitions for the engine option globals declared `extern` in Engine.h.
//  The host application owns these; the settings layer (T10) updates them at
//  runtime. Defaults here mirror 84Key's intended out-of-the-box configuration.
//

// 0: English, 1: Vietnamese
int vLanguage = 1;
// 0: Telex, 1: VNI, 2: Simple Telex 1, 3: Simple Telex 2
int vInputType = 0;
int vFreeMark = 0;
// 0: Unicode, 1: TCVN3, 2: VNI-Windows, 3: Unicode Compound, 4: CP1258
int vCodeTable = 0;
int vSwitchKeyStatus = 0;
int vCheckSpelling = 1;
int vUseModernOrthography = 1;
int vQuickTelex = 0;
int vRestoreIfWrongSpelling = 0;
// Off by default: this injects an invisible "empty char" + extra backspace on
// every transform to defeat browser autocomplete, which can leave stray
// characters in ordinary text fields. Opt-in via Settings if needed.
int vFixRecommendBrowser = 0;
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
// Off by default: when ON, 84Key disables itself whenever the macOS keyboard
// input source isn't reported as English — which silently breaks typing for
// users who keep a Vietnamese (or other) macOS layout. Opt-in via Settings.
int vOtherLanguage = 0;
int vTempOffOpenKey = 0;
// Flagship: automatic English detection defaults ON (see PROGRESS / SPEC).
int vAutoDetectEnglish = 1;

// ---------------------------------------------------------------------------
// macOS-local options (NOT declared in core/engine/Engine.h). These mirror the
// extra knobs OpenKey defines in its app layer and are referenced by the ported
// input core in InputController.mm. They are owned by the host app; the settings
// layer (T10) may update them at runtime.
// ---------------------------------------------------------------------------

// Send each character as its own CGEvent instead of one batched unicode string.
int vSendKeyStepByStep = 0;
// Fix Chromium-family browsers' address-bar autocomplete (shift+left instead of
// an extra empty char). Off by default.
int vFixChromiumBrowser = 0;
// Map the pressed key through the active keyboard layout before handing it to
// the engine (helps non-QWERTY layouts). Off by default.
int vPerformLayoutCompat = 0;
// Spotlight (and similar async fields) drop injected backspaces; the AX
// atomic-replace path is implemented in T14. Defined here so the ported code
// compiles; the AX behavior itself is intentionally not implemented yet.
int vFixSpotlight = 1;
// Web browsers (the omnibox and in-page editors like Google Docs) are async and
// mishandle a plain backspace+insert fired in one burst, corrupting transforms
// such as the doubled-tone restore "garr" -> "gar" (seen as "gảar"). When on,
// browser corrections use the OpenKey-style empty-char prefix (U+202F) + paced
// backspaces. On by default; escape hatch if a future web app regresses.
int vFixWebContentEditor = 1;
