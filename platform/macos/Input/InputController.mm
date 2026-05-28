#import "InputController.h"

#include "Engine.h"

@implementation InputController

- (instancetype)init {
    self = [super init];
    if (self) {
        vKeyInit();
    }
    return self;
}

- (NSString *)engineStatus {
    // Touching the engine here forces the C++ sources to link into the app.
    vKeyInit();
    return @"engine ready";
}

@end
