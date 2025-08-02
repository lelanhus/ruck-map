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
    
    init(container: ModelContainer) {
        let context = ModelContext(container)
        self.init(modelContext: context)
        
        Task {
            await startBackgroundTasks()
        }
    }
    
    deinit {
        autoSaveTask?.cancel()
        backgroundTask?.cancel()
    }
    
    // MARK: - Session Management
    
    /// Creates a new session with validation
    func createSession(loadWeight: Double) async throws -> RuckSession {
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
    
    /// Fetches the current active session
    func fetchActiveSession() async throws -> RuckSession? {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor).first
    }
    
    /// Fetches all sessions sorted by start date
    func fetchAllSessions(limit: Int = 100) async throws -> [RuckSession] {
        var descriptor = FetchDescriptor<RuckSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches a specific session by ID
    func fetchSession(id: UUID) async throws -> RuckSession? {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { $0.id == id }
        )
        
        return try modelContext.fetch(descriptor).first
    }
    
    /// Completes an active session
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
    
    /// Deletes a session
    func deleteSession(_ session: RuckSession) async throws {
        modelContext.delete(session)
        try await saveContext()
        
        logger.info("Deleted session with ID: \(session.id)")
    }
    
    // MARK: - Location Point Management
    
    /// Adds a location point to an active session
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
    
    /// Adds multiple location points in batch
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
            // Update elevation metrics for active sessions
            if let activeSession = try await fetchActiveSession() {
                await activeSession.updateElevationMetrics()
            }
            
            // Cleanup old temporary data if needed
            await cleanupOldTempData()
            
            logger.debug("Background maintenance completed")
        } catch {
            logger.error("Background maintenance failed: \(error.localizedDescription)")
        }
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
                // Compress location points for old sessions
                let compressor = TrackCompressor()
                let compressedPoints = await compressor.compress(
                    points: session.locationPoints,
                    epsilon: 10.0 // More aggressive compression for old data
                )
                
                // Replace with compressed points
                session.locationPoints.removeAll()
                session.locationPoints.append(contentsOf: compressedPoints)
                
                logger.info("Compressed session \(session.id): \(compressedPoints.count) points retained")
            }
            
            try await saveContext()
        } catch {
            logger.error("Cleanup failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Restore Functionality
    
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