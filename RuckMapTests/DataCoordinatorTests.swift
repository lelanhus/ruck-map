import XCTest
import SwiftData
import CoreLocation
@testable import RuckMap

@MainActor
final class DataCoordinatorTests: XCTestCase {
    var dataCoordinator: DataCoordinator!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a test DataCoordinator with in-memory storage
        dataCoordinator = try createTestDataCoordinator()
        await dataCoordinator.initialize()
        
        // Wait for initialization
        while !dataCoordinator.isInitialized {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    override func tearDown() async throws {
        dataCoordinator = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() async throws {
        XCTAssertTrue(dataCoordinator.isInitialized)
        XCTAssertNil(dataCoordinator.initializationError)
        XCTAssertEqual(dataCoordinator.backgroundSyncStatus, .idle)
    }
    
    // MARK: - Session Management Tests
    
    func testCreateSession() async throws {
        let session = try await dataCoordinator.createSession(loadWeight: 35.0)
        
        XCTAssertEqual(session.loadWeight, 35.0)
        XCTAssertTrue(session.isActive)
        XCTAssertNotNil(session.id)
    }
    
    func testGetActiveSession() async throws {
        // No active session initially
        let noSession = try await dataCoordinator.getActiveSession()
        XCTAssertNil(noSession)
        
        // Create session
        let session = try await dataCoordinator.createSession(loadWeight: 35.0)
        
        // Should find active session
        let activeSession = try await dataCoordinator.getActiveSession()
        XCTAssertNotNil(activeSession)
        XCTAssertEqual(activeSession?.id, session.id)
    }
    
    func testCompleteSession() async throws {
        let session = try await dataCoordinator.createSession(loadWeight: 35.0)
        
        try await dataCoordinator.completeSession(
            session,
            totalDistance: 5000.0,
            totalCalories: 750.0,
            averagePace: 360.0
        )
        
        XCTAssertFalse(session.isActive)
        XCTAssertNotNil(session.endDate)
        XCTAssertEqual(session.totalDistance, 5000.0)
        XCTAssertEqual(session.totalCalories, 750.0)
        XCTAssertEqual(session.averagePace, 360.0)
    }
    
    func testGetAllSessions() async throws {
        // Empty initially
        let emptySessions = try await dataCoordinator.getAllSessions()
        XCTAssertTrue(emptySessions.isEmpty)
        
        // Create and complete sessions
        let session1 = try await dataCoordinator.createSession(loadWeight: 35.0)
        try await dataCoordinator.completeSession(session1, totalDistance: 1000, totalCalories: 500, averagePace: 300)
        
        let session2 = try await dataCoordinator.createSession(loadWeight: 25.0)
        
        let sessions = try await dataCoordinator.getAllSessions()
        XCTAssertEqual(sessions.count, 2)
    }
    
    func testDeleteSession() async throws {
        let session = try await dataCoordinator.createSession(loadWeight: 35.0)
        let sessionId = session.id
        
        // Verify session exists
        let fetchedSession = try await dataCoordinator.getSession(id: sessionId)
        XCTAssertNotNil(fetchedSession)
        
        // Delete session
        try await dataCoordinator.deleteSession(session)
        
        // Verify session no longer exists
        let deletedSession = try await dataCoordinator.getSession(id: sessionId)
        XCTAssertNil(deletedSession)
    }
    
    // MARK: - Location Tracking Tests
    
    func testAddLocationPoint() async throws {
        let session = try await dataCoordinator.createSession(loadWeight: 35.0)
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            altitude: 10.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            timestamp: Date()
        )
        
        try await dataCoordinator.addLocationPoint(to: session, from: location)
        
        XCTAssertEqual(session.locationPoints.count, 1)
        
        let point = session.locationPoints[0]
        XCTAssertEqual(point.latitude, location.coordinate.latitude)
        XCTAssertEqual(point.longitude, location.coordinate.longitude)
    }
    
    func testAddLocationPointsWithCompression() async throws {
        let session = try await dataCoordinator.createSession(loadWeight: 35.0)
        
        // Create many location points
        var points: [LocationPoint] = []
        for i in 0..<200 {
            let point = LocationPoint(
                timestamp: Date().addingTimeInterval(Double(i)),
                latitude: 40.7128 + Double(i) * 0.0001,
                longitude: -74.0060,
                altitude: 10.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.0,
                course: 0.0
            )
            points.append(point)
        }
        
        try await dataCoordinator.addLocationPoints(
            to: session,
            points: points,
            compress: true,
            compressionEpsilon: 5.0
        )
        
        // Should be compressed
        XCTAssertLessThan(session.locationPoints.count, 200)
        XCTAssertGreaterThan(session.locationPoints.count, 2) // Should keep more than just endpoints
    }
    
    // MARK: - Export Tests
    
    func testExportSessionToGPX() async throws {
        let session = try createTestSessionWithPoints()
        
        let url = try await dataCoordinator.exportSessionToGPX(session)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(url.pathExtension == "gpx")
        
        let content = try String(contentsOf: url)
        XCTAssertTrue(content.contains("<?xml"))
        XCTAssertTrue(content.contains("<gpx"))
    }
    
    func testExportSessionToCSV() async throws {
        let session = try createTestSessionWithPoints()
        
        let url = try await dataCoordinator.exportSessionToCSV(session)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(url.pathExtension == "csv")
        
        let content = try String(contentsOf: url)
        XCTAssertTrue(content.contains("timestamp"))
        XCTAssertTrue(content.contains("latitude"))
    }
    
    func testExportMultipleSessions() async throws {
        let session1 = try createTestSessionWithPoints()
        let session2 = try createTestSessionWithPoints()
        
        let urls = try await dataCoordinator.exportSessions(
            [session1, session2],
            format: .gpx
        )
        
        XCTAssertEqual(urls.count, 2)
        
        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertTrue(url.pathExtension == "gpx")
        }
    }
    
    // MARK: - Track Compression Tests
    
    func testCompressSessionTrack() async throws {
        let session = try createTestSessionWithManyPoints(count: 1000)
        let originalCount = session.locationPoints.count
        
        let result = try await dataCoordinator.compressSessionTrack(
            session,
            epsilon: 5.0,
            preserveElevationChanges: true
        )
        
        XCTAssertLessThan(result.compressedCount, originalCount)
        XCTAssertEqual(session.locationPoints.count, result.compressedCount)
        XCTAssertGreaterThan(result.compressionRatio, 0.0)
        XCTAssertLessThanOrEqual(result.compressionRatio, 1.0)
    }
    
    // MARK: - Data Validation Tests
    
    func testValidateSession() async throws {
        let session = try await dataCoordinator.createSession(loadWeight: 35.0)
        
        let errors = await dataCoordinator.validateSession(session)
        XCTAssertTrue(errors.isEmpty)
        
        // Test with invalid data
        session.loadWeight = -10.0 // Invalid weight
        session.startDate = Date().addingTimeInterval(3600) // Future date
        
        let errorsWithInvalidData = await dataCoordinator.validateSession(session)
        XCTAssertFalse(errorsWithInvalidData.isEmpty)
        XCTAssertTrue(errorsWithInvalidData.contains { $0.contains("weight") })
        XCTAssertTrue(errorsWithInvalidData.contains { $0.contains("future") })
    }
    
    func testPerformDataValidation() async throws {
        // Create some test data
        _ = try await dataCoordinator.createSession(loadWeight: 35.0)
        
        let report = try await dataCoordinator.performDataValidation()
        
        XCTAssertGreaterThanOrEqual(report.totalSessions, 1)
        XCTAssertTrue(report.isValid)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() async throws {
        // Create session
        let session = try await dataCoordinator.createSession(loadWeight: 35.0)
        
        // Add location points
        for i in 0..<50 {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: 40.7128 + Double(i) * 0.001,
                    longitude: -74.0060 + Double(i) * 0.001
                ),
                altitude: 10.0 + Double(i) * 0.5,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                timestamp: Date().addingTimeInterval(Double(i * 30))
            )
            try await dataCoordinator.addLocationPoint(to: session, from: location)
        }
        
        XCTAssertEqual(session.locationPoints.count, 50)
        
        // Complete session
        try await dataCoordinator.completeSession(
            session,
            totalDistance: 2500.0,
            totalCalories: 400.0,
            averagePace: 300.0
        )
        
        XCTAssertFalse(session.isActive)
        
        // Compress track
        let compressionResult = try await dataCoordinator.compressSessionTrack(session)
        XCTAssertLessThan(compressionResult.compressedCount, 50)
        
        // Export session
        let gpxURL = try await dataCoordinator.exportSessionToGPX(session)
        XCTAssertTrue(FileManager.default.fileExists(atPath: gpxURL.path))
        
        // Validate
        let errors = await dataCoordinator.validateSession(session)
        XCTAssertTrue(errors.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetPerformance() async throws {
        let session = try createTestSessionWithManyPoints(count: 5000)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform various operations
        let compressionResult = try await dataCoordinator.compressSessionTrack(session)
        _ = try await dataCoordinator.exportSessionToGPX(session)
        let errors = await dataCoordinator.validateSession(session)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        XCTAssertLessThan(endTime - startTime, 60.0) // Should complete within 1 minute
        XCTAssertLessThan(compressionResult.compressedCount, 5000)
        XCTAssertTrue(errors.isEmpty)
        
        print("Processed \(session.locationPoints.count) points in \(String(format: "%.3f", endTime - startTime))s")
    }
    
    // MARK: - Helper Methods
    
    private func createTestDataCoordinator() throws -> DataCoordinator {
        // Create a custom DataCoordinator for testing
        return try DataCoordinator()
    }
    
    private func createTestSessionWithPoints() throws -> RuckSession {
        let session = try RuckSession(loadWeight: 35.0)
        session.endDate = Date()
        
        // Add some test location points
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
    
    private func createTestSessionWithManyPoints(count: Int) throws -> RuckSession {
        let session = try RuckSession(loadWeight: 35.0)
        
        // Add many location points with some variation
        for i in 0..<count {
            let point = LocationPoint(
                timestamp: session.startDate.addingTimeInterval(Double(i * 5)),
                latitude: 40.7128 + Double(i) * 0.0001 + sin(Double(i) * 0.01) * 0.001,
                longitude: -74.0060 + Double(i) * 0.0001 + cos(Double(i) * 0.01) * 0.001,
                altitude: 10.0 + sin(Double(i) * 0.1) * 5.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.5 + sin(Double(i) * 0.05) * 0.5,
                course: Double(i % 360)
            )
            session.locationPoints.append(point)
        }
        
        return session
    }
}