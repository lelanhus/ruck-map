# SwiftUI State Management Guide

## Overview

State management is the heart of SwiftUI applications. This guide covers all state management tools, their lifecycle, and best practices for iOS 18+.

## State Property Wrappers

### @State

**Purpose**: Local, view-owned state for value types

```swift
struct RuckTimerView: View {
    @State private var elapsedTime: TimeInterval = 0
    @State private var isRunning = false
    @State private var timer: Timer?
    
    var body: some View {
        VStack {
            Text(timeString(from: elapsedTime))
                .font(.largeTitle)
            
            Button(isRunning ? "Stop" : "Start") {
                isRunning.toggle()
                isRunning ? startTimer() : stopTimer()
            }
        }
    }
}
```

**Key Points**:
- Always mark as `private`
- Survives view updates
- Use for simple, view-local state
- Automatically animatable

### @StateObject vs @State with @Observable

**iOS 17+ (Recommended)**:
```swift
@Observable
class LocationTracker {
    var currentLocation: CLLocation?
    var isTracking = false
}

struct MapView: View {
    @State private var tracker = LocationTracker()  // Use @State with @Observable
    
    var body: some View {
        // View implementation
    }
}
```

**Legacy (iOS 16 and below)**:
```swift
class LocationTracker: ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var isTracking = false
}

struct MapView: View {
    @StateObject private var tracker = LocationTracker()  // Use @StateObject
    
    var body: some View {
        // View implementation
    }
}
```

### @Binding

**Purpose**: Two-way connection to state owned elsewhere

```swift
struct WeightInputView: View {
    @Binding var weight: Double
    
    var body: some View {
        VStack {
            Text("Ruck Weight: \(weight, specifier: "%.1f") lbs")
            Slider(value: $weight, in: 0...100, step: 5)
        }
    }
}

// Parent view
struct RuckSetupView: View {
    @State private var ruckWeight: Double = 35.0
    
    var body: some View {
        WeightInputView(weight: $ruckWeight)
    }
}
```

### @Environment

**Purpose**: Access system-wide values and injected dependencies

```swift
// System values
struct RuckView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        // View implementation
    }
}

// Custom environment values
struct DataControllerKey: EnvironmentKey {
    static let defaultValue = DataController()
}

extension EnvironmentValues {
    var dataController: DataController {
        get { self[DataControllerKey.self] }
        set { self[DataControllerKey.self] = newValue }
    }
}
```

### @AppStorage

**Purpose**: Automatic UserDefaults synchronization

```swift
struct SettingsView: View {
    @AppStorage("preferredUnits") private var preferredUnits = "miles"
    @AppStorage("defaultRuckWeight") private var defaultWeight = 35.0
    @AppStorage("enableHaptics") private var enableHaptics = true
    
    var body: some View {
        Form {
            Picker("Units", selection: $preferredUnits) {
                Text("Miles").tag("miles")
                Text("Kilometers").tag("km")
            }
            
            HStack {
                Text("Default Weight")
                Spacer()
                Text("\(defaultWeight, specifier: "%.0f") lbs")
            }
            
            Toggle("Haptic Feedback", isOn: $enableHaptics)
        }
    }
}
```

### @SceneStorage

**Purpose**: State restoration for scene-specific data

```swift
struct RuckMapView: View {
    @SceneStorage("mapRegion") private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @SceneStorage("selectedTab") private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab content
        }
    }
}
```

## The @Observable Macro

### Migration from ObservableObject

**Before (ObservableObject)**:
```swift
class RuckSession: ObservableObject {
    @Published var distance: Double = 0
    @Published var duration: TimeInterval = 0
    @Published var calories: Int = 0
    
    // All properties trigger updates when changed
}
```

**After (@Observable)**:
```swift
@Observable
class RuckSession {
    var distance: Double = 0
    var duration: TimeInterval = 0
    var calories: Int = 0
    
    // Only accessed properties trigger updates
}
```

### Performance Benefits

```swift
@Observable
class PerformanceExample {
    var frequentlyUpdated = 0  // Updates every second
    var rarelyAccessed = 0     // Updates rarely
    
    // View that only uses rarelyAccessed won't update
    // when frequentlyUpdated changes
}

struct OptimizedView: View {
    let model: PerformanceExample
    
    var body: some View {
        // This view only updates when rarelyAccessed changes
        Text("Value: \(model.rarelyAccessed)")
    }
}
```

## Advanced State Management Patterns

### Derived State

```swift
@Observable
class RuckingStats {
    var totalDistance: Double = 0
    var totalTime: TimeInterval = 0
    var totalCalories: Int = 0
    
    // Computed properties for derived state
    var averagePace: Double {
        guard totalTime > 0 else { return 0 }
        return totalDistance / (totalTime / 3600)
    }
    
    var caloriesPerMile: Double {
        guard totalDistance > 0 else { return 0 }
        return Double(totalCalories) / totalDistance
    }
}
```

### State Composition

```swift
@Observable
class AppState {
    var user = UserState()
    var session = SessionState()
    var settings = SettingsState()
}

@Observable
class UserState {
    var profile: UserProfile?
    var isAuthenticated = false
}

@Observable
class SessionState {
    var activeRuck: RuckSession?
    var recentRucks: [RuckSession] = []
}
```

### Async State Updates

```swift
@Observable
class WeatherService {
    var currentWeather: Weather?
    var isLoading = false
    var error: Error?
    
    func fetchWeather() async {
        isLoading = true
        error = nil
        
        do {
            currentWeather = try await weatherAPI.fetchCurrent()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

struct WeatherView: View {
    @State private var weather = WeatherService()
    
    var body: some View {
        Group {
            if weather.isLoading {
                ProgressView()
            } else if let error = weather.error {
                ErrorView(error: error)
            } else if let current = weather.currentWeather {
                WeatherDisplay(weather: current)
            }
        }
        .task {
            await weather.fetchWeather()
        }
    }
}
```

## Memory Management

### Avoiding Retain Cycles

```swift
@Observable
class DataManager {
    var items: [Item] = []
    
    func processItems() {
        Task { [weak self] in
            guard let self else { return }
            // Process items without creating retain cycle
            let processed = await self.heavyProcessing()
            self.items = processed
        }
    }
}
```

### State Lifecycle

```swift
struct LifecycleView: View {
    // Created once, survives view updates
    @State private var persistentState = 0
    
    // Created fresh on each parent update (if not @State)
    let computedValue = expensive()
    
    var body: some View {
        VStack {
            Text("Persistent: \(persistentState)")
            Button("Increment") {
                persistentState += 1
            }
        }
        .onAppear {
            // Called on view appearance
        }
        .onDisappear {
            // Clean up if needed
        }
    }
}
```

## Testing State Management

### Unit Testing @Observable Classes

```swift
@Test
func testRuckSessionCalculations() async {
    let session = RuckSession()
    
    session.distance = 3.0  // miles
    session.duration = 3600 // 1 hour
    session.weightCarried = 45.0
    
    #expect(session.pace == 3.0)
    #expect(session.caloriesPerHour > 0)
}
```

### Testing with Dependencies

```swift
@Test
func testLocationTracking() async {
    let tracker = LocationTracker()
    let mockLocationManager = MockLocationManager()
    
    tracker.locationManager = mockLocationManager
    
    await tracker.startTracking()
    
    mockLocationManager.sendMockLocation(
        CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
    
    #expect(tracker.currentLocation != nil)
}
```

## Best Practices

### 1. State Scope
```swift
// ✅ Good: Minimal state scope
struct RuckCard: View {
    let ruck: RuckSession  // Read-only data
    @Binding var isFavorite: Bool  // Only mutable state needed
}

// ❌ Bad: Too much state
struct RuckCard: View {
    @StateObject var appState: AppState  // Entire app state
}
```

### 2. State Initialization
```swift
// ✅ Good: Proper initialization
@State private var weight = UserDefaults.standard.double(forKey: "lastWeight")

// ❌ Bad: Complex initialization in view
@State private var data = fetchDataSynchronously()  // Blocks UI
```

### 3. State Updates
```swift
// ✅ Good: Batch updates
@Observable
class BatchExample {
    var items: [Item] = []
    
    func updateMultiple() {
        // Single update notification
        items = processedItems()
    }
}

// ❌ Bad: Multiple updates
func updateMultiple() {
    for i in 0..<items.count {
        items[i].process()  // Triggers update each time
    }
}
```

## Performance Optimization

### 1. Computed Property Caching
```swift
@Observable
class OptimizedModel {
    var sourceData: [DataPoint] = []
    private var _processedCache: ProcessedData?
    
    var processed: ProcessedData {
        if let cached = _processedCache {
            return cached
        }
        let result = expensiveProcessing(sourceData)
        _processedCache = result
        return result
    }
    
    func invalidateCache() {
        _processedCache = nil
    }
}
```

### 2. View Update Optimization
```swift
// Use EquatableView for expensive views
struct ExpensiveChart: View, Equatable {
    let dataPoints: [DataPoint]
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.dataPoints.count == rhs.dataPoints.count
    }
    
    var body: some View {
        // Expensive chart rendering
    }
}

// Usage
ExpensiveChart(dataPoints: data)
    .equatable()
```

## Debugging State Issues

### 1. State Change Tracking
```swift
@Observable
class DebugModel {
    var value: Int = 0 {
        didSet {
            print("Value changed from \(oldValue) to \(value)")
        }
    }
}
```

### 2. SwiftUI View Updates
```swift
struct DebugView: View {
    @State private var counter = 0
    
    var body: some View {
        let _ = Self._printChanges()  // Prints why view updated
        
        Text("Counter: \(counter)")
    }
}
```

## Conclusion

Modern SwiftUI state management with @Observable provides superior performance and simpler code compared to ObservableObject. Key takeaways:

1. Use @State with @Observable for reference types
2. Leverage automatic dependency tracking for performance
3. Keep state scoped appropriately
4. Test state changes independently from views
5. Monitor and optimize view updates

The combination of SwiftUI's reactive system and the @Observable macro creates a powerful, efficient state management system that scales from simple views to complex applications.