# ScrollView and Lazy stacks

## Contents

- [Intent](#intent)
- [Core patterns](#core-patterns)
- [Example: vertical custom feed](#example-vertical-custom-feed)
- [ScrollPosition capabilities](#scrollposition-capabilities)
- [Example: horizontal chips](#example-horizontal-chips)
- [Example: adaptive grid](#example-adaptive-grid)
- [Design choices to keep](#design-choices-to-keep)
- [iOS 26 Scroll Edge Effects](#ios-26-scroll-edge-effects)
- [Pitfalls](#pitfalls)

## Intent

Use `ScrollView` with `LazyVStack`, `LazyHStack`, or `LazyVGrid` when you need custom layout, mixed content, or horizontal/ grid-based scrolling.

## Core patterns

- Prefer `ScrollView` + `LazyVStack` for chat-like or custom feed layouts.
- Use `ScrollView(.horizontal)` + `LazyHStack` for chips, tags, avatars, and media strips.
- Use `LazyVGrid` for icon/media grids; prefer adaptive columns when possible.
- Use `ScrollPosition` for programmatic scrolling: scroll-to-id, scroll-to-edge, and point-based offsets.
- Use `safeAreaInset(edge:)` for input bars that should stick above the keyboard.

## Example: vertical custom feed

```swift
@MainActor
struct ConversationView: View {
  @State private var scrollPosition = ScrollPosition(edge: .bottom)

  var body: some View {
    ScrollView {
      LazyVStack {
        ForEach(messages) { message in
          MessageRow(message: message)
        }
      }
      .scrollTargetLayout()
      .padding(.horizontal, .layoutPadding)
    }
    .scrollPosition($scrollPosition)
    .safeAreaInset(edge: .bottom) {
      MessageInputBar()
    }
    .onChange(of: messages.last?.id) {
      withAnimation { scrollPosition.scrollTo(edge: .bottom) }
    }
  }
}
```

## ScrollPosition capabilities

`ScrollPosition` (iOS 18+) replaces `ScrollViewReader` for programmatic scrolling. It is declarative, supports bidirectional position tracking, and does not require a closure wrapper.

**Setup:** Declare state and attach to the scroll view. Apply `.scrollTargetLayout()` to the inner layout container so SwiftUI can track individual view identities.

```swift
@State private var scrollPosition = ScrollPosition(idType: Message.ID.self)

ScrollView {
    LazyVStack {
        ForEach(messages) { message in
            MessageRow(message: message)
        }
    }
    .scrollTargetLayout()
}
.scrollPosition($scrollPosition)
```

**Scroll to a specific item:**

```swift
scrollPosition.scrollTo(id: message.id, anchor: .top)
```

**Scroll to an edge:**

```swift
scrollPosition.scrollTo(edge: .bottom)
```

**Read the current position:**

```swift
if let currentID = scrollPosition.viewID(type: Message.ID.self) {
    // The view with this ID is currently at the scroll anchor
}
```

**Detect user-initiated scrolls:**

```swift
.onChange(of: scrollPosition.isPositionedByUser) { _, byUser in
    if byUser {
        // User scrolled manually -- show "scroll to bottom" button
    }
}
```

## Example: horizontal chips

```swift
ScrollView(.horizontal, showsIndicators: false) {
  LazyHStack {
    ForEach(chips) { chip in
      ChipView(chip: chip)
    }
  }
}
```

## Example: adaptive grid

```swift
let columns = [GridItem(.adaptive(minimum: 120))]

ScrollView {
  LazyVGrid(columns: columns) {
    ForEach(items) { item in
      GridItemView(item: item)
    }
  }
  .padding()
}
```

## Design choices to keep

- Use `Lazy*` stacks when item counts are large or unknown.
- Use non-lazy stacks for small, fixed-size content to avoid lazy overhead.
- Keep IDs stable for `ScrollPosition` tracking; changing IDs causes position jumps.
- Prefer explicit animations (`withAnimation`) when scrolling to an ID.

## iOS 26 Scroll Edge Effects

### scrollEdgeEffectStyle

Configure the visual treatment at scroll view edges (iOS 26+):

```swift
ScrollView {
    content
}
.scrollEdgeEffectStyle(.soft, for: .top)   // Soft fading edge at top
.scrollEdgeEffectStyle(.hard, for: .bottom) // Hard cutoff at bottom
```

`ScrollEdgeEffectStyle` values:
- `.automatic` -- platform default
- `.soft` -- soft fading edge effect
- `.hard` -- hard cutoff with dividing line

Use `scrollEdgeEffectHidden(_:for:)` to hide the edge effect entirely.

### backgroundExtensionEffect

Duplicates, mirrors, and blurs the view to extend behind safe area edges (iOS 26+):

```swift
NavigationSplitView {
    sidebar
} detail: {
    BannerView()
        .backgroundExtensionEffect()
}
```

Use sparingly -- Apple recommends only a single instance for visual clarity and performance. The modifier clips the view to prevent mirror overlap.

### safeAreaBar

Attach a bar view to the safe area edge, integrating with scroll edge effects (iOS 26+):

```swift
content
    .safeAreaBar(edge: .top) {
        FilterBar()
    }
```

## Pitfalls

- Avoid nesting scroll views of the same axis; it causes gesture conflicts.
- Don’t combine `List` and `ScrollView` in the same hierarchy without a clear reason.
- Overuse of `LazyVStack` for tiny content can add unnecessary complexity.
- Apply `scrollEdgeEffectStyle` on the ScrollView, not on inner content.
- Use `backgroundExtensionEffect()` on only one view per screen.
