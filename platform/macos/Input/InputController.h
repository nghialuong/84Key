#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Obj-C facade over the C++ Vietnamese typing engine and the macOS CGEvent
/// tap. The interface is pure Obj-C (no C++ types) so it can be imported into
/// Swift via the bridging header; the implementation (.mm) is Obj-C++ and talks
/// to the engine and CoreGraphics.
@interface InputController : NSObject

- (instancetype)init;

/// Create and enable the session-level CGEvent tap so Vietnamese typing is
/// processed system-wide. Returns NO if the tap could not be created (most
/// commonly because Accessibility permission has not been granted, or another
/// tap already owns this process). Safe to call again after a failure.
- (BOOL)start;

/// Disable and tear down the event tap. Safe to call when not running.
- (void)stop;

/// Whether the event tap is currently installed and enabled.
- (BOOL)isRunning;

/// Wraps AXIsProcessTrusted(): YES if this process is allowed to observe and
/// post keyboard events.
- (BOOL)hasAccessibilityPermission;

/// Like hasAccessibilityPermission, but asks macOS to surface its "open System
/// Settings" prompt when permission is missing (via
/// AXIsProcessTrustedWithOptions + kAXTrustedCheckOptionPrompt). Returns the
/// current trust state. Used by first-run onboarding.
- (BOOL)requestAccessibilityPermission;

/// Push option values into the engine + macOS-local option globals. Keys are the
/// option global names (e.g. @"vInputType", @"vAutoDetectEnglish",
/// @"vFixSpotlight"); values are integers. Unknown keys are ignored.
- (void)applyEngineOptions:(NSDictionary<NSString *, NSNumber *> *)options;

/// Load the bundled English and Vietnamese-by-Telex dictionaries into the engine
/// so automatic English detection works. Returns YES once the English dictionary
/// is ready. Safe to call again to reload.
- (BOOL)loadDictionaries;

@end

NS_ASSUME_NONNULL_END
