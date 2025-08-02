# SwiftUI Architecture Patterns

## Overview

SwiftUI architecture patterns have evolved significantly with iOS 18 and the introduction of the @Observable macro. This guide covers the most effective patterns for production applications.

## MV (Model-View) Pattern

### Why MV Over MVVM?

The Model-View pattern has emerged as the preferred architecture for SwiftUI applications, replacing traditional MVVM. This shift is driven by:

- **SwiftUI's built-in reactivity** eliminates the need for explicit view models
- **@Observable macro** provides automatic, granular view updates
- **Simpler architecture** with fewer layers and less boilerplate
- **Better performance** through more efficient view updates

### Implementation

```swift
import SwiftUI
import Observation

@Observable
class RuckSession {
    var distance: Double = 0.0
    var duration: TimeInterval = 0
    var weightCarried: Double = 0.0
    var isActive = false
    
    var pace: Double {
        guard duration > 0 else { return 0 }
        return distance / (duration / 3600)
    }
    
    func start() {
        isActive = true
    }
    
    func stop() {
        isActive = false
    }
}

struct RuckingView: View {
    @State private var session = RuckSession()
    
    var body: some View {
        VStack {
            Text("Distance: \(session.distance, specifier: "%.2f") miles")
            Text("Pace: \(session.pace, specifier: "%.2f") mph")
            
            Button(session.isActive ? "Stop" : "Start") {
                session.isActive ? session.stop() : session.start()
            }
        }
    }
}
```

### Key Benefits

1. **Automatic Dependency Tracking**: Views only update when accessed properties change
2. **Simplified Testing**: Models can be tested independently
3. **Natural Swift Syntax**: No property wrappers on model properties
4. **Better Performance**: More granular updates than ObservableObject

## MVVM Pattern (Legacy)

While MVVM is being replaced by MV, understanding it is important for:
- Maintaining existing codebases
- Gradual migration strategies
- Team familiarity

### Traditional MVVM Implementation

```swift
// Legacy approach - still valid but not recommended for new projects
class RuckSessionViewModel: ObservableObject {
    @Published var distance: Double = 0.0
    @Published var duration: TimeInterval = 0
    @Published var isActive = false
    
    var pace: Double {
        guard duration > 0 else { return 0 }
        return distance / (duration / 3600)
    }
}

struct RuckingView: View {
    @StateObject private var viewModel = RuckSessionViewModel()
    
    var body: some View {
        // Similar implementation
    }
}
```

### Migration Path from MVVM to MV

1. Replace `ObservableObject` with `@Observable`
2. Remove all `@Published` property wrappers
3. Change `@StateObject` to `@State`
4. Update `@ObservedObject` to simple property passing
5. Replace `@EnvironmentObject` with `@Environment`

## The Composable Architecture (TCA)

TCA provides a robust, testable architecture for complex applications.

### When to Use TCA

- Large teams (5+ developers)
- Complex state management requirements
- High test coverage requirements
- Apps with complex side effects

### Basic TCA Structure

```swift
import ComposableArchitecture

@Reducer
struct RuckFeature {
    @ObservableState
    struct State: Equatable {
        var distance: Double = 0
        var isTracking = false
        var route: [CLLocationCoordinate2D] = []
    }
    
    enum Action {
        case startButtonTapped
        case stopButtonTapped
        case locationUpdated(CLLocation)
    }
    
    @Dependency(\.locationManager) var locationManager
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startButtonTapped:
                state.isTracking = true
                return .run { send in
                    for await location in locationManager.startTracking() {
                        await send(.locationUpdated(location))
                    }
                }
                
            case .stopButtonTapped:
                state.isTracking = false
                return .cancel(id: LocationTracking.self)
                
            case let .locationUpdated(location):
                state.route.append(location.coordinate)
                // Calculate distance...
                return .none
            }
        }
    }
}
```

### TCA Benefits

1. **100% Testable**: Every state change is predictable
2. **Time Travel Debugging**: Replay user actions
3. **Modular**: Features can be developed in isolation
4. **Type-Safe**: Compile-time guarantees for state changes

## Architecture Decision Matrix

| Factor | MV Pattern | MVVM | TCA |
|--------|------------|------|-----|
| **Learning Curve** | Low | Medium | High |
| **Boilerplate** | Minimal | Moderate | Significant |
| **Testability** | Good | Good | Excellent |
| **Team Size** | 1-5 | Any | 5+ |
| **Performance** | Excellent | Good | Good |
| **Debugging** | Standard | Standard | Advanced |
| **Modularity** | Good | Good | Excellent |

## Best Practices

### 1. Start Simple
- Begin with MV pattern for new projects
- Migrate to TCA only when complexity demands it
- Keep models focused and single-purpose

### 2. State Management
```swift
// ✅ Good: Focused model
@Observable
class RuckTimer {
    var elapsed: TimeInterval = 0
    var isRunning = false
}

// ❌ Bad: Kitchen sink model
@Observable
class AppState {
    var user: User?
    var ruckSession: RuckSession?
    var settings: Settings
    var networkStatus: NetworkStatus
    // Too much in one place
}
```

### 3. Dependency Injection
```swift
struct RuckMapApp: App {
    @State private var dataController = DataController()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dataController)
        }
    }
}
```

### 4. Testing Strategy
- Unit test models independently
- Use Preview-driven development for views
- Integration test user flows
- Snapshot test complex UI states

## Migration Guidelines

### From UIKit to SwiftUI
1. Don't port UIKit patterns directly
2. Embrace SwiftUI's declarative nature
3. Start with small, isolated features
4. Use UIViewRepresentable for gradual migration

### From ObservableObject to @Observable
```swift
// Before
class Model: ObservableObject {
    @Published var value = 0
}

// After
@Observable
class Model {
    var value = 0
}
```

## Performance Considerations

1. **View Identity**: Use stable IDs in ForEach
2. **Computed Properties**: Cache expensive calculations
3. **State Scope**: Keep state as local as possible
4. **Lazy Loading**: Use lazy containers for large lists

## Conclusion

The MV pattern with @Observable represents the future of SwiftUI architecture. It provides the right balance of simplicity, performance, and maintainability for most applications. Reserve TCA for complex applications where its benefits outweigh the additional complexity.