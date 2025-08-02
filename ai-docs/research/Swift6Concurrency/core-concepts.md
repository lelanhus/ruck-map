# Swift 6 Concurrency Core Concepts

## Actor Model

### Actor Isolation
```swift
actor DataStore {
    private var sessions: [RuckSession] = []
    
    func add(_ session: RuckSession) {
        sessions.append(session)
    }
    
    func getAll() -> [RuckSession] {
        sessions
    }
}
```

### Global Actors
```swift
@MainActor
class SessionViewModel: ObservableObject {
    @Published var currentSession: RuckSession?
    
    func updateUI() {
        // Guaranteed to run on main thread
    }
}

// Custom global actor
@globalActor
actor BackgroundActor {
    static let shared = BackgroundActor()
}
```

## Structured Concurrency

### Task Groups
```swift
func processWaypoints(_ waypoints: [Waypoint]) async throws -> [ProcessedWaypoint] {
    try await withThrowingTaskGroup(of: ProcessedWaypoint.self) { group in
        for waypoint in waypoints {
            group.addTask {
                try await self.process(waypoint)
            }
        }
        
        var results: [ProcessedWaypoint] = []
        for try await result in group {
            results.append(result)
        }
        return results
    }
}
```

### Task Cancellation
```swift
class LocationTracker {
    private var trackingTask: Task<Void, Never>?
    
    func startTracking() {
        trackingTask = Task {
            while !Task.isCancelled {
                await updateLocation()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    func stopTracking() {
        trackingTask?.cancel()
    }
}
```

## Sendable Protocol

### Basic Sendable Conformance
```swift
struct SessionData: Sendable {
    let id: UUID
    let distance: Double
    let calories: Double
}

final class ImmutableSession: Sendable {
    let id: UUID
    let startDate: Date
    
    init(id: UUID, startDate: Date) {
        self.id = id
        self.startDate = startDate
    }
}
```

### @unchecked Sendable
```swift
final class LocationCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [UUID: CLLocation] = [:]
    
    func set(_ location: CLLocation, for id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        cache[id] = location
    }
    
    func get(_ id: UUID) -> CLLocation? {
        lock.lock()
        defer { lock.unlock() }
        return cache[id]
    }
}
```

## AsyncSequence

### Custom AsyncSequence
```swift
struct LocationStream: AsyncSequence {
    typealias Element = CLLocation
    
    struct AsyncIterator: AsyncIteratorProtocol {
        let locationManager: CLLocationManager
        
        mutating func next() async -> CLLocation? {
            await withCheckedContinuation { continuation in
                // Setup location update handler
                continuation.resume(returning: location)
            }
        }
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(locationManager: CLLocationManager())
    }
}

// Usage
for await location in LocationStream() {
    print("New location: \(location)")
}
```

### AsyncStream
```swift
func heartRateStream() -> AsyncStream<Double> {
    AsyncStream { continuation in
        let healthStore = HKHealthStore()
        
        // Setup heart rate observer
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { _, _, error in
            if let error = error {
                continuation.finish(throwing: error)
                return
            }
            
            // Fetch latest heart rate
            continuation.yield(heartRate)
        }
        
        healthStore.execute(query)
        
        continuation.onTermination = { _ in
            healthStore.stop(query)
        }
    }
}
```

## Continuation Patterns

### withCheckedContinuation
```swift
func fetchWeather() async throws -> WeatherData {
    try await withCheckedThrowingContinuation { continuation in
        WeatherKit.shared.weather(for: location) { result in
            switch result {
            case .success(let weather):
                continuation.resume(returning: weather)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}
```

### withTaskCancellationHandler
```swift
func longRunningOperation() async throws {
    try await withTaskCancellationHandler {
        try await performWork()
    } onCancel: {
        cleanup()
    }
}
```

## Key Swift 6 Features

1. **Complete Data Race Safety**: Enabled by default with strict checking
2. **Improved Actor Performance**: Better scheduling and lower overhead
3. **Enhanced Diagnostics**: Clearer error messages for concurrency issues
4. **Sendable Inference**: Better automatic Sendable conformance
5. **Isolated Parameters**: New `isolated` parameter syntax

## Migration Tips

1. Enable strict concurrency checking gradually:
   ```swift
   // In Package.swift or build settings
   .enableExperimentalFeature("StrictConcurrency=targeted")
   ```

2. Fix Sendable warnings systematically
3. Use `@preconcurrency` for legacy code
4. Leverage `@MainActor.assumeIsolated` for UI code
5. Test thoroughly with Thread Sanitizer enabled