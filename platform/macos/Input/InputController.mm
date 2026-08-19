//
//  InputController.mm
//  84Key — macOS input core (CGEvent tap + key send).
//
//  This file ports the input core of the OpenKey project
//  (tuyenvm/OpenKey, GPLv3): the CGEvent tap setup, the synthetic key/
//  backspace senders, and the keyDown handler that turns the engine's
//  vKeyHookState into backspaces + character events. Reused logic keeps its
//  original structure and attribution.
//
//  Original source: Sources/OpenKey/macOS/ModernKey/OpenKey.mm
//      Created by Tuyen on 1/18/19. Copyright (c) 2019 Tuyen Mai.
//
//  84Key changes:
//   - Wrapped the tap lifecycle in the Obj-C `InputController` class so Swift
//     can start/stop it through a pure Obj-C header.
//   - Added the Spotlight / system-search Accessibility atomic-replace path
//     (isAXReplaceTargetFocused / replaceFocusedTextViaAX) so async search
//     fields that drop injected backspaces type correctly; ordinary apps still
//     use the normal CGEvent backspace+insert path.
//   - Smart-switch-key, convert-tool, hotkey switching, and macro/Userdefaults
//     loading are out of scope for this task and are not ported.
//

#import "InputController.h"

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>

#include <mach/mach_time.h>

#include "Engine.h"

// Engine option globals (defined in EngineGlobals.cpp).
extern int vLanguage;
extern int vCodeTable;
extern int vFixRecommendBrowser;
extern int vUseMacro;
extern int vUseMacroInEnglishMode;
extern int vOtherLanguage;

// macOS-local options (defined in EngineGlobals.cpp).
extern int vSendKeyStepByStep;
extern int vFixChromiumBrowser;
extern int vPerformLayoutCompat;
extern int vFixSpotlight;
extern int vFixWebContentEditor;

// Notification posted (on the main queue) when the VI/EN switch hotkey toggles the
// language, so the SwiftUI layer can mirror the change in the menu bar / Settings.
NSString * const Key84LanguageDidToggleNotification = @"Key84LanguageDidToggle";

// When YES, the global tap ignores the switch hotkey. The Settings recorder sets
// this while capturing a new combo so the in-progress keypress doesn't also toggle
// the language (the session tap sees the key before the app's NSEvent monitor).
static bool gSwitchKeyCaptureActive = false;

// Engine helpers (declared in Vietnamese.h / Engine.h).
extern Uint16 keyCodeToCharacter(const Uint32& keyCode);
extern Uint16 _unicodeCompoundMark[];

#define MAX_UNICODE_STRING  20

#define OTHER_CONTROL_KEY (gFlag & kCGEventFlagMaskCommand) || (gFlag & kCGEventFlagMaskControl) || \
                            (gFlag & kCGEventFlagMaskAlternate) || (gFlag & kCGEventFlagMaskSecondaryFn) || \
                            (gFlag & kCGEventFlagMaskNumericPad) || (gFlag & kCGEventFlagMaskHelp)

#define DYNA_DATA(macro, pos) (macro ? pData->macroData[pos] : pData->charData[pos])

// ---------------------------------------------------------------------------
// File-scope state shared between the C callback and its helpers. (Mirrors the
// `extern "C"` block in OpenKey.mm; kept at file scope so the tap callback,
// which must be a plain C function, can reach it.)
// ---------------------------------------------------------------------------
namespace {

// apps which must be sent a special empty character
NSArray* gNiceSpaceApp = @[@"com.sublimetext.3", @"com.sublimetext.2"];

// apps which error with unicode Compound / browser autocomplete
NSArray* gUnicodeCompoundApp = @[@"com.apple.",
                                 @"com.google.Chrome", @"com.brave.Browser",
                                 @"com.microsoft.edgemac.Dev", @"com.microsoft.edgemac.Beta",
                                 @"com.microsoft.Edge.Dev", @"com.microsoft.Edge"];

CGEventSourceRef gEventSource = NULL;
vKeyHookState* pData = NULL;

UniChar gNewChar, gNewCharHi;
CGEventRef gNewEventDown, gNewEventUp;
CGKeyCode gKeycode;
CGEventFlags gFlag;
CGEventTapProxy gProxy;

Uint16 gNewCharString[MAX_UNICODE_STRING];
Uint16 gNewCharSize;
bool gWillContinueSending = false;
bool gWillSendControlKey = false;

std::vector<Uint16> gSyncKey;

Uint16 gUniChar[2];
int gI, gK;
Uint32 gTempChar;
int gJfront = 0;

// Event tap lifecycle objects (owned by the InputController instance).
CFMachPortRef gEventTap = NULL;
CFRunLoopSourceRef gRunLoopSource = NULL;

// Spotlight fix: apps whose async text field loses an injected backspace, so we
// replace text atomically via the Accessibility API instead of backspace+insert.
// (Ported from OpenKey.mm, ModernKey: _axReplaceApp / _axSystemWide.)
//
// The owning process differs by macOS version: classic Spotlight is
// "com.apple.Spotlight"; the rewritten Spotlight in macOS 26/27 (Tahoe) hosts
// the field in "com.apple.campo". This list is just a fast-path allowlist —
// isAXReplaceTargetFocused() also detects any system search field by behavior,
// so a future rename still works without a code change.
NSArray* gAxReplaceApp = @[@"com.apple.Spotlight", @"com.apple.campo"];
AXUIElementRef gAxSystemWide = NULL;
bool gAxFocusIsTarget = false;     // cached: is the focused element owned by an gAxReplaceApp?
double gAxFocusCheckedAt = 0;      // cache timestamp (seconds)

#define FRONT_APP ([[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier)

BOOL containUnicodeCompoundApp(NSString* topApp) {
    if (topApp == nil) return false;
    for (NSUInteger j = 0; j < [gUnicodeCompoundApp count]; j++) {
        if ([topApp hasPrefix:[gUnicodeCompoundApp objectAtIndex:j]] ||
            [[gUnicodeCompoundApp objectAtIndex:j] isEqualToString:topApp])
            return true;
    }
    return false;
}

// Web browsers whose pages (Google Docs, contenteditable) and address bars
// mishandle a plain backspace+insert fired in one burst: the async web layer
// applies the insert before the deletion, so the doubled-tone restore
// "garr"->"gar" surfaces as "gảar". For these we use the OpenKey-style empty-char
// prefix + paced backspaces. Prefix match so
// release channels (Chrome Canary, Edge Beta, Arc, ...) are covered. Safari is
// omitted on purpose — its content areas need char-by-char, handled elsewhere.
NSArray* gBrowserApp = @[@"com.google.Chrome", @"org.chromium.Chromium",
                         @"com.brave.Browser", @"com.microsoft.Edge", @"com.microsoft.edgemac",
                         @"com.vivaldi.Vivaldi", @"com.operasoftware.Opera", @"com.opera.Opera",
                         @"company.thebrowser.Browser", @"company.thebrowser.Arc",
                         @"company.thebrowser.dia", @"org.mozilla.firefox",
                         @"ai.perplexity.comet", @"com.openai.atlas",
                         @"com.duckduckgo.macos.browser", @"ru.yandex.desktop.yandex-browser"];

BOOL isBrowserApp(NSString* topApp) {
    if (topApp == nil) return false;
    for (NSString* b in gBrowserApp)
        if ([topApp hasPrefix:b]) return true;
    return false;
}

// The one place a synthetic event leaves this file.
//
// Two properties every posted event needs, and which were previously set at
// some call sites and not others:
//   * kCGEventFlagMaskNonCoalesced — a transform posts a burst (empty char, N
//     backspaces, then the replacement) and the window server must not merge
//     any two of them; a merged delete leaves the old character behind.
//   * a fresh timestamp — CGEventCreate* stamps the event when it is created,
//     and events that are reposted (or built once and cached) carry a stale
//     time. A burst of identically-stamped key events is what a receiving app
//     reads as key repeat, and repeat is exactly what it is allowed to drop.
//     This is only visible when the app is busy enough to take several of them
//     in one run-loop pass, i.e. when typing fast.
void PostSynthetic(CGEventRef e) {
    CGEventSetFlags(e, CGEventGetFlags(e) | kCGEventFlagMaskNonCoalesced);
    CGEventSetTimestamp(e, mach_absolute_time());
    CGEventTapPostEvent(gProxy, e);
}

void InsertKeyLength(const Uint8& len) {
    gSyncKey.push_back(len);
}

void SendPureCharacter(const Uint16& ch) {
    gNewEventDown = CGEventCreateKeyboardEvent(gEventSource, 0, true);
    gNewEventUp = CGEventCreateKeyboardEvent(gEventSource, 0, false);
    CGEventKeyboardSetUnicodeString(gNewEventDown, 1, &ch);
    CGEventKeyboardSetUnicodeString(gNewEventUp, 1, &ch);
    PostSynthetic(gNewEventDown);
    PostSynthetic(gNewEventUp);
    CFRelease(gNewEventDown);
    CFRelease(gNewEventUp);
    if (IS_DOUBLE_CODE(vCodeTable)) {
        InsertKeyLength(1);
    }
}

void SendKeyCode(Uint32 data) {
    gNewChar = (Uint16)data;
    if (!(data & CHAR_CODE_MASK)) {
        if (IS_DOUBLE_CODE(vCodeTable)) // VNI
            InsertKeyLength(1);

        gNewEventDown = CGEventCreateKeyboardEvent(gEventSource, gNewChar, true);
        gNewEventUp = CGEventCreateKeyboardEvent(gEventSource, gNewChar, false);
        CGEventFlags privateFlag = CGEventGetFlags(gNewEventDown);

        if (data & CAPS_MASK) {
            privateFlag |= kCGEventFlagMaskShift;
        } else {
            privateFlag &= ~kCGEventFlagMaskShift;
        }
        CGEventSetFlags(gNewEventDown, privateFlag);
        CGEventSetFlags(gNewEventUp, privateFlag);
        PostSynthetic(gNewEventDown);
        PostSynthetic(gNewEventUp);
    } else {
        if (vCodeTable == 0) { // unicode 2 bytes code
            gNewEventDown = CGEventCreateKeyboardEvent(gEventSource, 0, true);
            gNewEventUp = CGEventCreateKeyboardEvent(gEventSource, 0, false);
            CGEventKeyboardSetUnicodeString(gNewEventDown, 1, &gNewChar);
            CGEventKeyboardSetUnicodeString(gNewEventUp, 1, &gNewChar);
            PostSynthetic(gNewEventDown);
            PostSynthetic(gNewEventUp);
        } else if (vCodeTable == 1 || vCodeTable == 2 || vCodeTable == 4) { // VNI Windows, TCVN3, CP1258: 1 byte code
            gNewCharHi = HIBYTE(gNewChar);
            gNewChar = LOBYTE(gNewChar);

            gNewEventDown = CGEventCreateKeyboardEvent(gEventSource, 0, true);
            gNewEventUp = CGEventCreateKeyboardEvent(gEventSource, 0, false);
            CGEventKeyboardSetUnicodeString(gNewEventDown, 1, &gNewChar);
            CGEventKeyboardSetUnicodeString(gNewEventUp, 1, &gNewChar);
            PostSynthetic(gNewEventDown);
            PostSynthetic(gNewEventUp);
            if (gNewCharHi > 32) {
                if (vCodeTable == 2) // VNI
                    InsertKeyLength(2);
                CFRelease(gNewEventDown);
                CFRelease(gNewEventUp);
                gNewEventDown = CGEventCreateKeyboardEvent(gEventSource, 0, true);
                gNewEventUp = CGEventCreateKeyboardEvent(gEventSource, 0, false);
                CGEventKeyboardSetUnicodeString(gNewEventDown, 1, &gNewCharHi);
                CGEventKeyboardSetUnicodeString(gNewEventUp, 1, &gNewCharHi);
                PostSynthetic(gNewEventDown);
                PostSynthetic(gNewEventUp);
            } else {
                if (vCodeTable == 2) // VNI
                    InsertKeyLength(1);
            }
        } else if (vCodeTable == 3) { // Unicode Compound
            gNewCharHi = (gNewChar >> 13);
            gNewChar &= 0x1FFF;
            gUniChar[0] = gNewChar;
            gUniChar[1] = gNewCharHi > 0 ? (_unicodeCompoundMark[gNewCharHi - 1]) : 0;
            InsertKeyLength(gNewCharHi > 0 ? 2 : 1);
            gNewEventDown = CGEventCreateKeyboardEvent(gEventSource, 0, true);
            gNewEventUp = CGEventCreateKeyboardEvent(gEventSource, 0, false);
            CGEventKeyboardSetUnicodeString(gNewEventDown, (gNewCharHi > 0 ? 2 : 1), gUniChar);
            CGEventKeyboardSetUnicodeString(gNewEventUp, (gNewCharHi > 0 ? 2 : 1), gUniChar);
            PostSynthetic(gNewEventDown);
            PostSynthetic(gNewEventUp);
        }
    }
    CFRelease(gNewEventDown);
    CFRelease(gNewEventUp);
}

void SendEmptyCharacter() {
    if (IS_DOUBLE_CODE(vCodeTable)) // VNI or Unicode Compound
        InsertKeyLength(1);

    gNewChar = 0x202F; // empty char
    if ([gNiceSpaceApp containsObject:FRONT_APP]) {
        gNewChar = 0x200C; // Unicode character with empty space
    }

    gNewEventDown = CGEventCreateKeyboardEvent(gEventSource, 0, true);
    gNewEventUp = CGEventCreateKeyboardEvent(gEventSource, 0, false);
    CGEventKeyboardSetUnicodeString(gNewEventDown, 1, &gNewChar);
    CGEventKeyboardSetUnicodeString(gNewEventUp, 1, &gNewChar);
    PostSynthetic(gNewEventDown);
    PostSynthetic(gNewEventUp);
    CFRelease(gNewEventDown);
    CFRelease(gNewEventUp);
}

// One backspace, built fresh. A transform sends these in a run, and reposting a
// single cached event object hands the app the same event several times over —
// same identity, same creation time — which is the shape it drops as repeat.
void PostBackspace() {
    CGEventRef down = CGEventCreateKeyboardEvent(gEventSource, KEY_DELETE, true);
    CGEventRef up = CGEventCreateKeyboardEvent(gEventSource, KEY_DELETE, false);
    PostSynthetic(down);
    PostSynthetic(up);
    CFRelease(down);
    CFRelease(up);
}

void SendBackspace() {
    PostBackspace();

    if (IS_DOUBLE_CODE(vCodeTable)) { // VNI or Unicode Compound
        if (gSyncKey.size() > 0 && gSyncKey.back() > 1) {
            if (!(vCodeTable == 3 && containUnicodeCompoundApp(FRONT_APP))) {
                PostBackspace();
            }
        }
        if (gSyncKey.size() > 0)
            gSyncKey.pop_back();
    }
}

void SendShiftAndLeftArrow() {
    CGEventRef eventVkeyDown = CGEventCreateKeyboardEvent(gEventSource, KEY_LEFT, true);
    CGEventRef eventVkeyUp = CGEventCreateKeyboardEvent(gEventSource, KEY_LEFT, false);
    CGEventFlags privateFlag = CGEventGetFlags(eventVkeyDown);
    privateFlag |= kCGEventFlagMaskShift;
    CGEventSetFlags(eventVkeyDown, privateFlag);
    CGEventSetFlags(eventVkeyUp, privateFlag);

    PostSynthetic(eventVkeyDown);
    PostSynthetic(eventVkeyUp);

    if (IS_DOUBLE_CODE(vCodeTable)) { // VNI or Unicode Compound
        if (gSyncKey.size() > 0 && gSyncKey.back() > 1) {
            if (!(vCodeTable == 3 && containUnicodeCompoundApp(FRONT_APP))) {
                PostSynthetic(eventVkeyDown);
                PostSynthetic(eventVkeyUp);
            }
        }
        if (gSyncKey.size() > 0)
            gSyncKey.pop_back();
    }
    CFRelease(eventVkeyDown);
    CFRelease(eventVkeyUp);
}

void SendNewCharString(const bool& dataFromMacro = false, const Uint16& offset = 0) {
    gJfront = 0;
    gNewCharSize = dataFromMacro ? (Uint16)pData->macroData.size() : pData->newCharCount;
    gWillContinueSending = false;
    gWillSendControlKey = false;

    if (gNewCharSize > 0) {
        for (gK = dataFromMacro ? offset : pData->newCharCount - 1 - offset;
             dataFromMacro ? gK < (int)pData->macroData.size() : gK >= 0;
             dataFromMacro ? gK++ : gK--) {

            if (gJfront >= 16) {
                gWillContinueSending = true;
                break;
            }

            gTempChar = DYNA_DATA(dataFromMacro, gK);
            if (gTempChar & PURE_CHARACTER_MASK) {
                gNewCharString[gJfront++] = gTempChar;
                if (IS_DOUBLE_CODE(vCodeTable)) {
                    InsertKeyLength(1);
                }
            } else if (!(gTempChar & CHAR_CODE_MASK)) {
                if (IS_DOUBLE_CODE(vCodeTable)) // VNI
                    InsertKeyLength(1);
                gNewCharString[gJfront++] = keyCodeToCharacter(gTempChar);
            } else {
                if (vCodeTable == 0) { // unicode 2 bytes code
                    gNewCharString[gJfront++] = gTempChar;
                } else if (vCodeTable == 1 || vCodeTable == 2 || vCodeTable == 4) { // VNI Windows, TCVN3, CP1258
                    gNewChar = gTempChar;
                    gNewCharHi = HIBYTE(gNewChar);
                    gNewChar = LOBYTE(gNewChar);
                    gNewCharString[gJfront++] = gNewChar;

                    if (gNewCharHi > 32) {
                        if (vCodeTable == 2) // VNI
                            InsertKeyLength(2);
                        gNewCharString[gJfront++] = gNewCharHi;
                        gNewCharSize++;
                    } else {
                        if (vCodeTable == 2) // VNI
                            InsertKeyLength(1);
                    }
                } else if (vCodeTable == 3) { // Unicode Compound
                    gNewChar = gTempChar;
                    gNewCharHi = (gNewChar >> 13);
                    gNewChar &= 0x1FFF;

                    InsertKeyLength(gNewCharHi > 0 ? 2 : 1);
                    gNewCharString[gJfront++] = gNewChar;
                    if (gNewCharHi > 0) {
                        gNewCharSize++;
                        gNewCharString[gJfront++] = _unicodeCompoundMark[gNewCharHi - 1];
                    }
                }
            }
        } // end for
    }

    if (!gWillContinueSending && (pData->code == vRestore || pData->code == vRestoreAndStartNewSession)) { // if is restore
        if (keyCodeToCharacter(gKeycode) != 0) {
            gNewCharSize++;
            gNewCharString[gJfront++] = keyCodeToCharacter(gKeycode | ((gFlag & kCGEventFlagMaskAlphaShift) || (gFlag & kCGEventFlagMaskShift) ? CAPS_MASK : 0));
        } else {
            gWillSendControlKey = true;
        }
    }
    if (!gWillContinueSending && pData->code == vRestoreAndStartNewSession) {
        startNewSession();
    }

    gNewEventDown = CGEventCreateKeyboardEvent(gEventSource, 0, true);
    gNewEventUp = CGEventCreateKeyboardEvent(gEventSource, 0, false);
    CGEventKeyboardSetUnicodeString(gNewEventDown, gWillContinueSending ? 16 : gNewCharSize - offset, gNewCharString);
    CGEventKeyboardSetUnicodeString(gNewEventUp, gWillContinueSending ? 16 : gNewCharSize - offset, gNewCharString);
    PostSynthetic(gNewEventDown);
    PostSynthetic(gNewEventUp);
    CFRelease(gNewEventDown);
    CFRelease(gNewEventUp);

    if (gWillContinueSending) {
        SendNewCharString(dataFromMacro, dataFromMacro ? gK : 16);
    }

    // hCode is vRestore/vRestoreAndStartNewSession, word invalid, last key is a
    // control key (TAB, LEFT/RIGHT ARROW,...).
    if (gWillSendControlKey) {
        SendKeyCode(gKeycode);
    }
}

void handleMacro() {
    // fix autocomplete
    if (vFixRecommendBrowser) {
        SendEmptyCharacter();
        pData->backspaceCount++;
    }

    // send backspace
    if (pData->backspaceCount > 0) {
        for (int i = 0; i < pData->backspaceCount; i++) {
            SendBackspace();
        }
    }
    // send real data
    if (!vSendKeyStepByStep) {
        SendNewCharString(true);
    } else {
        for (int i = 0; i < (int)pData->macroData.size(); i++) {
            if (pData->macroData[i] & PURE_CHARACTER_MASK) {
                SendPureCharacter(pData->macroData[i]);
            } else {
                SendKeyCode(pData->macroData[i]);
            }
        }
    }
    SendKeyCode(gKeycode | (gFlag & kCGEventFlagMaskShift ? CAPS_MASK : 0));
}

void RequestNewSession() {
    // send event signal to Engine
    vKeyHandleEvent(vKeyEvent::Mouse, vKeyEventState::MouseDown, 0);

    if (IS_DOUBLE_CODE(vCodeTable)) { // VNI
        gSyncKey.clear();
    }
}

// Convert the pressed key through the active keyboard layout (optional compat).
NSDictionary* keyStringToKeyCodeMap() {
    static NSDictionary* map = @{
        @"`": @50, @"~": @50, @"1": @18, @"!": @18, @"2": @19, @"@": @19, @"3": @20, @"#": @20, @"4": @21, @"$": @21,
        @"5": @23, @"%": @23, @"6": @22, @"^": @22, @"7": @26, @"&": @26, @"8": @28, @"*": @28, @"9": @25, @"(": @25,
        @"0": @29, @")": @29, @"-": @27, @"_": @27, @"=": @24, @"+": @24,
        @"q": @12, @"w": @13, @"e": @14, @"r": @15, @"t": @17, @"y": @16, @"u": @32, @"i": @34, @"o": @31, @"p": @35,
        @"[": @33, @"{": @33, @"]": @30, @"}": @30, @"\\": @42, @"|": @42,
        @"a": @0, @"s": @1, @"d": @2, @"f": @3, @"g": @5, @"h": @4, @"j": @38, @"k": @40, @"l": @37,
        @";": @41, @":": @41, @"'": @39, @"\"": @39,
        @"z": @6, @"x": @7, @"c": @8, @"v": @9, @"b": @11, @"n": @45, @"m": @46,
        @",": @43, @"<": @43, @".": @47, @">": @47, @"/": @44, @"?": @44
    };
    return map;
}

CGKeyCode ConvertEventToKeyboardLayoutCompatKeyCode(CGEventRef keyEvent, CGKeyCode fallbackKeyCode) {
    NSEvent* kbLayoutCompatEvent = [NSEvent eventWithCGEvent:keyEvent];
    NSString* keyString = kbLayoutCompatEvent.charactersIgnoringModifiers;
    NSString* lowercased = [keyString lowercaseString];
    if (!lowercased) {
        return fallbackKeyCode;
    }
    NSNumber* keycode = [keyStringToKeyCodeMap() objectForKey:lowercased];
    if (keycode) {
        return (CGKeyCode)[keycode intValue];
    }
    return fallbackKeyCode;
}

// ---------------------------------------------------------------------------
// Spotlight Accessibility (AX) atomic-replace path.
//
// Ported from OpenKey.mm (tuyenvm/OpenKey, GPLv3), ModernKey:
//   isAXReplaceTargetFocused(), buildAXReplacementString(), asciiFold(),
//   replaceFocusedTextViaAX(). Spotlight's async text field drops an injected
//   backspace when typing fast (producing e.g. "chuúng" instead of "chúng"), so
//   for a clean N->N character replacement we rewrite the text before the caret
//   atomically through the Accessibility API. Any failure falls through to the
//   normal CGEvent backspace+insert path, so other apps are unaffected.
// ---------------------------------------------------------------------------

// Is the system-wide focused element a text field that loses injected
// backspaces (Spotlight and similar system search overlays), so we should
// rewrite it atomically via the Accessibility API instead? Cached for a short
// TTL so we don't do Accessibility IPC on every keystroke.
//
// Detection is twofold and version-robust:
//   1. fast path: the owning app's bundle id is in gAxReplaceApp; or
//   2. behavior path: an Apple system process (com.apple.*) presents a search
//      field (subrole AXSearchField) that exposes both kAXValue and
//      kAXSelectedTextRange (i.e. the atomic replace can actually run).
// (2) keeps macOS-27 Spotlight (com.apple.campo) and any future rename working
// without hardcoding a build-specific identifier.
bool isAXReplaceTargetFocused() {
    double now = CFAbsoluteTimeGetCurrent();
    if (now - gAxFocusCheckedAt < 0.15)
        return gAxFocusIsTarget;
    gAxFocusCheckedAt = now;
    gAxFocusIsTarget = false;

    if (gAxSystemWide == NULL) {
        gAxSystemWide = AXUIElementCreateSystemWide();
        AXUIElementSetMessagingTimeout(gAxSystemWide, 0.05f);
    }
    AXUIElementRef focused = NULL;
    if (AXUIElementCopyAttributeValue(gAxSystemWide, kAXFocusedUIElementAttribute, (CFTypeRef*)&focused) == kAXErrorSuccess && focused) {
        pid_t pid = 0;
        if (AXUIElementGetPid(focused, &pid) == kAXErrorSuccess && pid > 0) {
            NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
            NSString* bundle = app.bundleIdentifier;
            if (bundle && [gAxReplaceApp containsObject:bundle]) {
                gAxFocusIsTarget = true;                      // (1) fast path
            } else if (bundle && [bundle hasPrefix:@"com.apple."]) {
                // (2) behavior path: an Apple system search field we can rewrite.
                CFTypeRef subRef = NULL, valRef = NULL, rngRef = NULL;
                AXUIElementCopyAttributeValue(focused, kAXSubroleAttribute, &subRef);
                bool isSearch = (subRef && CFGetTypeID(subRef) == CFStringGetTypeID() &&
                                 [(__bridge NSString*)subRef isEqualToString:(__bridge NSString*)kAXSearchFieldSubrole]);
                bool canVal = (AXUIElementCopyAttributeValue(focused, kAXValueAttribute, &valRef) == kAXErrorSuccess &&
                               valRef && CFGetTypeID(valRef) == CFStringGetTypeID());
                bool canRng = (AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute, &rngRef) == kAXErrorSuccess &&
                               rngRef && CFGetTypeID(rngRef) == AXValueGetTypeID());
                if (isSearch && canVal && canRng)
                    gAxFocusIsTarget = true;
                if (subRef) CFRelease(subRef);
                if (valRef) CFRelease(valRef);
                if (rngRef) CFRelease(rngRef);
            }
        }
        CFRelease(focused);
    }
    return gAxFocusIsTarget;
}

// Build the replacement string (Unicode only) from the engine's charData, which
// is stored right-to-left; mirrors the decode in SendNewCharString.
NSString* buildAXReplacementString() {
    NSMutableString* s = [NSMutableString stringWithCapacity:pData->newCharCount];
    for (int k = pData->newCharCount - 1; k >= 0; k--) {
        Uint32 t = pData->charData[k];
        UniChar ch;
        if ((t & PURE_CHARACTER_MASK) || (t & CHAR_CODE_MASK))
            ch = (UniChar)(t & CHAR_MASK);
        else
            ch = keyCodeToCharacter(t);
        [s appendString:[NSString stringWithCharacters:&ch length:1]];
    }
    return s;
}

// Fold a string to its lowercase ASCII base letters (strip Vietnamese
// diacritics). Used to detect a stale Accessibility read: for an N->N mark
// replacement, the text before the caret must have the same base letters as the
// replacement.
NSString* asciiFold(NSString* s) {
    NSString* d = [[s lowercaseString] decomposedStringWithCanonicalMapping];
    NSMutableString* out = [NSMutableString stringWithCapacity:d.length];
    for (NSUInteger i = 0; i < d.length; i++) {
        unichar c = [d characterAtIndex:i];
        if (c >= 'a' && c <= 'z') [out appendFormat:@"%C", c];
        else if (c == 0x0111) [out appendString:@"d"]; // đ
    }
    return out;
}

// Replace the `backspaceCount` characters before the caret with `newText`
// directly through the Accessibility API (atomic; avoids the backspace/insert
// race in apps like Spotlight). When typing fast the field may not yet contain
// the characters the OS is still inserting, so we re-read briefly until the base
// letters before the caret match `newText` before replacing. Returns false on
// any failure (caller falls back to the CGEvent path).
bool replaceFocusedTextViaAX(int backspaceCount, NSString* newText) {
    if (backspaceCount <= 0 || newText == nil)
        return false;
    if (gAxSystemWide == NULL) {
        gAxSystemWide = AXUIElementCreateSystemWide();
        AXUIElementSetMessagingTimeout(gAxSystemWide, 0.05f);
    }
    AXUIElementRef focused = NULL;
    if (AXUIElementCopyAttributeValue(gAxSystemWide, kAXFocusedUIElementAttribute, (CFTypeRef*)&focused) != kAXErrorSuccess || !focused)
        return false;
    AXUIElementSetMessagingTimeout(focused, 0.05f);

    NSString* wantBase = asciiFold(newText);
    bool ok = false;
    int attempts = 0;
    for (attempts = 0; attempts < 20 && !ok; attempts++) {
        if (attempts > 0)
            usleep(300); // 0.3ms: let the OS finish inserting the pending letters

        CFTypeRef valueRef = NULL, rangeRef = NULL;
        bool readOK = (AXUIElementCopyAttributeValue(focused, kAXValueAttribute, &valueRef) == kAXErrorSuccess &&
                       valueRef && CFGetTypeID(valueRef) == CFStringGetTypeID() &&
                       AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute, &rangeRef) == kAXErrorSuccess &&
                       rangeRef && CFGetTypeID(rangeRef) == AXValueGetTypeID());
        if (readOK) {
            CFRange sel = {0, 0};
            NSString* cur = (__bridge NSString*)valueRef;
            if (AXValueGetValue((AXValueRef)rangeRef, kAXValueTypeCFRange, &sel) &&
                sel.location >= backspaceCount && sel.location <= (CFIndex)cur.length) {

                CFIndex delStart = sel.location - backspaceCount;
                NSString* before = [cur substringWithRange:NSMakeRange(delStart, backspaceCount)];
                if ([asciiFold(before) isEqualToString:wantBase]) {
                    NSString* updated = [cur stringByReplacingCharactersInRange:NSMakeRange(delStart, backspaceCount)
                                                                    withString:newText];
                    if (AXUIElementSetAttributeValue(focused, kAXValueAttribute, (__bridge CFTypeRef)updated) == kAXErrorSuccess) {
                        CFRange newSel = CFRangeMake(delStart + (CFIndex)newText.length, 0);
                        AXValueRef newRange = AXValueCreate(kAXValueTypeCFRange, &newSel);
                        if (newRange) {
                            AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute, newRange);
                            CFRelease(newRange);
                        }
                        ok = true;
                    } else {
                        attempts = 20; // write failed; stop and fall back
                    }
                }
            }
        }
        if (valueRef) CFRelease(valueRef);
        if (rangeRef) CFRelease(rangeRef);
    }
    CFRelease(focused);
    return ok;
}

/**
 * MAIN HOOK entry. Ported from OpenKeyCallback in OpenKey.mm.
 */
// Flip VI/EN and tell the UI. Shared by the keyed and modifier-only hotkeys.
static void Key84ToggleLanguage() {
    vLanguage = vLanguage ? 0 : 1;
    RequestNewSession();                 // drop any in-flight word
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:Key84LanguageDidToggleNotification
                          object:nil
                        userInfo:@{@"language": @(vLanguage)}];
    });
}

CGEventRef Key84Callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon) {
    // re-enable the tap if the system disabled it (timeout / user input)
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (gEventTap) {
            CGEventTapEnable(gEventTap, true);
        }
        return event;
    }

    // don't handle my own synthetic events
    if (CGEventGetIntegerValueField(event, kCGEventSourceStateID) == CGEventSourceGetSourceStateID(gEventSource)) {
        return event;
    }

    gFlag = CGEventGetFlags(event);
    gKeycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);

    if (type == kCGEventKeyDown && vPerformLayoutCompat) {
        gKeycode = ConvertEventToKeyboardLayoutCompatKeyCode(event, gKeycode);
    }

    // Modifier-only VI/EN hotkey (e.g. ⇧⌘): the low byte is the 0xFF sentinel and
    // bits 8-11 are the required modifiers. Fires when that exact combo is released
    // without any other key/mouse pressed in the meantime, so it doesn't clobber
    // combos like ⇧⌘S. Handled here, before the type filter below drops
    // kCGEventFlagsChanged. Suppressed while the Settings recorder is capturing.
    if (!gSwitchKeyCaptureActive && GET_SWITCH_KEY(vSwitchKeyStatus) == 0xFF) {
        static bool armed = false;
        int targetMods = vSwitchKeyStatus & 0xF00;
        int curMods = ((gFlag & kCGEventFlagMaskControl)   ? 0x100 : 0)
                    | ((gFlag & kCGEventFlagMaskAlternate) ? 0x200 : 0)
                    | ((gFlag & kCGEventFlagMaskCommand)   ? 0x400 : 0)
                    | ((gFlag & kCGEventFlagMaskShift)     ? 0x800 : 0);
        if (type == kCGEventFlagsChanged) {
            if (curMods == targetMods) {
                armed = true;                            // exact combo held
            } else if (armed) {
                armed = false;                           // a modifier changed: released or added
                // Fire only if a target modifier was released and no extra one is held.
                if ((curMods & targetMods) != targetMods && (curMods & ~targetMods) == 0) {
                    Key84ToggleLanguage();
                }
            }
        } else if (type == kCGEventKeyDown ||
                   type == kCGEventLeftMouseDown || type == kCGEventRightMouseDown) {
            armed = false;                               // modifiers used with another key → cancel
        }
        // Don't consume: let kCGEventFlagsChanged pass so modifier state stays sane.
    }

    // only the events below are interesting
    if ((type != kCGEventKeyDown) && (type != kCGEventKeyUp) &&
        (type != kCGEventLeftMouseDown) && (type != kCGEventRightMouseDown) &&
        (type != kCGEventLeftMouseDragged) && (type != kCGEventRightMouseDragged))
        return event;

    gProxy = proxy;

    // VI/EN switch hotkey. Matched before any language gating so it works in both
    // Vietnamese and English mode. Requires an exact modifier match (so ⌘E does not
    // fire on ⌘⇧E) and is suppressed while the Settings recorder is capturing.
    if (type == kCGEventKeyDown && vSwitchKeyStatus != 0 && !gSwitchKeyCaptureActive &&
        GET_SWITCH_KEY(vSwitchKeyStatus) == gKeycode &&
        HAS_CONTROL(vSwitchKeyStatus) == ((gFlag & kCGEventFlagMaskControl)   ? 1 : 0) &&
        HAS_OPTION(vSwitchKeyStatus)  == ((gFlag & kCGEventFlagMaskAlternate) ? 1 : 0) &&
        HAS_COMMAND(vSwitchKeyStatus) == ((gFlag & kCGEventFlagMaskCommand)   ? 1 : 0) &&
        HAS_SHIFT(vSwitchKeyStatus)   == ((gFlag & kCGEventFlagMaskShift)     ? 1 : 0)) {
        Key84ToggleLanguage();
        return NULL;                         // consume the hotkey
    }

    // English mode
    if (vLanguage == 0) {
        if (vUseMacro && vUseMacroInEnglishMode && type == kCGEventKeyDown) {
            vEnglishMode((type == kCGEventKeyDown ? vKeyEventState::KeyDown : vKeyEventState::MouseDown),
                         gKeycode,
                         (gFlag & kCGEventFlagMaskShift) || (gFlag & kCGEventFlagMaskAlphaShift),
                         OTHER_CONTROL_KEY);

            if (pData->code == vReplaceMaro) { // macro in english mode
                handleMacro();
                return NULL;
            }
        }
        return event;
    }

    // mouse: start a new word
    if (type == kCGEventLeftMouseDown || type == kCGEventRightMouseDown ||
        type == kCGEventLeftMouseDragged || type == kCGEventRightMouseDragged) {
        RequestNewSession();
        return event;
    }

    // "turn off Vietnamese when in other language" mode
    if (vOtherLanguage) {
        TISInputSourceRef isource = TISCopyCurrentKeyboardInputSource();
        if (isource != NULL) {
            CFArrayRef languages = (CFArrayRef)TISGetInputSourceProperty(isource, kTISPropertyInputSourceLanguages);
            if (languages != NULL && CFArrayGetCount(languages) > 0) {
                CFStringRef langRef = (CFStringRef)CFArrayGetValueAtIndex(languages, 0);
                NSString* currentLanguage = (__bridge NSString*)langRef;
                if (![currentLanguage isLike:@"en"]) {
                    CFRelease(isource);
                    return event;
                }
            }
            CFRelease(isource);
        }
    }

    // keyboard
    if (type == kCGEventKeyDown) {
        // send event signal to Engine
        vKeyHandleEvent(vKeyEvent::Keyboard,
                        vKeyEventState::KeyDown,
                        gKeycode,
                        gFlag & kCGEventFlagMaskShift ? 1 : (gFlag & kCGEventFlagMaskAlphaShift ? 2 : 0),
                        OTHER_CONTROL_KEY);
        // Opt-in diagnostic trace: run the binary with KEY84_TRACE=1 to log what
        // the engine decided per keystroke (for diagnosing live-app issues).
        static bool gTrace = (getenv("KEY84_TRACE") != NULL);
        if (gTrace) {
            NSLog(@"84Key[trace] kc=%d code=%d bsp=%d ncc=%d ext=%d vCT=%d fixRec=%d other=%d front=%@",
                  (int)gKeycode, (int)pData->code, (int)pData->backspaceCount,
                  (int)pData->newCharCount, (int)pData->extCode, vCodeTable,
                  vFixRecommendBrowser, vOtherLanguage, FRONT_APP);
        }
        if (pData->code == vDoNothing) { // do nothing
            if (IS_DOUBLE_CODE(vCodeTable)) { // VNI
                if (pData->extCode == 1) { // break key
                    gSyncKey.clear();
                } else if (pData->extCode == 2) { // delete key
                    if (gSyncKey.size() > 0) {
                        if (gSyncKey.back() > 1 && (vCodeTable == 2 || !containUnicodeCompoundApp(FRONT_APP))) {
                            PostBackspace();
                        }
                        gSyncKey.pop_back();
                    }
                } else if (pData->extCode == 3) { // normal key
                    InsertKeyLength(1);
                }
            }
            return event;
        } else if (pData->code == vWillProcess || pData->code == vRestore || pData->code == vRestoreAndStartNewSession) {
            // Spotlight (and similar system search overlays) drop injected
            // backspaces, corrupting transforms (e.g. "chúng" -> "chuúng" on
            // macOS 27, where the field is owned by com.apple.campo). When the
            // focused element is such a target we never use plain backspaces:
            //   - clean N->N Unicode mark change: rewrite atomically via the
            //     Accessibility API (best — no visible caret motion);
            //   - otherwise (N!=M, VNI, or an AX failure): select the chars to
            //     replace with Shift+Left and overwrite them via the normal
            //     SendNewCharString below.
            // Any non-target app falls through to the Chromium / CGEvent paths
            // unchanged. Ported from OpenKey.mm (tuyenvm/OpenKey, GPLv3).
            bool axTarget = (vFixSpotlight && pData->extCode != 4 &&
                             pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF &&
                             isAXReplaceTargetFocused());
            bool webEditor = false;  // async in-page web editor (Google Docs); set below
            if (axTarget) {
                if (vCodeTable == 0 && pData->code == vWillProcess &&
                    pData->backspaceCount == pData->newCharCount &&
                    replaceFocusedTextViaAX(pData->backspaceCount, buildAXReplacementString())) {
                    return NULL;
                }
                // Select-and-overwrite fallback: pick the chars with Shift+Left,
                // then let SendNewCharString type over the selection (bsp=0 so
                // the swallow-prone backspace loop below is skipped).
                for (gI = 0; gI < pData->backspaceCount; gI++)
                    SendShiftAndLeftArrow();
                pData->backspaceCount = 0;
            } else if (pData->extCode != 4) {
                // Browsers — the omnibox AND in-page editors like Google Docs —
                // mishandle a plain backspace+insert fired in one burst: the async
                // web layer applies the insert before the deletion, so "đủ"->"dđủ"
                // in the address bar and the doubled-tone restore "garr"->"gar"
                // surface as "gảar" in Docs. The fix (OpenKey lineage) is an
                // empty-char prefix (U+202F) that breaks the
                // autocomplete/composition state, then paced backspaces + text (the
                // pacing is applied in the backspace loop below). Gated by
                // vFixWebContentEditor (on by default).
                if (vFixWebContentEditor && isBrowserApp(FRONT_APP)) {
                    webEditor = true;
                    SendEmptyCharacter();
                    pData->backspaceCount++;   // also delete the empty char
                } else if (vFixRecommendBrowser) {
                    SendEmptyCharacter();
                    pData->backspaceCount++;
                }
            }

            // send backspace. An async web editor (Google Docs) needs each
            // delete to settle before the next event, and a gap before the
            // insert — otherwise the replacement lands before the deletion and
            // the restore "garr"->"gar" shows as "gảar". Pace it for web editors;
            // every other app keeps the original tight, delay-free path.
            if (pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF) {
                for (gI = 0; gI < pData->backspaceCount; gI++) {
                    SendBackspace();
                    if (webEditor) usleep(3000);  // 3ms between deletes
                }
                if (webEditor) usleep(8000);      // settle before the insert
            }

            // send new character
            if (!vSendKeyStepByStep) {
                SendNewCharString();
            } else {
                if (pData->newCharCount > 0 && pData->newCharCount <= MAX_BUFF) {
                    for (int i = pData->newCharCount - 1; i >= 0; i--) {
                        SendKeyCode(pData->charData[i]);
                    }
                }
                if (pData->code == vRestore || pData->code == vRestoreAndStartNewSession) {
                    SendKeyCode(gKeycode | ((gFlag & kCGEventFlagMaskAlphaShift) || (gFlag & kCGEventFlagMaskShift) ? CAPS_MASK : 0));
                }
                if (pData->code == vRestoreAndStartNewSession) {
                    startNewSession();
                }
            }
        } else if (pData->code == vReplaceMaro) { // MACRO
            handleMacro();
        }

        return NULL;
    }

    return event;
}

// One-time init of the engine + reusable events. Safe to call repeatedly.
void ensureEngineInitialized() {
    if (pData != NULL)
        return;
    if (gEventSource == NULL)
        gEventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
    pData = (vKeyHookState*)vKeyInit();
}

} // namespace

// ---------------------------------------------------------------------------
// Obj-C facade.
// ---------------------------------------------------------------------------
@implementation InputController

- (instancetype)init {
    self = [super init];
    if (self) {
        ensureEngineInitialized();
    }
    return self;
}

- (BOOL)hasAccessibilityPermission {
    return AXIsProcessTrusted() ? YES : NO;
}

- (BOOL)requestAccessibilityPermission {
    NSDictionary *options = @{ (__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES };
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options) ? YES : NO;
}

- (BOOL)isRunning {
    return (gEventTap != NULL && CGEventTapIsEnabled(gEventTap)) ? YES : NO;
}

- (BOOL)start {
    if ([self isRunning])
        return YES;

    ensureEngineInitialized();

    // Tear down any half-created tap from a previous failed attempt.
    [self stop];

    CGEventMask eventMask = CGEventMaskBit(kCGEventKeyDown) |
                            CGEventMaskBit(kCGEventKeyUp) |
                            CGEventMaskBit(kCGEventFlagsChanged) |
                            CGEventMaskBit(kCGEventLeftMouseDown) |
                            CGEventMaskBit(kCGEventRightMouseDown) |
                            CGEventMaskBit(kCGEventLeftMouseDragged) |
                            CGEventMaskBit(kCGEventRightMouseDragged);

    gEventTap = CGEventTapCreate(kCGSessionEventTap,
                                 kCGHeadInsertEventTap,
                                 kCGEventTapOptionDefault,
                                 eventMask,
                                 Key84Callback,
                                 NULL);
    if (gEventTap == NULL) {
        // Most commonly: Accessibility permission not granted.
        return NO;
    }

    gRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, gEventTap, 0);
    if (gRunLoopSource == NULL) {
        CFRelease(gEventTap);
        gEventTap = NULL;
        return NO;
    }

    CFRunLoopAddSource(CFRunLoopGetCurrent(), gRunLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(gEventTap, true);
    return [self isRunning];
}

- (void)stop {
    if (gEventTap != NULL) {
        CGEventTapEnable(gEventTap, false);
    }
    if (gRunLoopSource != NULL) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), gRunLoopSource, kCFRunLoopCommonModes);
        CFRelease(gRunLoopSource);
        gRunLoopSource = NULL;
    }
    if (gEventTap != NULL) {
        CFRelease(gEventTap);
        gEventTap = NULL;
    }
}

- (void)applyEngineOptions:(NSDictionary<NSString *, NSNumber *> *)options {
    for (NSString *key in options) {
        int v = options[key].intValue;
        #define SET_IF(name) if ([key isEqualToString:@#name]) { name = v; continue; }
        SET_IF(vLanguage) SET_IF(vInputType) SET_IF(vFreeMark) SET_IF(vCodeTable)
        SET_IF(vCheckSpelling) SET_IF(vUseModernOrthography) SET_IF(vQuickTelex)
        SET_IF(vRestoreIfWrongSpelling) SET_IF(vFixRecommendBrowser) SET_IF(vUseMacro)
        SET_IF(vUseMacroInEnglishMode) SET_IF(vUseSmartSwitchKey) SET_IF(vUpperCaseFirstChar)
        SET_IF(vAllowConsonantZFWJ) SET_IF(vQuickStartConsonant) SET_IF(vQuickEndConsonant)
        SET_IF(vAutoDetectEnglish) SET_IF(vOtherLanguage)
        SET_IF(vFixSpotlight) SET_IF(vSendKeyStepByStep) SET_IF(vFixChromiumBrowser)
        SET_IF(vFixWebContentEditor)
        SET_IF(vPerformLayoutCompat) SET_IF(vSwitchKeyStatus)
        #undef SET_IF
    }
}

- (void)setSwitchKeyCaptureActive:(BOOL)active {
    gSwitchKeyCaptureActive = active ? true : false;
}

- (BOOL)loadDictionaries {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *engPath = [bundle pathForResource:@"english_words" ofType:@"dat"];
    NSString *vietPath = [bundle pathForResource:@"viet_telex" ofType:@"dat"];
    if (engPath == nil || vietPath == nil)
        return NO;
    NSData *eng = [NSData dataWithContentsOfFile:engPath];
    NSData *viet = [NSData dataWithContentsOfFile:vietPath];
    if (eng == nil || viet == nil)
        return NO;
    initEnglishDict((const Byte *)eng.bytes, (int)eng.length);
    initVietByTelexDict((const Byte *)viet.bytes, (int)viet.length);
    return isEnglishDictReady() ? YES : NO;
}

@end
