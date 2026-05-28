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
//   - The Spotlight Accessibility atomic-replace path is intentionally omitted
//     here; see the TODO(T14) marker below. The normal CGEvent backspace+insert
//     path is used everywhere instead.
//   - Smart-switch-key, convert-tool, hotkey switching, and macro/Userdefaults
//     loading are out of scope for this task and are not ported.
//

#import "InputController.h"

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>

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
CGEventRef gBackSpaceDown = NULL;
CGEventRef gBackSpaceUp = NULL;

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

void InsertKeyLength(const Uint8& len) {
    gSyncKey.push_back(len);
}

void SendPureCharacter(const Uint16& ch) {
    gNewEventDown = CGEventCreateKeyboardEvent(gEventSource, 0, true);
    gNewEventUp = CGEventCreateKeyboardEvent(gEventSource, 0, false);
    CGEventKeyboardSetUnicodeString(gNewEventDown, 1, &ch);
    CGEventKeyboardSetUnicodeString(gNewEventUp, 1, &ch);
    CGEventTapPostEvent(gProxy, gNewEventDown);
    CGEventTapPostEvent(gProxy, gNewEventUp);
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
        privateFlag |= kCGEventFlagMaskNonCoalesced;

        CGEventSetFlags(gNewEventDown, privateFlag);
        CGEventSetFlags(gNewEventUp, privateFlag);
        CGEventTapPostEvent(gProxy, gNewEventDown);
        CGEventTapPostEvent(gProxy, gNewEventUp);
    } else {
        if (vCodeTable == 0) { // unicode 2 bytes code
            gNewEventDown = CGEventCreateKeyboardEvent(gEventSource, 0, true);
            gNewEventUp = CGEventCreateKeyboardEvent(gEventSource, 0, false);
            CGEventKeyboardSetUnicodeString(gNewEventDown, 1, &gNewChar);
            CGEventKeyboardSetUnicodeString(gNewEventUp, 1, &gNewChar);
            CGEventTapPostEvent(gProxy, gNewEventDown);
            CGEventTapPostEvent(gProxy, gNewEventUp);
        } else if (vCodeTable == 1 || vCodeTable == 2 || vCodeTable == 4) { // VNI Windows, TCVN3, CP1258: 1 byte code
            gNewCharHi = HIBYTE(gNewChar);
            gNewChar = LOBYTE(gNewChar);

            gNewEventDown = CGEventCreateKeyboardEvent(gEventSource, 0, true);
            gNewEventUp = CGEventCreateKeyboardEvent(gEventSource, 0, false);
            CGEventKeyboardSetUnicodeString(gNewEventDown, 1, &gNewChar);
            CGEventKeyboardSetUnicodeString(gNewEventUp, 1, &gNewChar);
            CGEventTapPostEvent(gProxy, gNewEventDown);
            CGEventTapPostEvent(gProxy, gNewEventUp);
            if (gNewCharHi > 32) {
                if (vCodeTable == 2) // VNI
                    InsertKeyLength(2);
                CFRelease(gNewEventDown);
                CFRelease(gNewEventUp);
                gNewEventDown = CGEventCreateKeyboardEvent(gEventSource, 0, true);
                gNewEventUp = CGEventCreateKeyboardEvent(gEventSource, 0, false);
                CGEventKeyboardSetUnicodeString(gNewEventDown, 1, &gNewCharHi);
                CGEventKeyboardSetUnicodeString(gNewEventUp, 1, &gNewCharHi);
                CGEventTapPostEvent(gProxy, gNewEventDown);
                CGEventTapPostEvent(gProxy, gNewEventUp);
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
            CGEventTapPostEvent(gProxy, gNewEventDown);
            CGEventTapPostEvent(gProxy, gNewEventUp);
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
    CGEventTapPostEvent(gProxy, gNewEventDown);
    CGEventTapPostEvent(gProxy, gNewEventUp);
    CFRelease(gNewEventDown);
    CFRelease(gNewEventUp);
}

void SendBackspace() {
    CGEventTapPostEvent(gProxy, gBackSpaceDown);
    CGEventTapPostEvent(gProxy, gBackSpaceUp);

    if (IS_DOUBLE_CODE(vCodeTable)) { // VNI or Unicode Compound
        if (gSyncKey.size() > 0 && gSyncKey.back() > 1) {
            if (!(vCodeTable == 3 && containUnicodeCompoundApp(FRONT_APP))) {
                CGEventTapPostEvent(gProxy, gBackSpaceDown);
                CGEventTapPostEvent(gProxy, gBackSpaceUp);
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

    CGEventTapPostEvent(gProxy, eventVkeyDown);
    CGEventTapPostEvent(gProxy, eventVkeyUp);

    if (IS_DOUBLE_CODE(vCodeTable)) { // VNI or Unicode Compound
        if (gSyncKey.size() > 0 && gSyncKey.back() > 1) {
            if (!(vCodeTable == 3 && containUnicodeCompoundApp(FRONT_APP))) {
                CGEventTapPostEvent(gProxy, eventVkeyDown);
                CGEventTapPostEvent(gProxy, eventVkeyUp);
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
    CGEventTapPostEvent(gProxy, gNewEventDown);
    CGEventTapPostEvent(gProxy, gNewEventUp);
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

/**
 * MAIN HOOK entry. Ported from OpenKeyCallback in OpenKey.mm.
 */
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

    // only the events below are interesting
    if ((type != kCGEventKeyDown) && (type != kCGEventKeyUp) &&
        (type != kCGEventLeftMouseDown) && (type != kCGEventRightMouseDown) &&
        (type != kCGEventLeftMouseDragged) && (type != kCGEventRightMouseDragged))
        return event;

    gProxy = proxy;

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
        if (pData->code == vDoNothing) { // do nothing
            if (IS_DOUBLE_CODE(vCodeTable)) { // VNI
                if (pData->extCode == 1) { // break key
                    gSyncKey.clear();
                } else if (pData->extCode == 2) { // delete key
                    if (gSyncKey.size() > 0) {
                        if (gSyncKey.back() > 1 && (vCodeTable == 2 || !containUnicodeCompoundApp(FRONT_APP))) {
                            CGEventTapPostEvent(gProxy, gBackSpaceDown);
                            CGEventTapPostEvent(gProxy, gBackSpaceUp);
                        }
                        gSyncKey.pop_back();
                    }
                } else if (pData->extCode == 3) { // normal key
                    InsertKeyLength(1);
                }
            }
            return event;
        } else if (pData->code == vWillProcess || pData->code == vRestore || pData->code == vRestoreAndStartNewSession) {
            // TODO(T14): Spotlight AX atomic-replace path. OpenKey replaces the
            // text before the caret atomically through the Accessibility API for
            // apps like Spotlight (whose async fields drop injected backspaces).
            // That path is implemented in T14; for now we always fall through to
            // the normal CGEvent backspace+insert path below.

            // fix autocomplete
            if (vFixRecommendBrowser && pData->extCode != 4) {
                if (vFixChromiumBrowser && [gUnicodeCompoundApp containsObject:FRONT_APP]) {
                    if (pData->backspaceCount > 0) {
                        SendShiftAndLeftArrow();
                        if (pData->backspaceCount == 1)
                            pData->backspaceCount--;
                    }
                } else {
                    SendEmptyCharacter();
                    pData->backspaceCount++;
                }
            }

            // send backspace
            if (pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF) {
                for (gI = 0; gI < pData->backspaceCount; gI++) {
                    SendBackspace();
                }
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
    if (gBackSpaceDown == NULL)
        gBackSpaceDown = CGEventCreateKeyboardEvent(gEventSource, KEY_DELETE, true);
    if (gBackSpaceUp == NULL)
        gBackSpaceUp = CGEventCreateKeyboardEvent(gEventSource, KEY_DELETE, false);
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
        SET_IF(vPerformLayoutCompat)
        #undef SET_IF
    }
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
