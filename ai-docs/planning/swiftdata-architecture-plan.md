# SwiftData Architecture Plan for Ruck Map

## Executive Summary

This comprehensive architecture plan designs a domain-driven SwiftData model system for the Ruck Map application, integrating seamlessly with CloudKit for multi-device synchronization. The architecture emphasizes offline-first capabilities, robust data consistency, and persona-specific optimization while maintaining testability and performance.

**Key Architecture Highlights:**
- Domain-driven design with clear aggregate boundaries
- Actor-isolated data operations for thread safety
- CloudKit integration with conflict resolution strategies
- Persona-specific data models supporting all user types
- Comprehensive migration and versioning strategy
- Offline-first architecture with intelligent sync patterns

**Technology Stack:**
- SwiftData with iOS 17+ features
- CloudKit private database integration
- Actor-based concurrency patterns
- Custom query optimization
- Background sync and conflict resolution

---

## Research Summary: Current SwiftData Best Practices

### Key Findings from Industry Research

**SwiftData Evolution (2024-2025):**
- SwiftData has matured significantly since WWDC 2023
- iOS 17+ introduces enhanced CloudKit integration capabilities
- Actor isolation patterns are now recommended for data operations
- Preview modifier patterns simplify testing and development
- Domain-driven design principles align well with SwiftData's @Model approach

**CloudKit Integration Patterns:**
- Seamless private database sync with minimal configuration
- Requires default values for all model properties
- Cannot use unique constraints with CloudKit sync
- Silent push notifications require dynamic @Query patterns for UI updates
- Background sync requires careful conflict resolution strategies

**Best Practices Identified:**
1. **Business Logic in Models**: Place domain logic directly in @Model classes for simplicity and testability
2. **Dynamic Queries**: Use initialization-based @Query construction for runtime filtering
3. **Actor Isolation**: Implement dedicated actors for data operations to ensure thread safety
4. **Preview Modifiers**: Use PreviewModifier and PreviewTrait for clean, reusable test data
5. **Offline-First Design**: Prioritize local data with background sync for optimal user experience

---

## Domain Model Architecture

### Aggregate Design and Bounded Contexts

The Ruck Map domain is organized into four primary aggregates with clear boundaries:

```
┌─────────────────────────────────────────────────────────────┐
│                    RUCK MAP DOMAIN                         │
├─────────────────────────────────────────────────────────────┤
│  User Aggregate          │  Activity Aggregate             │
│  ├─ User (Root)          │  ├─ RuckingSession (Root)       │
│  ├─ UserProfile          │  ├─ LocationPoint               │
│  ├─ UserPreferences      │  ├─ ActivityMetrics             │
│  └─ HealthMetrics        │  └─ SessionStats                │
├─────────────────────────────────────────────────────────────┤
│  Route Aggregate         │  Community Aggregate            │
│  ├─ Route (Root)         │  ├─ Group (Root)                │
│  ├─ Waypoint             │  ├─ Challenge                   │
│  ├─ Elevation            │  ├─ Achievement                 │
│  └─ RouteMetrics         │  └─ SocialActivity              │
└─────────────────────────────────────────────────────────────┘
```

### Core Domain Models

#### 1. User Aggregate

```swift
import SwiftData
import Foundation

@Model
final class User {
    // Primary identifiers
    @Attribute(.unique) var id: UUID
    var email: String
    var displayName: String
    var createdAt: Date
    var lastSyncDate: Date
    var isActive: Bool
    
    // Persona and preferences
    var persona: UserPersona
    var preferences: UserPreferences
    var healthProfile: HealthProfile
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \RuckingSession.user)
    var sessions: [RuckingSession] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Equipment.owner)
    var equipment: [Equipment] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Route.creator)
    var createdRoutes: [Route] = []
    
    @Relationship(deleteRule: .nullify)
    var groupMemberships: [GroupMembership] = []
    
    // Domain invariants and business rules
    init(email: String, displayName: String, persona: UserPersona) {
        self.id = UUID()
        self.email = email
        self.displayName = displayName
        self.persona = persona
        self.createdAt = Date()
        self.lastSyncDate = Date()
        self.isActive = true
        self.preferences = UserPreferences.defaultFor(persona: persona)
        self.healthProfile = HealthProfile()
    }
    
    // Business logic
    func updatePersona(_ newPersona: UserPersona) throws {
        guard newPersona != persona else { return }
        
        // Validate persona transition rules
        if !canTransitionTo(newPersona) {
            throw UserError.invalidPersonaTransition
        }
        
        persona = newPersona
        preferences = UserPreferences.defaultFor(persona: newPersona)
        lastSyncDate = Date()
    }
    
    private func canTransitionTo(_ newPersona: UserPersona) -> Bool {
        // Define valid persona transitions based on business rules
        switch (persona, newPersona) {
        case (.general, _): return true  // General users can transition to any specific persona
        case (_, .general): return false // Cannot downgrade to general
        default: return true // Allow transitions between specific personas
        }
    }
    
    // Computed properties for business logic
    var totalRuckingDistance: Double {
        sessions.reduce(0) { $0 + $1.distance }
    }
    
    var averagePackWeight: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.packWeight } / Double(sessions.count)
    }
    
    var experienceLevel: ExperienceLevel {
        let totalSessions = sessions.count
        let totalDistance = totalRuckingDistance
        
        switch (totalSessions, totalDistance) {
        case (0..<5, 0..<25): return .beginner
        case (5..<20, 25..<100): return .intermediate
        case (20..<50, 100..<500): return .advanced
        default: return .expert
        }
    }
}

// Supporting value types
struct UserPreferences: Codable {
    var unitSystem: UnitSystem = .imperial
    var privacyLevel: PrivacyLevel = .public
    var notificationSettings: NotificationSettings = NotificationSettings()
    var displaySettings: DisplaySettings = DisplaySettings()
    
    static func defaultFor(persona: UserPersona) -> UserPreferences {
        var preferences = UserPreferences()
        
        switch persona {
        case .militaryVeteran:
            preferences.unitSystem = .imperial
            preferences.displaySettings.showMilitaryTime = true
            preferences.displaySettings.emphasizeDistance = true
            
        case .fitnessEnthusiast:
            preferences.unitSystem = .metric
            preferences.displaySettings.showCalories = true
            preferences.displaySettings.showHeartRate = true
            
        case .urbanProfessional:
            preferences.displaySettings.showSocialFeatures = true
            preferences.notificationSettings.challengeReminders = true
            
        case .healthConsciousRetiree:
            preferences.displaySettings.largeText = true
            preferences.displaySettings.simplifiedUI = true
            preferences.privacyLevel = .private
            
        case .outdoorAdventurer:
            preferences.displaySettings.showElevation = true
            preferences.displaySettings.showWeather = true
            preferences.unitSystem = .imperial
            
        case .general:
            break // Use defaults
        }
        
        return preferences
    }
}

struct HealthProfile: Codable {
    var age: Int?
    var weight: Double?
    var height: Double?
    var fitnessLevel: FitnessLevel = .moderate
    var healthConditions: [HealthCondition] = []
    var maxHeartRate: Int?
    var restingHeartRate: Int?
    
    // Business logic for health calculations
    var bmi: Double? {
        guard let weight = weight, let height = height, height > 0 else { return nil }
        return weight / (height * height) * 703 // BMI formula
    }
    
    var recommendedMaxPackWeight: Double? {
        guard let weight = weight else { return nil }
        
        switch fitnessLevel {
        case .low: return weight * 0.10
        case .moderate: return weight * 0.15
        case .high: return weight * 0.20
        case .expert: return weight * 0.25
        }
    }
}

enum UserPersona: String, Codable, CaseIterable {
    case militaryVeteran = "military_veteran"
    case fitnessEnthusiast = "fitness_enthusiast"
    case urbanProfessional = "urban_professional"
    case healthConsciousRetiree = "health_conscious_retiree"
    case outdoorAdventurer = "outdoor_adventurer"
    case general = "general"
}

enum ExperienceLevel: String, Codable {
    case beginner, intermediate, advanced, expert
}

enum FitnessLevel: String, Codable {
    case low, moderate, high, expert
}

enum UnitSystem: String, Codable {
    case imperial, metric
}

enum PrivacyLevel: String, Codable {
    case `private`, friends, public
}
```

#### 2. Activity Aggregate

```swift
@Model
final class RuckingSession {
    // Primary identifiers
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    var isCompleted: Bool
    
    // Core metrics
    var distance: Double = 0.0
    var duration: TimeInterval = 0.0
    var packWeight: Double = 0.0
    var elevationGain: Double = 0.0
    var elevationLoss: Double = 0.0
    
    // Calculated metrics
    var calories: Double = 0.0
    var averagePace: Double = 0.0
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    
    // Environmental data
    var weather: WeatherData?
    var temperature: Double?
    var humidity: Double?
    
    // Relationships
    @Relationship(deleteRule: .nullify)
    var user: User?
    
    @Relationship(deleteRule: .nullify)
    var route: Route?
    
    @Relationship(deleteRule: .cascade)
    var locationPoints: [LocationPoint] = []
    
    @Relationship(deleteRule: .cascade)
    var metrics: [ActivityMetric] = []
    
    @Relationship(deleteRule: .nullify)
    var equipment: [Equipment] = []
    
    // CloudKit sync fields
    var syncStatus: SyncStatus = .pending
    var lastModified: Date
    
    init(startDate: Date, packWeight: Double, user: User) {
        self.id = UUID()
        self.startDate = startDate
        self.packWeight = packWeight
        self.user = user
        self.isCompleted = false
        self.lastModified = Date()
    }
    
    // Business Logic - Core Domain Methods
    
    func completeSession(endDate: Date, finalDistance: Double) throws {
        guard !isCompleted else {
            throw SessionError.alreadyCompleted
        }
        
        guard endDate > startDate else {
            throw SessionError.invalidEndDate
        }
        
        self.endDate = endDate
        self.distance = finalDistance
        self.duration = endDate.timeIntervalSince(startDate)
        self.isCompleted = true
        self.lastModified = Date()
        
        // Calculate derived metrics
        calculateDerivedMetrics()
        
        // Validate session integrity
        try validateSessionIntegrity()
    }
    
    private func calculateDerivedMetrics() {
        // Calculate pace (minutes per mile/km)
        if distance > 0 {
            averagePace = (duration / 60) / distance
        }
        
        // Calculate calories using RUCKCAL algorithm
        calories = RuckingCalculator.calculateCalories(
            weight: packWeight,
            bodyWeight: user?.healthProfile.weight ?? 70.0,
            distance: distance,
            time: duration,
            elevation: elevationGain,
            persona: user?.persona ?? .general
        )
        
        // Calculate heart rate metrics if available
        if !metrics.isEmpty {
            let heartRates = metrics.compactMap { $0.heartRate }
            if !heartRates.isEmpty {
                averageHeartRate = Int(heartRates.reduce(0, +) / heartRates.count)
                maxHeartRate = heartRates.max()
            }
        }
    }
    
    private func validateSessionIntegrity() throws {
        // Validate minimum session duration
        guard duration >= 60 else { // At least 1 minute
            throw SessionError.sessionTooShort
        }
        
        // Validate reasonable distance
        guard distance <= 50.0 else { // Max 50 miles/km per session
            throw SessionError.unreasonableDistance
        }
        
        // Validate pack weight
        if let userWeight = user?.healthProfile.weight {
            let maxRecommended = userWeight * 0.3 // 30% of body weight
            if packWeight > maxRecommended {
                // Log warning but don't throw - user choice
                print("Warning: Pack weight exceeds recommended maximum")
            }
        }
    }
    
    // Computed Properties - Business Logic
    
    var ruckWork: Double {
        // Ruck Work = Weight × Distance (military metric)
        return packWeight * distance
    }
    
    var ruckPower: Double {
        // Ruck Power = Ruck Work ÷ Time
        guard duration > 0 else { return 0 }
        return ruckWork / (duration / 3600) // Per hour
    }
    
    var intensityScore: Double {
        // Custom intensity calculation based on multiple factors
        let baseIntensity = ruckWork / 100.0
        let elevationFactor = (elevationGain / 100.0) * 1.2
        let paceFactor = averagePace > 0 ? (15.0 / averagePace) : 1.0
        
        return (baseIntensity + elevationFactor) * paceFactor
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    var formattedPace: String {
        guard averagePace > 0 else { return "--" }
        let minutes = Int(averagePace)
        let seconds = Int((averagePace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Query helpers for common operations
    static var recentSessions: FetchDescriptor<RuckingSession> {
        let descriptor = FetchDescriptor<RuckingSession>(
            predicate: #Predicate { $0.isCompleted },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        return descriptor
    }
    
    static func sessionsForUser(_ userId: UUID) -> FetchDescriptor<RuckingSession> {
        FetchDescriptor<RuckingSession>(
            predicate: #Predicate { session in
                session.user?.id == userId && session.isCompleted
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
    }
}

@Model
final class LocationPoint {
    var id: UUID
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var accuracy: Double
    var speed: Double?
    var heading: Double?
    
    @Relationship(deleteRule: .nullify)
    var session: RuckingSession?
    
    init(timestamp: Date, latitude: Double, longitude: Double, accuracy: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
    }
    
    // Business logic for location processing
    func distanceTo(_ other: LocationPoint) -> Double {
        LocationCalculator.haversineDistance(
            from: (latitude, longitude),
            to: (other.latitude, other.longitude)
        )
    }
    
    var isAccurate: Bool {
        accuracy <= 10.0 // Within 10 meters
    }
}

@Model
final class ActivityMetric {
    var id: UUID
    var timestamp: Date
    var metricType: MetricType
    var value: Double
    var unit: String
    
    // Specific metric values
    var heartRate: Int?
    var cadence: Int?
    var power: Double?
    
    @Relationship(deleteRule: .nullify)
    var session: RuckingSession?
    
    init(timestamp: Date, type: MetricType, value: Double, unit: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.metricType = type
        self.value = value
        self.unit = unit
    }
}

enum MetricType: String, Codable {
    case heartRate = "heart_rate"
    case cadence = "cadence"
    case power = "power"
    case pace = "pace"
    case elevation = "elevation"
    case temperature = "temperature"
}

enum SyncStatus: String, Codable {
    case pending, syncing, synced, failed
}

struct WeatherData: Codable {
    var condition: String
    var temperature: Double
    var humidity: Double
    var windSpeed: Double?
    var windDirection: Double?
    var pressure: Double?
}
```

#### 3. Route Aggregate

```swift
@Model
final class Route {
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var distance: Double
    var elevationGain: Double
    var elevationLoss: Double
    var difficulty: RouteDifficulty
    var estimatedDuration: TimeInterval
    
    // Categorization
    var routeType: RouteType
    var terrain: TerrainType
    var tags: [String] = []
    
    // Visibility and sharing
    var isPublic: Bool = false
    var isOfficial: Bool = false
    var createdAt: Date
    var lastModified: Date
    
    // Location data
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double?
    var endLongitude: Double?
    
    // Relationships
    @Relationship(deleteRule: .nullify)
    var creator: User?
    
    @Relationship(deleteRule: .cascade)
    var waypoints: [Waypoint] = []
    
    @Relationship(deleteRule: .nullify, inverse: \RuckingSession.route)
    var sessions: [RuckingSession] = []
    
    @Relationship(deleteRule: .cascade)
    var reviews: [RouteReview] = []
    
    init(name: String, distance: Double, startLat: Double, startLon: Double, creator: User?) {
        self.id = UUID()
        self.name = name
        self.distance = distance
        self.startLatitude = startLat
        self.startLongitude = startLon
        self.creator = creator
        self.createdAt = Date()
        self.lastModified = Date()
        self.elevationGain = 0
        self.elevationLoss = 0
        self.difficulty = .moderate
        self.routeType = .loop
        self.terrain = .mixed
        self.estimatedDuration = 0
    }
    
    // Business Logic
    
    func updateDifficulty() {
        // Auto-calculate difficulty based on distance, elevation, and terrain
        let distanceFactor = distance / 10.0 // Normalize to 10 miles
        let elevationFactor = elevationGain / 1000.0 // Normalize to 1000 feet
        let terrainFactor = terrain.difficultyMultiplier
        
        let difficultyScore = (distanceFactor + elevationFactor) * terrainFactor
        
        switch difficultyScore {
        case 0..<1.0:
            difficulty = .easy
        case 1.0..<2.5:
            difficulty = .moderate
        case 2.5..<4.0:
            difficulty = .hard
        default:
            difficulty = .extreme
        }
        
        lastModified = Date()
    }
    
    func addWaypoint(name: String, latitude: Double, longitude: Double, type: WaypointType) {
        let waypoint = Waypoint(
            name: name,
            latitude: latitude,
            longitude: longitude,
            type: type,
            order: waypoints.count
        )
        waypoint.route = self
        waypoints.append(waypoint)
        lastModified = Date()
    }
    
    func canBeEditedBy(_ user: User) -> Bool {
        return creator?.id == user.id || user.isAdmin
    }
    
    // Computed Properties
    
    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return reviews.reduce(0) { $0 + $1.rating } / Double(reviews.count)
    }
    
    var totalCompletions: Int {
        sessions.filter { $0.isCompleted }.count
    }
    
    var isPopular: Bool {
        totalCompletions >= 50 && averageRating >= 4.0
    }
    
    var estimatedCalories: Double {
        // Base calories for average user (70kg with 15kg pack)
        RuckingCalculator.calculateCalories(
            weight: 15.0,
            bodyWeight: 70.0,
            distance: distance,
            time: estimatedDuration,
            elevation: elevationGain,
            persona: .general
        )
    }
    
    // Query Helpers
    
    static var popularRoutes: FetchDescriptor<Route> {
        FetchDescriptor<Route>(
            predicate: #Predicate { route in
                route.isPublic && route.sessions.count >= 10
            },
            sortBy: [SortDescriptor(\.sessions.count, order: .reverse)]
        )
    }
    
    static func routesNear(latitude: Double, longitude: Double, radius: Double) -> FetchDescriptor<Route> {
        // Note: This is simplified - in production, you'd use spatial queries
        FetchDescriptor<Route>(
            predicate: #Predicate { route in
                route.isPublic
            }
        )
    }
}

@Model
final class Waypoint {
    var id: UUID
    var name: String
    var description: String?
    var latitude: Double
    var longitude: Double
    var elevation: Double?
    var waypointType: WaypointType
    var order: Int
    
    @Relationship(deleteRule: .nullify)
    var route: Route?
    
    init(name: String, latitude: Double, longitude: Double, type: WaypointType, order: Int) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.waypointType = type
        self.order = order
    }
}

@Model
final class RouteReview {
    var id: UUID
    var rating: Double // 1.0 to 5.0
    var comment: String?
    var createdAt: Date
    var difficulty: RouteDifficulty?
    var recommendedPackWeight: Double?
    
    @Relationship(deleteRule: .nullify)
    var route: Route?
    
    @Relationship(deleteRule: .nullify)
    var reviewer: User?
    
    init(rating: Double, reviewer: User) {
        self.id = UUID()
        self.rating = max(1.0, min(5.0, rating)) // Clamp to valid range
        self.reviewer = reviewer
        self.createdAt = Date()
    }
}

enum RouteDifficulty: String, Codable, CaseIterable {
    case easy, moderate, hard, extreme
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .moderate: return "Moderate"
        case .hard: return "Hard"
        case .extreme: return "Extreme"
        }
    }
}

enum RouteType: String, Codable {
    case loop, outAndBack = "out_and_back", pointToPoint = "point_to_point"
}

enum TerrainType: String, Codable {
    case urban, trail, mixed, mountain, beach
    
    var difficultyMultiplier: Double {
        switch self {
        case .urban: return 1.0
        case .trail: return 1.2
        case .mixed: return 1.1
        case .mountain: return 1.5
        case .beach: return 1.3
        }
    }
}

enum WaypointType: String, Codable {
    case start, checkpoint, waterStop = "water_stop", restArea = "rest_area", scenic, finish
}
```

#### 4. Equipment Aggregate

```swift
@Model
final class Equipment {
    @Attribute(.unique) var id: UUID
    var name: String
    var brand: String?
    var model: String?
    var equipmentType: EquipmentType
    var weight: Double
    var purchaseDate: Date?
    var purchasePrice: Double?
    var isActive: Bool = true
    
    // Usage tracking
    var totalDistance: Double = 0.0
    var totalSessions: Int = 0
    var totalHours: TimeInterval = 0.0
    var lastUsed: Date?
    
    // Maintenance
    var maintenanceNotes: String?
    var nextMaintenanceDate: Date?
    var replacementRecommendedAt: Double? // Distance or hours
    
    // Relationships
    @Relationship(deleteRule: .nullify)
    var owner: User?
    
    @Relationship(deleteRule: .nullify)
    var sessions: [RuckingSession] = []
    
    init(name: String, type: EquipmentType, weight: Double, owner: User?) {
        self.id = UUID()
        self.name = name
        self.equipmentType = type
        self.weight = weight
        self.owner = owner
        self.purchaseDate = Date()
    }
    
    // Business Logic
    
    func recordUsage(distance: Double, duration: TimeInterval) {
        totalDistance += distance
        totalSessions += 1
        totalHours += duration
        lastUsed = Date()
        
        // Check if replacement is recommended
        checkReplacementNeeded()
    }
    
    private func checkReplacementNeeded() {
        guard let threshold = replacementRecommendedAt else { return }
        
        let usageMetric = equipmentType.usesDistanceForReplacement ? totalDistance : totalHours
        
        if usageMetric >= threshold {
            // Could trigger notification or flag for user attention
            print("Equipment \(name) may need replacement")
        }
    }
    
    func estimateRemainingLife() -> Double? {
        guard let threshold = replacementRecommendedAt else { return nil }
        
        let usageMetric = equipmentType.usesDistanceForReplacement ? totalDistance : totalHours
        let remaining = threshold - usageMetric
        
        return max(0, remaining / threshold) // Percentage remaining
    }
    
    // Computed Properties
    
    var averageDistancePerSession: Double {
        guard totalSessions > 0 else { return 0 }
        return totalDistance / Double(totalSessions)
    }
    
    var costPerMile: Double? {
        guard let price = purchasePrice, totalDistance > 0 else { return nil }
        return price / totalDistance
    }
    
    var needsReplacement: Bool {
        guard let threshold = replacementRecommendedAt else { return false }
        let usageMetric = equipmentType.usesDistanceForReplacement ? totalDistance : totalHours
        return usageMetric >= threshold
    }
}

enum EquipmentType: String, Codable, CaseIterable {
    case backpack, boots, clothing, accessories
    
    var usesDistanceForReplacement: Bool {
        switch self {
        case .backpack, .boots: return true
        case .clothing, .accessories: return false
        }
    }
    
    var typicalReplacementThreshold: Double {
        switch self {
        case .backpack: return 2000.0 // miles
        case .boots: return 500.0 // miles
        case .clothing: return 200.0 // hours
        case .accessories: return 1000.0 // hours
        }
    }
}
```

---

## Data Access Architecture

### Actor-Based Repository Pattern

```swift
import SwiftData
import Foundation

@ModelActor
actor RuckMapDataActor {
    typealias DataResult<T> = Result<T, DataError>
    
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
    }
    
    // MARK: - User Operations
    
    func createUser(email: String, displayName: String, persona: UserPersona) async -> DataResult<User> {
        do {
            // Check for existing user
            if try userExists(email: email) {
                return .failure(.duplicateEmail)
            }
            
            let user = User(email: email, displayName: displayName, persona: persona)
            modelContext.insert(user)
            try modelContext.save()
            
            return .success(user)
        } catch {
            return .failure(.saveError(error))
        }
    }
    
    func fetchUser(id: UUID) async -> DataResult<User?> {
        do {
            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate { $0.id == id }
            )
            let users = try modelContext.fetch(descriptor)
            return .success(users.first)
        } catch {
            return .failure(.fetchError(error))
        }
    }
    
    private func userExists(email: String) throws -> Bool {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.email == email }
        )
        let users = try modelContext.fetch(descriptor)
        return !users.isEmpty
    }
    
    // MARK: - Session Operations
    
    func startRuckingSession(userId: UUID, packWeight: Double, routeId: UUID? = nil) async -> DataResult<RuckingSession> {
        do {
            guard let user = try fetchUserById(userId) else {
                return .failure(.userNotFound)
            }
            
            // Check for existing active session
            if let activeSession = try findActiveSession(for: user) {
                return .failure(.activeSessionExists(activeSession.id))
            }
            
            let session = RuckingSession(
                startDate: Date(),
                packWeight: packWeight,
                user: user
            )
            
            // Associate route if provided
            if let routeId = routeId {
                session.route = try fetchRouteById(routeId)
            }
            
            modelContext.insert(session)
            try modelContext.save()
            
            return .success(session)
        } catch {
            return .failure(.saveError(error))
        }
    }
    
    func completeRuckingSession(sessionId: UUID, endDate: Date, finalDistance: Double, locationPoints: [LocationPoint]) async -> DataResult<RuckingSession> {
        do {
            guard let session = try fetchSessionById(sessionId) else {
                return .failure(.sessionNotFound)
            }
            
            try session.completeSession(endDate: endDate, finalDistance: finalDistance)
            
            // Add location points
            for point in locationPoints {
                point.session = session
                modelContext.insert(point)
            }
            
            try modelContext.save()
            return .success(session)
        } catch let sessionError as SessionError {
            return .failure(.businessLogicError(sessionError.localizedDescription))
        } catch {
            return .failure(.saveError(error))
        }
    }
    
    // MARK: - Route Operations
    
    func createRoute(name: String, distance: Double, startLat: Double, startLon: Double, creatorId: UUID) async -> DataResult<Route> {
        do {
            guard let creator = try fetchUserById(creatorId) else {
                return .failure(.userNotFound)
            }
            
            let route = Route(
                name: name,
                distance: distance,
                startLat: startLat,
                startLon: startLon,
                creator: creator
            )
            
            modelContext.insert(route)
            try modelContext.save()
            
            return .success(route)
        } catch {
            return .failure(.saveError(error))
        }
    }
    
    func fetchPopularRoutes(limit: Int = 20) async -> DataResult<[Route]> {
        do {
            let descriptor = Route.popularRoutes
            descriptor.fetchLimit = limit
            let routes = try modelContext.fetch(descriptor)
            return .success(routes)
        } catch {
            return .failure(.fetchError(error))
        }
    }
    
    // MARK: - Equipment Operations
    
    func addEquipment(name: String, type: EquipmentType, weight: Double, ownerId: UUID) async -> DataResult<Equipment> {
        do {
            guard let owner = try fetchUserById(ownerId) else {
                return .failure(.userNotFound)
            }
            
            let equipment = Equipment(name: name, type: type, weight: weight, owner: owner)
            modelContext.insert(equipment)
            try modelContext.save()
            
            return .success(equipment)
        } catch {
            return .failure(.saveError(error))
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchUserById(_ id: UUID) throws -> User? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    private func fetchSessionById(_ id: UUID) throws -> RuckingSession? {
        let descriptor = FetchDescriptor<RuckingSession>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    private func fetchRouteById(_ id: UUID) throws -> Route? {
        let descriptor = FetchDescriptor<Route>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    private func findActiveSession(for user: User) throws -> RuckingSession? {
        let descriptor = FetchDescriptor<RuckingSession>(
            predicate: #Predicate { session in
                session.user?.id == user.id && !session.isCompleted
            }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    // MARK: - Batch Operations for Sync
    
    func getUnsyncedData() async -> DataResult<UnsyncedDataBatch> {
        do {
            let unsyncedSessions = try fetchUnsyncedSessions()
            let unsyncedRoutes = try fetchUnsyncedRoutes()
            let unsyncedEquipment = try fetchUnsyncedEquipment()
            
            let batch = UnsyncedDataBatch(
                sessions: unsyncedSessions,
                routes: unsyncedRoutes,
                equipment: unsyncedEquipment
            )
            
            return .success(batch)
        } catch {
            return .failure(.fetchError(error))
        }
    }
    
    private func fetchUnsyncedSessions() throws -> [RuckingSession] {
        let descriptor = FetchDescriptor<RuckingSession>(
            predicate: #Predicate { $0.syncStatus != .synced }
        )
        return try modelContext.fetch(descriptor)
    }
    
    private func fetchUnsyncedRoutes() throws -> [Route] {
        let descriptor = FetchDescriptor<Route>(
            predicate: #Predicate { route in
                route.lastModified > route.creator?.lastSyncDate ?? Date.distantPast
            }
        )
        return try modelContext.fetch(descriptor)
    }
    
    private func fetchUnsyncedEquipment() throws -> [Equipment] {
        let descriptor = FetchDescriptor<Equipment>(
            predicate: #Predicate { equipment in
                equipment.lastUsed ?? Date.distantPast > equipment.owner?.lastSyncDate ?? Date.distantPast
            }
        )
        return try modelContext.fetch(descriptor)
    }
}

// MARK: - Error Handling

enum DataError: LocalizedError {
    case duplicateEmail
    case userNotFound
    case sessionNotFound
    case activeSessionExists(UUID)
    case businessLogicError(String)
    case saveError(Error)
    case fetchError(Error)
    case syncError(Error)
    
    var errorDescription: String? {
        switch self {
        case .duplicateEmail:
            return "An account with this email already exists"
        case .userNotFound:
            return "User not found"
        case .sessionNotFound:
            return "Rucking session not found"
        case .activeSessionExists(let id):
            return "Active session \(id) already exists"
        case .businessLogicError(let message):
            return message
        case .saveError(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchError(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        case .syncError(let error):
            return "Sync failed: \(error.localizedDescription)"
        }
    }
}

enum SessionError: LocalizedError {
    case alreadyCompleted
    case invalidEndDate
    case sessionTooShort
    case unreasonableDistance
    
    var errorDescription: String? {
        switch self {
        case .alreadyCompleted:
            return "Session is already completed"
        case .invalidEndDate:
            return "End date must be after start date"
        case .sessionTooShort:
            return "Session must be at least 1 minute long"
        case .unreasonableDistance:
            return "Distance seems unreasonable for a single session"
        }
    }
}

// MARK: - Supporting Types

struct UnsyncedDataBatch {
    let sessions: [RuckingSession]
    let routes: [Route]
    let equipment: [Equipment]
    
    var isEmpty: Bool {
        sessions.isEmpty && routes.isEmpty && equipment.isEmpty
    }
    
    var totalCount: Int {
        sessions.count + routes.count + equipment.count
    }
}
```

---

## CloudKit Integration Architecture

### Sync Strategy and Conflict Resolution

```swift
import CloudKit
import SwiftData
import Foundation

@MainActor
class CloudKitSyncManager: ObservableObject {
    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var syncProgress: Double = 0.0
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: String?
    
    private let dataActor: RuckMapDataActor
    private let container: CKContainer
    private let database: CKDatabase
    private var syncTask: Task<Void, Error>?
    
    // Sync configuration
    private let batchSize = 50
    private let syncInterval: TimeInterval = 300 // 5 minutes
    private var backgroundTimer: Timer?
    
    init(dataActor: RuckMapDataActor, containerIdentifier: String) {
        self.dataActor = dataActor
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.privateCloudDatabase
        
        setupBackgroundSync()
        observeCloudKitNotifications()
    }
    
    // MARK: - Public Sync Interface
    
    func performInitialSync() async {
        await performSync(isInitial: true)
    }
    
    func performIncrementalSync() async {
        await performSync(isInitial: false)
    }
    
    func forceSyncAll() async {
        syncStatus = .syncing
        
        do {
            // Clear sync timestamps to force full sync
            await clearSyncTimestamps()
            await performSync(isInitial: true)
        } catch {
            await handleSyncError(error)
        }
    }
    
    // MARK: - Core Sync Logic
    
    private func performSync(isInitial: Bool) async {
        guard syncStatus != .syncing else { return }
        
        syncTask?.cancel()
        syncTask = Task {
            do {
                syncStatus = .syncing
                syncProgress = 0.0
                syncError = nil
                
                // Step 1: Push local changes to CloudKit
                await updateProgress(0.1, message: "Uploading local changes...")
                try await pushLocalChanges()
                
                // Step 2: Fetch remote changes from CloudKit
                await updateProgress(0.5, message: "Downloading remote changes...")
                try await fetchRemoteChanges(isInitial: isInitial)
                
                // Step 3: Resolve conflicts
                await updateProgress(0.8, message: "Resolving conflicts...")
                try await resolveConflicts()
                
                // Step 4: Update sync status
                await updateProgress(1.0, message: "Sync completed")
                syncStatus = .synced
                lastSyncDate = Date()
                
            } catch is CancellationError {
                syncStatus = .idle
            } catch {
                await handleSyncError(error)
            }
        }
        
        try? await syncTask?.value
    }
    
    // MARK: - Push Local Changes
    
    private func pushLocalChanges() async throws {
        let unsyncedResult = await dataActor.getUnsyncedData()
        
        guard case .success(let batch) = unsyncedResult else {
            throw SyncError.failedToFetchLocalChanges
        }
        
        guard !batch.isEmpty else { return }
        
        // Push sessions
        try await pushSessions(batch.sessions)
        
        // Push routes
        try await pushRoutes(batch.routes)
        
        // Push equipment
        try await pushEquipment(batch.equipment)
    }
    
    private func pushSessions(_ sessions: [RuckingSession]) async throws {
        let sessionBatches = sessions.chunked(into: batchSize)
        
        for (index, batch) in sessionBatches.enumerated() {
            let records = batch.compactMap { createCKRecord(from: $0) }
            
            try await pushRecords(records)
            
            // Update sync status for pushed sessions
            for session in batch {
                await updateSessionSyncStatus(session.id, status: .synced)
            }
            
            let progress = 0.1 + (0.3 * Double(index + 1) / Double(sessionBatches.count))
            await updateProgress(progress, message: "Uploading sessions...")
        }
    }
    
    private func pushRoutes(_ routes: [Route]) async throws {
        let routeBatches = routes.chunked(into: batchSize)
        
        for batch in routeBatches {
            let records = batch.compactMap { createCKRecord(from: $0) }
            try await pushRecords(records)
        }
    }
    
    private func pushEquipment(_ equipment: [Equipment]) async throws {
        let equipmentBatches = equipment.chunked(into: batchSize)
        
        for batch in equipmentBatches {
            let records = batch.compactMap { createCKRecord(from: $0) }
            try await pushRecords(records)
        }
    }
    
    private func pushRecords(_ records: [CKRecord]) async throws {
        let operation = CKModifyRecordsOperation(recordsToSave: records)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    // MARK: - Fetch Remote Changes
    
    private func fetchRemoteChanges(isInitial: Bool) async throws {
        // Fetch sessions
        try await fetchRemoteSessions(isInitial: isInitial)
        
        // Fetch routes
        try await fetchRemoteRoutes(isInitial: isInitial)
        
        // Fetch equipment
        try await fetchRemoteEquipment(isInitial: isInitial)
    }
    
    private func fetchRemoteSessions(isInitial: Bool) async throws {
        let recordType = "RuckingSession"
        let changeToken = isInitial ? nil : getChangeToken(for: recordType)
        
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = batchSize
        
        var fetchedRecords: [CKRecord] = []
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    fetchedRecords.append(record)
                case .failure(let error):
                    print("Failed to fetch record \(recordID): \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
        
        // Process fetched records
        for record in fetchedRecords {
            try await processRemoteSessionRecord(record)
        }
    }
    
    private func fetchRemoteRoutes(isInitial: Bool) async throws {
        // Similar implementation for routes
    }
    
    private func fetchRemoteEquipment(isInitial: Bool) async throws {
        // Similar implementation for equipment
    }
    
    // MARK: - Conflict Resolution
    
    private func resolveConflicts() async throws {
        // Implement conflict resolution strategy
        // For Ruck Map, we'll use "last writer wins" with some exceptions
        
        let conflicts = await identifyConflicts()
        
        for conflict in conflicts {
            try await resolveConflict(conflict)
        }
    }
    
    private func identifyConflicts() async -> [DataConflict] {
        // Compare local and remote timestamps to identify conflicts
        // Return array of conflicts that need resolution
        return []
    }
    
    private func resolveConflict(_ conflict: DataConflict) async throws {
        switch conflict.resolution {
        case .useLocal:
            // Keep local version, push to CloudKit
            break
        case .useRemote:
            // Use remote version, update local
            break
        case .merge:
            // Merge changes where possible
            break
        }
    }
    
    // MARK: - CloudKit Record Conversion
    
    private func createCKRecord(from session: RuckingSession) -> CKRecord? {
        let recordID = CKRecord.ID(recordName: session.id.uuidString)
        let record = CKRecord(recordType: "RuckingSession", recordID: recordID)
        
        record["startDate"] = session.startDate
        record["endDate"] = session.endDate
        record["distance"] = session.distance
        record["duration"] = session.duration
        record["packWeight"] = session.packWeight
        record["calories"] = session.calories
        record["isCompleted"] = session.isCompleted
        record["lastModified"] = session.lastModified
        
        // Add user reference
        if let userId = session.user?.id {
            let userReference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: userId.uuidString),
                action: .none
            )
            record["user"] = userReference
        }
        
        return record
    }
    
    private func createCKRecord(from route: Route) -> CKRecord? {
        let recordID = CKRecord.ID(recordName: route.id.uuidString)
        let record = CKRecord(recordType: "Route", recordID: recordID)
        
        record["name"] = route.name
        record["description"] = route.description
        record["distance"] = route.distance
        record["elevationGain"] = route.elevationGain
        record["difficulty"] = route.difficulty.rawValue
        record["isPublic"] = route.isPublic
        record["startLatitude"] = route.startLatitude
        record["startLongitude"] = route.startLongitude
        record["lastModified"] = route.lastModified
        
        return record
    }
    
    private func createCKRecord(from equipment: Equipment) -> CKRecord? {
        let recordID = CKRecord.ID(recordName: equipment.id.uuidString)
        let record = CKRecord(recordType: "Equipment", recordID: recordID)
        
        record["name"] = equipment.name
        record["brand"] = equipment.brand
        record["equipmentType"] = equipment.equipmentType.rawValue
        record["weight"] = equipment.weight
        record["totalDistance"] = equipment.totalDistance
        record["totalSessions"] = equipment.totalSessions
        record["isActive"] = equipment.isActive
        
        return record
    }
    
    // MARK: - Helper Methods
    
    private func updateProgress(_ progress: Double, message: String) async {
        await MainActor.run {
            self.syncProgress = progress
            // Could also update a status message if needed
        }
    }
    
    private func handleSyncError(_ error: Error) async {
        await MainActor.run {
            self.syncStatus = .failed
            self.syncError = error.localizedDescription
        }
    }
    
    private func updateSessionSyncStatus(_ sessionId: UUID, status: SyncStatus) async {
        // Update the session's sync status in the database
    }
    
    private func setupBackgroundSync() {
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { _ in
            Task {
                await self.performIncrementalSync()
            }
        }
    }
    
    private func observeCloudKitNotifications() {
        // Set up CloudKit subscription for remote change notifications
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await self.handleAccountChange()
            }
        }
    }
    
    private func handleAccountChange() async {
        // Handle CloudKit account changes
        syncStatus = .accountChanged
    }
    
    private func getChangeToken(for recordType: String) -> CKServerChangeToken? {
        // Retrieve stored change token for incremental sync
        return nil
    }
    
    private func clearSyncTimestamps() async {
        // Clear all sync timestamps to force full sync
    }
    
    private func processRemoteSessionRecord(_ record: CKRecord) async throws {
        // Convert CKRecord back to SwiftData model and handle conflicts
    }
}

// MARK: - Supporting Types

enum SyncStatus {
    case idle, syncing, synced, failed, accountChanged
}

enum SyncError: LocalizedError {
    case failedToFetchLocalChanges
    case networkUnavailable
    case accountNotAuthenticated
    case quotaExceeded
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .failedToFetchLocalChanges:
            return "Failed to fetch local changes"
        case .networkUnavailable:
            return "Network unavailable"
        case .accountNotAuthenticated:
            return "CloudKit account not authenticated"
        case .quotaExceeded:
            return "CloudKit storage quota exceeded"
        case .unknownError(let error):
            return "Unknown sync error: \(error.localizedDescription)"
        }
    }
}

struct DataConflict {
    let localRecord: Any
    let remoteRecord: CKRecord
    let resolution: ConflictResolution
}

enum ConflictResolution {
    case useLocal, useRemote, merge
}

// Array extension for chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

---

## Schema Migration Strategy

### Version Management and Migration Paths

```swift
import SwiftData
import Foundation

// MARK: - Schema Versions

enum SchemaVersion: Int, CaseIterable {
    case v1 = 1
    case v2 = 2
    case v3 = 3
    case v4 = 4
    
    static var current: SchemaVersion {
        return allCases.last!
    }
    
    var name: String {
        return "v\(rawValue)"
    }
}

// MARK: - Schema Version Definitions

struct SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        UserV1.self,
        RuckingSessionV1.self,
        RouteV1.self
    ]
}

struct SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [
        UserV2.self,
        RuckingSessionV2.self,
        RouteV2.self,
        EquipmentV2.self  // New model added
    ]
}

struct SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] = [
        UserV3.self,
        RuckingSessionV3.self,
        RouteV3.self,
        EquipmentV3.self,
        LocationPointV3.self  // New model added
    ]
}

struct SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] = [
        User.self,       // Current models
        RuckingSession.self,
        Route.self,
        Equipment.self,
        LocationPoint.self,
        ActivityMetric.self,  // New model added
        RouteReview.self      // New model added
    ]
}

// MARK: - Model Evolution

// V1 Models (Initial Release)
@Model
final class UserV1 {
    var id: UUID
    var email: String
    var displayName: String
    var createdAt: Date
    
    init(email: String, displayName: String) {
        self.id = UUID()
        self.email = email
        self.displayName = displayName
        self.createdAt = Date()
    }
}

@Model
final class RuckingSessionV1 {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var distance: Double
    var packWeight: Double
    var isCompleted: Bool
    
    @Relationship(deleteRule: .nullify)
    var user: UserV1?
    
    init(startDate: Date, packWeight: Double) {
        self.id = UUID()
        self.startDate = startDate
        self.packWeight = packWeight
        self.distance = 0.0
        self.isCompleted = false
    }
}

@Model
final class RouteV1 {
    var id: UUID
    var name: String
    var distance: Double
    var createdAt: Date
    
    init(name: String, distance: Double) {
        self.id = UUID()
        self.name = name
        self.distance = distance
        self.createdAt = Date()
    }
}

// V2 Models (Added Equipment and User Personas)
@Model
final class UserV2 {
    var id: UUID
    var email: String
    var displayName: String
    var createdAt: Date
    var persona: String  // Added persona as String
    
    @Relationship(deleteRule: .cascade)
    var equipment: [EquipmentV2] = []  // Added relationship
    
    init(email: String, displayName: String, persona: String = "general") {
        self.id = UUID()
        self.email = email
        self.displayName = displayName
        self.createdAt = Date()
        self.persona = persona
    }
}

@Model
final class EquipmentV2 {
    var id: UUID
    var name: String
    var equipmentType: String
    var weight: Double
    var createdAt: Date
    
    @Relationship(deleteRule: .nullify)
    var owner: UserV2?
    
    init(name: String, type: String, weight: Double) {
        self.id = UUID()
        self.name = name
        self.equipmentType = type
        self.weight = weight
        self.createdAt = Date()
    }
}

// MARK: - Migration Plan

struct MigrationPlan {
    static let migrations: [SchemaMigration] = [
        SchemaMigration(
            from: SchemaV1.self,
            to: SchemaV2.self,
            transformation: migrateV1ToV2
        ),
        SchemaMigration(
            from: SchemaV2.self,
            to: SchemaV3.self,
            transformation: migrateV2ToV3
        ),
        SchemaMigration(
            from: SchemaV3.self,
            to: SchemaV4.self,
            transformation: migrateV3ToV4
        )
    ]
    
    // V1 to V2 Migration
    static let migrateV1ToV2 = SchemaMigrationTransformation { context in
        // Add default persona to existing users
        let users = try context.fetch(FetchDescriptor<UserV1>())
        for user in users {
            // Migration will automatically handle the new properties
            // with default values defined in the model
        }
        
        // No equipment to migrate in V1
        print("Migrated \(users.count) users from V1 to V2")
    }
    
    // V2 to V3 Migration
    static let migrateV2ToV3 = SchemaMigrationTransformation { context in
        // Add location tracking capabilities
        let sessions = try context.fetch(FetchDescriptor<RuckingSessionV2>())
        for session in sessions {
            // No location points to migrate from V2
            // New sessions will start collecting location data
        }
        
        print("Migrated \(sessions.count) sessions from V2 to V3")
    }
    
    // V3 to V4 Migration
    static let migrateV3ToV4 = SchemaMigrationTransformation { context in
        // Add metrics and reviews
        let routes = try context.fetch(FetchDescriptor<RouteV3>())
        for route in routes {
            // Initialize empty reviews array
            // Existing routes will have no reviews initially
        }
        
        let sessions = try context.fetch(FetchDescriptor<RuckingSessionV3>())
        for session in sessions {
            // Initialize empty metrics array
            // Historical sessions will have basic metrics only
        }
        
        print("Migrated \(routes.count) routes and \(sessions.count) sessions from V3 to V4")
    }
}

// MARK: - Migration Execution

@MainActor
class MigrationManager: ObservableObject {
    @Published var migrationProgress: Double = 0.0
    @Published var migrationStatus: MigrationStatus = .idle
    @Published var migrationError: String?
    
    private let targetSchema = SchemaV4.self
    
    func checkMigrationNeeded() -> Bool {
        // Check if migration is needed by comparing current schema version
        // with the target schema version
        return getCurrentSchemaVersion() < SchemaVersion.current
    }
    
    func performMigration(from sourceContainer: ModelContainer) async throws -> ModelContainer {
        migrationStatus = .migrating
        migrationProgress = 0.0
        
        do {
            let migrationSteps = determineMigrationSteps()
            let totalSteps = migrationSteps.count
            
            var currentContainer = sourceContainer
            
            for (index, step) in migrationSteps.enumerated() {
                migrationProgress = Double(index) / Double(totalSteps)
                
                currentContainer = try await executeMigrationStep(step, container: currentContainer)
                
                // Validate migration step
                try await validateMigrationStep(step, container: currentContainer)
            }
            
            migrationProgress = 1.0
            migrationStatus = .completed
            
            return currentContainer
            
        } catch {
            migrationStatus = .failed
            migrationError = error.localizedDescription
            throw error
        }
    }
    
    private func getCurrentSchemaVersion() -> SchemaVersion {
        // Determine current schema version from existing data
        // This would typically check the database schema or a version marker
        return .v1 // Placeholder
    }
    
    private func determineMigrationSteps() -> [MigrationStep] {
        let currentVersion = getCurrentSchemaVersion()
        let targetVersion = SchemaVersion.current
        
        var steps: [MigrationStep] = []
        
        for version in SchemaVersion.allCases {
            if version.rawValue > currentVersion.rawValue && version.rawValue <= targetVersion.rawValue {
                steps.append(MigrationStep(toVersion: version))
            }
        }
        
        return steps
    }
    
    private func executeMigrationStep(_ step: MigrationStep, container: ModelContainer) async throws -> ModelContainer {
        // Execute the migration step
        // This would use SwiftData's migration APIs
        
        print("Executing migration step to \(step.toVersion.name)")
        
        // Simulate migration work
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        return container
    }
    
    private func validateMigrationStep(_ step: MigrationStep, container: ModelContainer) async throws {
        // Validate that the migration step completed successfully
        print("Validating migration step to \(step.toVersion.name)")
        
        // Perform validation checks
        let context = ModelContext(container)
        
        switch step.toVersion {
        case .v2:
            // Validate that all users have persona field
            let users = try context.fetch(FetchDescriptor<UserV2>())
            for user in users {
                guard !user.persona.isEmpty else {
                    throw MigrationError.validationFailed("User missing persona")
                }
            }
            
        case .v3:
            // Validate location point structure
            break
            
        case .v4:
            // Validate metrics and reviews structure
            break
            
        default:
            break
        }
    }
}

// MARK: - Supporting Types

struct SchemaMigration {
    let fromVersion: any VersionedSchema.Type
    let toVersion: any VersionedSchema.Type
    let transformation: SchemaMigrationTransformation
}

struct SchemaMigrationTransformation {
    let transform: (ModelContext) throws -> Void
    
    init(transform: @escaping (ModelContext) throws -> Void) {
        self.transform = transform
    }
}

struct MigrationStep {
    let toVersion: SchemaVersion
}

enum MigrationStatus {
    case idle, migrating, completed, failed
}

enum MigrationError: LocalizedError {
    case validationFailed(String)
    case incompatibleVersion
    case dataCorruption
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "Migration validation failed: \(message)"
        case .incompatibleVersion:
            return "Incompatible schema version"
        case .dataCorruption:
            return "Data corruption detected during migration"
        }
    }
}

// MARK: - Container Factory

struct ModelContainerFactory {
    static func createContainer() throws -> ModelContainer {
        let schema = Schema([
            User.self,
            RuckingSession.self,
            Route.self,
            Equipment.self,
            LocationPoint.self,
            ActivityMetric.self,
            RouteReview.self,
            Waypoint.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isAutosaveEnabled: true,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    static func createCloudKitContainer() throws -> ModelContainer {
        let schema = Schema([
            User.self,
            RuckingSession.self,
            Route.self,
            Equipment.self,
            LocationPoint.self,
            ActivityMetric.self,
            RouteReview.self,
            Waypoint.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isAutosaveEnabled: true,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .private("iCloud.com.yourteam.ruckmap")
        )
        
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    static func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            User.self,
            RuckingSession.self,
            Route.self,
            Equipment.self,
            LocationPoint.self,
            ActivityMetric.self,
            RouteReview.self,
            Waypoint.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isAutosaveEnabled: false,
            isStoredInMemoryOnly: true
        )
        
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
```

---

## Testing Architecture

### Unit Testing Strategy for SwiftData Models

```swift
import Testing
import SwiftData
import Foundation

// MARK: - Test Infrastructure

@MainActor
class SwiftDataTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var dataActor: RuckMapDataActor!
    
    init() async throws {
        container = try ModelContainerFactory.createTestContainer()
        context = container.mainContext
        dataActor = RuckMapDataActor(modelContainer: container)
    }
    
    deinit {
        container = nil
        context = nil
        dataActor = nil
    }
    
    func tearDown() throws {
        // Clear all data between tests
        try context.delete(model: User.self)
        try context.delete(model: RuckingSession.self)
        try context.delete(model: Route.self)
        try context.delete(model: Equipment.self)
        try context.save()
    }
}

// MARK: - User Domain Tests

@MainActor
struct UserDomainTests {
    
    @Test func testUserCreationWithPersona() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let email = "test@example.com"
        let displayName = "Test User"
        let persona = UserPersona.militaryVeteran
        
        // When
        let result = await testCase.dataActor.createUser(
            email: email,
            displayName: displayName,
            persona: persona
        )
        
        // Then
        guard case .success(let user) = result else {
            Issue.record("Failed to create user")
            return
        }
        
        #expect(user.email == email)
        #expect(user.displayName == displayName)
        #expect(user.persona == persona)
        #expect(user.isActive == true)
        #expect(user.preferences.unitSystem == .imperial) // Military veteran default
        #expect(user.preferences.displaySettings.showMilitaryTime == true)
    }
    
    @Test func testDuplicateEmailPrevention() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let email = "duplicate@example.com"
        
        // When - Create first user
        let firstResult = await testCase.dataActor.createUser(
            email: email,
            displayName: "First User",
            persona: .general
        )
        
        // When - Attempt to create duplicate
        let secondResult = await testCase.dataActor.createUser(
            email: email,
            displayName: "Second User",
            persona: .fitnessEnthusiast
        )
        
        // Then
        #expect(case .success = firstResult)
        #expect(case .failure(.duplicateEmail) = secondResult)
    }
    
    @Test func testPersonaTransitionRules() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let user = User(email: "test@example.com", displayName: "Test", persona: .general)
        testCase.context.insert(user)
        try testCase.context.save()
        
        // When - Valid transition (general to specific)
        let validTransition = try user.updatePersona(.militaryVeteran)
        
        // Then
        #expect(user.persona == .militaryVeteran)
        #expect(user.preferences.displaySettings.showMilitaryTime == true)
        
        // When - Invalid transition (specific to general)
        #expect(throws: UserError.invalidPersonaTransition) {
            try user.updatePersona(.general)
        }
    }
    
    @Test func testUserExperienceLevelCalculation() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let user = User(email: "experienced@example.com", displayName: "Experienced", persona: .militaryVeteran)
        testCase.context.insert(user)
        
        // Add multiple sessions to reach advanced level
        for i in 0..<25 {
            let session = RuckingSession(startDate: Date().addingTimeInterval(-Double(i) * 86400), packWeight: 35.0, user: user)
            session.distance = 5.0
            session.isCompleted = true
            testCase.context.insert(session)
        }
        
        try testCase.context.save()
        
        // When
        let experienceLevel = user.experienceLevel
        
        // Then
        #expect(experienceLevel == .advanced)
        #expect(user.totalRuckingDistance == 125.0) // 25 sessions × 5 miles
    }
    
    @Test func testHealthProfileBMICalculation() async throws {
        // Given
        var healthProfile = HealthProfile()
        healthProfile.weight = 180.0 // pounds
        healthProfile.height = 70.0 // inches
        
        // When
        let bmi = healthProfile.bmi
        
        // Then
        #expect(bmi != nil)
        #expect(abs(bmi! - 25.8) < 0.1) // BMI should be approximately 25.8
    }
    
    @Test func testRecommendedPackWeightCalculation() async throws {
        // Given
        var healthProfile = HealthProfile()
        healthProfile.weight = 200.0
        healthProfile.fitnessLevel = .moderate
        
        // When
        let recommendedWeight = healthProfile.recommendedMaxPackWeight
        
        // Then
        #expect(recommendedWeight == 30.0) // 15% of 200 lbs for moderate fitness
    }
}

// MARK: - Rucking Session Domain Tests

@MainActor
struct RuckingSessionDomainTests {
    
    @Test func testSessionCreationAndCompletion() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let user = User(email: "rucker@example.com", displayName: "Rucker", persona: .militaryVeteran)
        user.healthProfile.weight = 180.0
        testCase.context.insert(user)
        try testCase.context.save()
        
        // When - Start session
        let startResult = await testCase.dataActor.startRuckingSession(
            userId: user.id,
            packWeight: 35.0
        )
        
        guard case .success(let session) = startResult else {
            Issue.record("Failed to start session")
            return
        }
        
        // When - Complete session
        let endDate = Date().addingTimeInterval(3600) // 1 hour later
        let completionResult = await testCase.dataActor.completeRuckingSession(
            sessionId: session.id,
            endDate: endDate,
            finalDistance: 4.0,
            locationPoints: []
        )
        
        // Then
        guard case .success(let completedSession) = completionResult else {
            Issue.record("Failed to complete session")
            return
        }
        
        #expect(completedSession.isCompleted == true)
        #expect(completedSession.distance == 4.0)
        #expect(completedSession.duration == 3600)
        #expect(completedSession.calories > 0) // Should have calculated calories
        #expect(completedSession.ruckWork == 140.0) // 35 lbs × 4 miles
    }
    
    @Test func testRuckWorkAndPowerCalculations() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let user = User(email: "test@example.com", displayName: "Test", persona: .general)
        let session = RuckingSession(startDate: Date(), packWeight: 40.0, user: user)
        session.distance = 5.0
        session.duration = 3600 // 1 hour
        session.isCompleted = true
        
        testCase.context.insert(user)
        testCase.context.insert(session)
        try testCase.context.save()
        
        // When & Then
        #expect(session.ruckWork == 200.0) // 40 lbs × 5 miles
        #expect(session.ruckPower == 200.0) // 200 ruck-work / 1 hour
        #expect(session.averagePace == 12.0) // 60 minutes / 5 miles
    }
    
    @Test func testSessionValidationRules() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let user = User(email: "test@example.com", displayName: "Test", persona: .general)
        let session = RuckingSession(startDate: Date(), packWeight: 30.0, user: user)
        
        testCase.context.insert(user)
        testCase.context.insert(session)
        
        // When & Then - Test session too short
        let endDateTooSoon = Date().addingTimeInterval(30) // 30 seconds
        #expect(throws: SessionError.sessionTooShort) {
            try session.completeSession(endDate: endDateTooSoon, finalDistance: 1.0)
        }
        
        // When & Then - Test unreasonable distance
        let validEndDate = Date().addingTimeInterval(3600)
        #expect(throws: SessionError.unreasonableDistance) {
            try session.completeSession(endDate: validEndDate, finalDistance: 100.0)
        }
        
        // When & Then - Test invalid end date
        let pastEndDate = Date().addingTimeInterval(-3600)
        #expect(throws: SessionError.invalidEndDate) {
            try session.completeSession(endDate: pastEndDate, finalDistance: 5.0)
        }
    }
    
    @Test func testIntensityScoreCalculation() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let user = User(email: "test@example.com", displayName: "Test", persona: .general)
        let session = RuckingSession(startDate: Date(), packWeight: 50.0, user: user)
        session.distance = 6.0
        session.duration = 3600
        session.elevationGain = 500.0
        session.averagePace = 10.0 // minutes per mile
        session.isCompleted = true
        
        testCase.context.insert(user)
        testCase.context.insert(session)
        try testCase.context.save()
        
        // When
        let intensityScore = session.intensityScore
        
        // Then
        #expect(intensityScore > 0)
        // Intensity should account for weight, distance, elevation, and pace
        let expectedBase = (50.0 * 6.0) / 100.0 // Base from ruck work
        let expectedElevation = (500.0 / 100.0) * 1.2 // Elevation factor
        let expectedPace = 15.0 / 10.0 // Pace factor
        let expected = (expectedBase + expectedElevation) * expectedPace
        
        #expect(abs(intensityScore - expected) < 0.1)
    }
    
    @Test func testActiveSessionPrevention() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let user = User(email: "test@example.com", displayName: "Test", persona: .general)
        testCase.context.insert(user)
        try testCase.context.save()
        
        // When - Start first session
        let firstResult = await testCase.dataActor.startRuckingSession(
            userId: user.id,
            packWeight: 30.0
        )
        
        // When - Try to start second session
        let secondResult = await testCase.dataActor.startRuckingSession(
            userId: user.id,
            packWeight: 35.0
        )
        
        // Then
        #expect(case .success = firstResult)
        #expect(case .failure(.activeSessionExists) = secondResult)
    }
}

// MARK: - Route Domain Tests

@MainActor
struct RouteDomainTests {
    
    @Test func testRouteCreationAndDifficultyCalculation() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let user = User(email: "creator@example.com", displayName: "Creator", persona: .outdoorAdventurer)
        testCase.context.insert(user)
        try testCase.context.save()
        
        // When
        let result = await testCase.dataActor.createRoute(
            name: "Mountain Challenge",
            distance: 8.0,
            startLat: 40.7128,
            startLon: -74.0060,
            creatorId: user.id
        )
        
        guard case .success(let route) = result else {
            Issue.record("Failed to create route")
            return
        }
        
        // Given - Update route with elevation data
        route.elevationGain = 2000.0
        route.terrain = .mountain
        route.updateDifficulty()
        
        // Then
        #expect(route.name == "Mountain Challenge")
        #expect(route.distance == 8.0)
        #expect(route.difficulty == .hard) // Should be calculated based on distance and elevation
        #expect(route.creator?.id == user.id)
    }
    
    @Test func testWaypointManagement() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let user = User(email: "test@example.com", displayName: "Test", persona: .general)
        let route = Route(name: "Test Route", distance: 5.0, startLat: 40.0, startLon: -74.0, creator: user)
        
        testCase.context.insert(user)
        testCase.context.insert(route)
        try testCase.context.save()
        
        // When
        route.addWaypoint(name: "Checkpoint 1", latitude: 40.1, longitude: -74.1, type: .checkpoint)
        route.addWaypoint(name: "Water Stop", latitude: 40.2, longitude: -74.2, type: .waterStop)
        route.addWaypoint(name: "Finish", latitude: 40.3, longitude: -74.3, type: .finish)
        
        try testCase.context.save()
        
        // Then
        #expect(route.waypoints.count == 3)
        #expect(route.waypoints[0].name == "Checkpoint 1")
        #expect(route.waypoints[0].order == 0)
        #expect(route.waypoints[1].waypointType == .waterStop)
        #expect(route.waypoints[2].waypointType == .finish)
    }
    
    @Test func testRoutePopularityCalculation() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let creator = User(email: "creator@example.com", displayName: "Creator", persona: .general)
        let route = Route(name: "Popular Route", distance: 5.0, startLat: 40.0, startLon: -74.0, creator: creator)
        route.isPublic = true
        
        testCase.context.insert(creator)
        testCase.context.insert(route)
        
        // Add multiple sessions to make it popular
        for i in 0..<60 {
            let user = User(email: "user\(i)@example.com", displayName: "User \(i)", persona: .general)
            let session = RuckingSession(startDate: Date(), packWeight: 30.0, user: user)
            session.route = route
            session.isCompleted = true
            
            testCase.context.insert(user)
            testCase.context.insert(session)
        }
        
        // Add high-rated reviews
        for i in 0..<20 {
            let reviewer = User(email: "reviewer\(i)@example.com", displayName: "Reviewer \(i)", persona: .general)
            let review = RouteReview(rating: 4.5, reviewer: reviewer)
            review.route = route
            
            testCase.context.insert(reviewer)
            testCase.context.insert(review)
        }
        
        try testCase.context.save()
        
        // When & Then
        #expect(route.totalCompletions == 60)
        #expect(route.averageRating == 4.5)
        #expect(route.isPopular == true) // >= 50 completions and >= 4.0 rating
    }
    
    @Test func testRouteEditPermissions() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let creator = User(email: "creator@example.com", displayName: "Creator", persona: .general)
        let otherUser = User(email: "other@example.com", displayName: "Other", persona: .general)
        let adminUser = User(email: "admin@example.com", displayName: "Admin", persona: .general)
        adminUser.isAdmin = true
        
        let route = Route(name: "Test Route", distance: 5.0, startLat: 40.0, startLon: -74.0, creator: creator)
        
        testCase.context.insert(creator)
        testCase.context.insert(otherUser)
        testCase.context.insert(adminUser)
        testCase.context.insert(route)
        try testCase.context.save()
        
        // When & Then
        #expect(route.canBeEditedBy(creator) == true) // Creator can edit
        #expect(route.canBeEditedBy(otherUser) == false) // Other users cannot edit
        #expect(route.canBeEditedBy(adminUser) == true) // Admin can edit
    }
}

// MARK: - Equipment Domain Tests

@MainActor
struct EquipmentDomainTests {
    
    @Test func testEquipmentUsageTracking() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let user = User(email: "gear@example.com", displayName: "Gear User", persona: .militaryVeteran)
        let equipment = Equipment(name: "GORUCK GR1", type: .backpack, weight: 3.0, owner: user)
        equipment.replacementRecommendedAt = 1000.0 // 1000 miles
        
        testCase.context.insert(user)
        testCase.context.insert(equipment)
        try testCase.context.save()
        
        // When
        equipment.recordUsage(distance: 50.0, duration: 3600)
        equipment.recordUsage(distance: 75.0, duration: 4500)
        equipment.recordUsage(distance: 100.0, duration: 6000)
        
        try testCase.context.save()
        
        // Then
        #expect(equipment.totalDistance == 225.0)
        #expect(equipment.totalSessions == 3)
        #expect(equipment.totalHours == 14100) // 3600 + 4500 + 6000
        #expect(equipment.averageDistancePerSession == 75.0)
        #expect(equipment.needsReplacement == false) // Still under 1000 miles
        
        // Test remaining life calculation
        let remainingLife = equipment.estimateRemainingLife()
        #expect(remainingLife != nil)
        #expect(remainingLife! > 0.7) // Should have > 70% life remaining
    }
    
    @Test func testEquipmentReplacementRecommendation() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let user = User(email: "runner@example.com", displayName: "Runner", persona: .fitnessEnthusiast)
        let boots = Equipment(name: "Trail Runners", type: .boots, weight: 1.5, owner: user)
        boots.replacementRecommendedAt = 500.0 // 500 miles for boots
        
        testCase.context.insert(user)
        testCase.context.insert(boots)
        
        // When - Exceed replacement threshold
        boots.recordUsage(distance: 600.0, duration: 36000) // 600 miles
        
        try testCase.context.save()
        
        // Then
        #expect(boots.needsReplacement == true)
        #expect(boots.estimateRemainingLife() == 0.0) // No life remaining
    }
    
    @Test func testCostPerMileCalculation() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given
        let user = User(email: "buyer@example.com", displayName: "Buyer", persona: .general)
        let equipment = Equipment(name: "Expensive Pack", type: .backpack, weight: 4.0, owner: user)
        equipment.purchasePrice = 300.0
        
        testCase.context.insert(user)
        testCase.context.insert(equipment)
        
        // When
        equipment.recordUsage(distance: 100.0, duration: 6000)
        equipment.recordUsage(distance: 100.0, duration: 6000)
        
        try testCase.context.save()
        
        // Then
        let costPerMile = equipment.costPerMile
        #expect(costPerMile != nil)
        #expect(costPerMile! == 1.5) // $300 / 200 miles = $1.50 per mile
    }
}

// MARK: - Integration Tests

@MainActor
struct IntegrationTests {
    
    @Test func testCompleteRuckingWorkflow() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given - Create user with equipment
        let user = User(email: "integration@example.com", displayName: "Integration Test", persona: .militaryVeteran)
        user.healthProfile.weight = 180.0
        
        let backpack = Equipment(name: "Test Pack", type: .backpack, weight: 3.0, owner: user)
        let boots = Equipment(name: "Test Boots", type: .boots, weight: 2.0, owner: user)
        
        testCase.context.insert(user)
        testCase.context.insert(backpack)
        testCase.context.insert(boots)
        try testCase.context.save()
        
        // When - Create and complete a session
        let startResult = await testCase.dataActor.startRuckingSession(
            userId: user.id,
            packWeight: 35.0
        )
        
        guard case .success(let session) = startResult else {
            Issue.record("Failed to start session")
            return
        }
        
        // Associate equipment with session
        session.equipment = [backpack, boots]
        
        // Complete the session
        let endDate = Date().addingTimeInterval(3600)
        let completionResult = await testCase.dataActor.completeRuckingSession(
            sessionId: session.id,
            endDate: endDate,
            finalDistance: 5.0,
            locationPoints: []
        )
        
        guard case .success(let completedSession) = completionResult else {
            Issue.record("Failed to complete session")
            return
        }
        
        // Then - Verify all data relationships
        #expect(completedSession.isCompleted == true)
        #expect(completedSession.user?.id == user.id)
        #expect(completedSession.equipment.count == 2)
        #expect(user.sessions.contains(completedSession))
        #expect(user.totalRuckingDistance == 5.0)
        #expect(user.experienceLevel == .beginner) // First session
        
        // Verify equipment usage was not tracked (would need separate call)
        #expect(backpack.totalDistance == 0.0) // Equipment usage tracking is separate
    }
    
    @Test func testQueryPerformanceWithLargeDataSet() async throws {
        let testCase = try await SwiftDataTestCase()
        defer { try? testCase.tearDown() }
        
        // Given - Create large dataset
        let user = User(email: "performance@example.com", displayName: "Performance Test", persona: .general)
        testCase.context.insert(user)
        
        let startTime = Date()
        
        // Create 1000 sessions
        for i in 0..<1000 {
            let session = RuckingSession(
                startDate: Date().addingTimeInterval(-Double(i) * 86400),
                packWeight: Double.random(in: 20...50),
                user: user
            )
            session.distance = Double.random(in: 1...10)
            session.isCompleted = true
            testCase.context.insert(session)
        }
        
        try testCase.context.save()
        let insertTime = Date().timeIntervalSince(startTime)
        
        // When - Query recent sessions
        let queryStart = Date()
        let descriptor = RuckingSession.recentSessions
        let recentSessions = try testCase.context.fetch(descriptor)
        let queryTime = Date().timeIntervalSince(queryStart)
        
        // Then
        #expect(recentSessions.count == 20) // Limited to 20 by fetch descriptor
        #expect(queryTime < 0.1) // Query should be fast (< 100ms)
        #expect(insertTime < 5.0) // Inserts should be reasonable (< 5s for 1000 records)
        
        print("Insert time: \(insertTime)s, Query time: \(queryTime)s")
    }
}

// MARK: - Test Utilities

extension User {
    var isAdmin: Bool {
        get { false } // Simplified for testing
        set { } // Would set admin flag in real implementation
    }
}

extension ModelContext {
    func delete<T: PersistentModel>(model: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let instances = try fetch(descriptor)
        for instance in instances {
            delete(instance)
        }
    }
}
```

---

## Performance Optimization

### Query Optimization and Data Loading Strategies

```swift
import SwiftData
import Foundation

// MARK: - Query Optimization Patterns

struct OptimizedQueries {
    
    // MARK: - Paginated Queries
    
    static func paginatedSessions(for userId: UUID, page: Int, pageSize: Int = 20) -> FetchDescriptor<RuckingSession> {
        let offset = page * pageSize
        
        let descriptor = FetchDescriptor<RuckingSession>(
            predicate: #Predicate { session in
                session.user?.id == userId && session.isCompleted
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = offset
        
        return descriptor
    }
    
    // MARK: - Efficient Relationship Loading
    
    static func sessionsWithMinimalData(for userId: UUID) -> FetchDescriptor<RuckingSession> {
        let descriptor = FetchDescriptor<RuckingSession>(
            predicate: #Predicate { session in
                session.user?.id == userId && session.isCompleted
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        
        // Only load essential properties for list views
        descriptor.propertiesToFetch = [
            \RuckingSession.id,
            \RuckingSession.startDate,
            \RuckingSession.distance,
            \RuckingSession.duration,
            \RuckingSession.packWeight,
            \RuckingSession.calories
        ]
        
        return descriptor
    }
    
    // MARK: - Aggregation Queries
    
    static func userStatistics(for userId: UUID) -> FetchDescriptor<RuckingSession> {
        FetchDescriptor<RuckingSession>(
            predicate: #Predicate { session in
                session.user?.id == userId && session.isCompleted
            }
        )
    }
    
    // MARK: - Geospatial Queries (Simplified)
    
    static func routesNearLocation(latitude: Double, longitude: Double, radiusInMiles: Double) -> FetchDescriptor<Route> {
        // Note: This is a simplified version. In production, you'd use proper spatial indexing
        let latRange = radiusInMiles / 69.0 // Approximate miles per degree latitude
        let lonRange = radiusInMiles / (69.0 * cos(latitude * .pi / 180))
        
        return FetchDescriptor<Route>(
            predicate: #Predicate { route in
                route.isPublic &&
                route.startLatitude >= latitude - latRange &&
                route.startLatitude <= latitude + latRange &&
                route.startLongitude >= longitude - lonRange &&
                route.startLongitude <= longitude + lonRange
            },
            sortBy: [SortDescriptor(\.name)]
        )
    }
    
    // MARK: - Time-based Queries
    
    static func sessionsInDateRange(for userId: UUID, from startDate: Date, to endDate: Date) -> FetchDescriptor<RuckingSession> {
        FetchDescriptor<RuckingSession>(
            predicate: #Predicate { session in
                session.user?.id == userId &&
                session.isCompleted &&
                session.startDate >= startDate &&
                session.startDate <= endDate
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
    }
    
    // MARK: - Search Queries
    
    static func searchRoutes(query: String) -> FetchDescriptor<Route> {
        FetchDescriptor<Route>(
            predicate: #Predicate { route in
                route.isPublic && (
                    route.name.localizedStandardContains(query) ||
                    route.description?.localizedStandardContains(query) == true ||
                    route.tags.contains { $0.localizedStandardContains(query) }
                )
            },
            sortBy: [
                SortDescriptor(\.name.count), // Shorter names first (more relevant)
                SortDescriptor(\.averageRating, order: .reverse)
            ]
        )
    }
    
    // MARK: - Filtered Equipment Queries
    
    static func activeEquipment(for userId: UUID, type: EquipmentType? = nil) -> FetchDescriptor<Equipment> {
        if let type = type {
            return FetchDescriptor<Equipment>(
                predicate: #Predicate { equipment in
                    equipment.owner?.id == userId &&
                    equipment.isActive &&
                    equipment.equipmentType == type
                },
                sortBy: [SortDescriptor(\.lastUsed, order: .reverse)]
            )
        } else {
            return FetchDescriptor<Equipment>(
                predicate: #Predicate { equipment in
                    equipment.owner?.id == userId && equipment.isActive
                },
                sortBy: [SortDescriptor(\.lastUsed, order: .reverse)]
            )
        }
    }
}

// MARK: - Caching Layer

@MainActor
class DataCacheManager: ObservableObject {
    private var sessionCache: [UUID: [RuckingSession]] = [:]
    private var routeCache: [String: [Route]] = [:]
    private var userStatsCache: [UUID: UserStatistics] = [:]
    
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    private var cacheTimestamps: [String: Date] = [:]
    
    // MARK: - Session Caching
    
    func getCachedSessions(for userId: UUID) -> [RuckingSession]? {
        let cacheKey = "sessions_\(userId.uuidString)"
        
        if let timestamp = cacheTimestamps[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheTimeout,
           let sessions = sessionCache[userId] {
            return sessions
        }
        
        return nil
    }
    
    func cacheSessions(_ sessions: [RuckingSession], for userId: UUID) {
        let cacheKey = "sessions_\(userId.uuidString)"
        sessionCache[userId] = sessions
        cacheTimestamps[cacheKey] = Date()
    }
    
    func invalidateSessionCache(for userId: UUID) {
        let cacheKey = "sessions_\(userId.uuidString)"
        sessionCache.removeValue(forKey: userId)
        cacheTimestamps.removeValue(forKey: cacheKey)
    }
    
    // MARK: - Route Caching
    
    func getCachedRoutes(for query: String) -> [Route]? {
        let cacheKey = "routes_\(query)"
        
        if let timestamp = cacheTimestamps[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheTimeout,
           let routes = routeCache[query] {
            return routes
        }
        
        return nil
    }
    
    func cacheRoutes(_ routes: [Route], for query: String) {
        let cacheKey = "routes_\(query)"
        routeCache[query] = routes
        cacheTimestamps[cacheKey] = Date()
    }
    
    // MARK: - Statistics Caching
    
    func getCachedStatistics(for userId: UUID) -> UserStatistics? {
        let cacheKey = "stats_\(userId.uuidString)"
        
        if let timestamp = cacheTimestamps[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheTimeout,
           let stats = userStatsCache[userId] {
            return stats
        }
        
        return nil
    }
    
    func cacheStatistics(_ stats: UserStatistics, for userId: UUID) {
        let cacheKey = "stats_\(userId.uuidString)"
        userStatsCache[userId] = stats
        cacheTimestamps[cacheKey] = Date()
    }
    
    // MARK: - Cache Management
    
    func clearExpiredCache() {
        let now = Date()
        let expiredKeys = cacheTimestamps.compactMap { key, timestamp in
            now.timeIntervalSince(timestamp) > cacheTimeout ? key : nil
        }
        
        for key in expiredKeys {
            cacheTimestamps.removeValue(forKey: key)
            
            if key.hasPrefix("sessions_") {
                let userIdString = String(key.dropFirst("sessions_".count))
                if let userId = UUID(uuidString: userIdString) {
                    sessionCache.removeValue(forKey: userId)
                }
            } else if key.hasPrefix("routes_") {
                let query = String(key.dropFirst("routes_".count))
                routeCache.removeValue(forKey: query)
            } else if key.hasPrefix("stats_") {
                let userIdString = String(key.dropFirst("stats_".count))
                if let userId = UUID(uuidString: userIdString) {
                    userStatsCache.removeValue(forKey: userId)
                }
            }
        }
    }
    
    func clearAllCache() {
        sessionCache.removeAll()
        routeCache.removeAll()
        userStatsCache.removeAll()
        cacheTimestamps.removeAll()
    }
}

// MARK: - Background Processing

actor BackgroundDataProcessor {
    private let dataActor: RuckMapDataActor
    private let cacheManager: DataCacheManager
    
    init(dataActor: RuckMapDataActor, cacheManager: DataCacheManager) {
        self.dataActor = dataActor
        self.cacheManager = cacheManager
    }
    
    // MARK: - Statistics Calculation
    
    func calculateUserStatistics(for userId: UUID) async -> UserStatistics? {
        // Check cache first
        if let cached = await cacheManager.getCachedStatistics(for: userId) {
            return cached
        }
        
        // Fetch sessions for calculation
        let result = await dataActor.fetchUser(id: userId)
        guard case .success(let user) = result, let user = user else {
            return nil
        }
        
        let sessions = user.sessions.filter { $0.isCompleted }
        
        let stats = UserStatistics(
            totalSessions: sessions.count,
            totalDistance: sessions.reduce(0) { $0 + $1.distance },
            totalTime: sessions.reduce(0) { $0 + $1.duration },
            totalCalories: sessions.reduce(0) { $0 + $1.calories },
            averagePackWeight: sessions.isEmpty ? 0 : sessions.reduce(0) { $0 + $1.packWeight } / Double(sessions.count),
            longestSession: sessions.max(by: { $0.distance < $1.distance })?.distance ?? 0,
            fastestPace: sessions.compactMap { $0.averagePace > 0 ? $0.averagePace : nil }.min() ?? 0,
            totalElevationGain: sessions.reduce(0) { $0 + $1.elevationGain },
            currentStreak: calculateCurrentStreak(sessions: sessions),
            longestStreak: calculateLongestStreak(sessions: sessions)
        )
        
        // Cache the result
        await cacheManager.cacheStatistics(stats, for: userId)
        
        return stats
    }
    
    private func calculateCurrentStreak(sessions: [RuckingSession]) -> Int {
        let sortedSessions = sessions.sorted { $0.startDate > $1.startDate }
        var streak = 0
        var lastDate: Date?
        
        for session in sortedSessions {
            let sessionDate = Calendar.current.startOfDay(for: session.startDate)
            
            if let lastDate = lastDate {
                let daysDifference = Calendar.current.dateComponents([.day], from: sessionDate, to: lastDate).day ?? 0
                
                if daysDifference == 1 {
                    streak += 1
                } else if daysDifference > 1 {
                    break
                } // Same day sessions don't break streak
            } else {
                streak = 1
            }
            
            lastDate = sessionDate
        }
        
        return streak
    }
    
    private func calculateLongestStreak(sessions: [RuckingSession]) -> Int {
        let sortedSessions = sessions.sorted { $0.startDate < $1.startDate }
        var longestStreak = 0
        var currentStreak = 0
        var lastDate: Date?
        
        for session in sortedSessions {
            let sessionDate = Calendar.current.startOfDay(for: session.startDate)
            
            if let lastDate = lastDate {
                let daysDifference = Calendar.current.dateComponents([.day], from: lastDate, to: sessionDate).day ?? 0
                
                if daysDifference == 1 {
                    currentStreak += 1
                } else if daysDifference > 1 {
                    longestStreak = max(longestStreak, currentStreak)
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            lastDate = sessionDate
        }
        
        return max(longestStreak, currentStreak)
    }
    
    // MARK: - Route Processing
    
    func updateRouteMetrics() async {
        // Update route difficulty, popularity, and other derived metrics
        // This would run periodically to keep route data fresh
    }
    
    // MARK: - Equipment Maintenance
    
    func checkEquipmentMaintenance(for userId: UUID) async -> [Equipment] {
        let result = await dataActor.fetchUser(id: userId)
        guard case .success(let user) = result, let user = user else {
            return []
        }
        
        return user.equipment.filter { equipment in
            equipment.needsReplacement || shouldScheduleMaintenance(equipment)
        }
    }
    
    private func shouldScheduleMaintenance(_ equipment: Equipment) -> Bool {
        guard let nextMaintenanceDate = equipment.nextMaintenanceDate else {
            return false
        }
        
        return Date() >= nextMaintenanceDate
    }
}

// MARK: - Supporting Types

struct UserStatistics: Codable {
    let totalSessions: Int
    let totalDistance: Double
    let totalTime: TimeInterval
    let totalCalories: Double
    let averagePackWeight: Double
    let longestSession: Double
    let fastestPace: Double
    let totalElevationGain: Double
    let currentStreak: Int
    let longestStreak: Int
    
    var averageDistance: Double {
        guard totalSessions > 0 else { return 0 }
        return totalDistance / Double(totalSessions)
    }
    
    var averageSessionTime: TimeInterval {
        guard totalSessions > 0 else { return 0 }
        return totalTime / Double(totalSessions)
    }
    
    var overallPace: Double {
        guard totalDistance > 0 else { return 0 }
        return (totalTime / 60) / totalDistance // Minutes per mile/km
    }
}

// MARK: - Memory Management

class MemoryManager {
    static let shared = MemoryManager()
    
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    private init() {
        setupMemoryPressureMonitoring()
    }
    
    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        
        memoryPressureSource?.resume()
    }
    
    private func handleMemoryPressure() {
        // Clear caches and free up memory
        NotificationCenter.default.post(name: .memoryPressureDetected, object: nil)
    }
}

extension Notification.Name {
    static let memoryPressureDetected = Notification.Name("memoryPressureDetected")
}
```

---

## Implementation Strategy

### Development Phases and Timeline

#### Phase 1: Foundation (Months 1-2)

**Week 1-2: Core Domain Models**
- [ ] Implement User aggregate with persona system
- [ ] Create RuckingSession model with business logic
- [ ] Build Equipment model with usage tracking
- [ ] Set up basic SwiftData container and configuration
- [ ] Implement core validation rules and invariants

**Week 3-4: Data Access Layer**
- [ ] Create RuckMapDataActor with actor isolation
- [ ] Implement repository pattern for data operations
- [ ] Build error handling and result types
- [ ] Create query optimization patterns
- [ ] Set up unit test infrastructure

**Week 5-6: Basic CloudKit Integration**
- [ ] Configure CloudKit container and schema
- [ ] Implement basic sync functionality
- [ ] Create conflict resolution strategies
- [ ] Build offline-first data handling
- [ ] Test sync reliability and performance

**Week 7-8: Migration System**
- [ ] Design schema versioning strategy
- [ ] Implement migration infrastructure
- [ ] Create version compatibility checks
- [ ] Build rollback mechanisms
- [ ] Test migration scenarios

#### Phase 2: Advanced Features (Months 3-4)

**Week 9-10: Performance Optimization**
- [ ] Implement caching layer
- [ ] Optimize query performance
- [ ] Add background processing
- [ ] Create memory management strategies
- [ ] Profile and optimize critical paths

**Week 11-12: Persona-Specific Features**
- [ ] Implement military veteran specific models
- [ ] Create family-friendly safety features
- [ ] Build urban professional analytics
- [ ] Add senior accessibility features
- [ ] Design outdoor adventure tracking

**Week 13-14: Advanced Sync Features**
- [ ] Implement conflict resolution UI
- [ ] Add batch sync operations
- [ ] Create sync status monitoring
- [ ] Build network failure recovery
- [ ] Test multi-device scenarios

**Week 15-16: Route and Community Features**
- [ ] Implement Route aggregate
- [ ] Create waypoint and review systems
- [ ] Build community features foundation
- [ ] Add geospatial query capabilities
- [ ] Test route sharing and discovery

#### Phase 3: Production Readiness (Months 5-6)

**Week 17-18: Comprehensive Testing**
- [ ] Complete unit test suite
- [ ] Implement integration tests
- [ ] Create performance benchmarks
- [ ] Build stress testing scenarios
- [ ] Validate CloudKit sync at scale

**Week 19-20: Monitoring and Analytics**
- [ ] Implement data quality monitoring
- [ ] Create performance metrics
- [ ] Build usage analytics
- [ ] Add crash reporting integration
- [ ] Set up alerting systems

**Week 21-22: Documentation and Training**
- [ ] Complete API documentation
- [ ] Create development guides
- [ ] Build troubleshooting resources
- [ ] Document best practices
- [ ] Prepare team training materials

**Week 23-24: Launch Preparation**
- [ ] Final security review
- [ ] Performance optimization
- [ ] Data backup strategies
- [ ] Rollout planning
- [ ] Post-launch monitoring setup

---

## Next Steps and Recommendations

### Immediate Actions (Next 30 Days)

1. **Set up Development Environment**
   - Configure Xcode project with SwiftData
   - Set up CloudKit container and capabilities
   - Initialize testing infrastructure
   - Create basic project structure

2. **Implement Core Domain Models**
   - Start with User and RuckingSession models
   - Implement basic business logic and validation
   - Create fundamental relationships
   - Write initial unit tests

3. **Establish Data Access Patterns**
   - Implement RuckMapDataActor
   - Create basic CRUD operations
   - Set up error handling
   - Test actor isolation patterns

### Medium-term Goals (Next 3 Months)

1. **Complete Data Model Architecture**
   - Implement all domain aggregates
   - Finalize relationship mappings
   - Optimize query patterns
   - Complete business logic implementation

2. **Build CloudKit Integration**
   - Implement sync infrastructure
   - Create conflict resolution
   - Test offline scenarios
   - Optimize sync performance

3. **Develop Migration Strategy**
   - Create versioning system
   - Implement migration paths
   - Test upgrade scenarios
   - Build rollback capabilities

### Long-term Vision (6+ Months)

1. **Scale for Growth**
   - Optimize for large datasets
   - Implement advanced caching
   - Create analytics infrastructure
   - Build monitoring systems

2. **Advanced Features**
   - Implement AI/ML capabilities
   - Create predictive analytics
   - Build social features
   - Add enterprise functionality

3. **Platform Expansion**
   - Consider watchOS app
   - Explore macOS version
   - Plan web companion
   - Evaluate Android potential

---

## Conclusion

This SwiftData architecture plan provides a comprehensive foundation for the Ruck Map application, emphasizing domain-driven design principles, robust data consistency, and scalable CloudKit integration. The architecture specifically addresses the unique needs of each user persona while maintaining a clean, testable, and maintainable codebase.

**Key Success Factors:**

1. **Domain-Driven Design**: Clear aggregate boundaries and business logic encapsulation
2. **Actor-Based Concurrency**: Thread-safe data operations with SwiftData best practices
3. **CloudKit Integration**: Seamless multi-device sync with conflict resolution
4. **Persona Optimization**: Data models tailored to specific user needs
5. **Comprehensive Testing**: Unit and integration tests for business logic validation
6. **Performance Focus**: Optimized queries and caching strategies
7. **Migration Strategy**: Future-proof schema evolution and versioning

The implementation strategy provides a clear roadmap from foundation to production, with specific milestones and deliverables for each phase. This approach ensures steady progress while maintaining code quality and architectural integrity throughout the development process.

This architecture positions Ruck Map for success as a leading rucking application that leverages the latest SwiftData capabilities while serving the diverse needs of the military veteran, fitness enthusiast, urban professional, health-conscious retiree, and outdoor adventurer communities.