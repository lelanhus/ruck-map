# SwiftData Implementation Examples for RuckMap

## Complete Data Model Implementation

### 1. Core Models

```swift
import SwiftData
import CoreLocation

// MARK: - User Model
@Model
final class User {
    @Attribute(.unique) var id: UUID
    var name: String
    var weight: Double // in pounds
    var height: Double // in inches
    var birthDate: Date?
    var createdAt: Date
    var modifiedAt: Date
    
    @Relationship(deleteRule: .cascade)
    var sessions: [RuckSession]
    
    @Relationship(deleteRule: .cascade)
    var routes: [Route]
    
    @Relationship(deleteRule: .cascade)
    var preferences: UserPreferences?
    
    init(name: String, weight: Double, height: Double) {
        self.id = UUID()
        self.name = name
        self.weight = weight
        self.height = height
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.sessions = []
        self.routes = []
    }
}

// MARK: - RuckSession Model
@Model
final class RuckSession {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    var weight: Double // ruck weight in pounds
    var totalDistance: Double // in meters
    var totalCalories: Double
    var totalElevationGain: Double // in meters
    var totalWork: Double // in joules
    var averagePace: Double // min/km
    var averageHeartRate: Int?
    var rpe: Int? // Rate of Perceived Exertion (1-10)
    var notes: String?
    var isComplete: Bool
    
    @Relationship(inverse: \User.sessions)
    var user: User?
    
    @Relationship(deleteRule: .cascade)
    var waypoints: [Waypoint]
    
    @Relationship(deleteRule: .cascade)
    var segments: [SessionSegment]
    
    @Relationship
    var route: Route?
    
    @Relationship(deleteRule: .cascade)
    var weatherData: WeatherData?
    
    init(startDate: Date, weight: Double, user: User) {
        self.id = UUID()
        self.startDate = startDate
        self.weight = weight
        self.user = user
        self.totalDistance = 0
        self.totalCalories = 0
        self.totalElevationGain = 0
        self.totalWork = 0
        self.averagePace = 0
        self.isComplete = false
        self.waypoints = []
        self.segments = []
    }
}

// MARK: - Waypoint Model
@Model
final class Waypoint {
    var id: UUID
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var elevation: Double
    var speed: Double
    var heartRate: Int?
    var cadence: Int?
    
    @Relationship(inverse: \RuckSession.waypoints)
    var session: RuckSession?
    
    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        elevation: Double,
        speed: Double = 0
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.speed = speed
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Route Model
@Model
final class Route {
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var distance: Double
    var elevationGain: Double
    var estimatedDuration: TimeInterval
    var difficulty: RouteDifficulty
    var terrainType: TerrainType
    var createdAt: Date
    var modifiedAt: Date
    var isPublic: Bool
    var rating: Double?
    var timesCompleted: Int
    
    @Relationship(inverse: \User.routes)
    var creator: User?
    
    @Relationship
    var waypoints: [RouteWaypoint]
    
    @Relationship(inverse: \RuckSession.route)
    var sessions: [RuckSession]
    
    @Relationship
    var tags: [RouteTag]
    
    init(name: String, creator: User) {
        self.id = UUID()
        self.name = name
        self.creator = creator
        self.distance = 0
        self.elevationGain = 0
        self.estimatedDuration = 0
        self.difficulty = .moderate
        self.terrainType = .mixed
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isPublic = false
        self.timesCompleted = 0
        self.waypoints = []
        self.sessions = []
        self.tags = []
    }
}

// MARK: - Supporting Models
@Model
final class SessionSegment {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var distance: Double
    var elevationGain: Double
    var calories: Double
    var terrainType: TerrainType
    var averagePace: Double
    var averageHeartRate: Int?
    
    @Relationship(inverse: \RuckSession.segments)
    var session: RuckSession?
    
    init(startTime: Date, terrainType: TerrainType) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = startTime
        self.terrainType = terrainType
        self.distance = 0
        self.elevationGain = 0
        self.calories = 0
        self.averagePace = 0
    }
}

@Model
final class WeatherData {
    var id: UUID
    var timestamp: Date
    var temperature: Double // Celsius
    var humidity: Double // Percentage
    var windSpeed: Double // m/s
    var windDirection: Double // Degrees
    var pressure: Double // hPa
    var condition: String
    var visibility: Double // meters
    
    @Relationship(inverse: \RuckSession.weatherData)
    var session: RuckSession?
    
    init(timestamp: Date) {
        self.id = UUID()
        self.timestamp = timestamp
        self.temperature = 0
        self.humidity = 0
        self.windSpeed = 0
        self.windDirection = 0
        self.pressure = 1013.25
        self.condition = "Clear"
        self.visibility = 10000
    }
}

// MARK: - Enums
enum RouteDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case moderate = "Moderate"
    case hard = "Hard"
    case extreme = "Extreme"
}

enum TerrainType: String, Codable, CaseIterable {
    case pavement = "Pavement"
    case trail = "Trail"
    case sand = "Sand"
    case snow = "Snow"
    case mixed = "Mixed"
}
```

### 2. Repository Implementation

```swift
// MARK: - Repository Protocol
protocol RuckSessionRepository {
    func create(weight: Double, user: User) async throws -> RuckSession
    func fetchActive() async throws -> RuckSession?
    func fetchAll() async throws -> [RuckSession]
    func fetch(by id: UUID) async throws -> RuckSession?
    func update(_ session: RuckSession) async throws
    func complete(_ session: RuckSession, rpe: Int?, notes: String?) async throws
    func delete(_ session: RuckSession) async throws
    func fetchSessions(for user: User, limit: Int) async throws -> [RuckSession]
}

// MARK: - SwiftData Repository
@ModelActor
actor SwiftDataRuckSessionRepository: RuckSessionRepository {
    func create(weight: Double, user: User) async throws -> RuckSession {
        // Check for existing active session
        if let activeSession = try await fetchActive() {
            throw RuckMapError.activeSessionExists(activeSession.id)
        }
        
        let session = RuckSession(
            startDate: Date(),
            weight: weight,
            user: user
        )
        
        modelContext.insert(session)
        try modelContext.save()
        
        return session
    }
    
    func fetchActive() async throws -> RuckSession? {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { session in
                session.isComplete == false
            }
        )
        return try modelContext.fetch(descriptor).first
    }
    
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
    
    func update(_ session: RuckSession) async throws {
        session.modifiedAt = Date()
        try modelContext.save()
    }
    
    func complete(_ session: RuckSession, rpe: Int?, notes: String?) async throws {
        session.endDate = Date()
        session.isComplete = true
        session.rpe = rpe
        session.notes = notes
        
        try modelContext.save()
    }
    
    func delete(_ session: RuckSession) async throws {
        modelContext.delete(session)
        try modelContext.save()
    }
    
    func fetchSessions(for user: User, limit: Int = 50) async throws -> [RuckSession] {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { session in
                session.user?.id == user.id
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
}
```

### 3. Location Tracking Service

```swift
import CoreLocation
import Combine

@MainActor
class LocationTrackingService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var isTracking = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    private let repository: RuckSessionRepository
    private var activeSession: RuckSession?
    private var lastWaypointTime: Date?
    
    init(repository: RuckSessionRepository) {
        self.repository = repository
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
    }
    
    func startTracking(session: RuckSession) {
        activeSession = session
        isTracking = true
        locationManager.startUpdatingLocation()
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        activeSession = nil
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationTrackingService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              let session = activeSession,
              location.horizontalAccuracy > 0 else { return }
        
        currentLocation = location
        
        // Throttle waypoint creation (every 5 seconds)
        if let lastTime = lastWaypointTime,
           Date().timeIntervalSince(lastTime) < 5 {
            return
        }
        
        Task {
            await addWaypoint(location, to: session)
            lastWaypointTime = Date()
        }
    }
    
    private func addWaypoint(_ location: CLLocation, to session: RuckSession) async {
        let waypoint = Waypoint(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            elevation: location.altitude,
            speed: max(0, location.speed)
        )
        
        session.waypoints.append(waypoint)
        
        // Update session metrics
        updateSessionMetrics(session, with: location)
        
        do {
            try await repository.update(session)
        } catch {
            print("Failed to save waypoint: \(error)")
        }
    }
    
    private func updateSessionMetrics(_ session: RuckSession, with location: CLLocation) {
        // Calculate distance from last waypoint
        if let lastWaypoint = session.waypoints.dropLast().last {
            let lastLocation = CLLocation(
                latitude: lastWaypoint.latitude,
                longitude: lastWaypoint.longitude
            )
            
            let distance = location.distance(from: lastLocation)
            session.totalDistance += distance
            
            // Update elevation gain
            let elevationDiff = location.altitude - lastWaypoint.elevation
            if elevationDiff > 0 {
                session.totalElevationGain += elevationDiff
            }
        }
        
        // Update average pace
        let duration = Date().timeIntervalSince(session.startDate)
        if session.totalDistance > 0 && duration > 0 {
            let kmDistance = session.totalDistance / 1000
            let minutes = duration / 60
            session.averagePace = minutes / kmDistance
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
    }
}
```

### 4. View Model Implementation

```swift
@MainActor
class ActiveSessionViewModel: ObservableObject {
    @Published var activeSession: RuckSession?
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentPace: Double = 0
    @Published var isLoading = false
    @Published var error: Error?
    
    private let repository: RuckSessionRepository
    private let locationService: LocationTrackingService
    private let calorieCalculator: CalorieCalculator
    private var timer: Timer?
    
    init(
        repository: RuckSessionRepository,
        locationService: LocationTrackingService,
        calorieCalculator: CalorieCalculator
    ) {
        self.repository = repository
        self.locationService = locationService
        self.calorieCalculator = calorieCalculator
        
        setupBindings()
    }
    
    private func setupBindings() {
        locationService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.updateCurrentPace(from: location)
            }
            .store(in: &cancellables)
    }
    
    func startSession(weight: Double, user: User) async {
        isLoading = true
        error = nil
        
        do {
            let session = try await repository.create(weight: weight, user: user)
            activeSession = session
            
            locationService.startTracking(session: session)
            startTimer()
            
            // Fetch initial weather data
            await fetchWeatherData(for: session)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func endSession(rpe: Int?, notes: String?) async {
        guard let session = activeSession else { return }
        
        stopTimer()
        locationService.stopTracking()
        
        do {
            // Calculate final calories
            let calories = try await calorieCalculator.calculate(for: session)
            session.totalCalories = calories
            
            try await repository.complete(session, rpe: rpe, notes: notes)
            activeSession = nil
        } catch {
            self.error = error
        }
    }
    
    func pauseSession() {
        stopTimer()
        locationService.stopTracking()
    }
    
    func resumeSession() {
        guard let session = activeSession else { return }
        locationService.startTracking(session: session)
        startTimer()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateElapsedTime() {
        guard let session = activeSession else { return }
        elapsedTime = Date().timeIntervalSince(session.startDate)
    }
    
    private func updateCurrentPace(from location: CLLocation) {
        guard location.speed > 0 else {
            currentPace = 0
            return
        }
        
        // Convert m/s to min/km
        let metersPerSecond = location.speed
        let kilometersPerHour = metersPerSecond * 3.6
        let minutesPerKilometer = 60.0 / kilometersPerHour
        
        currentPace = minutesPerKilometer
    }
    
    private func fetchWeatherData(for session: RuckSession) async {
        // Implementation for fetching weather data
        // This would use WeatherKit or similar service
    }
}
```

### 5. SwiftUI Views

```swift
// MARK: - Active Session View
struct ActiveSessionView: View {
    @StateObject private var viewModel: ActiveSessionViewModel
    @State private var showEndSessionSheet = false
    
    init(dependencies: AppDependencies) {
        _viewModel = StateObject(
            wrappedValue: ActiveSessionViewModel(
                repository: dependencies.sessionRepository,
                locationService: dependencies.locationService,
                calorieCalculator: dependencies.calorieCalculator
            )
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if let session = viewModel.activeSession {
                // Timer Display
                Text(formatTime(viewModel.elapsedTime))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                
                // Metrics Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    MetricCard(
                        title: "Distance",
                        value: formatDistance(session.totalDistance),
                        unit: "km"
                    )
                    
                    MetricCard(
                        title: "Pace",
                        value: formatPace(viewModel.currentPace),
                        unit: "min/km"
                    )
                    
                    MetricCard(
                        title: "Calories",
                        value: "\(Int(session.totalCalories))",
                        unit: "cal"
                    )
                    
                    MetricCard(
                        title: "Elevation",
                        value: "\(Int(session.totalElevationGain))",
                        unit: "m"
                    )
                }
                
                // Control Buttons
                HStack(spacing: 20) {
                    Button(action: { viewModel.pauseSession() }) {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: { showEndSessionSheet = true }) {
                        Label("End", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            } else {
                StartSessionView(viewModel: viewModel)
            }
        }
        .padding()
        .sheet(isPresented: $showEndSessionSheet) {
            EndSessionSheet(viewModel: viewModel)
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let km = meters / 1000
        return String(format: "%.2f", km)
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 && pace.isFinite else { return "--:--" }
        
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Metric Card Component
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
```

### 6. Testing Implementation

```swift
// MARK: - Repository Tests
class RuckSessionRepositoryTests: XCTestCase {
    var repository: RuckSessionRepository!
    var modelContainer: ModelContainer!
    var user: User!
    
    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: [RuckSession.self, User.self, Waypoint.self],
            configurations: config
        )
        
        repository = SwiftDataRuckSessionRepository(
            modelContainer: modelContainer
        )
        
        user = User(name: "Test User", weight: 150, height: 70)
        let context = modelContainer.mainContext
        context.insert(user)
        try context.save()
    }
    
    func testCreateSession() async throws {
        // Act
        let session = try await repository.create(weight: 35, user: user)
        
        // Assert
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.weight, 35)
        XCTAssertEqual(session.user?.id, user.id)
        XCTAssertFalse(session.isComplete)
    }
    
    func testCannotCreateMultipleActiveSessions() async throws {
        // Arrange
        _ = try await repository.create(weight: 35, user: user)
        
        // Act & Assert
        do {
            _ = try await repository.create(weight: 40, user: user)
            XCTFail("Should not create multiple active sessions")
        } catch RuckMapError.activeSessionExists {
            // Expected error
        }
    }
    
    func testCompleteSession() async throws {
        // Arrange
        let session = try await repository.create(weight: 35, user: user)
        
        // Act
        try await repository.complete(session, rpe: 7, notes: "Good ruck")
        
        // Assert
        XCTAssertNotNil(session.endDate)
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.rpe, 7)
        XCTAssertEqual(session.notes, "Good ruck")
    }
}

// MARK: - View Model Tests
@MainActor
class ActiveSessionViewModelTests: XCTestCase {
    var viewModel: ActiveSessionViewModel!
    var mockRepository: MockRuckSessionRepository!
    var mockLocationService: MockLocationTrackingService!
    var mockCalorieCalculator: MockCalorieCalculator!
    
    override func setUp() {
        mockRepository = MockRuckSessionRepository()
        mockLocationService = MockLocationTrackingService()
        mockCalorieCalculator = MockCalorieCalculator()
        
        viewModel = ActiveSessionViewModel(
            repository: mockRepository,
            locationService: mockLocationService,
            calorieCalculator: mockCalorieCalculator
        )
    }
    
    func testStartSession() async throws {
        // Arrange
        let user = User(name: "Test", weight: 150, height: 70)
        
        // Act
        await viewModel.startSession(weight: 35, user: user)
        
        // Assert
        XCTAssertNotNil(viewModel.activeSession)
        XCTAssertTrue(mockLocationService.isTracking)
        XCTAssertEqual(mockRepository.createCallCount, 1)
    }
}
```

## Key Implementation Points

1. **Model Design**: Use @Model macro with proper relationships and delete rules
2. **Repository Pattern**: Abstract SwiftData operations for better testability
3. **Actor Isolation**: Use @ModelActor for thread-safe data operations
4. **Background Processing**: Handle location updates efficiently
5. **Testing**: Comprehensive unit and integration tests with mocks
6. **Error Handling**: Proper error types and recovery strategies
7. **Performance**: Optimize queries and batch operations

This implementation provides a solid foundation for the RuckMap application with proper separation of concerns, testability, and adherence to SwiftData best practices.