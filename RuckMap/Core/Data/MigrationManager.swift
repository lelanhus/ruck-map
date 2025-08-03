import Foundation
import SwiftData
import OSLog

/// Manages data migrations and schema versioning for RuckMap
actor MigrationManager {
    private let logger = Logger(subsystem: "com.ruckmap.app", category: "MigrationManager")
    private let userDefaults = UserDefaults.standard
    
    // Current schema version
    static let currentSchemaVersion = 1
    
    // Keys for UserDefaults
    private enum Keys {
        static let schemaVersion = "RuckMap.SchemaVersion"
        static let lastMigrationDate = "RuckMap.LastMigrationDate"
        static let migrationHistory = "RuckMap.MigrationHistory"
    }
    
    struct MigrationInfo {
        let fromVersion: Int
        let toVersion: Int
        let migrationDate: Date
        let duration: TimeInterval
        let recordsAffected: Int
        let success: Bool
    }
    
    /// Checks if migration is needed and performs it if required
    func checkAndPerformMigration(modelContainer: ModelContainer) async throws {
        let currentStoredVersion = getCurrentSchemaVersion()
        
        logger.info("Current stored schema version: \(currentStoredVersion)")
        logger.info("Target schema version: \(Self.currentSchemaVersion)")
        
        do {
            if currentStoredVersion < Self.currentSchemaVersion {
                logger.info("Migration needed from version \(currentStoredVersion) to \(Self.currentSchemaVersion)")
                try await performMigration(
                    from: currentStoredVersion,
                    to: Self.currentSchemaVersion,
                    modelContainer: modelContainer
                )
            } else {
                logger.info("No migration needed, performing data integrity check")
                // Even if no migration is needed, ensure data integrity
                let _ = try await fixMissingAttributeValues(modelContainer: modelContainer)
            }
        } catch {
            // Log the specific error details for debugging
            let errorString = error.localizedDescription
            logger.error("Migration check failed: \(errorString)")
            
            // Check if this is an attribute validation error
            if errorString.contains("missing attribute values") || 
               errorString.contains("mandatory destination attribute") {
                logger.warning("Detected attribute validation error, attempting to fix missing values")
                
                // Try to fix the issue before rethrowing
                do {
                    let fixedCount = try await fixMissingAttributeValues(modelContainer: modelContainer)
                    logger.info("Fixed \(fixedCount) records with missing attributes, retrying migration")
                    
                    // Retry migration after fixing attributes
                    if currentStoredVersion < Self.currentSchemaVersion {
                        try await performMigration(
                            from: currentStoredVersion,
                            to: Self.currentSchemaVersion,
                            modelContainer: modelContainer
                        )
                    }
                } catch {
                    logger.error("Failed to fix attribute validation issues: \(error.localizedDescription)")
                    throw MigrationError.attributeValidationFailed(errorString)
                }
            } else {
                throw error
            }
        }
    }
    
    /// Gets the current schema version from UserDefaults
    func getCurrentSchemaVersion() -> Int {
        let version = userDefaults.integer(forKey: Keys.schemaVersion)
        return version == 0 ? 1 : version // Default to version 1 for new installs
    }
    
    /// Sets the current schema version in UserDefaults
    private func setCurrentSchemaVersion(_ version: Int) {
        userDefaults.set(version, forKey: Keys.schemaVersion)
        userDefaults.set(Date(), forKey: Keys.lastMigrationDate)
    }
    
    /// Records migration history
    private func recordMigration(_ info: MigrationInfo) {
        var history = getMigrationHistory()
        history.append(info)
        
        // Keep only last 10 migrations
        if history.count > 10 {
            history = Array(history.suffix(10))
        }
        
        if let data = try? JSONEncoder().encode(history) {
            userDefaults.set(data, forKey: Keys.migrationHistory)
        }
    }
    
    /// Gets migration history
    func getMigrationHistory() -> [MigrationInfo] {
        guard let data = userDefaults.data(forKey: Keys.migrationHistory),
              let history = try? JSONDecoder().decode([MigrationInfo].self, from: data) else {
            return []
        }
        return history
    }
    
    // MARK: - Migration Execution
    
    /// Performs migration from one version to another
    private func performMigration(
        from fromVersion: Int,
        to toVersion: Int,
        modelContainer: ModelContainer
    ) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        var recordsAffected = 0
        var success = false
        
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let migrationInfo = MigrationInfo(
                fromVersion: fromVersion,
                toVersion: toVersion,
                migrationDate: Date(),
                duration: duration,
                recordsAffected: recordsAffected,
                success: success
            )
            recordMigration(migrationInfo)
        }
        
        do {
            logger.info("Starting migration from version \(fromVersion) to \(toVersion)")
            
            // Create a backup before migration
            try await createBackup(modelContainer: modelContainer)
            
            // Fix any missing attribute values before migration
            let fixedRecords = try await fixMissingAttributeValues(modelContainer: modelContainer)
            recordsAffected += fixedRecords
            
            // Perform version-specific migrations
            for version in (fromVersion + 1)...toVersion {
                logger.info("Migrating to version \(version)")
                
                let affected = try await performVersionMigration(
                    toVersion: version,
                    modelContainer: modelContainer
                )
                recordsAffected += affected
            }
            
            // Update schema version
            setCurrentSchemaVersion(toVersion)
            success = true
            
            let endTime = CFAbsoluteTimeGetCurrent()
            logger.info("""
                Migration completed successfully:
                - From version: \(fromVersion)
                - To version: \(toVersion)
                - Duration: \(String(format: "%.3f", endTime - startTime))s
                - Records affected: \(recordsAffected)
                """)
            
        } catch {
            logger.error("Migration failed: \(error.localizedDescription)")
            throw MigrationError.migrationFailed(fromVersion, toVersion, error)
        }
    }
    
    /// Performs migration for a specific version
    private func performVersionMigration(
        toVersion: Int,
        modelContainer: ModelContainer
    ) async throws -> Int {
        switch toVersion {
        case 1:
            // Initial version - no migration needed
            return 0
        case 2:
            // Example: Add new fields or modify existing data
            return try await migrateToVersion2(modelContainer: modelContainer)
        default:
            logger.warning("No migration implemented for version \(toVersion)")
            return 0
        }
    }
    
    // MARK: - Version-Specific Migrations
    
    /// Migration to version 2 (example)
    private func migrateToVersion2(modelContainer: ModelContainer) async throws -> Int {
        let context = ModelContext(modelContainer)
        var recordsAffected = 0
        
        // Example: Add compression status to existing sessions
        let sessionDescriptor = FetchDescriptor<RuckSession>()
        let sessions = try context.fetch(sessionDescriptor)
        
        for session in sessions {
            // Example migration logic
            if session.locationPoints.count > 1000 {
                // Mark for compression
                session.notes = (session.notes ?? "") + " [Needs compression]"
                recordsAffected += 1
            }
        }
        
        try context.save()
        return recordsAffected
    }
    
    // MARK: - Backup and Recovery
    
    /// Creates a backup before migration
    private func createBackup(modelContainer: ModelContainer) async throws {
        logger.info("Creating backup before migration")
        
        let backupURL = try getBackupURL()
        
        // Create backup directory if it doesn't exist
        let backupDirectory = backupURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: backupDirectory,
            withIntermediateDirectories: true
        )
        
        // Copy the current database file
        let storeURL = modelContainer.configurations.first?.url
        
        if let storeURL = storeURL {
            try FileManager.default.copyItem(at: storeURL, to: backupURL)
            logger.info("Backup created at: \(backupURL.path)")
        }
    }
    
    /// Gets backup file URL
    private func getBackupURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        
        let backupDirectory = documentsURL.appendingPathComponent("Backups")
        let timestamp = DateFormatter.backupFormatter.string(from: Date())
        
        return backupDirectory.appendingPathComponent("RuckMap_backup_\(timestamp).store")
    }
    
    /// Restores from backup if migration fails
    func restoreFromBackup(modelContainer: ModelContainer) async throws {
        logger.info("Attempting to restore from backup")
        
        let backupURL = try getLatestBackupURL()
        let storeURL = modelContainer.configurations.first?.url
        
        guard let storeURL = storeURL else {
            throw MigrationError.noStoreURL
        }
        
        // Remove current store
        try? FileManager.default.removeItem(at: storeURL)
        
        // Restore from backup
        try FileManager.default.copyItem(at: backupURL, to: storeURL)
        
        logger.info("Restored from backup: \(backupURL.path)")
    }
    
    /// Gets the latest backup file URL
    private func getLatestBackupURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        
        let backupDirectory = documentsURL.appendingPathComponent("Backups")
        
        let backupFiles = try FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: []
        )
        
        guard let latestBackup = backupFiles
            .filter({ $0.pathExtension == "store" })
            .sorted(by: { url1, url2 in
                let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate
                let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate
                return date1 ?? Date.distantPast > date2 ?? Date.distantPast
            })
            .first else {
            throw MigrationError.noBackupFound
        }
        
        return latestBackup
    }
    
    // MARK: - Attribute Value Fixes
    
    /// Fixes missing attribute values that could cause migration failures
    private func fixMissingAttributeValues(modelContainer: ModelContainer) async throws -> Int {
        let context = ModelContext(modelContainer)
        var recordsFixed = 0
        
        logger.info("Checking for missing attribute values")
        
        // Fix RuckSession records with missing values
        let sessionDescriptor = FetchDescriptor<RuckSession>()
        let sessions = try context.fetch(sessionDescriptor)
        
        for session in sessions {
            var needsSave = false
            
            // Ensure elevation values have defaults
            if session.maxElevation.isNaN || session.maxElevation.isInfinite {
                session.maxElevation = 0.0
                needsSave = true
            }
            
            if session.minElevation.isNaN || session.minElevation.isInfinite {
                session.minElevation = 0.0
                needsSave = true
            }
            
            // Ensure other numeric values have defaults
            if session.totalDistance.isNaN || session.totalDistance.isInfinite {
                session.totalDistance = 0.0
                needsSave = true
            }
            
            if session.elevationGain.isNaN || session.elevationGain.isInfinite {
                session.elevationGain = 0.0
                needsSave = true
            }
            
            if session.elevationLoss.isNaN || session.elevationLoss.isInfinite {
                session.elevationLoss = 0.0
                needsSave = true
            }
            
            if session.totalCalories.isNaN || session.totalCalories.isInfinite {
                session.totalCalories = 0.0
                needsSave = true
            }
            
            if session.averagePace.isNaN || session.averagePace.isInfinite {
                session.averagePace = 0.0
                needsSave = true
            }
            
            if session.loadWeight.isNaN || session.loadWeight.isInfinite {
                session.loadWeight = 0.0
                needsSave = true
            }
            
            // Ensure string values have defaults
            if session.syncStatus.isEmpty {
                session.syncStatus = "pending"
                needsSave = true
            }
            
            // Ensure version is valid
            if session.version <= 0 {
                session.version = 1
                needsSave = true
            }
            
            if needsSave {
                recordsFixed += 1
            }
        }
        
        // Fix LocationPoint records with missing values
        let pointDescriptor = FetchDescriptor<LocationPoint>()
        let points = try context.fetch(pointDescriptor)
        
        for point in points {
            var needsSave = false
            
            if point.latitude.isNaN || point.latitude.isInfinite || abs(point.latitude) > 90 {
                point.latitude = 0.0
                needsSave = true
            }
            
            if point.longitude.isNaN || point.longitude.isInfinite || abs(point.longitude) > 180 {
                point.longitude = 0.0
                needsSave = true
            }
            
            if point.altitude.isNaN || point.altitude.isInfinite {
                point.altitude = 0.0
                needsSave = true
            }
            
            if point.horizontalAccuracy.isNaN || point.horizontalAccuracy.isInfinite {
                point.horizontalAccuracy = 0.0
                needsSave = true
            }
            
            if point.verticalAccuracy.isNaN || point.verticalAccuracy.isInfinite {
                point.verticalAccuracy = 0.0
                needsSave = true
            }
            
            if point.speed.isNaN || point.speed.isInfinite || point.speed < 0 {
                point.speed = 0.0
                needsSave = true
            }
            
            if point.course.isNaN || point.course.isInfinite || point.course < 0 {
                point.course = 0.0
                needsSave = true
            }
            
            if needsSave {
                recordsFixed += 1
            }
        }
        
        // Save all changes if needed
        if recordsFixed > 0 {
            try context.save()
            logger.info("Fixed \(recordsFixed) records with missing or invalid attribute values")
        }
        
        return recordsFixed
    }
    
    // MARK: - Data Integrity Validation
    
    /// Validates data integrity after migration
    func validateDataIntegrity(modelContainer: ModelContainer) async throws -> ValidationReport {
        let context = ModelContext(modelContainer)
        var report = ValidationReport()
        
        // Validate sessions
        let sessionDescriptor = FetchDescriptor<RuckSession>()
        let sessions = try context.fetch(sessionDescriptor)
        
        report.totalSessions = sessions.count
        
        for session in sessions {
            // Check for valid data
            if session.startDate > Date() {
                report.errors.append("Session \(session.id) has future start date")
            }
            
            if let endDate = session.endDate, endDate < session.startDate {
                report.errors.append("Session \(session.id) has end date before start date")
            }
            
            if session.loadWeight < 0 || session.loadWeight > 200 {
                report.errors.append("Session \(session.id) has invalid weight: \(session.loadWeight)")
            }
            
            // Check location points
            report.totalLocationPoints += session.locationPoints.count
            
            for point in session.locationPoints {
                if abs(point.latitude) > 90 || abs(point.longitude) > 180 {
                    report.errors.append("Invalid coordinates in session \(session.id)")
                    break
                }
            }
        }
        
        report.isValid = report.errors.isEmpty
        
        logger.info("""
            Data integrity validation completed:
            - Sessions: \(report.totalSessions)
            - Location points: \(report.totalLocationPoints)
            - Errors: \(report.errors.count)
            - Valid: \(report.isValid)
            """)
        
        return report
    }
    
    // MARK: - Cleanup
    
    /// Cleans up old backup files
    func cleanupOldBackups(olderThan days: Int = 30) async throws {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        
        let backupDirectory = documentsURL.appendingPathComponent("Backups")
        
        guard FileManager.default.fileExists(atPath: backupDirectory.path) else {
            return
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let backupFiles = try FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: []
        )
        
        var deletedCount = 0
        
        for file in backupFiles {
            if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < cutoffDate {
                try FileManager.default.removeItem(at: file)
                deletedCount += 1
            }
        }
        
        logger.info("Cleaned up \(deletedCount) old backup files")
    }
}

// MARK: - Supporting Types

enum MigrationError: LocalizedError {
    case migrationFailed(Int, Int, Error)
    case noStoreURL
    case noBackupFound
    case invalidVersion(Int)
    case attributeValidationFailed(String)
    case dataCorrupted(String)
    
    var errorDescription: String? {
        switch self {
        case .migrationFailed(let from, let to, let error):
            return "Migration from version \(from) to \(to) failed: \(error.localizedDescription)"
        case .noStoreURL:
            return "Could not determine store URL for backup"
        case .noBackupFound:
            return "No backup file found for restoration"
        case .invalidVersion(let version):
            return "Invalid schema version: \(version)"
        case .attributeValidationFailed(let attribute):
            return "Attribute validation failed for: \(attribute). Missing mandatory values detected."
        case .dataCorrupted(let details):
            return "Data corruption detected: \(details)"
        }
    }
}

struct ValidationReport {
    var totalSessions = 0
    var totalLocationPoints = 0
    var errors: [String] = []
    var isValid = false
}

// Make MigrationInfo Codable for storage
extension MigrationManager.MigrationInfo: Codable {}

// Date formatter for backup files
private extension DateFormatter {
    static let backupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}