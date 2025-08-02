import XCTest
import SwiftData
import CoreLocation
@testable import RuckMap

final class SessionManagerTests: XCTestCase {
    var container: ModelContainer!
    var sessionManager: SessionManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: RuckSession.self, LocationPoint.self, TerrainSegment.self, WeatherConditions.self,
            configurations: config
        )
        
        sessionManager = SessionManager(modelContainer: container)
    }
    
    override func tearDown() async throws {
        sessionManager = nil
        container = nil
        try await super.tearDown()
    }
    
    // MARK: - Session Creation Tests
    
    func testCreateSession() async throws {
        let loadWeight = 35.0
        let session = try await sessionManager.createSession(loadWeight: loadWeight)
        
        XCTAssertEqual(session.loadWeight, loadWeight)
        XCTAssertTrue(session.isActive)
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.totalDistance, 0)
    }
    
    func testCreateSessionWithInvalidWeight() async {
        do {
            _ = try await sessionManager.createSession(loadWeight: -5.0)
            XCTFail("Expected error for negative weight")
        } catch SessionError.invalidWeight(let weight) {
            XCTAssertEqual(weight, -5.0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        do {
            _ = try await sessionManager.createSession(loadWeight: 250.0)
            XCTFail("Expected error for excessive weight")
        } catch SessionError.invalidWeight(let weight) {
            XCTAssertEqual(weight, 250.0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCannotCreateMultipleActiveSessions() async throws {
        // Create first session
        _ = try await sessionManager.createSession(loadWeight: 35.0)
        
        // Attempt to create second session should fail
        do {
            _ = try await sessionManager.createSession(loadWeight: 25.0)
            XCTFail("Expected error for multiple active sessions")
        } catch SessionError.activeSessionExists {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Session Fetching Tests
    
    func testFetchActiveSession() async throws {
        // No active session initially
        let noSession = try await sessionManager.fetchActiveSession()
        XCTAssertNil(noSession)
        
        // Create session and fetch it
        let session = try await sessionManager.createSession(loadWeight: 35.0)
        let fetchedSession = try await sessionManager.fetchActiveSession()
        
        XCTAssertNotNil(fetchedSession)
        XCTAssertEqual(fetchedSession?.id, session.id)
    }
    
    func testFetchAllSessions() async throws {
        // Empty initially
        let emptySessions = try await sessionManager.fetchAllSessions()
        XCTAssertTrue(emptySessions.isEmpty)
        
        // Create sessions
        let session1 = try await sessionManager.createSession(loadWeight: 35.0)
        try await sessionManager.completeSession(
            session1,
            totalDistance: 1000,
            totalCalories: 500,
            averagePace: 300
        )
        
        let session2 = try await sessionManager.createSession(loadWeight: 25.0)
        
        let sessions = try await sessionManager.fetchAllSessions()
        XCTAssertEqual(sessions.count, 2)
        
        // Should be sorted by start date (newest first)
        XCTAssertEqual(sessions[0].id, session2.id)
        XCTAssertEqual(sessions[1].id, session1.id)
    }
    
    func testFetchSessionById() async throws {
        let session = try await sessionManager.createSession(loadWeight: 35.0)
        
        let fetchedSession = try await sessionManager.fetchSession(id: session.id)
        XCTAssertNotNil(fetchedSession)
        XCTAssertEqual(fetchedSession?.id, session.id)
        
        // Test with non-existent ID
        let nonExistentSession = try await sessionManager.fetchSession(id: UUID())
        XCTAssertNil(nonExistentSession)
    }
    
    // MARK: - Session Completion Tests
    
    func testCompleteSession() async throws {
        let session = try await sessionManager.createSession(loadWeight: 35.0)
        XCTAssertTrue(session.isActive)
        
        let totalDistance = 5000.0
        let totalCalories = 750.0
        let averagePace = 360.0
        
        try await sessionManager.completeSession(
            session,
            totalDistance: totalDistance,
            totalCalories: totalCalories,
            averagePace: averagePace
        )
        
        XCTAssertFalse(session.isActive)
        XCTAssertNotNil(session.endDate)
        XCTAssertEqual(session.totalDistance, totalDistance)
        XCTAssertEqual(session.totalCalories, totalCalories)
        XCTAssertEqual(session.averagePace, averagePace)
    }
    
    func testCannotCompleteAlreadyCompletedSession() async throws {
        let session = try await sessionManager.createSession(loadWeight: 35.0)
        
        // Complete once
        try await sessionManager.completeSession(
            session,
            totalDistance: 1000,
            totalCalories: 500,
            averagePace: 300
        )
        
        // Attempt to complete again should fail
        do {
            try await sessionManager.completeSession(
                session,
                totalDistance: 2000,
                totalCalories: 1000,
                averagePace: 400
            )
            XCTFail("Expected error for already completed session")
        } catch SessionError.sessionAlreadyCompleted {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Location Point Tests
    
    func testAddLocationPoint() async throws {
        let session = try await sessionManager.createSession(loadWeight: 35.0)
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            altitude: 10.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            timestamp: Date()
        )
        
        try await sessionManager.addLocationPoint(to: session, from: location)
        
        XCTAssertEqual(session.locationPoints.count, 1)
        
        let point = session.locationPoints[0]
        XCTAssertEqual(point.latitude, location.coordinate.latitude)
        XCTAssertEqual(point.longitude, location.coordinate.longitude)
        XCTAssertEqual(point.altitude, location.altitude)
        XCTAssertEqual(session.currentLatitude, location.coordinate.latitude)
        XCTAssertEqual(session.currentLongitude, location.coordinate.longitude)
    }
    
    func testAddMultipleLocationPoints() async throws {
        let session = try await sessionManager.createSession(loadWeight: 35.0)
        
        let points = [
            LocationPoint(
                timestamp: Date(),
                latitude: 40.7128,
                longitude: -74.0060,
                altitude: 10.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 0.0,
                course: 0.0
            ),
            LocationPoint(
                timestamp: Date().addingTimeInterval(10),
                latitude: 40.7130,
                longitude: -74.0062,
                altitude: 12.0,
                horizontalAccuracy: 4.0,
                verticalAccuracy: 2.0,
                speed: 1.5,
                course: 45.0
            )
        ]
        
        try await sessionManager.addLocationPoints(to: session, points: points)
        
        XCTAssertEqual(session.locationPoints.count, 2)
        XCTAssertEqual(session.currentLatitude, points[1].latitude)
        XCTAssertEqual(session.currentLongitude, points[1].longitude)
        XCTAssertEqual(session.currentElevation, points[1].bestAltitude)
    }
    
    // MARK: - Session Deletion Tests
    
    func testDeleteSession() async throws {
        let session = try await sessionManager.createSession(loadWeight: 35.0)
        let sessionId = session.id
        
        // Verify session exists
        let fetchedSession = try await sessionManager.fetchSession(id: sessionId)
        XCTAssertNotNil(fetchedSession)
        
        // Delete session
        try await sessionManager.deleteSession(session)
        
        // Verify session no longer exists
        let deletedSession = try await sessionManager.fetchSession(id: sessionId)
        XCTAssertNil(deletedSession)
    }
    
    // MARK: - Restore Functionality Tests
    
    func testRestoreIncompleteSession() async throws {
        // No incomplete session initially
        let noSession = try await sessionManager.restoreIncompleteSession()
        XCTAssertNil(noSession)
        
        // Create incomplete session
        let session = try await sessionManager.createSession(loadWeight: 35.0)
        
        // Restore should find it
        let restoredSession = try await sessionManager.restoreIncompleteSession()
        XCTAssertNotNil(restoredSession)
        XCTAssertEqual(restoredSession?.id, session.id)
        
        // Complete the session
        try await sessionManager.completeSession(
            session,
            totalDistance: 1000,
            totalCalories: 500,
            averagePace: 300
        )
        
        // Should no longer be restored
        let noIncompleteSession = try await sessionManager.restoreIncompleteSession()
        XCTAssertNil(noIncompleteSession)
    }
    
    // MARK: - Performance Tests
    
    func testLargeLocationPointBatch() async throws {
        let session = try await sessionManager.createSession(loadWeight: 35.0)
        
        // Create large batch of location points
        var points: [LocationPoint] = []
        for i in 0..<1000 {
            let point = LocationPoint(
                timestamp: Date().addingTimeInterval(Double(i)),
                latitude: 40.7128 + Double(i) * 0.0001,
                longitude: -74.0060 + Double(i) * 0.0001,
                altitude: 10.0 + Double(i) * 0.1,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.0,
                course: 0.0
            )
            points.append(point)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        try await sessionManager.addLocationPoints(to: session, points: points)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        XCTAssertEqual(session.locationPoints.count, 1000)
        XCTAssertLessThan(endTime - startTime, 5.0) // Should complete within 5 seconds
    }
}