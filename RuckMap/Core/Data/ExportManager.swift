import Foundation
import SwiftData
import CoreLocation
import OSLog

/// Manages data export functionality for RuckMap sessions
actor ExportManager {
    private let logger = Logger(subsystem: "com.ruckmap.app", category: "ExportManager")
    
    enum ExportFormat: String, CaseIterable {
        case gpx
        case csv
        case json
    }
    
    enum ExportError: LocalizedError {
        case sessionNotFound
        case noLocationData
        case exportFailed(Error)
        case invalidFormat
        
        var errorDescription: String? {
            switch self {
            case .sessionNotFound:
                return "Session not found"
            case .noLocationData:
                return "No location data to export"
            case .exportFailed(let error):
                return "Export failed: \(error.localizedDescription)"
            case .invalidFormat:
                return "Invalid export format"
            }
        }
    }
    
    struct ExportResult {
        let url: URL
        let format: ExportFormat
        let fileSize: Int64
        let pointCount: Int
        let duration: TimeInterval
    }
    
    // MARK: - Public Export Methods
    
    /// Exports a session to GPX format with elevation data
    func exportToGPX(session: RuckSession) async throws -> ExportResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard !session.locationPoints.isEmpty else {
            throw ExportError.noLocationData
        }
        
        let gpxData = await generateGPXData(session: session)
        let url = try await saveToFile(
            data: gpxData,
            filename: "RuckSession_\(session.startDate.formatted(.iso8601))_\(session.id.uuidString.prefix(8))",
            extension: "gpx"
        )
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        logger.info("GPX export completed: \(session.locationPoints.count) points, \(fileSize) bytes")
        
        return ExportResult(
            url: url,
            format: .gpx,
            fileSize: fileSize,
            pointCount: session.locationPoints.count,
            duration: duration
        )
    }
    
    /// Exports a session to CSV format with all metrics
    func exportToCSV(session: RuckSession) async throws -> ExportResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard !session.locationPoints.isEmpty else {
            throw ExportError.noLocationData
        }
        
        let csvData = await generateCSVData(session: session)
        let url = try await saveToFile(
            data: csvData,
            filename: "RuckSession_\(session.startDate.formatted(.iso8601))_\(session.id.uuidString.prefix(8))",
            extension: "csv"
        )
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        logger.info("CSV export completed: \(session.locationPoints.count) points, \(fileSize) bytes")
        
        return ExportResult(
            url: url,
            format: .csv,
            fileSize: fileSize,
            pointCount: session.locationPoints.count,
            duration: duration
        )
    }
    
    /// Exports a session to JSON format
    func exportToJSON(session: RuckSession) async throws -> ExportResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let jsonData = try await generateJSONData(session: session)
        let url = try await saveToFile(
            data: jsonData,
            filename: "RuckSession_\(session.startDate.formatted(.iso8601))_\(session.id.uuidString.prefix(8))",
            extension: "json"
        )
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        logger.info("JSON export completed: \(fileSize) bytes")
        
        return ExportResult(
            url: url,
            format: .json,
            fileSize: fileSize,
            pointCount: session.locationPoints.count,
            duration: duration
        )
    }
    
    /// Exports multiple sessions in a batch
    func exportBatch(sessions: [RuckSession], format: ExportFormat) async throws -> [ExportResult] {
        var results: [ExportResult] = []
        
        for session in sessions {
            do {
                let result = try await export(session: session, format: format)
                results.append(result)
            } catch {
                logger.error("Failed to export session \(session.id): \(error.localizedDescription)")
                // Continue with other sessions
            }
        }
        
        return results
    }
    
    /// General export method
    func export(session: RuckSession, format: ExportFormat) async throws -> ExportResult {
        switch format {
        case .gpx:
            return try await exportToGPX(session: session)
        case .csv:
            return try await exportToCSV(session: session)
        case .json:
            return try await exportToJSON(session: session)
        }
    }
    
    // MARK: - GPX Generation
    
    private func generateGPXData(session: RuckSession) async -> Data {
        let dateFormatter = ISO8601DateFormatter()
        let startDateString = dateFormatter.string(from: session.startDate)
        
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="RuckMap" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
            <metadata>
                <name>Ruck Session - \(startDateString)</name>
                <desc>RuckMap ruck march session</desc>
                <time>\(startDateString)</time>
                <keywords>ruck,march,fitness,elevation</keywords>
            </metadata>
            <trk>
                <name>Ruck March - \(String(format: "%.1f", session.loadWeight))kg</name>
                <desc>Distance: \(String(format: "%.2f", session.totalDistance/1000))km, Duration: \(formatDuration(session.duration)), Load: \(String(format: "%.1f", session.loadWeight))kg</desc>
                <trkseg>
        
        """
        
        // Add track points
        for point in session.locationPoints {
            let timestamp = dateFormatter.string(from: point.timestamp)
            let elevation = point.bestAltitude
            
            gpx += """
                    <trkpt lat="\(point.latitude)" lon="\(point.longitude)">
                        <ele>\(elevation)</ele>
                        <time>\(timestamp)</time>
            
            """
            
            // Add extensions for additional data
            if point.speed > 0 || point.heartRate != nil || point.instantaneousGrade != nil {
                gpx += "            <extensions>\n"
                
                if point.speed > 0 {
                    gpx += "                <speed>\(point.speed)</speed>\n"
                }
                
                if let heartRate = point.heartRate {
                    gpx += "                <heartrate>\(Int(heartRate))</heartrate>\n"
                }
                
                if let grade = point.instantaneousGrade {
                    gpx += "                <grade>\(grade)</grade>\n"
                }
                
                if let accuracy = point.elevationAccuracy {
                    gpx += "                <elevation_accuracy>\(accuracy)</elevation_accuracy>\n"
                }
                
                if let confidence = point.elevationConfidence {
                    gpx += "                <elevation_confidence>\(confidence)</elevation_confidence>\n"
                }
                
                gpx += "            </extensions>\n"
            }
            
            gpx += "        </trkpt>\n"
        }
        
        gpx += """
                </trkseg>
            </trk>
        </gpx>
        """
        
        return gpx.data(using: .utf8) ?? Data()
    }
    
    // MARK: - CSV Generation
    
    private func generateCSVData(session: RuckSession) async -> Data {
        var csv = "timestamp,latitude,longitude,altitude,best_altitude,horizontal_accuracy,vertical_accuracy,speed,course,heart_rate,grade,elevation_accuracy,elevation_confidence,pressure,is_key_point\n"
        
        let dateFormatter = ISO8601DateFormatter()
        
        for point in session.locationPoints {
            let timestamp = dateFormatter.string(from: point.timestamp)
            let heartRate = point.heartRate.map { String($0) } ?? ""
            let grade = point.instantaneousGrade.map { String($0) } ?? ""
            let elevationAccuracy = point.elevationAccuracy.map { String($0) } ?? ""
            let elevationConfidence = point.elevationConfidence.map { String($0) } ?? ""
            let pressure = point.pressure.map { String($0) } ?? ""
            
            csv += "\(timestamp),\(point.latitude),\(point.longitude),\(point.altitude),\(point.bestAltitude),\(point.horizontalAccuracy),\(point.verticalAccuracy),\(point.speed),\(point.course),\(heartRate),\(grade),\(elevationAccuracy),\(elevationConfidence),\(pressure),\(point.isKeyPoint)\n"
        }
        
        return csv.data(using: .utf8) ?? Data()
    }
    
    // MARK: - JSON Generation
    
    private func generateJSONData(session: RuckSession) async throws -> Data {
        let exportSession = ExportableSession(from: session)
        return try JSONEncoder().encode(exportSession)
    }
    
    // MARK: - File Management
    
    private func saveToFile(data: Data, filename: String, extension ext: String) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("\(filename).\(ext)")
        
        do {
            try data.write(to: url)
            return url
        } catch {
            throw ExportError.exportFailed(error)
        }
    }
    
    /// Gets the exports directory URL
    func getExportsDirectory() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        
        let exportsURL = documentsURL.appendingPathComponent("Exports")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: exportsURL.path) {
            try FileManager.default.createDirectory(
                at: exportsURL,
                withIntermediateDirectories: true
            )
        }
        
        return exportsURL
    }
    
    /// Saves export to permanent location
    func saveExportPermanently(temporaryURL: URL, filename: String) async throws -> URL {
        let exportsDir = try getExportsDirectory()
        let permanentURL = exportsDir.appendingPathComponent(filename)
        
        try FileManager.default.copyItem(at: temporaryURL, to: permanentURL)
        
        // Clean up temporary file
        try? FileManager.default.removeItem(at: temporaryURL)
        
        return permanentURL
    }
    
    /// Cleans up old export files
    func cleanupOldExports(olderThan days: Int = 7) async throws {
        let exportsDir = try getExportsDirectory()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let exportFiles = try FileManager.default.contentsOfDirectory(
            at: exportsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: []
        )
        
        var deletedCount = 0
        
        for file in exportFiles {
            if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < cutoffDate {
                try FileManager.default.removeItem(at: file)
                deletedCount += 1
            }
        }
        
        logger.info("Cleaned up \(deletedCount) old export files")
    }
    
    // MARK: - Utilities
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Exportable Models

/// Simplified session model for JSON export
struct ExportableSession: Codable {
    let id: String
    let startDate: Date
    let endDate: Date?
    let totalDistance: Double
    let totalDuration: TimeInterval
    let loadWeight: Double
    let totalCalories: Double
    let averagePace: Double
    let elevationGain: Double
    let elevationLoss: Double
    let maxElevation: Double
    let minElevation: Double
    let averageGrade: Double
    let notes: String?
    let locationPoints: [ExportableLocationPoint]
    
    init(from session: RuckSession) {
        self.id = session.id.uuidString
        self.startDate = session.startDate
        self.endDate = session.endDate
        self.totalDistance = session.totalDistance
        self.totalDuration = session.totalDuration
        self.loadWeight = session.loadWeight
        self.totalCalories = session.totalCalories
        self.averagePace = session.averagePace
        self.elevationGain = session.elevationGain
        self.elevationLoss = session.elevationLoss
        self.maxElevation = session.maxElevation
        self.minElevation = session.minElevation
        self.averageGrade = session.averageGrade
        self.notes = session.notes
        self.locationPoints = session.locationPoints.map(ExportableLocationPoint.init)
    }
}

struct ExportableLocationPoint: Codable {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let bestAltitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let speed: Double
    let course: Double
    let heartRate: Double?
    let instantaneousGrade: Double?
    let elevationAccuracy: Double?
    let elevationConfidence: Double?
    let isKeyPoint: Bool
    
    init(from point: LocationPoint) {
        self.timestamp = point.timestamp
        self.latitude = point.latitude
        self.longitude = point.longitude
        self.altitude = point.altitude
        self.bestAltitude = point.bestAltitude
        self.horizontalAccuracy = point.horizontalAccuracy
        self.verticalAccuracy = point.verticalAccuracy
        self.speed = point.speed
        self.course = point.course
        self.heartRate = point.heartRate
        self.instantaneousGrade = point.instantaneousGrade
        self.elevationAccuracy = point.elevationAccuracy
        self.elevationConfidence = point.elevationConfidence
        self.isKeyPoint = point.isKeyPoint
    }
}