# Grids

## Contents
- Intent
- Choosing the right grid type
- Column strategies
- Cell sizing and aspect ratio
- Example: adaptive icon grid
- Example: fixed 3-column media grid
- Example: sectioned grid
- Selection and interaction patterns
- Performance guardrails
- Accessibility and polish
- Pitfalls

## Intent

Use grids for dense visual collections where row-based layouts waste space or
make scanning harder.

Good fits:

- icon pickers
- media galleries
- template choosers
- settings tiles
- dashboards with repeatable cards

Default to `LazyVGrid` for vertically scrolling collections on iOS. Reach for
`Grid` when content is small and non-scrollable, or when you need explicit row
composition rather than a large lazy container.

## Choosing the right grid type

### `LazyVGrid`

Use for the common iPhone/iPad case: many items, vertical scrolling, and a
column definition that should adapt to width.

### `LazyHGrid`

Use when horizontal scrolling is the dominant interaction and rows are easier to
define than columns.

### `Grid`

Use when:

- the item count is small
- the content is mostly static
- row/column relationships matter more than lazy loading
- you need `GridRow` composition instead of a repeated collection layout

For large scrolling datasets, `LazyVGrid` is usually the safer default.

## Column strategies

### Adaptive columns

Use `.adaptive` when you want the number of columns to respond to available
width.

```swift
let columns = [GridItem(.adaptive(minimum: 120, maximum: 240))]
```

This is the best default for icon pickers, template choosers, and photo grids
that should scale naturally across iPhone and iPad sizes.

### Flexible columns

Use multiple `.flexible` columns when you want a predictable column count.

```swift
let columns = [
    GridItem(.flexible(minimum: 100)),
    GridItem(.flexible(minimum: 100)),
    GridItem(.flexible(minimum: 100)),
]
```

This works well when design requires a fixed 2-column or 3-column rhythm.

### Fixed columns

Use `.fixed` only when the design truly requires exact widths. Fixed columns are
less resilient across device sizes and dynamic type changes.

## Cell sizing and aspect ratio

Grid cells should usually define their own shape without reading parent
geometry.

Preferred sizing tools:

- `.aspectRatio(1, contentMode: .fit)` for square thumbnails
- `.frame(maxWidth: .infinity)` when content should fill the available column
- internal padding instead of outer geometry math

Avoid `GeometryReader` inside lazy containers. It defeats lazy layout and adds
extra measurement work.

## Example: adaptive icon grid

```swift
let columns = [GridItem(.adaptive(minimum: 120, maximum: 240))]

LazyVGrid(columns: columns) {
    ForEach(icons) { icon in
        Button {
            select(icon)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(icon.previewName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 6))

                if icon.isSelected {
                    Image(systemName: "checkmark.seal.fill")
                        .padding(4)
                        .tint(.green)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
```

Why this works:

- adaptive columns scale across width classes
- square-ish cells come from image aspect ratio, not geometry reads
- the whole tile remains tappable

## Example: fixed 3-column media grid

```swift
LazyVGrid(
    columns: [
        .init(.flexible(minimum: 100), spacing: 4),
        .init(.flexible(minimum: 100), spacing: 4),
        .init(.flexible(minimum: 100), spacing: 4),
    ],
    spacing: 4
) {
    ForEach(items) { item in
        ThumbnailView(item: item)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 8))
    }
}
```

Use this when the design language wants a consistent three-up gallery instead of
an adaptive count.

## Example: sectioned grid

Sectioned grids work well for grouped content like categories or recents.

```swift
LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))]) {
    ForEach(sections) { section in
        Section {
            ForEach(section.items) { item in
                Tile(item: item)
            }
        } header: {
            Text(section.title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top)
        }
    }
}
```

Keep headers visually lightweight. Dense grids lose scan efficiency when every
section header is oversized or heavily decorated.

## Selection and interaction patterns

Grid interactions should stay obvious and forgiving.

Useful defaults:

- make the entire cell tappable with `.contentShape(Rectangle())`
- show selection state in one consistent corner or border treatment
- keep hover/focus/pressed states subtle but visible
- avoid stacking too many overlays on every item

For multi-select grids, prefer clear selection affordances instead of hidden
state changes triggered only by long press.

## Performance guardrails

- Use `LazyVGrid` for large collections.
- Keep overlay count low in every cell.
- Downsample large images before display.
- Avoid expensive formatting or filtering in cell bodies.
- Prefer stable item identity in `ForEach`.
- Precompute grouped or filtered collections before rendering.

If scrolling stutters, profile image decoding, per-cell overlays, and repeated
state invalidation before changing the grid structure itself.

## Accessibility and polish

- Maintain clear visual grouping and consistent spacing.
- Test with Dynamic Type even if cells are primarily visual.
- Ensure VoiceOver labels describe the item and selection state.
- Use meaningful focus order on iPad and keyboard-driven flows.
- Avoid tiny hit targets even when cells are visually dense.

A dense grid should still feel calm and legible, not like a wall of competing
badges and borders.

## Pitfalls

- Avoid heavy overlays in every grid cell; it can be expensive.
- Don’t nest grids inside other grids without a clear reason.
- Don’t put filtering logic inline in `ForEach`.
- Don’t use fixed columns where adaptive columns better match the product goal.
- **Never place `GeometryReader` inside lazy containers** (`LazyVGrid`,
  `LazyHGrid`, `LazyVStack`, `LazyHStack`). It forces eager measurement and
  defeats lazy loading. Use `.aspectRatio` for sizing, or `.onGeometryChange`
  (iOS 18+) if you need to read dimensions.
