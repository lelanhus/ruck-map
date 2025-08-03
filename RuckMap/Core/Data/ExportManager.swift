import Foundation
import SwiftData
import CoreLocation
import OSLog
import PDFKit
import UIKit
import SwiftUI
import MapKit

/// Manages data export functionality for RuckMap sessions
actor ExportManager {
    private let logger = Logger(subsystem: "com.ruckmap.app", category: "ExportManager")
    
    enum ExportFormat: String, CaseIterable {
        case gpx
        case csv
        case json
        case pdf
    }
    
    enum ExportError: LocalizedError {
        case sessionNotFound
        case noLocationData
        case exportFailed(Error)
        case invalidFormat
        case pdfGenerationFailed
        case mapImageGenerationFailed
        
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
            case .pdfGenerationFailed:
                return "Failed to generate PDF report"
            case .mapImageGenerationFailed:
                return "Failed to generate map image"
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
    
    // MARK: - Public Export Methods (SessionExportData)
    
    /// Exports session data to GPX format
    func exportToGPX(sessionData: SessionExportData) async throws -> ExportResult {
        logger.info("Exporting session \(sessionData.id) to GPX")
        
        // Create simple GPX without location data for now
        let gpxContent = createSimpleGPX(from: sessionData)
        let fileName = "RuckMap_\(sessionData.id.uuidString)_\(Date().timeIntervalSince1970).gpx"
        let url = try await saveToFile(content: gpxContent, fileName: fileName)
        
        return ExportResult(
            url: url,
            format: .gpx,
            fileSize: Int64(gpxContent.data(using: .utf8)?.count ?? 0),
            pointCount: 0,
            duration: 0
        )
    }
    
    /// Exports session data to CSV format
    func exportToCSV(sessionData: SessionExportData) async throws -> ExportResult {
        logger.info("Exporting session \(sessionData.id) to CSV")
        
        let csvContent = createSimpleCSV(from: sessionData)
        let fileName = "RuckMap_\(sessionData.id.uuidString)_\(Date().timeIntervalSince1970).csv"
        let url = try await saveToFile(content: csvContent, fileName: fileName)
        
        return ExportResult(
            url: url,
            format: .csv,
            fileSize: Int64(csvContent.data(using: .utf8)?.count ?? 0),
            pointCount: 0,
            duration: 0
        )
    }
    
    /// Exports session data to JSON format
    func exportToJSON(sessionData: SessionExportData) async throws -> ExportResult {
        logger.info("Exporting session \(sessionData.id) to JSON")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(sessionData)
        let fileName = "RuckMap_\(sessionData.id.uuidString)_\(Date().timeIntervalSince1970).json"
        let url = try await saveToFile(data: data, fileName: fileName)
        
        return ExportResult(
            url: url,
            format: .json,
            fileSize: Int64(data.count),
            pointCount: 0,
            duration: 0
        )
    }
    
    // MARK: - Public Export Methods (Requested Interface)
    
    /// Exports session as GPX (GPS Exchange Format) for use with other mapping apps
    func exportAsGPX(session: RuckSession) async throws -> URL {
        let result = try await exportToGPX(session: session)
        return result.url
    }
    
    /// Exports session as CSV for spreadsheet analysis
    func exportAsCSV(session: RuckSession) async throws -> URL {
        let result = try await exportToCSV(session: session)
        return result.url
    }
    
    /// Exports session as JSON for full data export
    func exportAsJSON(session: RuckSession) async throws -> URL {
        let result = try await exportToJSON(session: session)
        return result.url
    }
    
    /// Exports session as PDF summary report
    func exportAsPDF(session: RuckSession) async throws -> URL {
        let result = try await exportToPDF(session: session)
        return result.url
    }
    
    /// Creates a share text for the session
    func createShareTextForSession(_ session: RuckSession) -> String {
        return createShareText(session: session)
    }
    
    // MARK: - Public Export Methods (Full Session)
    
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
    
    /// Exports a session to PDF format
    func exportToPDF(session: RuckSession) async throws -> ExportResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let pdfData = try await generatePDFData(session: session)
        let url = try await saveToFile(
            data: pdfData,
            filename: "RuckSession_\(session.startDate.formatted(.iso8601))_\(session.id.uuidString.prefix(8))",
            extension: "pdf"
        )
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        logger.info("PDF export completed: \(fileSize) bytes")
        
        return ExportResult(
            url: url,
            format: .pdf,
            fileSize: fileSize,
            pointCount: session.locationPoints.count,
            duration: duration
        )
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
        case .pdf:
            return try await exportToPDF(session: session)
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
        
        // Add waypoints for terrain changes
        if !session.terrainSegments.isEmpty {
            for (index, segment) in session.terrainSegments.enumerated() {
                // Find location point closest to segment start time
                if let startPoint = session.locationPoints.min(by: { abs($0.timestamp.timeIntervalSince(segment.startTime)) < abs($1.timestamp.timeIntervalSince(segment.startTime)) }) {
                    let waypointName = "Terrain_\(index + 1)_\(segment.terrainType.displayName)"
                    let timestamp = dateFormatter.string(from: segment.startTime)
                    
                    let waypoint = """
                    <wpt lat="\(startPoint.latitude)" lon="\(startPoint.longitude)">
                        <ele>\(startPoint.bestAltitude)</ele>
                        <time>\(timestamp)</time>
                        <name>\(waypointName)</name>
                        <desc>Terrain: \(segment.terrainType.displayName), Grade: \(String(format: "%.1f", segment.grade))%, Confidence: \(String(format: "%.1f", segment.confidence * 100))%</desc>
                        <sym>Flag</sym>
                        <extensions>
                            <terrain_type>\(segment.terrainType.rawValue)</terrain_type>
                            <grade>\(segment.grade)</grade>
                            <confidence>\(segment.confidence)</confidence>
                            <is_manual>\(segment.isManuallySet)</is_manual>
                        </extensions>
                    </wpt>
                    
                    """
                    
                    // Insert waypoint before closing gpx tag
                    gpx = gpx.replacingOccurrences(of: "</gpx>", with: waypoint + "</gpx>")
                }
            }
        }
        
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
        
        // Add summary statistics section
        csv += "\n# Summary Statistics\n"
        csv += "Metric,Value,Unit\n"
        csv += "Session ID,\(session.id.uuidString),\n"
        csv += "Start Date,\(dateFormatter.string(from: session.startDate)),\n"
        if let endDate = session.endDate {
            csv += "End Date,\(dateFormatter.string(from: endDate)),\n"
            csv += "Duration,\(String(format: "%.1f", endDate.timeIntervalSince(session.startDate))),seconds\n"
        }
        csv += "Total Distance,\(String(format: "%.3f", session.totalDistance)),meters\n"
        csv += "Total Distance,\(String(format: "%.3f", session.totalDistance / 1000)),kilometers\n"
        csv += "Load Weight,\(String(format: "%.1f", session.loadWeight)),kg\n"
        csv += "Total Calories,\(String(format: "%.0f", session.totalCalories)),kcal\n"
        csv += "Average Pace,\(String(format: "%.2f", session.averagePace)),min/km\n"
        csv += "Elevation Gain,\(String(format: "%.1f", session.elevationGain)),meters\n"
        csv += "Elevation Loss,\(String(format: "%.1f", session.elevationLoss)),meters\n"
        csv += "Max Elevation,\(String(format: "%.1f", session.maxElevation)),meters\n"
        csv += "Min Elevation,\(String(format: "%.1f", session.minElevation)),meters\n"
        csv += "Elevation Range,\(String(format: "%.1f", session.maxElevation - session.minElevation)),meters\n"
        csv += "Average Grade,\(String(format: "%.2f", session.averageGrade)),percent\n"
        csv += "Max Grade,\(String(format: "%.2f", session.maxGrade)),percent\n"
        csv += "Min Grade,\(String(format: "%.2f", session.minGrade)),percent\n"
        csv += "Location Points,\(session.locationPoints.count),count\n"
        csv += "Terrain Segments,\(session.terrainSegments.count),count\n"
        csv += "Elevation Accuracy,\(String(format: "%.2f", session.elevationAccuracy)),meters\n"
        csv += "Barometer Data Points,\(session.barometerDataPoints),count\n"
        csv += "High Quality Elevation,\(session.hasHighQualityElevationData),boolean\n"
        
        // Add weather data if available
        if let weather = session.weatherConditions {
            csv += "\n# Weather Conditions\n"
            csv += "Weather Metric,Value,Unit\n"
            csv += "Temperature,\(String(format: "%.1f", weather.temperature)),celsius\n"
            csv += "Temperature,\(String(format: "%.1f", weather.temperatureFahrenheit)),fahrenheit\n"
            csv += "Humidity,\(String(format: "%.1f", weather.humidity)),percent\n"
            csv += "Wind Speed,\(String(format: "%.1f", weather.windSpeed)),m/s\n"
            csv += "Wind Speed,\(String(format: "%.1f", weather.windSpeedMPH)),mph\n"
            csv += "Wind Direction,\(String(format: "%.0f", weather.windDirection)),degrees\n"
            csv += "Precipitation,\(String(format: "%.1f", weather.precipitation)),mm/hr\n"
            csv += "Pressure,\(String(format: "%.1f", weather.pressure)),hPa\n"
            csv += "Apparent Temperature,\(String(format: "%.1f", weather.apparentTemperature)),celsius\n"
            csv += "Weather Severity Score,\(String(format: "%.2f", weather.weatherSeverityScore)),\n"
            if let description = weather.weatherDescription {
                csv += "Weather Description,\(description),\n"
            }
        }
        
        // Add terrain segment details
        if !session.terrainSegments.isEmpty {
            csv += "\n# Terrain Segments\n"
            csv += "Segment,Start Time,End Time,Terrain Type,Grade,Confidence,Duration,Manual\n"
            for (index, segment) in session.terrainSegments.enumerated() {
                csv += "\(index + 1),\(dateFormatter.string(from: segment.startTime)),\(dateFormatter.string(from: segment.endTime)),\(segment.terrainType.displayName),\(String(format: "%.2f", segment.grade)),\(String(format: "%.3f", segment.confidence)),\(String(format: "%.1f", segment.duration)),\(segment.isManuallySet)\n"
            }
        }
        
        return csv.data(using: .utf8) ?? Data()
    }
    
    // MARK: - PDF Generation
    
    private func generatePDFData(session: RuckSession) async throws -> Data {
        // Simple PDF generation - in production would use PDFKit
        let pdfContent = """
        RUCK SESSION SUMMARY
        ==================
        
        Date: \(session.startDate.formatted(date: .long, time: .shortened))
        Duration: \(FormatUtilities.formatDuration(session.duration))
        Distance: \(FormatUtilities.formatDistance(session.distance))
        
        Performance Metrics:
        - Average Pace: \(formatPace(session.averagePace))
        - Calories Burned: \(Int(session.totalCalories)) kcal
        - Elevation Gain: \(formatElevation(session.elevationGain))
        - Load Weight: \(FormatUtilities.formatWeight(session.loadWeight))
        
        \(session.weatherConditions != nil ? "Weather: \(session.weatherConditions!.temperature)°C, \(session.weatherConditions!.humidity)% humidity" : "")
        
        Notes: \(session.notes ?? "No notes")
        RPE: \(session.rpe ?? 0)/10
        """
        
        return pdfContent.data(using: String.Encoding.utf8) ?? Data()
    }
    
    private func createShareText(session: RuckSession) -> String {
        let emoji = session.rpe ?? 0 >= 8 ? "💪" : "🎒"
        return "\(emoji) Just completed a \(FormatUtilities.formatDistance(session.distance)) ruck in \(FormatUtilities.formatDuration(session.duration))! Burned \(Int(session.totalCalories)) calories. #RuckMap #Rucking"
    }
    
    // MARK: - Formatting Helpers
    
    private func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d min/km", minutes, seconds)
    }
    
    private func formatElevation(_ elevation: Double) -> String {
        return String(format: "%.0f m", elevation)
    }
    
    // MARK: - JSON Generation
    
    private func generateJSONData(session: RuckSession) async throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let exportSession = EnhancedExportableSession(from: session)
        return try encoder.encode(exportSession)
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
    
    /// Saves to file from content string
    private func saveToFile(content: String, fileName: String) async throws -> URL {
        guard let data = content.data(using: .utf8) else {
            throw ExportError.exportFailed(NSError(domain: "ExportManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert content to data"]))
        }
        return try await saveToFile(data: data, fileName: fileName)
    }
    
    /// Saves to file from data
    private func saveToFile(data: Data, fileName: String) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: url)
            return url
        } catch {
            throw ExportError.exportFailed(error)
        }
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
    
    // MARK: - Simple Export Helpers
    
    private func createSimpleGPX(from data: SessionExportData) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="RuckMap">
            <metadata>
                <name>Ruck Session \(data.id)</name>
                <time>\(ISO8601DateFormatter().string(from: data.startDate))</time>
            </metadata>
            <trk>
                <name>Ruck Session</name>
                <desc>Distance: \(String(format: "%.2f", data.totalDistance / 1000)) km, Load: \(data.loadWeight) kg</desc>
                <extensions>
                    <calories>\(Int(data.totalCalories))</calories>
                    <avgPace>\(data.averagePace)</avgPace>
                    <elevationGain>\(data.elevationGain)</elevationGain>
                    <elevationLoss>\(data.elevationLoss)</elevationLoss>
                </extensions>
            </trk>
        </gpx>
        """
    }
    
    private func createSimpleCSV(from data: SessionExportData) -> String {
        var csv = "Session ID,Start Date,End Date,Distance (km),Load (kg),Calories,Avg Pace (min/km),Elevation Gain (m),Elevation Loss (m)\n"
        
        csv += "\"\(data.id)\","
        csv += "\"\(ISO8601DateFormatter().string(from: data.startDate))\","
        csv += "\"\(data.endDate.map { ISO8601DateFormatter().string(from: $0) } ?? "")\","
        csv += "\(String(format: "%.2f", data.totalDistance / 1000)),"
        csv += "\(data.loadWeight),"
        csv += "\(Int(data.totalCalories)),"
        csv += "\(String(format: "%.2f", data.averagePace)),"
        csv += "\(String(format: "%.1f", data.elevationGain)),"
        csv += "\(String(format: "%.1f", data.elevationLoss))"
        
        return csv
    }
    
    // MARK: - PDF Generation\n    \n    private func generatePDFData(session: RuckSession) async throws -> Data {\n        let pdfMetaData = [\n            kCGPDFContextCreator: \"RuckMap\",\n            kCGPDFContextAuthor: \"RuckMap Export\",\n            kCGPDFContextTitle: \"Ruck Session Report - \\(session.startDate.formatted(.dateTime))\"\n        ]\n        \n        let format = UIGraphicsPDFRendererFormat()\n        format.documentInfo = pdfMetaData as [String: Any]\n        \n        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // 8.5 x 11 inches\n        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)\n        \n        let pdfData = renderer.pdfData { context in\n            context.beginPage()\n            \n            // Draw PDF content\n            drawPDFContent(for: session, in: pageRect, context: context.cgContext)\n        }\n        \n        return pdfData\n    }\n    \n    @MainActor\n    private func drawPDFContent(for session: RuckSession, in pageRect: CGRect, context: CGContext) {\n        let margin: CGFloat = 50\n        let contentRect = pageRect.insetBy(dx: margin, dy: margin)\n        var currentY: CGFloat = contentRect.minY\n        \n        // Title\n        let titleFont = UIFont.boldSystemFont(ofSize: 24)\n        let title = \"Ruck Session Report\"\n        let titleRect = CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 40)\n        title.draw(in: titleRect, withAttributes: [.font: titleFont])\n        currentY += 50\n        \n        // Session overview\n        let headerFont = UIFont.boldSystemFont(ofSize: 16)\n        let bodyFont = UIFont.systemFont(ofSize: 12)\n        \n        let overview = generatePDFOverview(session: session)\n        let overviewRect = CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 200)\n        overview.draw(in: overviewRect, withAttributes: [.font: bodyFont])\n        currentY += 220\n        \n        // Route statistics\n        \"Route Statistics\".draw(in: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 20), withAttributes: [.font: headerFont])\n        currentY += 30\n        \n        let stats = generatePDFStatistics(session: session)\n        let statsRect = CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 150)\n        stats.draw(in: statsRect, withAttributes: [.font: bodyFont])\n        currentY += 170\n        \n        // Equipment and notes section\n        if let notes = session.notes, !notes.isEmpty {\n            \"Notes\".draw(in: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 20), withAttributes: [.font: headerFont])\n            currentY += 30\n            \n            let notesRect = CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 100)\n            notes.draw(in: notesRect, withAttributes: [.font: bodyFont])\n        }\n    }\n    \n    private func generatePDFOverview(session: RuckSession) -> String {\n        let formatter = DateFormatter()\n        formatter.dateStyle = .full\n        formatter.timeStyle = .short\n        \n        let duration = session.endDate?.timeIntervalSince(session.startDate) ?? 0\n        \n        return \"\"\"\n        Date: \\(formatter.string(from: session.startDate))\n        Duration: \\(formatDuration(duration))\n        Distance: \\(String(format: \"%.2f\", session.totalDistance / 1000)) km\n        Load Weight: \\(String(format: \"%.1f\", session.loadWeight)) kg\n        \n        Calories Burned: \\(Int(session.totalCalories))\n        Average Pace: \\(formatPaceMinPerKm(session.averagePace))\n        \n        Elevation Gain: \\(String(format: \"%.0f\", session.elevationGain)) m\n        Elevation Loss: \\(String(format: \"%.0f\", session.elevationLoss)) m\n        Max Elevation: \\(String(format: \"%.0f\", session.maxElevation)) m\n        Min Elevation: \\(String(format: \"%.0f\", session.minElevation)) m\n        \"\"\"\n    }\n    \n    private func generatePDFStatistics(session: RuckSession) -> String {\n        var stats = \"\"\"\n        Grade Analysis:\n        Average Grade: \\(String(format: \"%.2f\", session.averageGrade))%\n        Maximum Grade: \\(String(format: \"%.2f\", session.maxGrade))%\n        Minimum Grade: \\(String(format: \"%.2f\", session.minGrade))%\n        \n        Data Quality:\n        Location Points: \\(session.locationPoints.count)\n        Elevation Accuracy: \\(String(format: \"%.1f\", session.elevationAccuracy)) m\n        Barometer Data Points: \\(session.barometerDataPoints)\n        High Quality Data: \\(session.hasHighQualityElevationData ? \"Yes\" : \"No\")\n        \"\"\"\n        \n        if let weather = session.weatherConditions {\n            stats += \"\"\"\n            \n            \n            Weather Conditions:\n            Temperature: \\(String(format: \"%.1f\", weather.temperature))°C (\\(String(format: \"%.1f\", weather.temperatureFahrenheit))°F)\n            Humidity: \\(String(format: \"%.1f\", weather.humidity))%\n            Wind: \\(String(format: \"%.1f\", weather.windSpeed)) m/s (\\(String(format: \"%.1f\", weather.windSpeedMPH)) mph)\n            Pressure: \\(String(format: \"%.1f\", weather.pressure)) hPa\n            \"\"\"\n        }\n        \n        return stats\n    }\n    \n    // MARK: - Helper Functions\n    \n    private func calculateDistance(from: LocationPoint, to: LocationPoint) -> Double {\n        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)\n        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)\n        return fromLocation.distance(from: toLocation)\n    }\n    \n    private func createShareText(session: RuckSession) -> String {\n        let formatter = DateFormatter()\n        formatter.dateStyle = .medium\n        formatter.timeStyle = .short\n        \n        let distance = String(format: \"%.2f\", session.totalDistance / 1000)\n        let duration = session.endDate != nil ? formatDuration(session.endDate!.timeIntervalSince(session.startDate)) : \"In Progress\"\n        let weight = String(format: \"%.1f\", session.loadWeight)\n        \n        return \"\"\"\n        🎒 Ruck March Completed!\n        📅 \\(formatter.string(from: session.startDate))\n        📏 Distance: \\(distance) km\n        ⏱️ Duration: \\(duration)\n        🎒 Load: \\(weight) kg\n        🔥 Calories: \\(Int(session.totalCalories))\n        ⛰️ Elevation: +\\(String(format: \"%.0f\", session.elevationGain))m\n        \n        #RuckMarch #Fitness #Training\n        Tracked with RuckMap 📍\n        \"\"\"\n    }\n    \n    private func formatPaceMinPerKm(_ paceMinPerKm: Double) -> String {\n        guard paceMinPerKm > 0 else { return \"N/A\" }\n        \n        let minutes = Int(paceMinPerKm)\n        let seconds = Int((paceMinPerKm - Double(minutes)) * 60)\n        return String(format: \"%d:%02d /km\", minutes, seconds)\n    }\n    \n    // MARK: - Utilities
    
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

// MARK: - Enhanced JSON Export Models

/// Enhanced session model for complete JSON export including terrain and weather data
struct EnhancedExportableSession: Codable {
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
    let maxGrade: Double
    let minGrade: Double
    let elevationAccuracy: Double
    let barometerDataPoints: Int
    let hasHighQualityElevationData: Bool
    let rpe: Int?
    let notes: String?
    let voiceNoteURL: String?
    let createdAt: Date
    let modifiedAt: Date
    let version: Int
    let syncStatus: String
    
    // Enhanced data
    let locationPoints: [ExportableLocationPoint]
    let terrainSegments: [ExportableTerrainSegment]
    let weatherConditions: ExportableWeatherConditions?
    
    // Calculated metrics
    let netElevationChange: Double
    let totalElevationChange: Double
    let elevationRange: Double
    let isActive: Bool
    let duration: TimeInterval
    
    // Export metadata
    let exportTimestamp: Date
    let exportVersion: String
    let dataQualityScore: Double
    
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
        self.maxGrade = session.maxGrade
        self.minGrade = session.minGrade
        self.elevationAccuracy = session.elevationAccuracy
        self.barometerDataPoints = session.barometerDataPoints
        self.hasHighQualityElevationData = session.hasHighQualityElevationData
        self.rpe = session.rpe
        self.notes = session.notes
        self.voiceNoteURL = session.voiceNoteURL?.absoluteString
        self.createdAt = session.createdAt
        self.modifiedAt = session.modifiedAt
        self.version = session.version
        self.syncStatus = session.syncStatus
        
        // Enhanced data
        self.locationPoints = session.locationPoints.map(ExportableLocationPoint.init)
        self.terrainSegments = session.terrainSegments.map(ExportableTerrainSegment.init)
        self.weatherConditions = session.weatherConditions.map(ExportableWeatherConditions.init)
        
        // Calculated metrics
        self.netElevationChange = session.netElevationChange
        self.totalElevationChange = session.totalElevationChange
        self.elevationRange = session.elevationRange
        self.isActive = session.isActive
        self.duration = session.duration
        
        // Export metadata
        self.exportTimestamp = Date()
        self.exportVersion = "1.0"
        
        // Calculate data quality score
        var qualityScore = 0.0
        if session.hasHighQualityElevationData { qualityScore += 0.3 }
        if session.locationPoints.count > 100 { qualityScore += 0.2 }
        if session.elevationAccuracy <= 5.0 { qualityScore += 0.2 }
        if !session.terrainSegments.isEmpty { qualityScore += 0.15 }
        if session.weatherConditions != nil { qualityScore += 0.15 }
        self.dataQualityScore = min(qualityScore, 1.0)
    }
}

struct ExportableTerrainSegment: Codable {
    let startTime: Date
    let endTime: Date
    let terrainType: String
    let terrainTypeDisplayName: String
    let grade: Double
    let confidence: Double
    let isManuallySet: Bool
    let duration: TimeInterval
    let adjustedDifficulty: Double
    let terrainFactor: Double
    
    init(from segment: TerrainSegment) {
        self.startTime = segment.startTime
        self.endTime = segment.endTime
        self.terrainType = segment.terrainType.rawValue
        self.terrainTypeDisplayName = segment.terrainType.displayName
        self.grade = segment.grade
        self.confidence = segment.confidence
        self.isManuallySet = segment.isManuallySet
        self.duration = segment.duration
        self.adjustedDifficulty = segment.adjustedDifficulty
        self.terrainFactor = segment.terrainType.terrainFactor
    }
}

struct ExportableWeatherConditions: Codable {
    let timestamp: Date
    let temperature: Double
    let temperatureFahrenheit: Double
    let humidity: Double
    let windSpeed: Double
    let windSpeedMPH: Double
    let windDirection: Double
    let precipitation: Double
    let pressure: Double
    let weatherDescription: String?
    let conditionCode: String?
    let apparentTemperature: Double
    let isHarshConditions: Bool
    let temperatureAdjustmentFactor: Double
    let weatherSeverityScore: Double
    
    init(from weather: WeatherConditions) {
        self.timestamp = weather.timestamp
        self.temperature = weather.temperature
        self.temperatureFahrenheit = weather.temperatureFahrenheit
        self.humidity = weather.humidity
        self.windSpeed = weather.windSpeed
        self.windSpeedMPH = weather.windSpeedMPH
        self.windDirection = weather.windDirection
        self.precipitation = weather.precipitation
        self.pressure = weather.pressure
        self.weatherDescription = weather.weatherDescription
        self.conditionCode = weather.conditionCode
        self.apparentTemperature = weather.apparentTemperature
        self.isHarshConditions = weather.isHarshConditions
        self.temperatureAdjustmentFactor = weather.temperatureAdjustmentFactor
        self.weatherSeverityScore = weather.weatherSeverityScore
    }
}
