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
/// post keyboard events. Onboarding to grant this is a later task.
- (BOOL)hasAccessibilityPermission;

@end

NS_ASSUME_NONNULL_END
