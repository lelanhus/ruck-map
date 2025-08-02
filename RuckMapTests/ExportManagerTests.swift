import XCTest
import SwiftData
@testable import RuckMap

final class ExportManagerTests: XCTestCase {
    var exportManager: ExportManager!
    var testSession: RuckSession!
    
    override func setUp() async throws {
        try await super.setUp()
        exportManager = ExportManager()
        testSession = try createTestSession()
    }
    
    override func tearDown() async throws {
        exportManager = nil
        testSession = nil
        
        // Clean up any test files
        try await cleanupTestFiles()
        try await super.tearDown()
    }
    
    // MARK: - GPX Export Tests
    
    func testGPXExport() async throws {
        let result = try await exportManager.exportToGPX(session: testSession)
        
        XCTAssertEqual(result.format, .gpx)
        XCTAssertGreaterThan(result.fileSize, 0)
        XCTAssertEqual(result.pointCount, testSession.locationPoints.count)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        
        // Verify GPX content
        let gpxContent = try String(contentsOf: result.url)
        XCTAssertTrue(gpxContent.contains("<?xml version=\"1.0\""))
        XCTAssertTrue(gpxContent.contains("<gpx"))
        XCTAssertTrue(gpxContent.contains("<trk>"))
        XCTAssertTrue(gpxContent.contains("<trkpt"))
        XCTAssertTrue(gpxContent.contains("lat=\""))
        XCTAssertTrue(gpxContent.contains("lon=\""))
        XCTAssertTrue(gpxContent.contains("<ele>"))
        XCTAssertTrue(gpxContent.contains("<time>"))
    }
    
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
        XCTAssertTrue(gpxContent.contains("<extensions>"))
        XCTAssertTrue(gpxContent.contains("<elevation_accuracy>"))
        XCTAssertTrue(gpxContent.contains("<elevation_confidence>"))
        XCTAssertTrue(gpxContent.contains("<grade>"))
    }
    
    func testGPXExportEmptySession() async throws {
        let emptySession = RuckSession()
        
        do {
            _ = try await exportManager.exportToGPX(session: emptySession)
            XCTFail("Expected error for empty session")
        } catch ExportManager.ExportError.noLocationData {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - CSV Export Tests
    
    func testCSVExport() async throws {
        let result = try await exportManager.exportToCSV(session: testSession)
        
        XCTAssertEqual(result.format, .csv)
        XCTAssertGreaterThan(result.fileSize, 0)
        XCTAssertEqual(result.pointCount, testSession.locationPoints.count)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        
        // Verify CSV content
        let csvContent = try String(contentsOf: result.url)
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        // Should have header + data rows
        XCTAssertEqual(lines.count, testSession.locationPoints.count + 1)
        
        // Verify header
        let header = lines[0]
        XCTAssertTrue(header.contains("timestamp"))
        XCTAssertTrue(header.contains("latitude"))
        XCTAssertTrue(header.contains("longitude"))
        XCTAssertTrue(header.contains("altitude"))
        XCTAssertTrue(header.contains("speed"))
        
        // Verify data rows
        for i in 1..<lines.count {
            let fields = lines[i].components(separatedBy: ",")
            XCTAssertGreaterThanOrEqual(fields.count, 10) // Should have at least 10 fields
        }
    }
    
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
        XCTAssertTrue(csvContent.contains("140")) // Heart rate
        XCTAssertTrue(csvContent.contains("1.5")) // Elevation accuracy
        XCTAssertTrue(csvContent.contains("0.8")) // Elevation confidence
        XCTAssertTrue(csvContent.contains("101.3")) // Pressure
        XCTAssertTrue(csvContent.contains("true")) // Key point
    }
    
    // MARK: - JSON Export Tests
    
    func testJSONExport() async throws {
        let result = try await exportManager.exportToJSON(session: testSession)
        
        XCTAssertEqual(result.format, .json)
        XCTAssertGreaterThan(result.fileSize, 0)
        XCTAssertEqual(result.pointCount, testSession.locationPoints.count)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        
        // Verify JSON content
        let jsonData = try Data(contentsOf: result.url)
        let exportedSession = try JSONDecoder().decode(ExportManager.ExportableSession.self, from: jsonData)
        
        XCTAssertEqual(exportedSession.id, testSession.id.uuidString)
        XCTAssertEqual(exportedSession.loadWeight, testSession.loadWeight)
        XCTAssertEqual(exportedSession.locationPoints.count, testSession.locationPoints.count)
        
        // Verify location point data
        let firstPoint = exportedSession.locationPoints[0]
        let originalPoint = testSession.locationPoints[0]
        XCTAssertEqual(firstPoint.latitude, originalPoint.latitude)
        XCTAssertEqual(firstPoint.longitude, originalPoint.longitude)
        XCTAssertEqual(firstPoint.altitude, originalPoint.altitude)
    }
    
    // MARK: - Batch Export Tests
    
    func testBatchExport() async throws {
        let session2 = try createTestSession()
        let sessions = [testSession!, session2]
        
        let results = try await exportManager.exportBatch(sessions: sessions, format: .gpx)
        
        XCTAssertEqual(results.count, 2)
        
        for result in results {
            XCTAssertEqual(result.format, .gpx)
            XCTAssertGreaterThan(result.fileSize, 0)
            XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        }
    }
    
    func testBatchExportWithFailures() async throws {
        let emptySession = RuckSession() // This will fail export
        let sessions = [testSession!, emptySession]
        
        let results = try await exportManager.exportBatch(sessions: sessions, format: .gpx)
        
        // Should succeed for valid session, skip invalid one
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].format, .gpx)
    }
    
    // MARK: - File Management Tests
    
    func testExportsDirectory() async throws {
        let exportsDir = try await exportManager.getExportsDirectory()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportsDir.path))
        XCTAssertTrue(exportsDir.path.contains("Exports"))
    }
    
    func testSaveExportPermanently() async throws {
        let result = try await exportManager.exportToGPX(session: testSession)
        let tempURL = result.url
        let filename = "test_permanent_export.gpx"
        
        let permanentURL = try await exportManager.saveExportPermanently(
            temporaryURL: tempURL,
            filename: filename
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: permanentURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path)) // Should be cleaned up
        XCTAssertTrue(permanentURL.path.contains("Exports"))
        XCTAssertTrue(permanentURL.lastPathComponent == filename)
    }
    
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
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile1.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile2.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recentFile.path))
        
        // Clean up test file
        try? FileManager.default.removeItem(at: recentFile)
    }
    
    // MARK: - Performance Tests
    
    func testLargeSessionExport() async throws {
        // Create session with many location points
        let largeSession = try createLargeTestSession(pointCount: 5000)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await exportManager.exportToGPX(session: largeSession)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        XCTAssertEqual(result.pointCount, 5000)
        XCTAssertGreaterThan(result.fileSize, 0)
        XCTAssertLessThan(endTime - startTime, 30.0) // Should complete within 30 seconds
        
        print("Exported \(result.pointCount) points in \(String(format: "%.3f", endTime - startTime))s")
    }
    
    // MARK: - Error Handling Tests
    
    func testExportInvalidFormat() async throws {
        // This would be tested if we had invalid format scenarios
        // For now, the enum prevents invalid formats at compile time
    }
    
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
        XCTAssertGreaterThan(result.fileSize, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestSession() throws -> RuckSession {
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
    
    private func createLargeTestSession(pointCount: Int) throws -> RuckSession {
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
    
    private func cleanupTestFiles() async throws {
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