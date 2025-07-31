# iOS Architecture Plan for Ruck Map

## Executive Summary

This document outlines a comprehensive iOS architecture for the Ruck Map application, leveraging Swift 6.2+ concurrency patterns and SwiftUI with Liquid Glass design system integration. The architecture is designed to support the five key user personas identified in the user research, with a focus on military veterans, fitness enthusiast parents, young urban professionals, health-conscious retirees, and outdoor adventure seekers.

**Key Technologies:**
- Swift 6.2+ with Approachable Concurrency features
- SwiftUI with Liquid Glass design system
- SwiftData with actor isolation patterns
- Advanced concurrency patterns using MainActor, @concurrent, and custom actors
- Cross-platform compatibility (iPhone/iPad/Mac)

**Architecture Highlights:**
- Actor-based concurrency for thread-safe data handling
- Liquid Glass UI components for modern, translucent interfaces
- Modular design supporting persona-specific features
- Comprehensive offline capabilities for outdoor scenarios
- Real-time synchronization with robust conflict resolution

---

## Technology Stack Analysis

### Swift 6.2 Concurrency Features

Based on current research, Swift 6.2 introduces several critical improvements for concurrency:

**Approachable Concurrency:**
- Default MainActor isolation for simplified mental models
- `@concurrent` attribute for explicit off-actor execution
- Caller isolation inheritance for nonisolated async functions
- Region-based isolation for safer non-Sendable type handling

**Implementation Strategy:**
```swift
// Enable approachable concurrency features
// In Package.swift or build settings
swiftSettings: [
    .enableExperimentalFeature("ApproachableConcurrency"),
    .enableExperimentalFeature("NonisolatedNonsendingByDefault")
]
```

### SwiftUI + Liquid Glass Integration

**Liquid Glass Characteristics:**
- Translucent material that reflects and refracts surroundings
- Dynamic transformation based on content and context
- Real-time rendering with specular highlights
- Hierarchical material system (regular, thick, thin variations)

**Key Components:**
- `glassEffect()` modifier for translucent backgrounds
- `GlassEffectContainer` for grouping related elements
- Interactive glass effects with `.interactive()` modifier
- Tinted glass materials for branding consistency

### SwiftData with Actor Isolation

SwiftData integration will leverage actor isolation patterns for thread-safe data access:

```swift
@ModelActor
actor RuckDataActor {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    func performDataOperation<T>(_ operation: () throws -> T) async throws -> T {
        try operation()
    }
}
```

---

## Architecture Overview

### Layer Structure

```
┌─────────────────────────────────────────┐
│              Presentation               │
│  (SwiftUI + Liquid Glass Components)   │
├─────────────────────────────────────────┤
│               Domain                    │
│    (Business Logic + Use Cases)        │
├─────────────────────────────────────────┤
│                Data                     │
│   (SwiftData + Network + Location)     │
├─────────────────────────────────────────┤
│            Infrastructure               │
│     (Device Services + External)       │
└─────────────────────────────────────────┘
```

### Core Architectural Patterns

1. **MVVM with Actor Isolation**
2. **Repository Pattern with SwiftData**
3. **Use Case/Interactor Pattern**
4. **Dependency Injection Container**
5. **Event-Driven Architecture**

---

## Concurrency Architecture Design

### Actor System Hierarchy

```swift
// Main coordination actor
@MainActor
class AppCoordinator: ObservableObject {
    @Published private(set) var appState: AppState = .initializing
    
    private let dataManager: RuckDataManager
    private let locationManager: LocationManager
    private let authManager: AuthenticationManager
    
    func handleDeepLink(_ url: URL) async {
        // Handle deep linking with proper isolation
    }
}

// Data management actor
actor RuckDataManager {
    private let modelContainer: ModelContainer
    private let networkService: NetworkService
    private let cacheManager: CacheManager
    
    func syncRuckingData() async throws {
        // Coordinated data synchronization
    }
    
    nonisolated func observeChanges() -> AsyncStream<DataChange> {
        // Provide reactive data updates
    }
}

// Location services actor
@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    private let trackingActor = LocationTrackingActor()
    
    func startRuckingSession() async throws -> RuckingSession {
        try await trackingActor.createSession(from: currentLocation)
    }
}

// Background location processing
actor LocationTrackingActor {
    private var activeSession: RuckingSession?
    private let dataManager: RuckDataManager
    
    func createSession(from location: CLLocation?) throws -> RuckingSession {
        // Create new rucking session
    }
    
    func updateSession(with location: CLLocation) async {
        // Update active session with new location data
    }
}
```

### MainActor Usage Patterns

**UI Components (Always MainActor):**
```swift
@MainActor
class RuckingViewModel: ObservableObject {
    @Published private(set) var viewState: RuckingViewState = .idle
    @Published private(set) var currentStats: RuckingStats?
    
    private let dataManager: RuckDataManager
    private let locationManager: LocationManager
    
    func startRucking(weight: Double, route: Route?) async {
        viewState = .starting
        
        do {
            // This creates a suspension point, jumping off MainActor
            let session = try await locationManager.startRuckingSession()
            await dataManager.saveSession(session)
            
            // Back on MainActor for UI updates
            viewState = .active(session)
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    @concurrent
    private func calculateCalories(weight: Double, distance: Double, time: TimeInterval) async -> Double {
        // This runs off the main actor even when called from MainActor context
        return RuckingCalculator.calculateCalories(weight: weight, distance: distance, time: time)
    }
}
```

### TaskGroup Hierarchies for Parallel Operations

```swift
actor DataSynchronizationActor {
    func performFullSync() async throws {
        try await withThrowingTaskGroup(of: SyncResult.self) { group in
            // Add parallel sync tasks
            group.addTask { try await self.syncUserProfile() }
            group.addTask { try await self.syncRuckingSessions() }
            group.addTask { try await self.syncRoutes() }
            group.addTask { try await self.syncCommunityData() }
            
            // Collect results
            var results: [SyncResult] = []
            for try await result in group {
                results.append(result)
            }
            
            // Process consolidated results
            try await processSyncResults(results)
        }
    }
    
    private func syncUserProfile() async throws -> SyncResult {
        // Sync user profile data
    }
    
    private func syncRuckingSessions() async throws -> SyncResult {
        // Sync rucking session data
    }
}
```

### Cancellation Strategies

```swift
@MainActor
class RuckingSessionManager: ObservableObject {
    private var activeSessionTask: Task<Void, Error>?
    private var syncTask: Task<Void, Error>?
    
    func startSession() async {
        // Cancel any existing session
        activeSessionTask?.cancel()
        
        activeSessionTask = Task {
            try await performSession()
        }
        
        do {
            try await activeSessionTask?.value
        } catch is CancellationError {
            // Handle cancellation gracefully
            await handleSessionCancellation()
        } catch {
            // Handle other errors
            await handleSessionError(error)
        }
    }
    
    func stopSession() {
        activeSessionTask?.cancel()
        activeSessionTask = nil
    }
    
    private func performSession() async throws {
        // Check for cancellation at appropriate points
        try Task.checkCancellation()
        
        // Long-running session logic
        while !Task.isCancelled {
            try await processLocationUpdate()
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
}
```

---

## SwiftUI + Liquid Glass Integration Plan

### Component Library Architecture

```swift
// Base Liquid Glass components
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    let tint: Color
    let intensity: GlassIntensity
    
    var body: some View {
        content
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .glassEffect(.regular.tint(tint.opacity(0.8)).interactive())
            }
    }
}

// Rucking-specific components
struct RuckingStatsPanel: View {
    let stats: RuckingStats
    
    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 16) {
                StatRow(title: "Distance", value: stats.formattedDistance)
                StatRow(title: "Time", value: stats.formattedTime)
                StatRow(title: "Calories", value: stats.formattedCalories)
                StatRow(title: "Weight", value: stats.formattedWeight)
            }
            .padding()
            .glassEffect(.thick.tint(.blue.opacity(0.6)))
        }
    }
}

struct FloatingActionButton: View {
    let action: () -> Void
    let systemImage: String
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
        }
        .glassEffect(.regular.tint(.green.opacity(0.8)).interactive())
        .clipShape(Circle())
    }
}
```

### Dynamic Theming System

```swift
@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .military
    
    var glassConfiguration: GlassConfiguration {
        switch currentTheme {
        case .military:
            return GlassConfiguration(
                primaryTint: .green,
                secondaryTint: .gray,
                intensity: .regular
            )
        case .fitness:
            return GlassConfiguration(
                primaryTint: .orange,
                secondaryTint: .blue,
                intensity: .thick
            )
        case .outdoor:
            return GlassConfiguration(
                primaryTint: .brown,
                secondaryTint: .green,
                intensity: .regular
            )
        }
    }
}

struct GlassConfiguration {
    let primaryTint: Color
    let secondaryTint: Color
    let intensity: GlassIntensity
}
```

### Persona-Specific UI Adaptations

```swift
// Military Veteran UI
struct MilitaryDashboard: View {
    @StateObject private var viewModel: MilitaryDashboardViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 20) {
                // PT Test Progress
                MilitaryPTProgressCard()
                
                // Unit Challenges
                UnitChallengesSection()
                
                // Equipment Tracking
                EquipmentStatusPanel()
            }
        }
        .navigationTitle("Mission Ready")
    }
}

// Family-Friendly UI
struct FamilyDashboard: View {
    @StateObject private var viewModel: FamilyDashboardViewModel
    
    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 16) {
                // Family Goals
                FamilyGoalsCard()
                
                // Kid-Friendly Routes
                SafeRoutesSection()
                
                // Parent Network
                ParentCommunityPanel()
            }
        }
        .navigationTitle("Family Fitness")
    }
}
```

### Interruptible Animations

```swift
struct AnimatedGlassButton: View {
    @State private var isPressed = false
    @State private var animationTask: Task<Void, Error>?
    
    var body: some View {
        Button("Start Rucking") {
            handlePress()
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .glassEffect(.regular.tint(.blue.opacity(0.8)).interactive())
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
    
    private func handlePress() {
        // Cancel any existing animation
        animationTask?.cancel()
        
        animationTask = Task {
            await MainActor.run {
                isPressed = true
            }
            
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isPressed = false
            }
        }
    }
}
```

---

## SwiftData Architecture

### Model Definitions with Relationships

```swift
@Model
final class RuckingSession {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    var distance: Double
    var duration: TimeInterval
    var packWeight: Double
    var calories: Double
    var route: Route?
    var user: User
    
    @Relationship(deleteRule: .cascade)
    var locationPoints: [LocationPoint] = []
    
    @Relationship(deleteRule: .nullify)
    var equipment: [Equipment] = []
    
    init(startDate: Date, packWeight: Double, user: User) {
        self.id = UUID()
        self.startDate = startDate
        self.packWeight = packWeight
        self.user = user
        self.distance = 0
        self.duration = 0
        self.calories = 0
    }
}

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var email: String
    var displayName: String
    var persona: UserPersona
    var preferences: UserPreferences
    var createdAt: Date
    var lastSyncDate: Date
    
    @Relationship(deleteRule: .cascade, inverse: \RuckingSession.user)
    var sessions: [RuckingSession] = []
    
    @Relationship(deleteRule: .cascade)
    var equipment: [Equipment] = []
    
    init(email: String, displayName: String, persona: UserPersona) {
        self.id = UUID()
        self.email = email
        self.displayName = displayName
        self.persona = persona
        self.preferences = UserPreferences.defaultFor(persona: persona)
        self.createdAt = Date()
        self.lastSyncDate = Date()
    }
}

@Model
final class Route {
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var distance: Double
    var elevation: Double
    var difficulty: RouteDifficulty
    var isPublic: Bool
    var createdBy: User
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade)
    var waypoints: [Waypoint] = []
    
    @Relationship(deleteRule: .nullify, inverse: \RuckingSession.route)
    var sessions: [RuckingSession] = []
}
```

### Data Repository with Actor Isolation

```swift
@ModelActor
actor RuckDataRepository {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
    }
    
    // MARK: - Session Operations
    
    func createSession(startDate: Date, packWeight: Double, userId: UUID) throws -> RuckingSession {
        guard let user = try fetchUser(id: userId) else {
            throw DataError.userNotFound
        }
        
        let session = RuckingSession(startDate: startDate, packWeight: packWeight, user: user)
        modelContext.insert(session)
        try modelContext.save()
        return session
    }
    
    func updateSession(_ session: RuckingSession, endDate: Date, distance: Double, duration: TimeInterval) throws {
        session.endDate = endDate
        session.distance = distance
        session.duration = duration
        session.calories = RuckingCalculator.calculateCalories(
            weight: session.packWeight,
            distance: distance,
            time: duration
        )
        try modelContext.save()
    }
    
    func fetchRecentSessions(for userId: UUID, limit: Int = 10) throws -> [RuckingSession] {
        let predicate = #Predicate<RuckingSession> { session in
            session.user.id == userId
        }
        
        let descriptor = FetchDescriptor<RuckingSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - User Operations
    
    func fetchUser(id: UUID) throws -> User? {
        let predicate = #Predicate<User> { user in
            user.id == id
        }
        let descriptor = FetchDescriptor<User>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
    
    // MARK: - Synchronization Support
    
    func getUnsyncedData() throws -> UnsyncedDataBatch {
        // Fetch all data that needs to be synced
        let unsyncedSessions = try fetchUnsyncedSessions()
        let unsyncedRoutes = try fetchUnsyncedRoutes()
        
        return UnsyncedDataBatch(sessions: unsyncedSessions, routes: unsyncedRoutes)
    }
    
    nonisolated func observeChanges() -> AsyncStream<ModelChange> {
        // Provide reactive updates for UI
    }
}
```

### Migration Strategy

```swift
enum DataMigrationPlan {
    static let migrations: [Migration] = [
        Migration(
            from: .version1,
            to: .version2,
            changes: [
                .addColumn(table: "RuckingSession", column: "calories", type: .double),
                .addTable("Equipment"),
                .addRelationship(from: "RuckingSession", to: "Equipment", type: .manyToMany)
            ]
        ),
        Migration(
            from: .version2,
            to: .version3,
            changes: [
                .addColumn(table: "User", column: "persona", type: .string),
                .addColumn(table: "User", column: "preferences", type: .data)
            ]
        )
    ]
}

@MainActor
class DataMigrationManager {
    func performMigrations() async throws {
        for migration in DataMigrationPlan.migrations {
            try await executeMigration(migration)
        }
    }
    
    private func executeMigration(_ migration: Migration) async throws {
        // Execute migration steps
    }
}
```

---

## Data Flow Architecture

### Event-Driven State Management

```swift
// Centralized event system
actor EventBus {
    private var subscribers: [EventType: [EventHandler]] = [:]
    
    func subscribe<T: AppEvent>(to eventType: T.Type, handler: @escaping (T) async -> Void) {
        let wrappedHandler = EventHandler { event in
            if let typedEvent = event as? T {
                await handler(typedEvent)
            }
        }
        
        subscribers[T.eventType, default: []].append(wrappedHandler)
    }
    
    func publish<T: AppEvent>(_ event: T) async {
        let handlers = subscribers[T.eventType] ?? []
        await withTaskGroup(of: Void.self) { group in
            for handler in handlers {
                group.addTask {
                    await handler.handle(event)
                }
            }
        }
    }
}

// Event definitions
protocol AppEvent {
    static var eventType: EventType { get }
}

struct RuckingSessionStarted: AppEvent {
    static let eventType = EventType.sessionStarted
    let session: RuckingSession
    let startLocation: CLLocation
}

struct LocationUpdated: AppEvent {
    static let eventType = EventType.locationUpdated
    let location: CLLocation
    let sessionId: UUID
}

struct SessionCompleted: AppEvent {
    static let eventType = EventType.sessionCompleted
    let session: RuckingSession
    let stats: RuckingStats
}
```

### Reactive Data Pipeline

```swift
@MainActor
class DataPipeline: ObservableObject {
    @Published private(set) var connectionStatus: ConnectionStatus = .offline
    @Published private(set) var syncProgress: Double = 0.0
    
    private let dataRepository: RuckDataRepository
    private let networkService: NetworkService
    private let eventBus: EventBus
    
    private var syncTask: Task<Void, Error>?
    
    init(dataRepository: RuckDataRepository, networkService: NetworkService, eventBus: EventBus) {
        self.dataRepository = dataRepository
        self.networkService = networkService
        self.eventBus = eventBus
        
        setupEventSubscriptions()
    }
    
    private func setupEventSubscriptions() {
        Task {
            await eventBus.subscribe(to: RuckingSessionStarted.self) { [weak self] event in
                await self?.handleSessionStarted(event)
            }
            
            await eventBus.subscribe(to: LocationUpdated.self) { [weak self] event in
                await self?.handleLocationUpdate(event)
            }
            
            await eventBus.subscribe(to: SessionCompleted.self) { [weak self] event in
                await self?.handleSessionCompleted(event)
            }
        }
    }
    
    private func handleSessionStarted(_ event: RuckingSessionStarted) async {
        // Handle session start
        await MainActor.run {
            // Update UI state
        }
    }
    
    func startContinuousSync() {
        syncTask?.cancel()
        
        syncTask = Task {
            while !Task.isCancelled {
                try await performSync()
                try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
    }
    
    @concurrent
    private func performSync() async throws {
        // This runs off the main actor
        let unsyncedData = try await dataRepository.getUnsyncedData()
        
        guard !unsyncedData.isEmpty else { return }
        
        await MainActor.run {
            connectionStatus = .syncing
            syncProgress = 0.0
        }
        
        let totalItems = unsyncedData.totalCount
        var processedItems = 0
        
        for batch in unsyncedData.batches {
            try await networkService.sync(batch)
            processedItems += batch.count
            
            await MainActor.run {
                syncProgress = Double(processedItems) / Double(totalItems)
            }
        }
        
        await MainActor.run {
            connectionStatus = .online
            syncProgress = 1.0
        }
    }
}
```

---

## Testing Strategy

### Actor Isolation Testing

```swift
final class RuckDataRepositoryTests: XCTestCase {
    var repository: RuckDataRepository!
    var testContainer: ModelContainer!
    
    override func setUp() async throws {
        testContainer = try ModelContainer(
            for: RuckingSession.self, User.self, Route.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        repository = RuckDataRepository(modelContainer: testContainer)
    }
    
    func testCreateSession() async throws {
        // Test session creation with proper isolation
        let user = User(email: "test@example.com", displayName: "Test User", persona: .militaryVeteran)
        try await repository.insertUser(user)
        
        let session = try await repository.createSession(
            startDate: Date(),
            packWeight: 35.0,
            userId: user.id
        )
        
        XCTAssertEqual(session.packWeight, 35.0)
        XCTAssertEqual(session.user.id, user.id)
    }
    
    func testConcurrentDataAccess() async throws {
        // Test concurrent access to repository
        let user = User(email: "test@example.com", displayName: "Test User", persona: .militaryVeteran)
        try await repository.insertUser(user)
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    do {
                        _ = try await self.repository.createSession(
                            startDate: Date(),
                            packWeight: Double(i + 20),
                            userId: user.id
                        )
                    } catch {
                        XCTFail("Concurrent session creation failed: \(error)")
                    }
                }
            }
        }
        
        let sessions = try await repository.fetchRecentSessions(for: user.id, limit: 10)
        XCTAssertEqual(sessions.count, 10)
    }
}

// UI Testing with MainActor
@MainActor
final class RuckingViewModelTests: XCTestCase {
    var viewModel: RuckingViewModel!
    var mockRepository: MockRuckDataRepository!
    var mockLocationManager: MockLocationManager!
    
    override func setUp() async throws {
        mockRepository = MockRuckDataRepository()
        mockLocationManager = MockLocationManager()
        viewModel = RuckingViewModel(
            dataRepository: mockRepository,
            locationManager: mockLocationManager
        )
    }
    
    func testStartRucking() async throws {
        // This test runs on MainActor
        mockLocationManager.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        await viewModel.startRucking(weight: 30.0, route: nil)
        
        XCTAssertEqual(viewModel.viewState, .active)
        XCTAssertNotNil(viewModel.currentSession)
    }
}
```

### Liquid Glass Component Testing

```swift
final class LiquidGlassComponentTests: XCTestCase {
    func testRuckingStatsPanel() throws {
        let stats = RuckingStats(
            distance: 5.0,
            time: 3600,
            calories: 500,
            weight: 35.0
        )
        
        let panel = RuckingStatsPanel(stats: stats)
        let view = panel.body
        
        // Test component structure and glass effects
        XCTAssertTrue(view.hasGlassEffect)
        XCTAssertEqual(view.glassConfiguration.intensity, .thick)
    }
    
    func testThemeAdaptation() throws {
        let themeManager = ThemeManager()
        themeManager.currentTheme = .military
        
        let configuration = themeManager.glassConfiguration
        XCTAssertEqual(configuration.primaryTint, .green)
        XCTAssertEqual(configuration.intensity, .regular)
    }
}
```

---

## Performance Considerations

### Memory Management with Actors

```swift
// Weak reference patterns in actor contexts
actor LocationTrackingActor {
    weak var delegate: LocationTrackingDelegate?
    private var locationBuffer: CircularBuffer<CLLocation>
    
    init(bufferSize: Int = 100) {
        self.locationBuffer = CircularBuffer(capacity: bufferSize)
    }
    
    func addLocation(_ location: CLLocation) async {
        locationBuffer.append(location)
        
        // Avoid retaining delegates strongly
        await delegate?.locationUpdated(location)
    }
    
    nonisolated func cleanup() {
        Task { [weak self] in
            await self?.performCleanup()
        }
    }
    
    private func performCleanup() {
        locationBuffer.removeAll()
    }
}

// Circular buffer for efficient location storage
struct CircularBuffer<T> {
    private var buffer: [T?]
    private var head = 0
    private var tail = 0
    private let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }
    
    mutating func append(_ item: T) {
        buffer[tail] = item
        tail = (tail + 1) % capacity
        if tail == head {
            head = (head + 1) % capacity
        }
    }
    
    mutating func removeAll() {
        buffer = Array(repeating: nil, count: capacity)
        head = 0
        tail = 0
    }
}
```

### Liquid Glass Rendering Optimization

```swift
struct OptimizedGlassContainer<Content: View>: View {
    let content: Content
    @State private var renderingOptimization = true
    
    var body: some View {
        content
            .drawingGroup(opaque: false, colorMode: .linear)
            .glassEffect(.regular.tint(.blue.opacity(0.6)))
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // Pause expensive glass effects when backgrounded
                renderingOptimization = false
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                renderingOptimization = true
            }
    }
}

// Conditional glass effects based on device performance
extension View {
    @ViewBuilder
    func adaptiveGlassEffect(_ configuration: GlassConfiguration) -> some View {
        if ProcessInfo.processInfo.thermalState == .nominal {
            self.glassEffect(.regular.tint(configuration.primaryTint))
        } else {
            // Fallback to simpler effects on older devices
            self.background(configuration.primaryTint.opacity(0.3))
        }
    }
}
```

### Background Processing Optimization

```swift
actor BackgroundTaskManager {
    private var activeTasks: [String: Task<Void, Error>] = [:]
    
    func scheduleBackgroundSync() async {
        let taskId = "background-sync-\(UUID())"
        
        activeTasks[taskId] = Task {
            defer { activeTasks.removeValue(forKey: taskId) }
            
            // Perform background sync with proper resource management
            try await performOptimizedSync()
        }
    }
    
    private func performOptimizedSync() async throws {
        // Batch operations for efficiency
        let batchSize = 50
        let pendingItems = try await getPendingSyncItems()
        
        for batch in pendingItems.chunked(into: batchSize) {
            try await processBatch(batch)
            
            // Yield control to avoid blocking
            await Task.yield()
        }
    }
    
    func cancelAllTasks() async {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
    }
}
```

---

## Implementation Roadmap

### Phase 1: Foundation (Months 1-2)

**Week 1-2: Core Architecture Setup**
- [ ] Initialize Swift 6.2 project with concurrency features
- [ ] Set up SwiftData model layer with basic entities
- [ ] Implement base actor system (RuckDataRepository, LocationTrackingActor)
- [ ] Create fundamental Liquid Glass components

**Week 3-4: Basic Rucking Functionality**
- [ ] Implement location tracking with proper actor isolation
- [ ] Create basic rucking session management
- [ ] Build core UI components with Liquid Glass integration
- [ ] Implement calorie calculation algorithms (RUCKCAL™)

**Week 5-6: Data Persistence**
- [ ] Complete SwiftData model relationships
- [ ] Implement data repository pattern with actor isolation
- [ ] Create migration system for future schema changes
- [ ] Add basic offline data storage

**Week 7-8: Basic UI Implementation**
- [ ] Build main rucking interface with Liquid Glass
- [ ] Implement persona-specific UI adaptations
- [ ] Create settings and profile management screens
- [ ] Add basic navigation structure

### Phase 2: Persona Features (Months 3-4)

**Week 9-10: Military Veteran Features**
- [ ] Implement military fitness standards tracking
- [ ] Create unit/group challenge system
- [ ] Build equipment wear tracking
- [ ] Add veteran community features

**Week 11-12: Family & Parent Features**
- [ ] Create family-friendly route recommendations
- [ ] Implement safety features and emergency contacts
- [ ] Build parent accountability network
- [ ] Add child activity tracking (when applicable)

**Week 13-14: Urban Professional Features**
- [ ] City route optimization algorithms
- [ ] Social sharing and competitive features
- [ ] Integration with fitness wearables
- [ ] Advanced analytics and progress tracking

**Week 15-16: Senior & Adventure Features**
- [ ] Health monitoring integration
- [ ] Offline maps and route planning
- [ ] Equipment optimization recommendations
- [ ] Adventure-specific training programs

### Phase 3: Advanced Features (Months 5-6)

**Week 17-18: Advanced Concurrency**
- [ ] Implement complex data synchronization
- [ ] Add real-time collaboration features
- [ ] Create background processing optimization
- [ ] Build comprehensive error handling

**Week 19-20: Community & Social**
- [ ] Group rucking coordination
- [ ] Event planning and management
- [ ] Leaderboards and achievements
- [ ] Community content sharing

**Week 21-22: Health & Integration**
- [ ] HealthKit integration with actor isolation
- [ ] Third-party fitness app connections
- [ ] Medical provider data sharing
- [ ] Comprehensive health monitoring

**Week 23-24: Polish & Optimization**
- [ ] Performance optimization for all device types
- [ ] Comprehensive testing and bug fixes
- [ ] Accessibility improvements
- [ ] Final UI/UX polish with Liquid Glass refinements

---

## Risk Assessment and Mitigation

### Technical Risks

**Risk: Swift 6.2 Compatibility Issues**
- *Probability:* Medium
- *Impact:* High
- *Mitigation:* Maintain compatibility layers, extensive testing with beta versions, gradual feature adoption

**Risk: Liquid Glass Performance on Older Devices**
- *Probability:* High  
- *Impact:* Medium
- *Mitigation:* Adaptive rendering system, performance-based feature toggling, comprehensive device testing

**Risk: Actor Reentrancy Issues**
- *Probability:* Medium
- *Impact:* High
- *Mitigation:* Comprehensive concurrency testing, proper task cancellation strategies, actor design reviews

### Business Risks

**Risk: Persona Feature Complexity**
- *Probability:* High
- *Impact:* Medium
- *Mitigation:* Phased rollout, user feedback integration, modular feature architecture

**Risk: Battery Life Impact**
- *Probability:* Medium
- *Impact:* High
- *Mitigation:* Efficient location tracking, background processing optimization, user-configurable settings

### Mitigation Strategies

1. **Comprehensive Testing Strategy**
   - Unit tests for all actor interactions
   - UI tests for Liquid Glass components
   - Performance testing on various device configurations
   - User acceptance testing with target personas

2. **Gradual Feature Rollout**
   - MVP with core functionality first
   - Persona-specific features as optional modules
   - A/B testing for new features
   - User feedback integration loops

3. **Performance Monitoring**
   - Real-time performance metrics
   - Battery usage monitoring
   - Crash reporting and analysis
   - User experience feedback collection

---

## Conclusion

This architecture plan provides a comprehensive foundation for building the Ruck Map application using cutting-edge Swift 6.2 concurrency patterns and SwiftUI with Liquid Glass design integration. The modular, actor-based approach ensures thread safety while maintaining high performance and user experience quality.

The design specifically addresses the needs of the five identified user personas while providing a scalable foundation for future feature additions. The implementation roadmap provides a clear path to market while managing technical and business risks effectively.

**Key Success Factors:**
1. Proper adoption of Swift 6.2 concurrency patterns
2. Effective Liquid Glass design system integration
3. Persona-specific feature implementation
4. Comprehensive testing and performance optimization
5. Iterative development with user feedback integration

**Next Steps:**
1. Set up development environment with Swift 6.2 beta
2. Begin Phase 1 foundation implementation
3. Establish continuous integration with concurrency testing
4. Create design system documentation for Liquid Glass components
5. Begin user testing with core personas for feature validation

This architecture positions Ruck Map as a leading fitness application that leverages the latest iOS technologies while serving the specific needs of the rucking community across all identified user segments.