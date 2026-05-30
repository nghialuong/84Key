# Focus Debugging

Runtime tools for diagnosing focus issues in UIKit and SwiftUI apps.

Docs: [UIFocusDebugger](https://sosumi.ai/documentation/uikit/uifocusdebugger)

## UIFocusDebugger (LLDB)

`UIFocusDebugger` is a runtime-only class for use in the LLDB console during
a debugging session. Do not call these methods from app code.

### Commands

```lldb
// Show current focus state
po UIFocusDebugger.status()

// Check why a specific view can't receive focus
po UIFocusDebugger.checkFocusability(for: myButton)

// Show focus group hierarchy
po UIFocusDebugger.focusGroups(for: myViewController)

// Show preferred focus chain
po UIFocusDebugger.preferredFocusEnvironments(for: myViewController)

// Simulate a focus update from a given environment
po UIFocusDebugger.simulateFocusUpdateRequest(from: myViewController)
```

### Common Diagnostic Patterns

**"Why won't this view focus?"**

```lldb
po UIFocusDebugger.checkFocusability(for: myView)
```

Common causes returned:
- View is hidden or has zero alpha
- View is not in the view hierarchy
- `canBecomeFocused` returns `false`
- A parent's `shouldUpdateFocus(in:)` returned `false`
- The view is covered by another view

**"Where does focus go next?"**

```lldb
po UIFocusDebugger.simulateFocusUpdateRequest(from: currentView)
```

Shows the focus engine's evaluation of the next destination based on geometry.

## SwiftUI Focus Debugging

SwiftUI does not expose `UIFocusDebugger` directly. Strategies:

1. **Add `.onChange(of: focusedField)`** to log focus transitions:

```swift
.onChange(of: focusedField) { old, new in
    print("Focus moved: \(String(describing: old)) → \(String(describing: new))")
}
```

2. **Use Accessibility Inspector** (Xcode → Open Developer Tool) to inspect
   focus order and accessibility element hierarchy.

3. **Set breakpoints in `didUpdateFocus(in:with:)`** for UIKit-hosted views
   within SwiftUI.

## Focus Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Programmatically setting focus in `viewDidLoad` | Focus engine hasn't completed initial update | Use `viewDidAppear` or `DispatchQueue.main.async` |
| Calling `setNeedsFocusUpdate()` without `updateFocusIfNeeded()` | Focus update is deferred indefinitely | Pair both calls: `setNeedsFocusUpdate(); updateFocusIfNeeded()` |
| Overriding `preferredFocusEnvironments` with stale references | Focus targets a deallocated or off-screen view | Return currently valid, on-screen environments |
| Using `isHidden = true` to disable focus on a view | Removes the view from layout entirely | Use `canBecomeFocused` override or `focusable(false)` |
| Animating focus changes without `UIFocusAnimationCoordinator` | Animation doesn't sync with system focus animation | Use `coordinator.addCoordinatedFocusingAnimations` |
| Forgetting `collisionComponent` on RealityKit entities | Entity can't receive gaze/direct-touch input or hover feedback in visionOS | Add `CollisionComponent` alongside `InputTargetComponent` |
| Not testing with Full Keyboard Access on macOS | Tab focus skips custom controls | Enable Keyboard Navigation in System Settings and test |
| Relying on touch-based interactions on tvOS | No touch input available | Make all actions accessible via focus + select |
