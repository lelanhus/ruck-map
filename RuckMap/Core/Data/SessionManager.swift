import Foundation
import SwiftData
import CoreLocation
import OSLog

/// Manages SwiftData operations for RuckSession with auto-save functionality
@ModelActor
actor SessionManager {
    private let logger = Logger(subsystem: "com.ruckmap.app", category: "SessionManager")
    private var autoSaveTask: Task<Void, Never>?
    private var backgroundTask: Task<Void, Never>?
    
    // Init is automatically provided by @ModelActor
    // Start background tasks when first method is called
    private var backgroundTasksStarted = false
    
    private func ensureBackgroundTasksStarted() {
        guard !backgroundTasksStarted else { return }
        backgroundTasksStarted = true
        Task {
            startBackgroundTasks()
        }
    }
    
    deinit {
        autoSaveTask?.cancel()
        backgroundTask?.cancel()
    }
    
    // MARK: - Session Management
    
    /// Creates a new session with validation (internal use)
    func createSession(loadWeight: Double) async throws -> RuckSession {
        ensureBackgroundTasksStarted()
        
        guard loadWeight > 0 && loadWeight <= 200 else {
            throw SessionError.invalidWeight(loadWeight)
        }
        
        // Check for existing active session
        if let activeSession = try await fetchActiveSession() {
            throw SessionError.activeSessionExists(activeSession.id)
        }
        
        let session = try RuckSession(loadWeight: loadWeight)
        modelContext.insert(session)
        
        try await saveContext()
        
        logger.info("Created new session with ID: \(session.id)")
        return session
    }
    
    /// Creates a new session and returns just the ID
    func createSessionAndReturnId(loadWeight: Double) async throws -> UUID {
        let session = try await createSession(loadWeight: loadWeight)
        return session.id
    }
    
    /// Fetches the current active session ID
    func fetchActiveSessionId() async throws -> UUID? {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        
        if let session = try modelContext.fetch(descriptor).first {
            return session.id
        }
        return nil
    }
    
    /// Fetches the current active session (internal use only)
    func fetchActiveSession() async throws -> RuckSession? {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor).first
    }
    
    /// Fetches all session IDs sorted by start date
    func fetchAllSessionIds(limit: Int = 100) async throws -> [UUID] {
        var descriptor = FetchDescriptor<RuckSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        let sessions = try modelContext.fetch(descriptor)
        return sessions.map { $0.id }
    }
    
    /// Fetches all sessions sorted by start date (internal use only)
    func fetchAllSessions(limit: Int = 100) async throws -> [RuckSession] {
        var descriptor = FetchDescriptor<RuckSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Gets session export data by ID
    func getSessionExportData(id: UUID) async throws -> SessionExportData? {
        guard let session = try await fetchSession(id: id) else {
            return nil
        }
        
        return SessionExportData(
            id: session.id,
            startDate: session.startDate,
            endDate: session.endDate,
            totalDistance: session.totalDistance,
            loadWeight: session.loadWeight,
            totalCalories: session.totalCalories,
            averagePace: session.averagePace,
            elevationGain: session.elevationGain,
            elevationLoss: session.elevationLoss,
            maxElevation: session.maxElevation,
            minElevation: session.minElevation,
            elevationRange: session.elevationRange,
            averageGrade: session.averageGrade,
            maxGrade: session.maxGrade,
            minGrade: session.minGrade,
            locationPointsCount: session.locationPoints.count,
            elevationAccuracy: session.elevationAccuracy,
            barometerDataPoints: session.barometerDataPoints,
            hasHighQualityElevationData: session.hasHighQualityElevationData,
            version: session.version,
            createdAt: session.createdAt,
            modifiedAt: session.modifiedAt
        )
    }
    
    /// Fetches a specific session by ID (internal use only)
    func fetchSession(id: UUID) async throws -> RuckSession? {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { $0.id == id }
        )
        
        return try modelContext.fetch(descriptor).first
    }
    
    /// Completes a session by ID
    func completeSessionById(
        _ sessionId: UUID,
        totalDistance: Double,
        totalCalories: Double,
        averagePace: Double
    ) async throws {
        guard let session = try await fetchSession(id: sessionId) else {
            throw SessionError.sessionNotFound(sessionId)
        }
        
        try await completeSession(
            session,
            totalDistance: totalDistance,
            totalCalories: totalCalories,
            averagePace: averagePace
        )
    }
    
    /// Completes an active session (internal use)
    func completeSession(
        _ session: RuckSession,
        totalDistance: Double,
        totalCalories: Double,
        averagePace: Double
    ) async throws {
        guard session.endDate == nil else {
            throw SessionError.sessionAlreadyCompleted
        }
        
        session.endDate = Date()
        session.totalDistance = totalDistance
        session.totalCalories = totalCalories
        session.averagePace = averagePace
        session.totalDuration = session.duration
        session.updateModificationDate()
        
        try await saveContext()
        
        logger.info("Completed session with ID: \(session.id)")
    }
    
    /// Deletes a session by ID
    func deleteSessionById(_ sessionId: UUID) async throws {
        guard let session = try await fetchSession(id: sessionId) else {
            throw SessionError.sessionNotFound(sessionId)
        }
        
        try await deleteSession(session)
    }
    
    /// Deletes a session (internal use)
    func deleteSession(_ session: RuckSession) async throws {
        modelContext.delete(session)
        try await saveContext()
        
        logger.info("Deleted session with ID: \(session.id)")
    }
    
    // MARK: - Location Point Management
    
    /// Adds a location point by session ID
    func addLocationPointById(
        to sessionId: UUID,
        from location: CLLocation,
        isKeyPoint: Bool = false
    ) async throws {
        guard let session = try await fetchSession(id: sessionId) else {
            throw SessionError.sessionNotFound(sessionId)
        }
        
        try await addLocationPoint(to: session, from: location, isKeyPoint: isKeyPoint)
    }
    
    /// Adds a location point to an active session (internal use)
    func addLocationPoint(
        to session: RuckSession,
        from location: CLLocation,
        isKeyPoint: Bool = false
    ) async throws {
        let locationPoint = LocationPoint(from: location, isKeyPoint: isKeyPoint)
        session.locationPoints.append(locationPoint)
        session.updateModificationDate()
        
        // Update current position
        session.currentLatitude = location.coordinate.latitude
        session.currentLongitude = location.coordinate.longitude
        session.currentElevation = location.altitude
        
        logger.debug("Added location point to session \(session.id)")
    }
    
    /// Adds multiple location points from data by session ID
    func addLocationPointsFromData(
        to sessionId: UUID,
        pointData: [LocationPointData]
    ) async throws {
        guard let session = try await fetchSession(id: sessionId) else {
            throw SessionError.sessionNotFound(sessionId)
        }
        
        // Convert data to LocationPoint objects
        let points = pointData.map { data in
            LocationPoint(
                timestamp: data.timestamp,
                latitude: data.latitude,
                longitude: data.longitude,
                altitude: data.altitude,
                horizontalAccuracy: data.horizontalAccuracy,
                verticalAccuracy: data.verticalAccuracy,
                speed: data.speed,
                course: data.course,
                isKeyPoint: data.isKeyPoint
            )
        }
        
        try await addLocationPoints(to: session, points: points)
    }
    
    /// Adds multiple location points in batch (internal use)
    func addLocationPoints(
        to session: RuckSession,
        points: [LocationPoint]
    ) async throws {
        session.locationPoints.append(contentsOf: points)
        session.updateModificationDate()
        
        // Update current position from last point
        if let lastPoint = points.last {
            session.currentLatitude = lastPoint.latitude
            session.currentLongitude = lastPoint.longitude
            session.currentElevation = lastPoint.bestAltitude
        }
        
        logger.debug("Added \(points.count) location points to session \(session.id)")
    }
    
    // MARK: - Auto-Save Functionality
    
    /// Starts auto-save timer (every 30 seconds)
    private func startBackgroundTasks() {
        autoSaveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                
                if !Task.isCancelled {
                    await performAutoSave()
                }
            }
        }
        
        // Background processing for data cleanup
        backgroundTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                
                if !Task.isCancelled {
                    await performBackgroundMaintenance()
                }
            }
        }
    }
    
    /// Performs auto-save if there are unsaved changes
    private func performAutoSave() async {
        do {
            if modelContext.hasChanges {
                try modelContext.save()
                logger.debug("Auto-save completed successfully")
            }
        } catch {
            logger.error("Auto-save failed: \(error.localizedDescription)")
        }
    }
    
    /// Performs background maintenance tasks
    private func performBackgroundMaintenance() async {
        do {
            // TODO: Update elevation metrics for active sessions
            // This needs to be refactored to work within actor boundaries
            logger.debug("Elevation metrics update skipped due to actor isolation")
            
            // Cleanup old temporary data if needed
            await cleanupOldTempData()
            
            logger.debug("Background maintenance completed")
        } catch {
            logger.error("Background maintenance failed: \(error.localizedDescription)")
        }
    }
    
    /// Updates session location points (for compression)
    func updateSessionLocationPoints(sessionId: UUID, newPoints: [LocationPoint]) async throws {
        guard let session = try await fetchSession(id: sessionId) else {
            throw SessionError.sessionNotFound(sessionId)
        }
        
        session.locationPoints.removeAll()
        session.locationPoints.append(contentsOf: newPoints)
        session.updateModificationDate()
        
        try await saveContext()
    }
    
    /// Compresses a session's track data
    func compressSessionTrack(
        sessionId: UUID,
        epsilon: Double = 5.0,
        preserveElevationChanges: Bool = true
    ) async throws -> CompressionStats {
        guard let session = try await fetchSession(id: sessionId) else {
            throw SessionError.sessionNotFound(sessionId)
        }
        
        // For now, return dummy stats - compression needs to be refactored
        // to work within the actor boundary
        let originalCount = session.locationPoints.count
        
        // TODO: Implement compression that works within actor boundaries
        logger.warning("Track compression temporarily disabled due to actor isolation")
        
        return CompressionStats(
            compressionRatio: 1.0,
            originalCount: originalCount,
            compressedCount: originalCount,
            preservedKeyPoints: originalCount
        )
    }
    
    /// Gets validation data for a session
    func getSessionValidationData(id: UUID) async throws -> SessionValidationData? {
        guard let session = try await fetchSession(id: id) else {
            return nil
        }
        
        var locationIssues: [String] = []
        
        // Location data validation
        for (index, point) in session.locationPoints.enumerated() {
            if abs(point.latitude) > 90 {
                locationIssues.append("Invalid latitude at point \(index): \(point.latitude)")
            }
            
            if abs(point.longitude) > 180 {
                locationIssues.append("Invalid longitude at point \(index): \(point.longitude)")
            }
            
            if point.horizontalAccuracy < 0 {
                locationIssues.append("Invalid accuracy at point \(index): \(point.horizontalAccuracy)")
            }
        }
        
        return SessionValidationData(
            startDate: session.startDate,
            endDate: session.endDate,
            loadWeight: session.loadWeight,
            locationIssues: locationIssues
        )
    }
    
    /// Cleans up old temporary data (location points older than 30 days for completed sessions)
    private func cleanupOldTempData() async {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        do {
            let oldSessionsDescriptor = FetchDescriptor<RuckSession>(
                predicate: #Predicate { session in
                    session.endDate != nil &&
                    session.endDate! < thirtyDaysAgo &&
                    session.locationPoints.count > 1000
                }
            )
            
            let oldSessions = try modelContext.fetch(oldSessionsDescriptor)
            
            for session in oldSessions {
                // TODO: Implement compression that works within actor boundaries
                logger.info("Would compress session \(session.id) with \(session.locationPoints.count) points")
            }
            
            try await saveContext()
        } catch {
            logger.error("Cleanup failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Restore Functionality
    
    /// Checks if there are incomplete sessions
    func hasIncompleteSession() async throws -> Bool {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate<RuckSession> { session in
                session.endDate == nil
            }
        )
        
        let sessions = try modelContext.fetch(descriptor)
        return !sessions.isEmpty
    }
    
    /// Restores incomplete sessions on app launch
    func restoreIncompleteSession() async throws -> RuckSession? {
        if let activeSession = try await fetchActiveSession() {
            logger.info("Restored incomplete session with ID: \(activeSession.id)")
            return activeSession
        }
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func saveContext() async throws {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
            throw SessionError.saveFailed(error)
        }
    }
}

// MARK: - Errors

enum SessionError: LocalizedError {
    case invalidWeight(Double)
    case activeSessionExists(UUID)
    case sessionAlreadyCompleted
    case saveFailed(Error)
    case sessionNotFound(UUID)
    
    var errorDescription: String? {
        switch self {
        case .invalidWeight(let weight):
            return "Invalid weight: \(weight) kg. Must be between 0 and 200."
        case .activeSessionExists(let id):
            return "An active session already exists (ID: \(id)). Complete it before starting a new one."
        case .sessionAlreadyCompleted:
            return "Session is already completed."
        case .saveFailed(let error):
            return "Failed to save session: \(error.localizedDescription)"
        case .sessionNotFound(let id):
            return "Session with ID \(id) not found."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidWeight:
            return "Enter a weight between 0 and 200 kg."
        case .activeSessionExists:
            return "Complete the current session before starting a new one."
        case .sessionAlreadyCompleted:
            return "Start a new session instead."
        case .saveFailed:
            return "Check available storage space and try again."
        case .sessionNotFound:
            return "The session may have been deleted. Refresh the list."
        }
    }
}

// MARK: - Sendable Types

/// Data for session validation (Sendable)
struct SessionValidationData: Sendable {
    let startDate: Date
    let endDate: Date?
    let loadWeight: Double
    let locationIssues: [String]
}

/// Compression statistics (Sendable)
struct CompressionStats: Sendable {
    let compressionRatio: Double
    let originalCount: Int
    let compressedCount: Int
    let preservedKeyPoints: Int
}