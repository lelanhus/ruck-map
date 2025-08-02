# SwiftUI Quick Reference Guide

## Architecture Patterns

### MV Pattern (Recommended for iOS 17+)
```swift
@Observable
class Model {
    var property = value
}

struct View: View {
    @State private var model = Model()
    var body: some View { /* ... */ }
}
```

### State Management Quick Reference

| Property Wrapper | Use Case | Ownership | iOS Version |
|-----------------|----------|-----------|-------------|
| `@State` | Local view state | View owns | All |
| `@Binding` | Two-way binding | Parent owns | All |
| `@StateObject` | Reference type (legacy) | View owns | iOS 14+ |
| `@ObservedObject` | Reference type (legacy) | External owns | All |
| `@State` + `@Observable` | Reference type (modern) | View owns | iOS 17+ |
| `@Environment` | System/custom values | System owns | All |
| `@AppStorage` | UserDefaults | Persistent | iOS 14+ |
| `@SceneStorage` | Scene state | Scene owns | iOS 14+ |

## Common Patterns

### Navigation
```swift
// Modern navigation (iOS 16+)
NavigationStack(path: $path) {
    ContentView()
        .navigationDestination(for: Type.self) { item in
            DetailView(item: item)
        }
}
```

### Async Data Loading
```swift
struct DataView: View {
    @State private var data: [Item] = []
    
    var body: some View {
        List(data) { item in
            ItemRow(item: item)
        }
        .task {
            data = await fetchData()
        }
    }
}
```

### Sheet Presentation
```swift
.sheet(isPresented: $showingSheet) {
    SheetContent()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
```

### Animation
```swift
// Implicit
.animation(.spring(), value: property)

// Explicit
withAnimation(.spring()) {
    property = newValue
}
```

## Performance Tips

1. **Use `LazyVStack/LazyHStack`** for large lists
2. **Animate transforms** not frames: `.scaleEffect()` over `.frame()`
3. **Cache expensive computations** in `@State` variables
4. **Use `EquatableView`** for complex views that rarely change
5. **Avoid `AnyView`** when possible

## Accessibility Checklist

- [ ] Add `.accessibilityLabel()` to all interactive elements
- [ ] Use `.accessibilityHint()` for complex actions
- [ ] Test with VoiceOver enabled
- [ ] Support Dynamic Type with `.font(.body)`
- [ ] Ensure 4.5:1 color contrast ratio
- [ ] Test with Reduce Motion enabled

## Common Modifiers

### Layout
```swift
.frame(width:, height:)
.padding()
.offset(x:, y:)
.position(x:, y:)
.alignmentGuide()
```

### Styling
```swift
.foregroundColor()
.background()
.cornerRadius()
.shadow()
.opacity()
```

### Interaction
```swift
.onTapGesture {}
.onLongPressGesture {}
.gesture(DragGesture())
.allowsHitTesting()
.disabled()
```

### Animation
```swift
.animation(_, value:)
.transition()
.scaleEffect()
.rotationEffect()
.matchedGeometryEffect()
```

## iOS 18 Features

- `NavigationStack` with type-safe navigation
- `@Observable` macro for models
- Enhanced `ScrollView` with `.scrollPosition()`
- `ContentUnavailableView` for empty states
- Improved `Charts` framework

## Liquid Glass (iOS 26) Preparation

```swift
// Use semantic materials
.background(.regularMaterial)

// Prepare for glass effects
if #available(iOS 26.0, *) {
    view.glassEffect(.adaptive)
} else {
    view.background(.ultraThinMaterial)
}
```

## Testing Quick Start

```swift
// Swift Testing
@Test("Test name")
func testSomething() {
    #expect(value == expected)
}

// Preview Testing
#Preview {
    MyView()
        .environment(\.locale, .init(identifier: "es"))
}

// UI Testing
app.buttons["identifier"].tap()
XCTAssertTrue(app.staticTexts["text"].exists)
```

## Debugging

```swift
// Print view updates
let _ = Self._printChanges()

// Debug preview
.border(Color.red)
.background(Color.blue.opacity(0.1))

// Performance
.drawingGroup() // For complex graphics
```

## Common Gotchas

1. **`@State` initialization**: Use `init()` not inline
2. **Navigation path type safety**: Use consistent types
3. **`ForEach` requires stable IDs**: Use `Identifiable`
4. **Environment values propagate down**: Not sideways
5. **Animations need value parameter**: `.animation(.spring(), value: property)`

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/swiftui)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [WWDC Videos](https://developer.apple.com/wwdc/)
- [Swift Forums](https://forums.swift.org/c/swiftui/)