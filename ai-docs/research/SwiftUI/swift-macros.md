# Swift Macros in SwiftUI

## Overview

Swift macros, introduced in Swift 5.9, provide powerful compile-time code generation capabilities. This guide focuses on SwiftUI-specific macros and creating custom macros for iOS development.

## Built-in SwiftUI Macros

### @Observable Macro

The most significant macro for SwiftUI development, replacing ObservableObject.

```swift
import Observation

// Before expansion
@Observable
class RuckViewModel {
    var distance: Double = 0
    var duration: TimeInterval = 0
    var isActive = false
    
    var pace: Double {
        guard duration > 0 else { return 0 }
        return distance / (duration / 3600)
    }
}

// After macro expansion (simplified)
class RuckViewModel {
    @ObservationTracked var distance: Double = 0
    @ObservationTracked var duration: TimeInterval = 0
    @ObservationTracked var isActive = false
    
    var pace: Double {
        guard duration > 0 else { return 0 }
        return distance / (duration / 3600)
    }
    
    // Generated observation tracking code
    internal let _$observationRegistrar = ObservationRegistrar()
    
    internal func access<T>(_ keyPath: KeyPath<RuckViewModel, T>) {
        _$observationRegistrar.access(self, keyPath: keyPath)
    }
    
    internal func withMutation<T>(_ keyPath: KeyPath<RuckViewModel, T>, _ mutation: () throws -> T) rethrows -> T {
        _$observationRegistrar.withMutation(self, keyPath: keyPath, mutation)
    }
}
```

### @Model Macro (SwiftData)

For persistent data models in SwiftUI apps.

```swift
import SwiftData

@Model
class RuckSession {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var distance: Double
    var weight: Double
    var route: [LocationPoint]
    var notes: String
    
    init(startDate: Date = .now, weight: Double = 35.0) {
        self.id = UUID()
        self.startDate = startDate
        self.distance = 0
        self.weight = weight
        self.route = []
        self.notes = ""
    }
}

// The @Model macro generates:
// - Persistence metadata
// - Change tracking
// - Relationship management
// - Query capabilities
```

### @Entry Macro (Widget Kit)

For widget configuration entries.

```swift
import WidgetKit

@Entry
struct RuckWidgetEntry: TimelineEntry {
    let date: Date
    let ruckData: RuckSummary
    let nextRuckTime: Date?
}

// Generates conformance and required implementations
```

## Creating Custom Macros

### Expression Macros

```swift
// Define a macro for creating SF Symbol configurations
@freestanding(expression)
public macro SFSymbol(_ name: String, pointSize: Double = 17, weight: Font.Weight = .regular) -> Image = #externalMacro(
    module: "RuckMacros",
    type: "SFSymbolMacro"
)

// Usage
struct IconView: View {
    var body: some View {
        VStack {
            #SFSymbol("figure.walk", pointSize: 24, weight: .bold)
            #SFSymbol("map.fill", pointSize: 20)
            #SFSymbol("chart.line.uptrend.xyaxis")
        }
    }
}

// Implementation
public struct SFSymbolMacro: ExpressionMacro {
    public static func expansion(
        of node: some AttributeSyntax,
        providingExpressionsFor expression: some ExprSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        // Parse arguments and generate Image code
        return """
        Image(systemName: \(name))
            .font(.system(size: \(pointSize), weight: \(weight)))
            .symbolRenderingMode(.hierarchical)
        """
    }
}
```

### Attached Macros

```swift
// Create a macro for view styling
@attached(member)
@attached(conformance)
public macro StyledView(
    padding: Double = 16,
    cornerRadius: Double = 12,
    shadow: Bool = true
) = #externalMacro(module: "RuckMacros", type: "StyledViewMacro")

// Usage
@StyledView(padding: 20, cornerRadius: 16, shadow: true)
struct RuckCard: View {
    let session: RuckSession
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(session.formattedDate)
            Text("\(session.distance, specifier: "%.2f") miles")
        }
    }
}

// Macro generates:
extension RuckCard: StyledViewProtocol {
    var styledBody: some View {
        body
            .padding(20)
            .background(Color.secondarySystemBackground)
            .cornerRadius(16)
            .shadow(radius: 4)
    }
}
```

### Property Wrapper Macros

```swift
// Create a UserDefaults property wrapper with macro
@attached(accessor)
public macro AppStorage<T>(
    _ key: String,
    defaultValue: T
) = #externalMacro(module: "RuckMacros", type: "AppStorageMacro")

// Usage
struct Settings {
    @AppStorage("preferredUnits", defaultValue: "miles")
    var preferredUnits: String
    
    @AppStorage("defaultWeight", defaultValue: 35.0)
    var defaultWeight: Double
}

// Generates getters and setters with UserDefaults
```

## Performance Optimization Macros

### Memoization Macro

```swift
@attached(peer)
public macro Memoized() = #externalMacro(
    module: "RuckMacros",
    type: "MemoizedMacro"
)

struct CalculationView: View {
    let data: [RuckSession]
    
    @Memoized
    func calculateStatistics() -> Statistics {
        // Expensive calculation
        return Statistics(sessions: data)
    }
    
    var body: some View {
        let stats = calculateStatistics()
        StatisticsView(stats: stats)
    }
}

// Generates caching logic:
private var _calculateStatisticsCache: Statistics?
private var _calculateStatisticsCacheKey: Int?

func calculateStatistics() -> Statistics {
    let key = data.hashValue
    if let cached = _calculateStatisticsCache,
       _calculateStatisticsCacheKey == key {
        return cached
    }
    
    let result = // Original calculation
    _calculateStatisticsCache = result
    _calculateStatisticsCacheKey = key
    return result
}
```

### Dependency Injection Macro

```swift
@attached(member)
public macro Injectable() = #externalMacro(
    module: "RuckMacros",
    type: "InjectableMacro"
)

@Injectable
class LocationService {
    func startTracking() { /* ... */ }
    func stopTracking() { /* ... */ }
}

// Usage in views
struct MapView: View {
    @Injected var locationService: LocationService
    
    var body: some View {
        // Use locationService
    }
}
```

## SwiftUI-Specific Utility Macros

### View Modifier Macro

```swift
@freestanding(expression)
public macro ArmyThemed<Content: View>(
    _ content: Content
) -> some View = #externalMacro(
    module: "RuckMacros",
    type: "ArmyThemedMacro"
)

// Usage
struct ThemedView: View {
    var body: some View {
        #ArmyThemed(
            VStack {
                Text("RUCK TRACKER")
                Text("Mission Ready")
            }
        )
    }
}

// Expands to:
VStack {
    Text("RUCK TRACKER")
    Text("Mission Ready")
}
.foregroundColor(.armyGreen)
.font(.custom("StencilStd", size: 17))
.textCase(.uppercase)
```

### Environment Value Macro

```swift
@attached(member, names: named(EnvironmentKey), named(EnvironmentValues))
public macro EnvironmentValue<T>(
    _ keyName: String,
    defaultValue: T
) = #externalMacro(
    module: "RuckMacros",
    type: "EnvironmentValueMacro"
)

@EnvironmentValue("ruckTheme", defaultValue: .standard)
enum RuckTheme {
    case standard
    case highContrast
    case night
}

// Generates all the boilerplate:
private struct RuckThemeKey: EnvironmentKey {
    static let defaultValue: RuckTheme = .standard
}

extension EnvironmentValues {
    var ruckTheme: RuckTheme {
        get { self[RuckThemeKey.self] }
        set { self[RuckThemeKey.self] = newValue }
    }
}
```

## Testing with Macros

### Test Generation Macro

```swift
@attached(peer, names: prefixed(test))
public macro TestCase() = #externalMacro(
    module: "RuckMacros",
    type: "TestCaseMacro"
)

@TestCase
func calculatePace(distance: Double, duration: TimeInterval) -> Double {
    guard duration > 0 else { return 0 }
    return distance / (duration / 3600)
}

// Generates:
func testCalculatePace() {
    XCTAssertEqual(calculatePace(distance: 3.0, duration: 3600), 3.0)
    XCTAssertEqual(calculatePace(distance: 0, duration: 3600), 0)
    XCTAssertEqual(calculatePace(distance: 5.0, duration: 0), 0)
}
```

## Macro Best Practices

### 1. Type Safety

```swift
// Good: Type-safe macro
@freestanding(expression)
public macro LocalizedString(
    _ key: String,
    comment: String = ""
) -> LocalizedStringKey = #externalMacro(
    module: "RuckMacros",
    type: "LocalizedStringMacro"
)

// Usage
Text(#LocalizedString("ruck.start", comment: "Button to start ruck"))
```

### 2. Error Handling

```swift
public struct ValidationMacro: ExpressionMacro {
    public static func expansion(
        of node: some AttributeSyntax,
        providingExpressionsFor expression: some ExprSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        // Validate inputs
        guard let arguments = node.argument?.as(TupleExprElementListSyntax.self),
              arguments.count >= 1 else {
            throw MacroError.invalidArguments
        }
        
        // Generate code with proper error handling
        return """
        do {
            try validate(\(arguments))
        } catch {
            assertionFailure("Validation failed: \\(error)")
        }
        """
    }
}
```

### 3. Debugging Support

```swift
// Add debug information to generated code
@attached(member)
public macro Traceable() = #externalMacro(
    module: "RuckMacros",
    type: "TraceableMacro"
)

@Traceable
class DataManager {
    func fetchData() async throws -> [RuckSession] {
        // Implementation
    }
}

// Generates with debug support:
func fetchData() async throws -> [RuckSession] {
    #if DEBUG
    print("[TRACE] \(#function) called at \(Date())")
    defer { print("[TRACE] \(#function) completed") }
    #endif
    
    // Original implementation
}
```

## Migration from Property Wrappers

### Converting ObservableObject to @Observable

```swift
// Before: Property Wrapper
class OldViewModel: ObservableObject {
    @Published var value = 0
    @Published var isLoading = false
}

// After: Macro
@Observable
class NewViewModel {
    var value = 0
    var isLoading = false
}
```

### Custom Property Wrapper to Macro

```swift
// Before: Property Wrapper
@propertyWrapper
struct Validated<Value> {
    var wrappedValue: Value {
        didSet { validate() }
    }
    let validator: (Value) -> Bool
}

// After: Macro
@attached(accessor)
public macro Validated<T>(
    _ validator: (T) -> Bool
) = #externalMacro(module: "RuckMacros", type: "ValidatedMacro")

// Usage remains similar
struct Form {
    @Validated({ $0 > 0 })
    var weight: Double = 35.0
}
```

## Performance Considerations

### Compile-Time vs Runtime

```swift
// Compile-time (Macro) - No runtime overhead
#Preview {
    RuckView()
        .environment(\.ruckData, .preview)
}

// Runtime (Function) - Has overhead
func preview() -> some View {
    RuckView()
        .environment(\.ruckData, .preview)
}
```

### Code Size Impact

```swift
// Be mindful of generated code size
@attached(member, names: arbitrary)
public macro GenerateBoilerplate() = #externalMacro(
    module: "RuckMacros",
    type: "BoilerplateMacro"
)

// Only use when it reduces overall code size
@GenerateBoilerplate
struct LargeDataModel {
    // Generates hundreds of lines of boilerplate
}
```

## Debugging Macros

### Expanding Macros in Xcode

```swift
// Right-click on macro usage and select "Expand Macro"
@Observable
class ViewModel {
    var value = 0
}

// See the expanded code in Xcode
```

### Macro Diagnostics

```swift
public struct DiagnosticMacro: ExpressionMacro {
    public static func expansion(
        of node: some AttributeSyntax,
        providingExpressionsFor expression: some ExprSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        // Add diagnostics for better error messages
        context.diagnose(
            Diagnostic(
                node: node,
                message: MacroDiagnostic.customMessage("Consider using @Observable instead")
            )
        )
        
        return expression
    }
}
```

## Future of Macros in SwiftUI

### Upcoming Features

1. **Parameter Packs**: More flexible macro arguments
2. **Type Parameter Macros**: Generic macro support
3. **Incremental Compilation**: Faster macro processing
4. **IDE Integration**: Better debugging and visualization

### Potential Use Cases

```swift
// Automatic SwiftUI preview generation
@AutoPreview
struct ComplexView: View { /* ... */ }

// Accessibility compliance checking
@AccessibilityCompliant
struct AccessibleView: View { /* ... */ }

// Performance monitoring
@PerformanceTracked
struct OptimizedView: View { /* ... */ }
```

## Conclusion

Swift macros represent a powerful evolution in Swift development:

1. **Reduce boilerplate** while maintaining type safety
2. **Improve performance** through compile-time code generation
3. **Enhance developer experience** with domain-specific abstractions
4. **Enable new patterns** not possible with runtime approaches

Key takeaways:
- Use built-in macros like @Observable for modern SwiftUI development
- Create custom macros for repetitive patterns in your codebase
- Always prioritize readability and maintainability
- Test macro expansions thoroughly
- Stay updated with Swift evolution proposals for new macro capabilities