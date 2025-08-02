# Testing SwiftData with Swift 6

## Overview

Testing SwiftData applications requires special considerations due to persistence, concurrency, and CloudKit integration. This guide covers comprehensive testing strategies for Swift 6's strict concurrency model.

## Unit Testing Setup

### 1. In-Memory Test Container

```swift
import XCTest
import SwiftData
@testable import RuckMap

class SwiftDataTestBase: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: [RuckSession.self, User.self, Route.self],
            configurations: config
        )
        modelContext = modelContainer.mainContext
    }
    
    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }
}
```

### 2. Test Data Factory

```swift
@MainActor
class TestDataFactory {
    let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func createRuckSession(
        startDate: Date = Date(),
        weight: Double = 35,
        distance: Double = 5000
    ) -> RuckSession {
        let session = RuckSession(startDate: startDate, weight: weight)
        session.distance = distance
        context.insert(session)
        return session
    }
    
    func createUser(name: String = "Test User") -> User {
        let user = User(name: name)
        context.insert(user)
        return user
    }
}
```

## Testing with Swift 6 Concurrency

### 1. Actor-Isolated Tests

```swift
@ModelActor
actor TestDataStore {
    func fetchSessions() throws -> [RuckSession] {
        let descriptor = FetchDescriptor<RuckSession>()
        return try modelContext.fetch(descriptor)
    }
    
    func createSession(weight: Double) throws -> RuckSession {
        let session = RuckSession(startDate: Date(), weight: weight)
        modelContext.insert(session)
        try modelContext.save()
        return session
    }
}

class DataStoreTests: SwiftDataTestBase {
    func testActorIsolation() async throws {
        let store = TestDataStore(modelContainer: modelContainer)
        
        // Create session in actor context
        let session = try await store.createSession(weight: 35)
        XCTAssertNotNil(session.id)
        
        // Fetch in actor context
        let sessions = try await store.fetchSessions()
        XCTAssertEqual(sessions.count, 1)
    }
}
```

### 2. MainActor Testing

```swift
@MainActor
class ViewModelTests: SwiftDataTestBase {
    func testSessionViewModel() async throws {
        let viewModel = SessionViewModel(modelContext: modelContext)
        
        // Test @MainActor methods
        await viewModel.startSession(weight: 35)
        XCTAssertNotNil(viewModel.currentSession)
        
        await viewModel.endSession()
        XCTAssertNil(viewModel.currentSession)
    }
}
```

### 3. Sendable Conformance Testing

```swift
// Ensure your data transfer objects are Sendable
struct SessionData: Sendable {
    let id: UUID
    let distance: Double
    let calories: Double
}

class SendableTests: XCTestCase {
    func testDataTransferBetweenActors() async {
        let sessionData = SessionData(
            id: UUID(),
            distance: 5000,
            calories: 350
        )
        
        // This compiles only if SessionData is Sendable
        await processOnBackgroundActor(sessionData)
    }
    
    func processOnBackgroundActor(_ data: SessionData) async {
        // Process data safely across actor boundaries
    }
}
```

## Mocking and Dependency Injection

### 1. Protocol-Based Mocking

```swift
protocol DataStoreProtocol {
    func fetchSessions() async throws -> [RuckSession]
    func save(_ session: RuckSession) async throws
    func delete(_ session: RuckSession) async throws
}

// Production implementation
@MainActor
class SwiftDataStore: DataStoreProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchSessions() async throws -> [RuckSession] {
        try modelContext.fetch(FetchDescriptor<RuckSession>())
    }
    
    func save(_ session: RuckSession) async throws {
        modelContext.insert(session)
        try modelContext.save()
    }
    
    func delete(_ session: RuckSession) async throws {
        modelContext.delete(session)
        try modelContext.save()
    }
}

// Mock implementation
class MockDataStore: DataStoreProtocol {
    var sessions: [RuckSession] = []
    var saveCallCount = 0
    var shouldThrowError = false
    
    func fetchSessions() async throws -> [RuckSession] {
        if shouldThrowError {
            throw TestError.mockError
        }
        return sessions
    }
    
    func save(_ session: RuckSession) async throws {
        saveCallCount += 1
        if shouldThrowError {
            throw TestError.mockError
        }
        sessions.append(session)
    }
    
    func delete(_ session: RuckSession) async throws {
        sessions.removeAll { $0.id == session.id }
    }
}
```

### 2. Dependency Injection

```swift
@MainActor
class SessionViewModel: ObservableObject {
    private let dataStore: DataStoreProtocol
    @Published var sessions: [RuckSession] = []
    
    init(dataStore: DataStoreProtocol) {
        self.dataStore = dataStore
    }
    
    func loadSessions() async {
        do {
            sessions = try await dataStore.fetchSessions()
        } catch {
            // Handle error
        }
    }
}

// Testing with mock
class SessionViewModelTests: XCTestCase {
    @MainActor
    func testLoadSessions() async {
        let mockStore = MockDataStore()
        mockStore.sessions = [
            RuckSession(startDate: Date(), weight: 35),
            RuckSession(startDate: Date(), weight: 40)
        ]
        
        let viewModel = SessionViewModel(dataStore: mockStore)
        await viewModel.loadSessions()
        
        XCTAssertEqual(viewModel.sessions.count, 2)
    }
}
```

## Integration Testing

### 1. Testing Data Persistence

```swift
class PersistenceIntegrationTests: SwiftDataTestBase {
    func testDataPersistsAcrossContexts() throws {
        // Create in first context
        let session = RuckSession(startDate: Date(), weight: 35)
        modelContext.insert(session)
        try modelContext.save()
        
        // Create new context and fetch
        let newContext = ModelContext(modelContainer)
        let fetched = try newContext.fetch(FetchDescriptor<RuckSession>())
        
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.weight, 35)
    }
}
```

### 2. Testing Relationships

```swift
class RelationshipIntegrationTests: SwiftDataTestBase {
    func testCascadeDelete() throws {
        // Create user with sessions
        let user = User(name: "Test User")
        let session1 = RuckSession(startDate: Date(), weight: 35)
        let session2 = RuckSession(startDate: Date(), weight: 40)
        
        user.sessions.append(session1)
        user.sessions.append(session2)
        
        modelContext.insert(user)
        try modelContext.save()
        
        // Delete user
        modelContext.delete(user)
        try modelContext.save()
        
        // Verify sessions are deleted
        let remainingSessions = try modelContext.fetch(
            FetchDescriptor<RuckSession>()
        )
        XCTAssertEqual(remainingSessions.count, 0)
    }
}
```

## Testing CloudKit Sync

### 1. Mock CloudKit Container

```swift
class MockCloudKitContainer {
    var simulateNetworkError = false
    var syncDelay: TimeInterval = 0
    var conflictResolution: ConflictResolution = .lastWriterWins
    
    enum ConflictResolution {
        case lastWriterWins
        case custom((local: Any, remote: Any) -> Any)
    }
    
    func sync() async throws {
        if simulateNetworkError {
            throw CKError(.networkUnavailable)
        }
        
        try await Task.sleep(nanoseconds: UInt64(syncDelay * 1_000_000_000))
    }
}
```

### 2. Sync Testing

```swift
class CloudKitSyncTests: XCTestCase {
    func testSyncWithNetworkFailure() async throws {
        let mockContainer = MockCloudKitContainer()
        mockContainer.simulateNetworkError = true
        
        do {
            try await mockContainer.sync()
            XCTFail("Expected network error")
        } catch {
            XCTAssertTrue(error is CKError)
        }
    }
    
    func testSyncDelay() async throws {
        let mockContainer = MockCloudKitContainer()
        mockContainer.syncDelay = 2.0
        
        let start = Date()
        try await mockContainer.sync()
        let elapsed = Date().timeIntervalSince(start)
        
        XCTAssertGreaterThanOrEqual(elapsed, 2.0)
    }
}
```

## Performance Testing

### 1. Measure Test

```swift
class PerformanceTests: SwiftDataTestBase {
    func testBulkInsertPerformance() throws {
        measure {
            do {
                for i in 0..<1000 {
                    let session = RuckSession(
                        startDate: Date(),
                        weight: Double(35 + i % 20)
                    )
                    modelContext.insert(session)
                }
                try modelContext.save()
            } catch {
                XCTFail("Failed to insert: \(error)")
            }
        }
    }
    
    func testFetchPerformance() throws {
        // Setup: Insert test data
        for i in 0..<1000 {
            let session = RuckSession(
                startDate: Date().addingTimeInterval(Double(i) * 3600),
                weight: 35
            )
            modelContext.insert(session)
        }
        try modelContext.save()
        
        // Measure fetch
        measure {
            do {
                let descriptor = FetchDescriptor<RuckSession>(
                    sortBy: [SortDescriptor(\.startDate)]
                )
                _ = try modelContext.fetch(descriptor)
            } catch {
                XCTFail("Failed to fetch: \(error)")
            }
        }
    }
}
```

### 2. Memory Testing

```swift
class MemoryTests: SwiftDataTestBase {
    func testMemoryUsageWithLargeDataset() throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(metrics: [XCTMemoryMetric()], options: options) {
            autoreleasepool {
                do {
                    // Create large dataset
                    for _ in 0..<10000 {
                        let session = RuckSession(
                            startDate: Date(),
                            weight: 35
                        )
                        modelContext.insert(session)
                    }
                    try modelContext.save()
                    
                    // Fetch all
                    _ = try modelContext.fetch(FetchDescriptor<RuckSession>())
                } catch {
                    XCTFail("Operation failed: \(error)")
                }
            }
        }
    }
}
```

## Testing Best Practices

### 1. Test Isolation

```swift
class IsolatedTests: XCTestCase {
    func testWithIsolatedContainer() throws {
        // Each test gets its own container
        let container = try ModelContainer(
            for: [RuckSession.self],
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        
        let context = container.mainContext
        // Test operations...
    }
}
```

### 2. Async Test Helpers

```swift
extension XCTestCase {
    func eventually(
        timeout: TimeInterval = 10,
        condition: @escaping () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        XCTFail("Condition not met within timeout")
    }
}

// Usage
func testEventualConsistency() async {
    await viewModel.startSync()
    
    await eventually {
        await viewModel.syncStatus == .completed
    }
}
```

### 3. Test Data Cleanup

```swift
class CleanupTests: SwiftDataTestBase {
    override func tearDown() async throws {
        // Clean up all test data
        let sessions = try modelContext.fetch(FetchDescriptor<RuckSession>())
        for session in sessions {
            modelContext.delete(session)
        }
        try modelContext.save()
        
        try await super.tearDown()
    }
}
```

## Common Testing Patterns

### 1. Given-When-Then

```swift
func testSessionCompletion() throws {
    // Given
    let session = RuckSession(startDate: Date(), weight: 35)
    session.distance = 5000
    modelContext.insert(session)
    
    // When
    session.endDate = Date()
    session.calories = 350
    try modelContext.save()
    
    // Then
    XCTAssertNotNil(session.endDate)
    XCTAssertEqual(session.calories, 350)
}
```

### 2. Arrange-Act-Assert

```swift
func testDeleteSession() throws {
    // Arrange
    let factory = TestDataFactory(context: modelContext)
    let session = factory.createRuckSession()
    try modelContext.save()
    
    // Act
    modelContext.delete(session)
    try modelContext.save()
    
    // Assert
    let remaining = try modelContext.fetch(FetchDescriptor<RuckSession>())
    XCTAssertEqual(remaining.count, 0)
}
```

## Resources

- [Apple Testing Documentation](https://developer.apple.com/documentation/xctest)
- [Swift Testing Framework](https://github.com/apple/swift-testing)
- [WWDC: Testing Tips & Tricks](https://developer.apple.com/videos/play/wwdc2023/10175/)
- [Swift Concurrency Testing](https://developer.apple.com/documentation/swift/concurrency)