# Focus Patterns Reference

## Contents
- FocusState patterns
- Default focus
- Focused values and scene values
- Focusable custom views
- Focus sections for directional movement (macOS/tvOS)
- Focus restoration after presentations
- UIKit focus guides
- Common mistakes checklist

## FocusState patterns

```swift
struct CheckoutForm: View {
    enum Field: Hashable { case address, city, postalCode }

    @State private var address = ""
    @State private var city = ""
    @State private var postalCode = ""
    @FocusState private var focusedField: Field?

    var body: some View {
        Form {
            TextField("Address", text: $address)
                .focused($focusedField, equals: .address)
                .onSubmit { focusedField = .city }

            TextField("City", text: $city)
                .focused($focusedField, equals: .city)
                .onSubmit { focusedField = .postalCode }

            TextField("Postal Code", text: $postalCode)
                .focused($focusedField, equals: .postalCode)
        }
        .onAppear { focusedField = .address }
    }
}
```

Use `Bool` focus state only for one-off cases. Prefer a `Hashable` enum when more than one control can be focused.

## Default focus

```swift
struct CommandPaletteView: View {
    enum Target: Hashable { case search }
    @FocusState private var target: Target?

    var body: some View {
        VStack {
            TextField("Search commands", text: $query)
                .focused($target, equals: .search)
        }
        .defaultFocus($target, .search)
    }
}
```

Choose one unambiguous default target. Competing defaults make focus feel unstable.

## Focused values and scene values

```swift
struct SelectedDocumentKey: FocusedValueKey {
    typealias Value = Binding<Document>
}

extension FocusedValues {
    var selectedDocument: Binding<Document>? {
        get { self[SelectedDocumentKey.self] }
        set { self[SelectedDocumentKey.self] = newValue }
    }
}

struct DocumentEditor: View {
    @Binding var document: Document

    var body: some View {
        TextEditor(text: $document.body)
            .focusedSceneValue(\.selectedDocument, $document)
    }
}
```

Use focused scene values when command menus, toolbar actions, or scene-level controls need access to the current focused content.

## Focusable custom views

```swift
struct TVCardButton: View {
    let title: String
    let action: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 16)
                .fill(isFocused ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                .overlay { Text(title) }
        }
        .buttonStyle(.plain)
        .focusable(interactions: .activate)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.04 : 1.0)
        .animation(.snappy, value: isFocused)
    }
}
```

Prefer semantic controls like `Button` first. Add `.focusable(interactions:)` only when the custom control needs explicit focus participation.
Do not make arbitrary gesture-only views the primary action target on tvOS or keyboard-driven interfaces; expose the action through a semantic control or a custom control with explicit focus and activation behavior.

## Focus sections for directional movement

`focusSection()` is available on macOS 13+ and tvOS 15+.

```swift
struct LibraryView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Button("Recent") { }
                Button("Favorites") { }
                Button("Downloaded") { }
            }
            .focusSection()

            LazyVGrid(columns: columns) {
                ForEach(items) { item in
                    Button(item.title) { open(item) }
                }
            }
            .focusSection()
        }
    }
}
```

Use `focusSection()` on macOS or tvOS when the user should move through one group before jumping into another.

## Focus restoration after presentations

```swift
struct SearchFiltersView: View {
    @State private var isPresentingFilters = false
    @FocusState private var isFiltersButtonFocused: Bool

    var body: some View {
        Button("Filters") {
            isPresentingFilters = true
        }
        .focused($isFiltersButtonFocused)
        .sheet(isPresented: $isPresentingFilters) {
            FiltersSheet()
                .onDisappear {
                    Task { @MainActor in
                        isFiltersButtonFocused = true
                    }
                }
        }
    }
}
```

Restore focus to the trigger or to the next logical destination after dismissing temporary UI.

## UIKit focus guides

```swift
final class PlayerViewController: UIViewController {
    private let skipGuide = UIFocusGuide()
    @IBOutlet private weak var playButton: UIButton!
    @IBOutlet private weak var nextEpisodeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addLayoutGuide(skipGuide)
        skipGuide.preferredFocusEnvironments = [nextEpisodeButton]

        NSLayoutConstraint.activate([
            skipGuide.leadingAnchor.constraint(equalTo: playButton.trailingAnchor),
            skipGuide.trailingAnchor.constraint(equalTo: nextEpisodeButton.leadingAnchor),
            skipGuide.topAnchor.constraint(equalTo: playButton.topAnchor),
            skipGuide.bottomAnchor.constraint(equalTo: playButton.bottomAnchor)
        ])
    }
}
```

A focus guide is an invisible layout guide. Constrain it like any other layout guide, then set `preferredFocusEnvironments` to the destination views.

## Common mistakes checklist

- Using shared model state to drive `@FocusState`
- Forgetting to restore focus after dismissing transient UI
- Making decorative containers focusable
- Adding multiple defaults to the same focus region
- Using UIKit focus guides for layouts SwiftUI can solve with `focusSection()`
- Publishing scene-focused values that should only be view-local
