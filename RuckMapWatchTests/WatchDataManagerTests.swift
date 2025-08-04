import Testing
import SwiftData
import Foundation
import CoreLocation
@testable import RuckMapWatch

/// Comprehensive tests for WatchDataManager using Swift Testing framework
@Suite("Watch Data Manager Tests")
struct WatchDataManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test("WatchDataManager initialization")
    func watchDataManagerInitialization() throws {
        let dataManager = try WatchDataManager()
        
        #expect(dataManager.currentSession == nil)
        #expect(dataManager.recentSessions.isEmpty)
    }
    
    // MARK: - Session Management Tests
    
    @Test("Create new session with default load weight")
    func createSessionWithDefaultLoadWeight() throws {
        let dataManager = try WatchDataManager()
        
        let session = try dataManager.createSession()
        
        #expect(dataManager.currentSession != nil)
        #expect(dataManager.currentSession?.id == session.id)
        #expect(session.loadWeight == 0.0)
        #expect(session.isActive == true)
        #expect(session.locationPoints.isEmpty)
    }
    
    @Test("Create new session with custom load weight", arguments: [10.0, 25.5, 50.0])
    func createSessionWithCustomLoadWeight(loadWeight: Double) throws {
        let dataManager = try WatchDataManager()
        
        let session = try dataManager.createSession(loadWeight: loadWeight)
        
        #expect(session.loadWeight == loadWeight)
        #expect(dataManager.currentSession?.loadWeight == loadWeight)
    }
    
    @Test("Complete current session")
    func completeCurrentSession() throws {
        let dataManager = try WatchDataManager()
        let session = try dataManager.createSession(loadWeight: 20.0)
        
        // Verify session is active
        #expect(session.isActive == true)
        #expect(dataManager.currentSession != nil)
        
        // Complete the session
        try dataManager.completeCurrentSession()
        
        // Verify session is completed and no longer current
        #expect(session.isActive == false)
        #expect(session.endDate != nil)
        #expect(dataManager.currentSession == nil)
    }
    
    @Test("Complete session without active session throws error")
    func completeSessionWithoutActiveSessionThrowsError() throws {
        let dataManager = try WatchDataManager()
        
        #expect(throws: WatchDataError.noActiveSession) {
            try dataManager.completeCurrentSession()
        }
    }
    
    @Test("Pause and resume current session")
    func pauseAndResumeCurrentSession() throws {
        let dataManager = try WatchDataManager()
        let session = try dataManager.createSession(loadWeight: 15.0)
        
        // Initially not paused
        #expect(session.isPaused == false)
        
        // Pause session
        try dataManager.pauseCurrentSession()
        #expect(session.isPaused == true)
        
        // Resume session
        try dataManager.resumeCurrentSession()
        #expect(session.isPaused == false)
    }
    
    @Test("Pause session without active session throws error")
    func pauseSessionWithoutActiveSessionThrowsError() throws {
        let dataManager = try WatchDataManager()
        
        #expect(throws: WatchDataError.noActiveSession) {
            try dataManager.pauseCurrentSession()
        }
    }
    
    @Test("Resume session without active session throws error")
    func resumeSessionWithoutActiveSessionThrowsError() throws {
        let dataManager = try WatchDataManager()
        
        #expect(throws: WatchDataError.noActiveSession) {
            try dataManager.resumeCurrentSession()
        }
    }
    
    // MARK: - Location Point Management Tests
    
    @Test("Add location point to active session")
    func addLocationPointToActiveSession() throws {
        let dataManager = try WatchDataManager()
        let session = try dataManager.createSession()
        
        let location = createTestLocation()
        try dataManager.addLocationPoint(from: location)
        
        #expect(session.locationPoints.count == 1)
        #expect(session.currentLatitude == location.coordinate.latitude)
        #expect(session.currentLongitude == location.coordinate.longitude)
        
        let addedPoint = session.locationPoints.first!
        #expect(addedPoint.latitude == location.coordinate.latitude)
        #expect(addedPoint.longitude == location.coordinate.longitude)
        #expect(addedPoint.altitude == location.altitude)
    }
    
    @Test("Add location point without active session throws error")
    func addLocationPointWithoutActiveSessionThrowsError() throws {
        let dataManager = try WatchDataManager()
        let location = createTestLocation()
        
        #expect(throws: WatchDataError.noActiveSession) {
            try dataManager.addLocationPoint(from: location)
        }
    }
    
    @Test("Add multiple location points and verify batch saving")
    func addMultipleLocationPointsAndVerifyBatchSaving() throws {
        let dataManager = try WatchDataManager()
        let session = try dataManager.createSession()
        
        // Add 15 location points (should trigger save at point 10)
        for i in 0..<15 {
            let location = createTestLocation(
                latitude: 37.7749 + Double(i) * 0.001,
                longitude: -122.4194 + Double(i) * 0.001
            )
            try dataManager.addLocationPoint(from: location)
        }
        
        #expect(session.locationPoints.count == 15)
        
        // Verify the last location updated the session's current location
        let lastLocation = session.locationPoints.last!
        #expect(session.currentLatitude == lastLocation.latitude)
        #expect(session.currentLongitude == lastLocation.longitude)
    }
    
    // MARK: - Session Retrieval Tests
    
    @Test("Get session by ID")
    func getSessionById() throws {
        let dataManager = try WatchDataManager()
        let session = try dataManager.createSession(loadWeight: 30.0)
        let sessionId = session.id
        
        // Complete session to ensure it's saved
        try dataManager.completeCurrentSession()
        
        // Retrieve session by ID
        let retrievedSession = dataManager.getSession(id: sessionId)
        
        #expect(retrievedSession != nil)
        #expect(retrievedSession?.id == sessionId)
        #expect(retrievedSession?.loadWeight == 30.0)
    }
    
    @Test("Get non-existent session returns nil")
    func getNonExistentSessionReturnsNil() throws {
        let dataManager = try WatchDataManager()
        let nonExistentId = UUID()
        
        let retrievedSession = dataManager.getSession(id: nonExistentId)
        #expect(retrievedSession == nil)
    }
    
    // MARK: - Recent Sessions Tests
    
    @Test("Recent sessions tracking")
    func recentSessionsTracking() throws {
        let dataManager = try WatchDataManager()
        
        // Create and complete multiple sessions
        for i in 0..<3 {
            let session = try dataManager.createSession(loadWeight: Double(i + 1) * 10.0)
            
            // Add some location points
            let location = createTestLocation(latitude: 37.7749 + Double(i) * 0.001)
            try dataManager.addLocationPoint(from: location)
            
            try dataManager.completeCurrentSession()
        }
        
        // Should have 3 recent sessions
        #expect(dataManager.recentSessions.count == 3)
        
        // Sessions should be ordered by start date (most recent first)
        let sessions = dataManager.recentSessions
        for i in 0..<sessions.count - 1 {
            #expect(sessions[i].startDate >= sessions[i + 1].startDate)
        }
    }
    
    @Test("Recent sessions limit to 5")
    func recentSessionsLimitToFive() throws {
        let dataManager = try WatchDataManager()
        
        // Create 7 sessions
        for i in 0..<7 {
            let session = try dataManager.createSession(loadWeight: Double(i + 1) * 5.0)
            try dataManager.completeCurrentSession()
        }
        
        // Should only keep 5 recent sessions in memory
        #expect(dataManager.recentSessions.count == 5)
    }
    
    // MARK: - Storage Statistics Tests
    
    @Test("Storage statistics calculation")
    func storageStatisticsCalculation() throws {
        let dataManager = try WatchDataManager()
        
        // Initially no sessions
        var stats = dataManager.getStorageStats()
        #expect(stats.sessionCount == 0)
        #expect(stats.locationPointCount == 0)
        #expect(stats.estimatedSizeKB == 0.0)
        
        // Create session with location points
        let session = try dataManager.createSession()
        
        // Add 10 location points
        for i in 0..<10 {
            let location = createTestLocation(latitude: 37.7749 + Double(i) * 0.0001)
            try dataManager.addLocationPoint(from: location)
        }
        
        try dataManager.completeCurrentSession()
        
        // Check updated stats
        stats = dataManager.getStorageStats()
        #expect(stats.sessionCount == 1)
        #expect(stats.locationPointCount == 10)
        #expect(stats.estimatedSizeKB == 5.0) // 10 points × 0.5KB each
        #expect(stats.estimatedSizeMB == 5.0 / 1024.0)
    }
    
    // MARK: - Data Integrity Tests
    
    @Test("Session modification date updates")
    func sessionModificationDateUpdates() throws {
        let dataManager = try WatchDataManager()
        let session = try dataManager.createSession()
        let initialModifiedAt = session.modifiedAt
        
        // Adding location point should update modification date
        let location = createTestLocation()
        try dataManager.addLocationPoint(from: location)
        
        #expect(session.modifiedAt > initialModifiedAt)
    }
    
    @Test("Session relationship integrity")
    func sessionRelationshipIntegrity() throws {
        let dataManager = try WatchDataManager()
        let session = try dataManager.createSession()
        
        // Add location points
        for i in 0..<3 {
            let location = createTestLocation(latitude: 37.7749 + Double(i) * 0.001)
            try dataManager.addLocationPoint(from: location)
        }
        
        // Verify all location points are associated with the session
        for point in session.locationPoints {
            #expect(point.session?.id == session.id)
        }
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Memory efficient location point storage")
    func memoryEfficientLocationPointStorage() throws {
        let dataManager = try WatchDataManager()
        let session = try dataManager.createSession()
        
        // Add many location points to test memory efficiency
        let numberOfPoints = 100
        
        for i in 0..<numberOfPoints {
            let location = createTestLocation(
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001
            )
            try dataManager.addLocationPoint(from: location)
        }
        
        #expect(session.locationPoints.count == numberOfPoints)
        
        // Verify session current location is updated to the last point
        let lastPoint = session.locationPoints.last!
        #expect(session.currentLatitude == lastPoint.latitude)
        #expect(session.currentLongitude == lastPoint.longitude)
    }
}

// MARK: - Mock Data and Test Helpers

extension WatchDataManagerTests {
    
    /// Create a test CLLocation for testing
    private func createTestLocation(
        latitude: Double = 37.7749,
        longitude: Double = -122.4194,
        altitude: Double = 100.0,
        accuracy: Double = 5.0,
        speed: Double = 2.0
    ) -> CLLocation {
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 3.0,
            course: 45.0,
            speed: speed,
            timestamp: Date()
        )
    }
    
    /// Create multiple test locations for route simulation
    private func createTestRoute(pointCount: Int = 10) -> [CLLocation] {
        var locations: [CLLocation] = []
        
        for i in 0..<pointCount {
            let location = createTestLocation(
                latitude: 37.7749 + Double(i) * 0.001,
                longitude: -122.4194 + Double(i) * 0.001,
                altitude: 100.0 + Double(i) * 2.0 // Gradual elevation gain
            )
            locations.append(location)
        }
        
        return locations
    }
}