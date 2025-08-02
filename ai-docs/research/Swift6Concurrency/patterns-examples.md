# Swift 6 Concurrency Patterns & Examples

## Location Services with Actors

```swift
actor LocationService {
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    init() {
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        Task { @MainActor in
            locationManager.delegate = LocationDelegate(service: self)
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        if let location = currentLocation,
           location.timestamp.timeIntervalSinceNow > -5 {
            return location
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            Task { @MainActor in
                locationManager.requestLocation()
            }
        }
    }
    
    func updateLocation(_ location: CLLocation) {
        currentLocation = location
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }
}

@MainActor
class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private let service: LocationService
    
    init(service: LocationService) {
        self.service = service
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task {
            await service.updateLocation(location)
        }
    }
}
```

## Network Request Patterns

```swift
actor NetworkService {
    private let session = URLSession.shared
    private var activeTasks: [UUID: Task<Data, Error>] = [:]
    
    func fetchData(from url: URL) async throws -> Data {
        let taskID = UUID()
        
        let task = Task<Data, Error> {
            defer {
                Task {
                    await self.removeTask(taskID)
                }
            }
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.invalidResponse
            }
            
            return data
        }
        
        activeTasks[taskID] = task
        return try await task.value
    }
    
    private func removeTask(_ id: UUID) {
        activeTasks.removeValue(forKey: id)
    }
    
    func cancelAllRequests() {
        activeTasks.values.forEach { $0.cancel() }
        activeTasks.removeAll()
    }
}

enum NetworkError: Error {
    case invalidResponse
    case noData
}
```

## SwiftUI Integration

```swift
@MainActor
class RuckSessionViewModel: ObservableObject {
    @Published var sessions: [RuckSession] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let dataStore: DataStore
    private var loadTask: Task<Void, Never>?
    
    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }
    
    func loadSessions() {
        loadTask?.cancel()
        
        loadTask = Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                let fetchedSessions = try await dataStore.fetchAllSessions()
                
                // Check if task was cancelled
                try Task.checkCancellation()
                
                sessions = fetchedSessions
                error = nil
            } catch is CancellationError {
                // Handle cancellation silently
            } catch {
                self.error = error
            }
        }
    }
    
    func refresh() async {
        // Can be called from async context
        await loadSessions()
    }
}

// SwiftUI View
struct SessionListView: View {
    @StateObject private var viewModel: RuckSessionViewModel
    
    var body: some View {
        List(viewModel.sessions) { session in
            SessionRow(session: session)
        }
        .task {
            viewModel.loadSessions()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}
```

## Background Task Management

```swift
actor BackgroundTaskManager {
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var activeOperations: Set<UUID> = []
    
    func performBackgroundOperation<T>(
        operation: () async throws -> T
    ) async throws -> T {
        let operationID = UUID()
        activeOperations.insert(operationID)
        
        await beginBackgroundTask()
        
        defer {
            activeOperations.remove(operationID)
            if activeOperations.isEmpty {
                Task {
                    await endBackgroundTask()
                }
            }
        }
        
        return try await operation()
    }
    
    @MainActor
    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task { @MainActor in
                self?.backgroundTask = .invalid
            }
        }
    }
    
    @MainActor
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}

// Usage
let backgroundManager = BackgroundTaskManager()

func syncData() async throws {
    try await backgroundManager.performBackgroundOperation {
        try await dataStore.sync()
    }
}
```

## Data Race Prevention Examples

### Before (Swift 5 - Data Race)
```swift
class Counter {
    var value = 0
    
    func increment() {
        value += 1  // Data race when called from multiple threads
    }
}
```

### After (Swift 6 - Safe)
```swift
actor Counter {
    private var value = 0
    
    func increment() {
        value += 1  // Safe - actor provides synchronization
    }
    
    func getValue() -> Int {
        value
    }
}

// Alternative with lock
final class ThreadSafeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    
    func increment() {
        lock.withLock {
            value += 1
        }
    }
    
    func getValue() -> Int {
        lock.withLock { value }
    }
}
```

## Testing Async Code

```swift
import XCTest

class LocationServiceTests: XCTestCase {
    var locationService: LocationService!
    
    override func setUp() {
        locationService = LocationService()
    }
    
    func testGetCurrentLocation() async throws {
        // Arrange
        let expectedLocation = CLLocation(
            latitude: 37.7749,
            longitude: -122.4194
        )
        
        // Act
        let task = Task {
            try await locationService.getCurrentLocation()
        }
        
        // Simulate location update
        await locationService.updateLocation(expectedLocation)
        
        let location = try await task.value
        
        // Assert
        XCTAssertEqual(location.coordinate.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(location.coordinate.longitude, -122.4194, accuracy: 0.0001)
    }
    
    func testConcurrentRequests() async throws {
        // Test multiple concurrent location requests
        async let location1 = locationService.getCurrentLocation()
        async let location2 = locationService.getCurrentLocation()
        async let location3 = locationService.getCurrentLocation()
        
        // Simulate single location update
        let testLocation = CLLocation(latitude: 0, longitude: 0)
        await locationService.updateLocation(testLocation)
        
        // All requests should receive the same location
        let results = try await [location1, location2, location3]
        XCTAssertTrue(results.allSatisfy { $0 == testLocation })
    }
}
```

## Migration Checklist

1. **Enable Strict Concurrency**
   ```swift
   // swift-tools-version: 6.0
   .target(
       name: "RuckMap",
       swiftSettings: [
           .enableExperimentalFeature("StrictConcurrency")
       ]
   )
   ```

2. **Fix Sendable Warnings**
   - Make immutable types conform to Sendable
   - Use actors for mutable shared state
   - Apply @unchecked Sendable with proper synchronization

3. **Update Async Patterns**
   - Replace completion handlers with async/await
   - Use AsyncSequence for streams
   - Implement proper task cancellation

4. **Test Thoroughly**
   - Enable Thread Sanitizer
   - Test concurrent access patterns
   - Verify cancellation behavior