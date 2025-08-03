import Testing
import SwiftData
@testable import RuckMap

@Suite("Export Manager Tests")
struct ExportManagerTests {
    let exportManager: ExportManager
    let testSession: RuckSession
    
    init() async throws {
        exportManager = ExportManager()
        testSession = try Self.createTestSession()
    }
    
    deinit {
        Task {
            try? await Self.cleanupTestFiles(exportManager: exportManager)
        }
    }
    
    // MARK: - GPX Export Tests
    
    @Test("GPX export creates valid file with correct content")
    func testGPXExport() async throws {
        let result = try await exportManager.exportToGPX(session: testSession)
        
        #expect(result.format == .gpx)
        #expect(result.fileSize > 0)
        #expect(result.pointCount == testSession.locationPoints.count)
        #expect(FileManager.default.fileExists(atPath: result.url.path))
        
        // Verify GPX content
        let gpxContent = try String(contentsOf: result.url)
        #expect(gpxContent.contains("<?xml version=\"1.0\""))
        #expect(gpxContent.contains("<gpx"))
        #expect(gpxContent.contains("<trk>"))
        #expect(gpxContent.contains("<trkpt"))
        #expect(gpxContent.contains("lat=\""))
        #expect(gpxContent.contains("lon=\""))
        #expect(gpxContent.contains("<ele>"))
        #expect(gpxContent.contains("<time>"))
    }
    
    @Test("GPX export includes elevation extensions when data is available")
    func testGPXExportWithElevationData() async throws {
        // Add elevation data to location points
        for point in testSession.locationPoints {
            point.updateElevationData(
                barometricAltitude: point.altitude + 2.0,
                fusedAltitude: point.altitude + 1.0,
                accuracy: 1.5,
                confidence: 0.8,
                grade: 2.5,
                pressure: 101.3
            )
        }
        
        let result = try await exportManager.exportToGPX(session: testSession)
        let gpxContent = try String(contentsOf: result.url)
        
        // Verify elevation extensions
        #expect(gpxContent.contains("<extensions>"))
        #expect(gpxContent.contains("<elevation_accuracy>"))
        #expect(gpxContent.contains("<elevation_confidence>"))
        #expect(gpxContent.contains("<grade>"))
    }
    
    @Test("GPX export throws error for empty session")
    func testGPXExportEmptySession() async throws {
        let emptySession = RuckSession()
        
        await #expect(throws: ExportManager.ExportError.noLocationData) {
            try await exportManager.exportToGPX(session: emptySession)
        }
    }
    
    // MARK: - CSV Export Tests
    
    @Test("CSV export creates valid file with proper structure")
    func testCSVExport() async throws {
        let result = try await exportManager.exportToCSV(session: testSession)
        
        #expect(result.format == .csv)
        #expect(result.fileSize > 0)
        #expect(result.pointCount == testSession.locationPoints.count)
        #expect(FileManager.default.fileExists(atPath: result.url.path))
        
        // Verify CSV content
        let csvContent = try String(contentsOf: result.url)
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        // Should have header + data rows
        #expect(lines.count == testSession.locationPoints.count + 1)
        
        // Verify header
        let header = lines[0]
        #expect(header.contains("timestamp"))
        #expect(header.contains("latitude"))
        #expect(header.contains("longitude"))
        #expect(header.contains("altitude"))
        #expect(header.contains("speed"))
        
        // Verify data rows
        for i in 1..<lines.count {
            let fields = lines[i].components(separatedBy: ",")
            #expect(fields.count >= 10) // Should have at least 10 fields
        }
    }
    
    @Test("CSV export includes all available data fields")
    func testCSVExportWithAllData() async throws {
        // Add comprehensive data to location points
        for (index, point) in testSession.locationPoints.enumerated() {
            point.heartRate = 140.0 + Double(index)
            point.instantaneousGrade = Double(index % 10) - 5.0
            point.elevationAccuracy = 1.5
            point.elevationConfidence = 0.8
            point.pressure = 101.3
            point.isKeyPoint = index % 5 == 0
        }
        
        let result = try await exportManager.exportToCSV(session: testSession)
        let csvContent = try String(contentsOf: result.url)
        
        // Verify all data is present
        #expect(csvContent.contains("140")) // Heart rate
        #expect(csvContent.contains("1.5")) // Elevation accuracy
        #expect(csvContent.contains("0.8")) // Elevation confidence
        #expect(csvContent.contains("101.3")) // Pressure
        #expect(csvContent.contains("true")) // Key point
    }
    
    // MARK: - JSON Export Tests
    
    @Test("JSON export creates valid file with complete data structure")
    func testJSONExport() async throws {
        let result = try await exportManager.exportToJSON(session: testSession)
        
        #expect(result.format == .json)
        #expect(result.fileSize > 0)
        #expect(result.pointCount == testSession.locationPoints.count)
        #expect(FileManager.default.fileExists(atPath: result.url.path))
        
        // Verify JSON content
        let jsonData = try Data(contentsOf: result.url)
        let exportedSession = try JSONDecoder().decode(ExportManager.ExportableSession.self, from: jsonData)
        
        #expect(exportedSession.id == testSession.id.uuidString)
        #expect(exportedSession.loadWeight == testSession.loadWeight)
        #expect(exportedSession.locationPoints.count == testSession.locationPoints.count)
        
        // Verify location point data
        let firstPoint = exportedSession.locationPoints[0]
        let originalPoint = testSession.locationPoints[0]
        #expect(firstPoint.latitude == originalPoint.latitude)
        #expect(firstPoint.longitude == originalPoint.longitude)
        #expect(firstPoint.altitude == originalPoint.altitude)
    }
    
    // MARK: - Batch Export Tests
    
    @Test("Batch export processes multiple sessions correctly")
    func testBatchExport() async throws {
        let session2 = try Self.createTestSession()
        let sessions = [testSession, session2]
        
        let results = try await exportManager.exportBatch(sessions: sessions, format: .gpx)
        
        #expect(results.count == 2)
        
        for result in results {
            #expect(result.format == .gpx)
            #expect(result.fileSize > 0)
            #expect(FileManager.default.fileExists(atPath: result.url.path))
        }
    }
    
    @Test("Batch export handles failures gracefully")
    func testBatchExportWithFailures() async throws {
        let emptySession = RuckSession() // This will fail export
        let sessions = [testSession, emptySession]
        
        let results = try await exportManager.exportBatch(sessions: sessions, format: .gpx)
        
        // Should succeed for valid session, skip invalid one
        #expect(results.count == 1)
        #expect(results[0].format == .gpx)
    }
    
    // MARK: - File Management Tests
    
    @Test("Exports directory is created and accessible")
    func testExportsDirectory() async throws {
        let exportsDir = try await exportManager.getExportsDirectory()
        
        #expect(FileManager.default.fileExists(atPath: exportsDir.path))
        #expect(exportsDir.path.contains("Exports"))
    }
    
    @Test("Save export permanently moves file correctly")
    func testSaveExportPermanently() async throws {
        let result = try await exportManager.exportToGPX(session: testSession)
        let tempURL = result.url
        let filename = "test_permanent_export.gpx"
        
        let permanentURL = try await exportManager.saveExportPermanently(
            temporaryURL: tempURL,
            filename: filename
        )
        
        #expect(FileManager.default.fileExists(atPath: permanentURL.path))
        #expect(!FileManager.default.fileExists(atPath: tempURL.path)) // Should be cleaned up
        #expect(permanentURL.path.contains("Exports"))
        #expect(permanentURL.lastPathComponent == filename)
    }
    
    @Test("Cleanup old exports removes files older than specified days")
    func testCleanupOldExports() async throws {
        let exportsDir = try await exportManager.getExportsDirectory()
        
        // Create some old test files
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let oldFile1 = exportsDir.appendingPathComponent("old_export_1.gpx")
        let oldFile2 = exportsDir.appendingPathComponent("old_export_2.csv")
        let recentFile = exportsDir.appendingPathComponent("recent_export.gpx")
        
        try "test".write(to: oldFile1, atomically: true, encoding: .utf8)
        try "test".write(to: oldFile2, atomically: true, encoding: .utf8)
        try "test".write(to: recentFile, atomically: true, encoding: .utf8)
        
        // Set old dates
        try FileManager.default.setAttributes(
            [.creationDate: oldDate],
            ofItemAtPath: oldFile1.path
        )
        try FileManager.default.setAttributes(
            [.creationDate: oldDate],
            ofItemAtPath: oldFile2.path
        )
        
        // Cleanup old exports (older than 7 days)
        try await exportManager.cleanupOldExports(olderThan: 7)
        
        // Old files should be deleted, recent file should remain
        #expect(!FileManager.default.fileExists(atPath: oldFile1.path))
        #expect(!FileManager.default.fileExists(atPath: oldFile2.path))
        #expect(FileManager.default.fileExists(atPath: recentFile.path))
        
        // Clean up test file
        try? FileManager.default.removeItem(at: recentFile)
    }
    
    // MARK: - Performance Tests
    
    @Test("Large session export completes within reasonable time", .timeLimit(.seconds(30)))
    func testLargeSessionExport() async throws {
        // Create session with many location points
        let largeSession = try Self.createLargeTestSession(pointCount: 5000)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await exportManager.exportToGPX(session: largeSession)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        #expect(result.pointCount == 5000)
        #expect(result.fileSize > 0)
        #expect(endTime - startTime < 30.0) // Should complete within 30 seconds
        
        print("Exported \(result.pointCount) points in \(String(format: "%.3f", endTime - startTime))s")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Export format validation is handled at compile time")
    func testExportFormatValidation() async throws {
        // This test verifies that the enum prevents invalid formats at compile time
        // We can test all valid formats work correctly
        let formats: [ExportManager.ExportFormat] = [.gpx, .csv, .json]
        
        for format in formats {
            switch format {
            case .gpx:
                let result = try await exportManager.exportToGPX(session: testSession)
                #expect(result.format == .gpx)
            case .csv:
                let result = try await exportManager.exportToCSV(session: testSession)
                #expect(result.format == .csv)
            case .json:
                let result = try await exportManager.exportToJSON(session: testSession)
                #expect(result.format == .json)
            }
        }
    }
    
    @Test("Export handles invalid coordinate data gracefully")
    func testExportWithCorruptedData() async throws {
        // Create session with invalid coordinate data
        let corruptedSession = RuckSession()
        let invalidPoint = LocationPoint(
            timestamp: Date(),
            latitude: 999.0, // Invalid latitude
            longitude: 999.0, // Invalid longitude
            altitude: 0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            speed: 0,
            course: 0
        )
        corruptedSession.locationPoints.append(invalidPoint)
        
        // Export should still work (data validation is separate concern)
        let result = try await exportManager.exportToGPX(session: corruptedSession)
        #expect(result.fileSize > 0)
    }
    
    // MARK: - Helper Methods
    
    static func createTestSession() throws -> RuckSession {
        let session = try RuckSession(loadWeight: 35.0)
        session.endDate = Date()
        session.totalDistance = 5000.0
        session.totalCalories = 750.0
        session.averagePace = 360.0
        
        // Add test location points
        for i in 0..<10 {
            let point = LocationPoint(
                timestamp: session.startDate.addingTimeInterval(Double(i * 30)),
                latitude: 40.7128 + Double(i) * 0.001,
                longitude: -74.0060 + Double(i) * 0.001,
                altitude: 10.0 + Double(i) * 2.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.5,
                course: Double(i * 10)
            )
            session.locationPoints.append(point)
        }
        
        return session
    }
    
    static func createLargeTestSession(pointCount: Int) throws -> RuckSession {
        let session = try RuckSession(loadWeight: 35.0)
        session.endDate = Date()
        session.totalDistance = Double(pointCount) * 10.0 // 10m between points
        
        // Add many location points
        for i in 0..<pointCount {
            let point = LocationPoint(
                timestamp: session.startDate.addingTimeInterval(Double(i * 5)),
                latitude: 40.7128 + Double(i) * 0.0001,
                longitude: -74.0060 + Double(i) * 0.0001,
                altitude: 10.0 + sin(Double(i) * 0.1) * 5.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.5,
                course: Double(i % 360)
            )
            session.locationPoints.append(point)
        }
        
        return session
    }
    
    static func cleanupTestFiles(exportManager: ExportManager) async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFiles = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil,
            options: []
        ).filter { url in
            let filename = url.lastPathComponent
            return filename.contains("RuckSession_") ||
                   filename.contains("test_")
        }
        
        for file in testFiles {
            try? FileManager.default.removeItem(at: file)
        }
        
        // Also cleanup exports directory
        do {
            let exportsDir = try await exportManager.getExportsDirectory()
            let exportFiles = try FileManager.default.contentsOfDirectory(
                at: exportsDir,
                includingPropertiesForKeys: nil,
                options: []
            )
            
            for file in exportFiles {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            // Ignore cleanup errors
        }
    }
}