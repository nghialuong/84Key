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
int vFixRecommendBrowser = 1;
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
int vOtherLanguage = 1;
int vTempOffOpenKey = 0;
// Flagship: automatic English detection defaults ON (see PROGRESS / SPEC).
int vAutoDetectEnglish = 1;
