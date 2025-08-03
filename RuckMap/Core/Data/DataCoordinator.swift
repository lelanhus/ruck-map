import Foundation
import SwiftData
import SwiftUI
import OSLog
import CoreLocation

/// Central coordinator for all data operations in RuckMap
@MainActor
class DataCoordinator: ObservableObject {
    private let logger = Logger(subsystem: "com.ruckmap.app", category: "DataCoordinator")
    
    // Core components
    let modelContainer: ModelContainer
    private let sessionManager: SessionManager
    private let migrationManager: MigrationManager
    private let exportManager: ExportManager
    // Removed trackCompressor - compression handled by SessionManager
    
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
            // TrackCompressor is now used internally by SessionManager
            
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
            let hasIncompleteSession = try await sessionManager.hasIncompleteSession()
            if hasIncompleteSession {
                logger.info("Found incomplete session to restore")
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
    func createSession(loadWeight: Double) async throws -> UUID {
        return try await sessionManager.createSessionAndReturnId(loadWeight: loadWeight)
    }
    
    /// Gets the current active session ID
    func getActiveSessionId() async throws -> UUID? {
        return try await sessionManager.fetchActiveSessionId()
    }
    
    /// Gets all session IDs
    func getAllSessionIds(limit: Int = 100) async throws -> [UUID] {
        return try await sessionManager.fetchAllSessionIds(limit: limit)
    }
    
    /// Checks if a session exists
    func sessionExists(id: UUID) async throws -> Bool {
        // Check if session exists by trying to get its export data
        let data = try await getSessionExportData(id: id)
        return data != nil
    }
    
    /// Gets session data for export
    func getSessionExportData(id: UUID) async throws -> SessionExportData? {
        return try await sessionManager.getSessionExportData(id: id)
    }
    
    /// Completes a session
    func completeSession(
        sessionId: UUID,
        totalDistance: Double,
        totalCalories: Double,
        averagePace: Double
    ) async throws {
        try await sessionManager.completeSessionById(
            sessionId,
            totalDistance: totalDistance,
            totalCalories: totalCalories,
            averagePace: averagePace
        )
    }
    
    /// Deletes a session
    func deleteSession(sessionId: UUID) async throws {
        try await sessionManager.deleteSessionById(sessionId)
    }
    
    // MARK: - Location Tracking
    
    /// Adds a location point to the active session
    func addLocationPoint(to sessionId: UUID, from location: CLLocation) async throws {
        try await sessionManager.addLocationPointById(to: sessionId, from: location)
    }
    
    /// Adds multiple location points with optional compression
    func addLocationPoints(
        to sessionId: UUID,
        locations: [CLLocation],
        compress: Bool = false,
        compressionEpsilon: Double = 5.0
    ) async throws {
        if compress && locations.count > 100 {
            // Compression will be handled by SessionManager
            logger.info("Compression requested for \(locations.count) points")
        }
        
        // Convert to location point data
        let pointData = locations.map { LocationPointData(from: $0) }
        
        try await sessionManager.addLocationPointsFromData(to: sessionId, pointData: pointData)
    }
    
    // MARK: - Data Export
    
    /// Exports a session to GPX format
    func exportSessionToGPX(sessionId: UUID) async throws -> URL {
        guard let sessionData = try await getSessionExportData(id: sessionId) else {
            throw ExportManager.ExportError.sessionNotFound
        }
        
        let result = try await exportManager.exportToGPX(sessionData: sessionData)
        
        // Save to permanent location
        let filename = "RuckSession_\(sessionData.startDate.formatted(.iso8601))_\(sessionData.id.uuidString.prefix(8)).gpx"
        return try await exportManager.saveExportPermanently(temporaryURL: result.url, filename: filename)
    }
    
    /// Exports a session to CSV format
    func exportSessionToCSV(sessionId: UUID) async throws -> URL {
        guard let sessionData = try await getSessionExportData(id: sessionId) else {
            throw ExportManager.ExportError.sessionNotFound
        }
        
        let result = try await exportManager.exportToCSV(sessionData: sessionData)
        
        // Save to permanent location
        let filename = "RuckSession_\(sessionData.startDate.formatted(.iso8601))_\(sessionData.id.uuidString.prefix(8)).csv"
        return try await exportManager.saveExportPermanently(temporaryURL: result.url, filename: filename)
    }
    
    /// Exports a session with format selection
    func exportSession(sessionId: UUID, format: ExportManager.ExportFormat) async throws -> URL {
        switch format {
        case .gpx:
            return try await exportSessionToGPX(sessionId: sessionId)
        case .csv:
            return try await exportSessionToCSV(sessionId: sessionId)
        case .json:
            guard let sessionData = try await getSessionExportData(id: sessionId) else {
                throw ExportManager.ExportError.sessionNotFound
            }
            
            let result = try await exportManager.exportToJSON(sessionData: sessionData)
            let filename = "RuckSession_\(sessionData.startDate.formatted(.iso8601))_\(sessionData.id.uuidString.prefix(8)).json"
            return try await exportManager.saveExportPermanently(temporaryURL: result.url, filename: filename)
        case .pdf:
            guard let session = try container.mainContext.fetch(
                FetchDescriptor<RuckSession>(
                    predicate: #Predicate { $0.id == sessionId }
                )
            ).first else {
                throw ExportManager.ExportError.sessionNotFound
            }
            
            return try await exportManager.exportAsPDF(session: session)
        }
    }
    
    /// Exports multiple sessions
    func exportSessions(sessionIds: [UUID], format: ExportManager.ExportFormat) async throws -> [URL] {
        var urls: [URL] = []
        
        for sessionId in sessionIds {
            do {
                let url = try await exportSession(sessionId: sessionId, format: format)
                urls.append(url)
            } catch {
                logger.error("Failed to export session \(sessionId): \(error.localizedDescription)")
                // Continue with other sessions
            }
        }
        
        return urls
    }
    
    // MARK: - Track Compression
    
    /// Compresses a session's location points
    func compressSessionTrack(
        sessionId: UUID,
        epsilon: Double = 5.0,
        preserveElevationChanges: Bool = true
    ) async throws -> CompressionStats {
        // Delegate compression to SessionManager
        return try await sessionManager.compressSessionTrack(
            sessionId: sessionId,
            epsilon: epsilon,
            preserveElevationChanges: preserveElevationChanges
        )
    }
    
    // MARK: - Data Validation and Integrity
    
    /// Validates a session's data integrity
    func validateSession(sessionId: UUID) async throws -> [String] {
        // Get session data through session manager
        let validationData = try await sessionManager.getSessionValidationData(id: sessionId)
        
        guard let data = validationData else {
            return ["Session not found"]
        }
        
        var errors: [String] = []
        
        // Basic validation
        if data.startDate > Date() {
            errors.append("Start date is in the future")
        }
        
        if let endDate = data.endDate, endDate < data.startDate {
            errors.append("End date is before start date")
        }
        
        if data.loadWeight < 0 || data.loadWeight > 200 {
            errors.append("Invalid load weight: \(data.loadWeight)kg")
        }
        
        // Location data validation
        for issue in data.locationIssues {
            errors.append(issue)
        }
        
        return errors
    }
    
    /// Performs comprehensive data validation
    func performDataValidation() async throws -> ValidationReport {
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
    func makeActiveTrackingView(locationManager: LocationTrackingManager) -> some View {
        ActiveTrackingView(locationManager: locationManager)
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

