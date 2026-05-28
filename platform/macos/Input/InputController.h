#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Obj-C facade over the C++ Vietnamese typing engine. The interface is pure
/// Obj-C (no C++ types) so it can be imported into Swift via the bridging
/// header; the implementation (.mm) is Obj-C++ and talks to the engine.
@interface InputController : NSObject

- (instancetype)init;

/// Smoke check that the C++ engine is linked and initializes. The CGEvent tap
/// and key sending are added in T8.
- (NSString *)engineStatus;

@end

NS_ASSUME_NONNULL_END
