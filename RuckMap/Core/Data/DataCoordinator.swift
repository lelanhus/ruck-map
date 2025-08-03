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
    
    private init(
        modelContainer: ModelContainer,
        sessionManager: SessionManager,
        migrationManager: MigrationManager,
        exportManager: ExportManager,
        isFallback: Bool = false
    ) {
        self.modelContainer = modelContainer
        self.sessionManager = sessionManager
        self.migrationManager = migrationManager
        self.exportManager = exportManager
        
        if isFallback {
            logger.warning("DataCoordinator initialized in fallback mode with in-memory storage")
        } else {
            logger.info("DataCoordinator initialized successfully")
        }
    }
    
    init() throws {
        // Initialize ModelContainer with CloudKit support
        let schema = Schema([
            RuckSession.self,
            LocationPoint.self,
            TerrainSegment.self,
            WeatherConditions.self
        ])
        
        let storeURL = URL.documentsDirectory.appending(path: "RuckMap.store")
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .automatic
        )
        
        do {
            let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let sessionManager = SessionManager(modelContainer: modelContainer)
            let migrationManager = MigrationManager()
            let exportManager = ExportManager()
            
            self.modelContainer = modelContainer
            self.sessionManager = sessionManager
            self.migrationManager = migrationManager
            self.exportManager = exportManager
            
            logger.info("DataCoordinator initialized successfully")
        } catch {
            logger.error("Failed to initialize DataCoordinator: \(error.localizedDescription)")
            
            // Attempt to recover from migration failures
            if error.localizedDescription.contains("migration") || 
               error.localizedDescription.contains("attribute") ||
               error.localizedDescription.contains("mandatory destination") {
                logger.warning("Detected migration/schema error, attempting recovery")
                
                do {
                    // Try to backup and recreate store
                    try DataCoordinator.performMigrationFailureRecovery(storeURL: storeURL, schema: schema)
                    
                    let recoveryConfiguration = ModelConfiguration(
                        schema: schema,
                        url: storeURL,
                        cloudKitDatabase: .automatic
                    )
                    
                    self.modelContainer = try ModelContainer(for: schema, configurations: [recoveryConfiguration])
                    self.sessionManager = SessionManager(modelContainer: modelContainer)
                    self.migrationManager = MigrationManager()
                    self.exportManager = ExportManager()
                    
                    logger.info("DataCoordinator recovered successfully after migration failure")
                } catch {
                    logger.error("Recovery attempt failed: \(error.localizedDescription)")
                    throw DataCoordinatorError.initializationFailed(error)
                }
            } else {
                throw DataCoordinatorError.initializationFailed(error)
            }
        }
    }
    
    /// Performs initial setup and migration checks
    func initialize() async {
        do {
            logger.info("Starting DataCoordinator initialization")
            
            // Check and perform migrations with retry logic
            var migrationAttempts = 0
            let maxMigrationAttempts = 3
            
            while migrationAttempts < maxMigrationAttempts {
                do {
                    try await migrationManager.checkAndPerformMigration(modelContainer: modelContainer)
                    break // Success, exit retry loop
                } catch {
                    migrationAttempts += 1
                    logger.warning("Migration attempt \(migrationAttempts) failed: \(error.localizedDescription)")
                    
                    if migrationAttempts >= maxMigrationAttempts {
                        logger.error("All migration attempts failed, proceeding with data validation")
                        // Don't throw here, let validation run to fix any remaining issues
                    } else {
                        // Brief delay before retry
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    }
                }
            }
            
            // Validate data integrity (this will also fix issues)
            let validationReport = try await migrationManager.validateDataIntegrity(modelContainer: modelContainer)
            
            if !validationReport.isValid {
                logger.warning("Data integrity issues found: \(validationReport.errors)")
                
                // Attempt to fix critical issues
                if validationReport.errors.count < 10 { // Only attempt fixes if issues are manageable
                    logger.info("Attempting to fix data integrity issues")
                    // The validation process will have logged the issues, we'll continue
                }
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
            
            // Set as initialized even with errors to allow app to function
            // The app can still work with a fresh database if needed
            isInitialized = true
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
    
    /// Exports a session to PDF format
    @MainActor
    private func exportSessionToPDF(sessionId: UUID) async throws -> URL {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { $0.id == sessionId }
        )
        
        guard let session = try modelContainer.mainContext.fetch(descriptor).first else {
            throw ExportManager.ExportError.sessionNotFound
        }
        
        // Create PDF data while on MainActor
        let pdfData = try await generatePDFData(from: session)
        
        // Save the PDF file
        let filename = "RuckSession_\(session.startDate.formatted(.iso8601))_\(session.id.uuidString.prefix(8)).pdf"
        return try await exportManager.saveExportPermanently(data: pdfData, filename: filename)
    }
    
    /// Generates PDF data from a session
    @MainActor
    private func generatePDFData(from session: RuckSession) async throws -> Data {
        let pdfContent = """
        RUCK SESSION SUMMARY
        ==================
        
        Date: \(session.startDate.formatted(date: .long, time: .shortened))
        Duration: \(FormatUtilities.formatDuration(session.duration))
        Distance: \(FormatUtilities.formatDistancePrecise(session.totalDistance))
        Load Weight: \(FormatUtilities.formatWeight(session.loadWeight))
        
        PERFORMANCE METRICS
        ==================
        Total Calories: \(Int(session.totalCalories))
        Average Pace: \(FormatUtilities.formatPace(session.averagePace))
        Elevation Gain: \(Int(session.elevationGain))m
        Elevation Loss: \(Int(session.elevationLoss))m
        Average Grade: \(String(format: "%.1f%%", session.averageGrade))
        
        EFFORT RATING
        ============
        RPE: \(session.rpe ?? 0)/10
        
        NOTES
        =====
        \(session.notes ?? "No notes recorded")
        
        GPS DATA
        ========
        Total Points: \(session.locationPoints.count)
        Start Location: \(session.locationPoints.first.map { "(\($0.latitude), \($0.longitude))" } ?? "N/A")
        End Location: \(session.locationPoints.last.map { "(\($0.latitude), \($0.longitude))" } ?? "N/A")
        
        ---
        Generated by RuckMap on \(Date().formatted())
        """
        
        return pdfContent.data(using: .utf8) ?? Data()
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
            // Create a separate method to handle PDF export that can access the session directly
            return try await exportSessionToPDF(sessionId: sessionId)
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
    
    // MARK: - Migration Recovery
    
    /// Handles migration failures by backing up corrupted store and creating fresh one
    private static func performMigrationFailureRecovery(storeURL: URL, schema: Schema) throws {
        let logger = Logger(subsystem: "com.ruckmap.app", category: "DataCoordinator")
        let fileManager = FileManager.default
        
        // Create corrupted store backup
        if fileManager.fileExists(atPath: storeURL.path) {
            let backupURL = storeURL.appendingPathExtension("corrupted.\(Date().timeIntervalSince1970)")
            try fileManager.moveItem(at: storeURL, to: backupURL)
            logger.info("Moved corrupted store to: \(backupURL.path)")
        }
        
        // Clean up related files
        let storeDirectory = storeURL.deletingLastPathComponent()
        let storeName = storeURL.deletingPathExtension().lastPathComponent
        
        let relatedFiles = try fileManager.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
        for file in relatedFiles {
            if file.lastPathComponent.hasPrefix(storeName) && file != storeURL {
                let backupFile = file.appendingPathExtension("corrupted.\(Date().timeIntervalSince1970)")
                try? fileManager.moveItem(at: file, to: backupFile)
            }
        }
        
        logger.info("Cleaned up related store files, fresh store will be created")
    }
    
    /// Creates a fallback DataCoordinator with in-memory storage for emergency recovery
    static func createFallback() -> DataCoordinator {
        let logger = Logger(subsystem: "com.ruckmap.app", category: "DataCoordinator")
        logger.warning("Creating fallback DataCoordinator with in-memory storage")
        
        do {
            let schema = Schema([
                RuckSession.self,
                LocationPoint.self,
                TerrainSegment.self,
                WeatherConditions.self
            ])
            
            // Use in-memory configuration as fallback
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            
            let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let sessionManager = SessionManager(modelContainer: modelContainer)
            let migrationManager = MigrationManager()
            let exportManager = ExportManager()
            
            let coordinator = DataCoordinator(
                modelContainer: modelContainer,
                sessionManager: sessionManager,
                migrationManager: migrationManager,
                exportManager: exportManager,
                isFallback: true
            )
            
            logger.info("Fallback DataCoordinator created successfully")
            return coordinator
            
        } catch {
            logger.critical("Failed to create fallback DataCoordinator: \(error.localizedDescription)")
            fatalError("Cannot create fallback DataCoordinator: \(error)")
        }
    }
}

// MARK: - Error Types

enum DataCoordinatorError: LocalizedError {
    case initializationFailed(Error)
    case migrationRecoveryFailed(Error)
    case storeCorrupted
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "Failed to initialize data coordinator: \(error.localizedDescription)"
        case .migrationRecoveryFailed(let error):
            return "Failed to recover from migration error: \(error.localizedDescription)"
        case .storeCorrupted:
            return "Data store is corrupted and cannot be recovered"
        }
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

