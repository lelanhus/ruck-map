import Foundation
import SwiftData
import CoreLocation

// MARK: - Watch-Optimized Ruck Session

/// Lightweight ruck session model optimized for Apple Watch storage constraints
@Model
final class WatchRuckSession: @unchecked Sendable {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var totalDistance: Double = 0.0 // meters
    var totalDuration: TimeInterval = 0.0
    var loadWeight: Double = 0.0 // kg
    var totalCalories: Double = 0.0
    var averagePace: Double = 0.0 // min/km
    var currentPace: Double = 0.0 // min/km
    var elevationGain: Double = 0.0 // meters
    var elevationLoss: Double = 0.0 // meters
    var currentElevation: Double = 0.0 // meters
    var currentGrade: Double = 0.0 // percentage
    var createdAt: Date
    var modifiedAt: Date
    
    // Current location for real-time display
    var currentLatitude: Double?
    var currentLongitude: Double?
    
    // Session state
    var isPaused: Bool = false
    
    // Simplified relationships for Watch
    @Relationship(deleteRule: .cascade)
    var locationPoints: [WatchLocationPoint]
    
    init(loadWeight: Double = 0.0) {
        self.id = UUID()
        self.startDate = Date()
        self.loadWeight = loadWeight
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.locationPoints = []
    }
    
    var isActive: Bool {
        endDate == nil
    }
    
    var duration: TimeInterval {
        guard let endDate = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        return endDate.timeIntervalSince(startDate)
    }
    
    /// Net elevation change (gain - loss)
    var netElevationChange: Double {
        elevationGain - elevationLoss
    }
    
    func updateModificationDate() {
        self.modifiedAt = Date()
    }
    
    /// Complete the session
    func complete() {
        self.endDate = Date()
        self.totalDuration = duration
        updateModificationDate()
    }
    
    /// Pause the session
    func pause() {
        self.isPaused = true
        updateModificationDate()
    }
    
    /// Resume the session
    func resume() {
        self.isPaused = false
        updateModificationDate()
    }
}

// MARK: - Watch-Optimized Location Point

/// Lightweight location point model optimized for Apple Watch
@Model
final class WatchLocationPoint: @unchecked Sendable {
    var timestamp: Date = Date()
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var altitude: Double = 0.0
    var horizontalAccuracy: Double = 0.0
    var verticalAccuracy: Double = 0.0
    var speed: Double = 0.0 // m/s
    var course: Double = 0.0 // degrees
    
    // Essential elevation data only
    var bestAltitude: Double = 0.0 // Pre-calculated best altitude
    var instantaneousGrade: Double? // Current grade percentage
    
    // Heart rate data from HealthKit
    var heartRate: Double?
    
    @Relationship(inverse: \WatchRuckSession.locationPoints)
    var session: WatchRuckSession?
    
    init(from location: CLLocation) {
        self.timestamp = location.timestamp
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.speed = max(0, location.speed) // Ensure non-negative
        self.course = location.course >= 0 ? location.course : 0
        self.bestAltitude = location.altitude // Will be updated with better data
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var clLocation: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }
    
    func distance(to other: WatchLocationPoint) -> Double {
        clLocation.distance(from: other.clLocation)
    }
    
    var isAccurate: Bool {
        horizontalAccuracy <= 10.0 && horizontalAccuracy > 0
    }
    
    /// Update heart rate data from HealthKit
    func updateHeartRate(_ heartRate: Double?) {
        self.heartRate = heartRate
    }
    
    /// Calculate elevation change to another point
    func elevationChange(to other: WatchLocationPoint) -> Double {
        return other.bestAltitude - self.bestAltitude
    }
    
    /// Calculate grade percentage to another point
    func gradeTo(_ other: WatchLocationPoint) -> Double {
        let elevationChange = elevationChange(to: other)
        let horizontalDistance = distance(to: other)
        guard horizontalDistance > 0 else { return 0.0 }
        
        let grade = (elevationChange / horizontalDistance) * 100.0
        return max(-20.0, min(20.0, grade)) // Clamp to ±20%
    }
}

// MARK: - Watch Data Manager

/// Manages local Watch data storage with automatic cleanup
@MainActor
@Observable
final class WatchDataManager {
    private let modelContainer: ModelContainer
    private let dataRetentionHours: TimeInterval = 48 * 3600 // 48 hours in seconds
    
    // Published properties
    var currentSession: WatchRuckSession?
    var recentSessions: [WatchRuckSession] = []
    
    init() throws {
        let schema = Schema([
            WatchRuckSession.self,
            WatchLocationPoint.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none // No CloudKit sync from Watch
        )
        
        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
        
        // Start automatic cleanup
        startAutomaticCleanup()
    }
    
    /// Create a new ruck session
    func createSession(loadWeight: Double = 0.0) throws -> WatchRuckSession {
        let session = WatchRuckSession(loadWeight: loadWeight)
        modelContainer.mainContext.insert(session)
        
        try modelContainer.mainContext.save()
        
        self.currentSession = session
        loadRecentSessions()
        
        return session
    }
    
    /// Add location point to current session
    func addLocationPoint(from location: CLLocation) throws {
        guard let session = currentSession else {
            throw WatchDataError.noActiveSession
        }
        
        let locationPoint = WatchLocationPoint(from: location)
        session.locationPoints.append(locationPoint)
        
        // Update session current location
        session.currentLatitude = location.coordinate.latitude
        session.currentLongitude = location.coordinate.longitude
        session.updateModificationDate()
        
        // Save every 10 points to avoid memory pressure
        if session.locationPoints.count % 10 == 0 {
            try modelContainer.mainContext.save()
        }
    }
    
    /// Complete the current session
    func completeCurrentSession() throws {
        guard let session = currentSession else {
            throw WatchDataError.noActiveSession
        }
        
        session.complete()
        try modelContainer.mainContext.save()
        
        self.currentSession = nil
        loadRecentSessions()
    }
    
    /// Pause the current session
    func pauseCurrentSession() throws {
        guard let session = currentSession else {
            throw WatchDataError.noActiveSession
        }
        
        session.pause()
        try modelContainer.mainContext.save()
    }
    
    /// Resume the current session
    func resumeCurrentSession() throws {
        guard let session = currentSession else {
            throw WatchDataError.noActiveSession
        }
        
        session.resume()
        try modelContainer.mainContext.save()
    }
    
    /// Load recent sessions for display
    private func loadRecentSessions() {
        let fetchDescriptor = FetchDescriptor<WatchRuckSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        
        do {
            let sessions = try modelContainer.mainContext.fetch(fetchDescriptor)
            self.recentSessions = Array(sessions.prefix(5)) // Keep only 5 recent sessions in memory
        } catch {
            print("Failed to load recent sessions: \(error)")
            self.recentSessions = []
        }
    }
    
    /// Get session by ID
    func getSession(id: UUID) -> WatchRuckSession? {
        let fetchDescriptor = FetchDescriptor<WatchRuckSession>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            return try modelContainer.mainContext.fetch(fetchDescriptor).first
        } catch {
            print("Failed to fetch session \(id): \(error)")
            return nil
        }
    }
    
    /// Delete old sessions beyond retention period
    private func cleanupOldSessions() throws {
        let cutoffDate = Date().addingTimeInterval(-dataRetentionHours)
        
        let fetchDescriptor = FetchDescriptor<WatchRuckSession>(
            predicate: #Predicate { $0.startDate < cutoffDate }
        )
        
        let oldSessions = try modelContainer.mainContext.fetch(fetchDescriptor)
        
        for session in oldSessions {
            modelContainer.mainContext.delete(session)
        }
        
        if !oldSessions.isEmpty {
            try modelContainer.mainContext.save()
            print("Cleaned up \(oldSessions.count) old sessions")
        }
    }
    
    /// Start automatic cleanup timer
    private func startAutomaticCleanup() {
        // Clean up every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                do {
                    try self?.cleanupOldSessions()
                } catch {
                    print("Failed to cleanup old sessions: \(error)")
                }
            }
        }
        
        // Initial cleanup
        Task {
            do {
                try cleanupOldSessions()
            } catch {
                print("Failed initial cleanup: \(error)")
            }
        }
    }
    
    /// Get storage usage statistics
    func getStorageStats() -> WatchStorageStats {
        let totalSessions = recentSessions.count
        let totalLocationPoints = recentSessions.reduce(0) { $0 + $1.locationPoints.count }
        
        return WatchStorageStats(
            sessionCount: totalSessions,
            locationPointCount: totalLocationPoints,
            estimatedSizeKB: Double(totalLocationPoints) * 0.5 // Rough estimate: 0.5KB per point
        )
    }
}

// MARK: - Supporting Types

struct WatchStorageStats {
    let sessionCount: Int
    let locationPointCount: Int
    let estimatedSizeKB: Double
    
    var estimatedSizeMB: Double {
        estimatedSizeKB / 1024.0
    }
}

enum WatchDataError: LocalizedError {
    case noActiveSession
    case sessionAlreadyExists
    case storageFailure(Error)
    
    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active ruck session"
        case .sessionAlreadyExists:
            return "A session is already in progress"
        case .storageFailure(let error):
            return "Storage error: \(error.localizedDescription)"
        }
    }
}