# SwiftData Best Practices and Patterns

## Architecture Patterns

### 1. Repository Pattern

The Repository pattern provides a clean abstraction over SwiftData, improving testability and separation of concerns.

```swift
// Repository Protocol
protocol RuckSessionRepository {
    func fetchAll() async throws -> [RuckSession]
    func fetch(by id: UUID) async throws -> RuckSession?
    func save(_ session: RuckSession) async throws
    func delete(_ session: RuckSession) async throws
    func fetchActive() async throws -> RuckSession?
}

// Implementation
@ModelActor
actor SwiftDataRuckSessionRepository: RuckSessionRepository {
    func fetchAll() async throws -> [RuckSession] {
        let descriptor = FetchDescriptor<RuckSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetch(by id: UUID) async throws -> RuckSession? {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    func save(_ session: RuckSession) async throws {
        modelContext.insert(session)
        try modelContext.save()
    }
    
    func delete(_ session: RuckSession) async throws {
        modelContext.delete(session)
        try modelContext.save()
    }
    
    func fetchActive() async throws -> RuckSession? {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { $0.endDate == nil }
        )
        return try modelContext.fetch(descriptor).first
    }
}
```

### 2. MVVM with SwiftData

```swift
// View Model
@MainActor
class RuckSessionListViewModel: ObservableObject {
    @Published var sessions: [RuckSession] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let repository: RuckSessionRepository
    
    init(repository: RuckSessionRepository) {
        self.repository = repository
    }
    
    func loadSessions() async {
        isLoading = true
        error = nil
        
        do {
            sessions = try await repository.fetchAll()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func deleteSession(_ session: RuckSession) async {
        do {
            try await repository.delete(session)
            await loadSessions()
        } catch {
            self.error = error
        }
    }
}

// View
struct RuckSessionListView: View {
    @StateObject private var viewModel: RuckSessionListViewModel
    
    init(repository: RuckSessionRepository) {
        _viewModel = StateObject(
            wrappedValue: RuckSessionListViewModel(repository: repository)
        )
    }
    
    var body: some View {
        List {
            ForEach(viewModel.sessions) { session in
                RuckSessionRow(session: session)
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await viewModel.deleteSession(viewModel.sessions[index])
                    }
                }
            }
        }
        .task {
            await viewModel.loadSessions()
        }
        .refreshable {
            await viewModel.loadSessions()
        }
    }
}
```

### 3. Coordinator Pattern

```swift
// Data Coordinator
@MainActor
class DataCoordinator: ObservableObject {
    let modelContainer: ModelContainer
    private let sessionRepository: RuckSessionRepository
    private let userRepository: UserRepository
    
    init() throws {
        self.modelContainer = try ModelContainer(
            for: [RuckSession.self, User.self, Route.self],
            configurations: ModelConfiguration(cloudKitDatabase: .automatic)
        )
        
        self.sessionRepository = SwiftDataRuckSessionRepository(
            modelContainer: modelContainer
        )
        self.userRepository = SwiftDataUserRepository(
            modelContainer: modelContainer
        )
    }
    
    func makeSessionListView() -> some View {
        RuckSessionListView(repository: sessionRepository)
    }
    
    func makeSessionDetailView(for session: RuckSession) -> some View {
        RuckSessionDetailView(
            session: session,
            repository: sessionRepository
        )
    }
}

// App Entry Point
@main
struct RuckMapApp: App {
    @StateObject private var dataCoordinator: DataCoordinator
    
    init() {
        do {
            _dataCoordinator = StateObject(
                wrappedValue: try DataCoordinator()
            )
        } catch {
            fatalError("Failed to initialize data coordinator: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataCoordinator)
                .modelContainer(dataCoordinator.modelContainer)
        }
    }
}
```

## Data Validation

### 1. Model-Level Validation

```swift
@Model
final class RuckSession {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var distance: Double
    var weight: Double
    var calories: Double
    
    init(startDate: Date, weight: Double) throws {
        guard weight > 0 && weight < 200 else {
            throw ValidationError.invalidWeight(weight)
        }
        
        guard startDate <= Date() else {
            throw ValidationError.futureDate
        }
        
        self.id = UUID()
        self.startDate = startDate
        self.weight = weight
        self.distance = 0
        self.calories = 0
    }
    
    func complete(endDate: Date, distance: Double, calories: Double) throws {
        guard endDate > startDate else {
            throw ValidationError.invalidEndDate
        }
        
        guard distance >= 0 else {
            throw ValidationError.invalidDistance
        }
        
        guard calories >= 0 else {
            throw ValidationError.invalidCalories
        }
        
        self.endDate = endDate
        self.distance = distance
        self.calories = calories
    }
}

enum ValidationError: LocalizedError {
    case invalidWeight(Double)
    case futureDate
    case invalidEndDate
    case invalidDistance
    case invalidCalories
    
    var errorDescription: String? {
        switch self {
        case .invalidWeight(let weight):
            return "Invalid weight: \(weight) lbs. Must be between 0 and 200."
        case .futureDate:
            return "Start date cannot be in the future."
        case .invalidEndDate:
            return "End date must be after start date."
        case .invalidDistance:
            return "Distance must be non-negative."
        case .invalidCalories:
            return "Calories must be non-negative."
        }
    }
}
```

### 2. Repository-Level Validation

```swift
extension SwiftDataRuckSessionRepository {
    func save(_ session: RuckSession) async throws {
        // Validate business rules
        if let activeSession = try await fetchActive(),
           activeSession.id != session.id {
            throw BusinessRuleError.activeSessionExists
        }
        
        // Validate data integrity
        try validateSession(session)
        
        // Save
        modelContext.insert(session)
        try modelContext.save()
    }
    
    private func validateSession(_ session: RuckSession) throws {
        // Check for duplicate sessions
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { existing in
                existing.id != session.id &&
                existing.startDate == session.startDate
            }
        )
        
        if let _ = try modelContext.fetch(descriptor).first {
            throw BusinessRuleError.duplicateSession
        }
    }
}
```

## Background Processing

### 1. Background Data Import

```swift
actor BackgroundDataProcessor {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func importGPXFile(at url: URL) async throws {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        
        // Parse GPX file
        let gpxData = try await parseGPX(from: url)
        
        // Create session
        let session = RuckSession(
            startDate: gpxData.startDate,
            weight: 35 // Default or from settings
        )
        
        // Add waypoints in batches
        for batch in gpxData.waypoints.chunked(into: 100) {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            for waypointData in batch {
                let waypoint = Waypoint(
                    timestamp: waypointData.timestamp,
                    latitude: waypointData.latitude,
                    longitude: waypointData.longitude,
                    elevation: waypointData.elevation
                )
                session.waypoints.append(waypoint)
            }
        }
        
        // Save
        context.insert(session)
        try context.save()
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

### 2. Background Sync Monitoring

```swift
@MainActor
class SyncMonitor: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var pendingChanges: Int = 0
    
    private var backgroundTask: Task<Void, Never>?
    
    enum SyncStatus {
        case idle
        case syncing
        case failed(Error)
    }
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        backgroundTask = Task {
            for await notification in NotificationCenter.default.notifications(
                named: .NSPersistentStoreRemoteChange
            ) {
                await handleRemoteChange(notification)
            }
        }
    }
    
    private func handleRemoteChange(_ notification: Notification) async {
        syncStatus = .syncing
        
        do {
            // Process changes
            await processRemoteChanges()
            lastSyncDate = Date()
            syncStatus = .idle
        } catch {
            syncStatus = .failed(error)
        }
    }
    
    deinit {
        backgroundTask?.cancel()
    }
}
```

## Memory Management

### 1. Batch Processing

```swift
extension SwiftDataRuckSessionRepository {
    func processLargeDaataset() async throws {
        let batchSize = 50
        var offset = 0
        
        while true {
            // Create new context for each batch
            let batchContext = ModelContext(modelContainer)
            
            // Fetch batch
            let descriptor = FetchDescriptor<RuckSession>(
                sortBy: [SortDescriptor(\.startDate)]
            )
            descriptor.fetchLimit = batchSize
            descriptor.fetchOffset = offset
            
            let sessions = try batchContext.fetch(descriptor)
            
            if sessions.isEmpty {
                break
            }
            
            // Process batch
            for session in sessions {
                // Process session
                session.isProcessed = true
            }
            
            try batchContext.save()
            
            // Clear context to free memory
            batchContext.reset()
            
            offset += batchSize
            
            // Allow other tasks to run
            await Task.yield()
        }
    }
}
```

### 2. Lazy Loading Relationships

```swift
@Model
final class Route {
    var id: UUID
    var name: String
    
    // Lazy loaded - not fetched until accessed
    @Relationship(deleteRule: .cascade)
    var waypoints: [Waypoint]
    
    // Computed property for memory-efficient access
    var waypointCount: Int {
        get async throws {
            let context = modelContext
            let descriptor = FetchDescriptor<Waypoint>(
                predicate: #Predicate { $0.route?.id == self.id }
            )
            return try context.fetchCount(descriptor)
        }
    }
}
```

## Error Handling Patterns

### 1. Comprehensive Error Types

```swift
enum DataError: LocalizedError {
    case notFound(type: String, id: UUID)
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case validationFailed(ValidationError)
    case syncFailed(CloudKitError)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let type, let id):
            return "\(type) with ID \(id) not found"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        case .validationFailed(let error):
            return error.localizedDescription
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notFound:
            return "The item may have been deleted."
        case .saveFailed:
            return "Try saving again or check storage space."
        case .fetchFailed:
            return "Try refreshing the data."
        case .validationFailed:
            return "Check the entered values and try again."
        case .syncFailed:
            return "Check your internet connection and iCloud settings."
        }
    }
}
```

### 2. Error Recovery

```swift
class ErrorRecoveryManager {
    static func recover(from error: Error) async throws {
        switch error {
        case DataError.saveFailed:
            try await recoverFromSaveFailure()
        case DataError.syncFailed(let cloudKitError):
            try await recoverFromSyncFailure(cloudKitError)
        default:
            throw error
        }
    }
    
    private static func recoverFromSaveFailure() async throws {
        // Clear cache
        // Retry save
        // Fallback to local storage
    }
    
    private static func recoverFromSyncFailure(_ error: CloudKitError) async throws {
        switch error {
        case .quotaExceeded:
            // Clean up old data
            // Notify user
        case .networkUnavailable:
            // Queue for later
            // Enable offline mode
        default:
            throw error
        }
    }
}
```

## Performance Optimization

### 1. Query Optimization

```swift
extension SwiftDataRuckSessionRepository {
    func fetchOptimized(
        after date: Date,
        limit: Int = 50
    ) async throws -> [RuckSession] {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { $0.startDate > date },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        
        // Limit results
        descriptor.fetchLimit = limit
        
        // Only fetch needed properties
        descriptor.propertiesToFetch = [
            \.id,
            \.startDate,
            \.distance,
            \.calories
        ]
        
        // Don't prefetch relationships
        descriptor.relationshipKeyPathsForPrefetching = []
        
        return try modelContext.fetch(descriptor)
    }
}
```

### 2. Caching Strategy

```swift
actor CachedRepository<Model: PersistentModel> {
    private var cache: [UUID: Model] = [:]
    private let modelContainer: ModelContainer
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    private var cacheTimestamps: [UUID: Date] = [:]
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func fetch(id: UUID) async throws -> Model? {
        // Check cache
        if let cached = cache[id],
           let timestamp = cacheTimestamps[id],
           Date().timeIntervalSince(timestamp) < cacheExpiration {
            return cached
        }
        
        // Fetch from database
        let context = ModelContext(modelContainer)
        let fetched = try context.fetch(
            FetchDescriptor<Model>(
                predicate: #Predicate { $0.id == id }
            )
        ).first
        
        // Update cache
        if let fetched = fetched {
            cache[id] = fetched
            cacheTimestamps[id] = Date()
        }
        
        return fetched
    }
    
    func invalidate(id: UUID) {
        cache.removeValue(forKey: id)
        cacheTimestamps.removeValue(forKey: id)
    }
    
    func invalidateAll() {
        cache.removeAll()
        cacheTimestamps.removeAll()
    }
}
```

## Resources

- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Swift Forums - SwiftData](https://forums.swift.org/c/related-projects/swiftdata)
- [WWDC Videos on SwiftData](https://developer.apple.com/wwdc23/10154)
- [Hacking with Swift - SwiftData](https://www.hackingwithswift.com/quick-start/swiftdata)
- [Ray Wenderlich - SwiftData Tutorial](https://www.raywenderlich.com/swiftdata)