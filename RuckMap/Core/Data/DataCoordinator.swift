import Foundation
import SwiftData
import SwiftUI
import OSLog

/// Central coordinator for all data operations in RuckMap
@MainActor
class DataCoordinator: ObservableObject {
    private let logger = Logger(subsystem: "com.ruckmap.app", category: "DataCoordinator")
    
    // Core components
    let modelContainer: ModelContainer
    private let sessionManager: SessionManager
    private let migrationManager: MigrationManager
    private let exportManager: ExportManager
    private let trackCompressor: TrackCompressor
    
    // Published state
    @Published var isInitialized = false
    @Published var initializationError: Error?
    @Published var backgroundSyncStatus: SyncStatus = .idle
    
    enum SyncStatus {
        case idle
        case syncing
        case failed(Error)
    }
    
    init() throws {
        // Initialize ModelContainer with CloudKit support
        let schema = Schema([
            RuckSession.self,
            LocationPoint.self,
            TerrainSegment.self,
            WeatherConditions.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: URL.documentsDirectory.appending(path: "RuckMap.store"),
            cloudKitDatabase: .automatic
        )
        
        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.sessionManager = SessionManager(modelContainer: modelContainer)
            self.migrationManager = MigrationManager()
            self.exportManager = ExportManager()
            self.trackCompressor = TrackCompressor()
            
            logger.info("DataCoordinator initialized successfully")
        } catch {
            logger.error("Failed to initialize DataCoordinator: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Performs initial setup and migration checks
    func initialize() async {
        do {
            logger.info("Starting DataCoordinator initialization")
            
            // Check and perform migrations
            try await migrationManager.checkAndPerformMigration(modelContainer: modelContainer)
            
            // Validate data integrity
            let validationReport = try await migrationManager.validateDataIntegrity(modelContainer: modelContainer)
            
            if !validationReport.isValid {
                logger.warning("Data integrity issues found: \(validationReport.errors)")
            }
            
            // Clean up old backups
            try await migrationManager.cleanupOldBackups()
            
            // Clean up old exports
            try await exportManager.cleanupOldExports()
            
            // Check for incomplete sessions
            if let incompleteSession = try await sessionManager.restoreIncompleteSession() {
                logger.info("Restored incomplete session: \(incompleteSession.id)")
            }
            
            isInitialized = true
            logger.info("DataCoordinator initialization completed successfully")
            
        } catch {
            logger.error("DataCoordinator initialization failed: \(error.localizedDescription)")
            initializationError = error
        }
    }
    
    // MARK: - Session Management
    
    /// Creates a new ruck session
    func createSession(loadWeight: Double) async throws -> RuckSession {
        return try await sessionManager.createSession(loadWeight: loadWeight)
    }
    
    /// Gets the current active session
    func getActiveSession() async throws -> RuckSession? {
        return try await sessionManager.fetchActiveSession()
    }
    
    /// Gets all sessions
    func getAllSessions(limit: Int = 100) async throws -> [RuckSession] {
        return try await sessionManager.fetchAllSessions(limit: limit)
    }
    
    /// Gets a specific session
    func getSession(id: UUID) async throws -> RuckSession? {
        return try await sessionManager.fetchSession(id: id)
    }
    
    /// Completes a session
    func completeSession(
        _ session: RuckSession,
        totalDistance: Double,
        totalCalories: Double,
        averagePace: Double
    ) async throws {
        try await sessionManager.completeSession(
            session,
            totalDistance: totalDistance,
            totalCalories: totalCalories,
            averagePace: averagePace
        )
    }
    
    /// Deletes a session
    func deleteSession(_ session: RuckSession) async throws {
        try await sessionManager.deleteSession(session)
    }
    
    // MARK: - Location Tracking
    
    /// Adds a location point to the active session
    func addLocationPoint(to session: RuckSession, from location: CoreLocation.CLLocation) async throws {
        try await sessionManager.addLocationPoint(to: session, from: location)
    }
    
    /// Adds multiple location points with optional compression
    func addLocationPoints(
        to session: RuckSession,
        points: [LocationPoint],
        compress: Bool = false,
        compressionEpsilon: Double = 5.0
    ) async throws {
        var finalPoints = points
        
        if compress && points.count > 100 {
            // Compress points if there are many
            finalPoints = await trackCompressor.compress(
                points: points,
                epsilon: compressionEpsilon
            )
            
            logger.info("Compressed \(points.count) points to \(finalPoints.count)")
        }
        
        try await sessionManager.addLocationPoints(to: session, points: finalPoints)
    }
    
    // MARK: - Data Export
    
    /// Exports a session to GPX format
    func exportSessionToGPX(_ session: RuckSession) async throws -> URL {
        let result = try await exportManager.exportToGPX(session: session)
        
        // Save to permanent location
        let filename = "RuckSession_\(session.startDate.formatted(.iso8601))_\(session.id.uuidString.prefix(8)).gpx"
        return try await exportManager.saveExportPermanently(temporaryURL: result.url, filename: filename)
    }
    
    /// Exports a session to CSV format
    func exportSessionToCSV(_ session: RuckSession) async throws -> URL {
        let result = try await exportManager.exportToCSV(session: session)
        
        // Save to permanent location
        let filename = "RuckSession_\(session.startDate.formatted(.iso8601))_\(session.id.uuidString.prefix(8)).csv"
        return try await exportManager.saveExportPermanently(temporaryURL: result.url, filename: filename)
    }
    
    /// Exports a session with format selection
    func exportSession(_ session: RuckSession, format: ExportManager.ExportFormat) async throws -> URL {
        switch format {
        case .gpx:
            return try await exportSessionToGPX(session)
        case .csv:
            return try await exportSessionToCSV(session)
        case .json:
            let result = try await exportManager.exportToJSON(session: session)
            let filename = "RuckSession_\(session.startDate.formatted(.iso8601))_\(session.id.uuidString.prefix(8)).json"
            return try await exportManager.saveExportPermanently(temporaryURL: result.url, filename: filename)
        }
    }
    
    /// Exports multiple sessions
    func exportSessions(_ sessions: [RuckSession], format: ExportManager.ExportFormat) async throws -> [URL] {
        var urls: [URL] = []
        
        for session in sessions {
            do {
                let url = try await exportSession(session, format: format)
                urls.append(url)
            } catch {
                logger.error("Failed to export session \(session.id): \(error.localizedDescription)")
                // Continue with other sessions
            }
        }
        
        return urls
    }
    
    // MARK: - Track Compression
    
    /// Compresses a session's location points
    func compressSessionTrack(
        _ session: RuckSession,
        epsilon: Double = 5.0,
        preserveElevationChanges: Bool = true
    ) async throws -> TrackCompressor.CompressionResult {
        let result = await trackCompressor.compressWithResult(
            points: session.locationPoints,
            epsilon: epsilon,
            preserveElevationChanges: preserveElevationChanges
        )
        
        // Update session with compressed points
        session.locationPoints.removeAll()
        session.locationPoints.append(contentsOf: result.compressedPoints)
        session.updateModificationDate()
        
        // Save changes
        try modelContainer.mainContext.save()
        
        logger.info("Compressed session \(session.id): \(result.compressionRatio * 100)% size reduction")
        
        return result
    }
    
    // MARK: - Data Validation and Integrity
    
    /// Validates a session's data integrity
    func validateSession(_ session: RuckSession) async -> [String] {
        var errors: [String] = []
        
        // Basic validation
        if session.startDate > Date() {
            errors.append("Start date is in the future")
        }
        
        if let endDate = session.endDate, endDate < session.startDate {
            errors.append("End date is before start date")
        }
        
        if session.loadWeight < 0 || session.loadWeight > 200 {
            errors.append("Invalid load weight: \(session.loadWeight)kg")
        }
        
        // Location data validation
        for (index, point) in session.locationPoints.enumerated() {
            if abs(point.latitude) > 90 {
                errors.append("Invalid latitude at point \(index): \(point.latitude)")
            }
            
            if abs(point.longitude) > 180 {
                errors.append("Invalid longitude at point \(index): \(point.longitude)")
            }
            
            if point.horizontalAccuracy < 0 {
                errors.append("Invalid accuracy at point \(index): \(point.horizontalAccuracy)")
            }
        }
        
        return errors
    }
    
    /// Performs comprehensive data validation
    func performDataValidation() async throws -> MigrationManager.ValidationReport {
        return try await migrationManager.validateDataIntegrity(modelContainer: modelContainer)
    }
    
    // MARK: - Background Tasks
    
    /// Monitors CloudKit sync status
    private func startSyncMonitoring() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.backgroundSyncStatus = .syncing
                
                // Process sync completion after a delay
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                self?.backgroundSyncStatus = .idle
            }
        }
    }
    
    /// Cleans up resources
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - View Factory Methods

extension DataCoordinator {
    /// Creates a session list view with proper dependencies
    func makeSessionListView() -> some View {
        SessionListView()
            .environmentObject(self)
            .modelContainer(modelContainer)
    }
    
    /// Creates a session detail view
    func makeSessionDetailView(for session: RuckSession) -> some View {
        SessionDetailView(session: session)
            .environmentObject(self)
            .modelContainer(modelContainer)
    }
    
    /// Creates an active tracking view
    func makeActiveTrackingView() -> some View {
        ActiveTrackingView()
            .environmentObject(self)
            .modelContainer(modelContainer)
    }
}

// MARK: - Placeholder Views

/// Placeholder for session list view
struct SessionListView: View {
    var body: some View {
        Text("Session List View")
    }
}

/// Placeholder for session detail view
struct SessionDetailView: View {
    let session: RuckSession
    
    var body: some View {
        Text("Session Detail View for \(session.id)")
    }
}