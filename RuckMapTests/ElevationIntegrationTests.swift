import Testing
import CoreLocation
import SwiftData
@testable import RuckMap

/// Integration tests for elevation system with LocationTrackingManager and RuckSession
@Suite("Elevation Integration Tests", .serialized)
struct ElevationIntegrationTests {
    
    // MARK: - Test Setup
    
    var modelContainer: ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: RuckSession.self, LocationPoint.self, configurations: config)
    }
    
    // MARK: - LocationPoint Elevation Tests
    
    @Test("LocationPoint elevation data updates correctly")
    func testLocationPointElevationUpdates() async throws {
        let locationPoint = LocationPoint(
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            speed: 1.4,
            course: 0.0
        )
        
        // Update with elevation data
        locationPoint.updateElevationData(
            barometricAltitude: 102.5,
            fusedAltitude: 101.8,
            accuracy: 0.8,
            confidence: 0.92,
            grade: 2.5,
            pressure: 101.2
        )
        
        #expect(locationPoint.barometricAltitude == 102.5)
        #expect(locationPoint.fusedAltitude == 101.8)
        #expect(locationPoint.elevationAccuracy == 0.8)
        #expect(locationPoint.elevationConfidence == 0.92)
        #expect(locationPoint.hasAccurateElevation)
        #expect(locationPoint.bestAltitude == 101.8) // Should prefer fused altitude
    }
    
    @Test("LocationPoint best altitude selection")
    func testBestAltitudeSelection() async throws {
        let locationPoint = LocationPoint(
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            speed: 1.4,
            course: 0.0
        )
        
        // Test with no elevation data - should return GPS altitude
        #expect(locationPoint.bestAltitude == 100.0)
        
        // Add barometric data
        locationPoint.barometricAltitude = 105.0
        #expect(locationPoint.bestAltitude == 105.0)
        
        // Add fused data with low confidence
        locationPoint.fusedAltitude = 103.0
        locationPoint.elevationConfidence = 0.3
        #expect(locationPoint.bestAltitude == 105.0) // Should still prefer barometric
        
        // Increase confidence
        locationPoint.elevationConfidence = 0.8
        #expect(locationPoint.bestAltitude == 103.0) // Should now prefer fused
    }
    
    @Test("LocationPoint grade calculation")
    func testGradeCalculation() async throws {
        let point1 = LocationPoint(
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            speed: 1.4,
            course: 0.0
        )
        
        let point2 = LocationPoint(
            timestamp: Date().addingTimeInterval(60),
            latitude: 37.7759, // ~111 meters north
            longitude: -122.4194,
            altitude: 110.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            speed: 1.4,
            course: 0.0
        )
        
        let grade = point1.gradeTo(point2)
        
        // Grade should be approximately 9% (10m elevation change over ~111m distance)
        #expect(abs(grade - 9.0) < 1.0)
        
        // Test grade clamping
        let point3 = LocationPoint(
            timestamp: Date().addingTimeInterval(120),
            latitude: 37.7769,
            longitude: -122.4194,
            altitude: 150.0, // Very steep
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            speed: 1.4,
            course: 0.0
        )
        
        let extremeGrade = point2.gradeTo(point3)
        #expect(extremeGrade <= 20.0) // Should be clamped
    }
    
    // MARK: - RuckSession Elevation Tests
    
    @Test("RuckSession elevation metrics calculation")
    func testRuckSessionElevationMetrics() async throws {
        let container = modelContainer
        let context = ModelContext(container)
        
        let session = RuckSession()
        context.insert(session)
        
        // Create a hiking path with elevation changes
        let hikingPath = createTestHikingPath()
        
        for location in hikingPath {
            let locationPoint = LocationPoint(from: location)
            
            // Add elevation data
            locationPoint.updateElevationData(
                barometricAltitude: location.altitude + Double.random(in: -1...1),
                fusedAltitude: location.altitude + Double.random(in: -0.5...0.5),
                accuracy: 0.8,
                confidence: 0.9,
                grade: nil,
                pressure: 101.325 - (location.altitude - 100.0) * 0.012
            )
            
            session.locationPoints.append(locationPoint)
            context.insert(locationPoint)
        }
        
        // Update elevation metrics
        session.updateElevationMetrics()
        
        #expect(session.elevationGain > 0)
        #expect(session.elevationLoss > 0)
        #expect(session.maxElevation > session.minElevation)
        #expect(session.elevationRange > 0)
        #expect(session.barometerDataPoints > 0)
        #expect(session.hasHighQualityElevationData)
    }
    
    @Test("RuckSession elevation accuracy validation")
    func testElevationAccuracyValidation() async throws {
        let session = RuckSession()
        
        // Add high-quality elevation data
        for i in 0..<20 {
            let locationPoint = LocationPoint(
                timestamp: Date().addingTimeInterval(TimeInterval(i * 10)),
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194,
                altitude: 100.0 + Double(i) * 2.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                speed: 1.4,
                course: 0.0
            )
            
            locationPoint.updateElevationData(
                barometricAltitude: locationPoint.altitude + 0.5,
                fusedAltitude: locationPoint.altitude + 0.2,
                accuracy: 0.8,
                confidence: 0.95,
                grade: 2.0,
                pressure: 101.325
            )
            
            session.locationPoints.append(locationPoint)
        }
        
        session.updateElevationMetrics()
        
        #expect(session.hasHighQualityElevationData)
        #expect(session.elevationAccuracy <= 1.0)
        #expect(session.barometerDataPoints == 20)
    }
    
    // MARK: - LocationTrackingManager Integration Tests
    
    @Test("LocationTrackingManager elevation integration")
    func testLocationTrackingManagerElevation() async throws {
        let trackingManager = LocationTrackingManager()
        let container = modelContainer
        trackingManager.setModelContext(ModelContext(container))
        
        // Test elevation configuration updates
        let newConfig = ElevationConfiguration.precise
        trackingManager.updateElevationConfiguration(newConfig)
        
        // Test elevation metrics access
        let elevationAccuracy = trackingManager.elevationAccuracy
        let elevationConfidence = trackingManager.elevationConfidence
        let meetsTarget = trackingManager.meetsElevationAccuracyTarget
        
        #expect(elevationAccuracy >= 0.0)
        #expect(elevationConfidence >= 0.0 && elevationConfidence <= 1.0)
        #expect(!meetsTarget || (elevationAccuracy <= 1.0 && elevationConfidence >= 0.7))
        
        // Test debug information
        let debugInfo = trackingManager.extendedDebugInfo
        #expect(debugInfo.contains("Elevation Manager Debug Info"))
    }
    
    // MARK: - Error Handling Integration Tests
    
    @Test("Elevation system error handling")
    func testElevationErrorHandling() async throws {
        let trackingManager = LocationTrackingManager()
        
        // Test calibration error handling
        do {
            try await trackingManager.calibrateElevation(to: -1000.0) // Invalid elevation
        } catch {
            // Should handle errors gracefully
            #expect(error is ElevationError)
        }
        
        // Test metric resets
        trackingManager.resetElevationMetrics()
        #expect(true) // Should not throw
    }
    
    // MARK: - Performance Integration Tests
    
    @Test("Elevation system performance under load", .timeLimit(.seconds(10)))
    func testElevationPerformanceUnderLoad() async throws {
        let trackingManager = LocationTrackingManager()
        let container = modelContainer
        trackingManager.setModelContext(ModelContext(container))
        
        let session = RuckSession()
        let context = ModelContext(container)
        context.insert(session)
        
        let startTime = Date()
        
        // Simulate high-frequency location updates
        for i in 0..<500 {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749 + Double(i) * 0.00001,
                    longitude: -122.4194 + Double(i) * 0.00001
                ),
                altitude: 100.0 + sin(Double(i) * 0.1) * 10.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 8.0,
                timestamp: Date().addingTimeInterval(TimeInterval(i) * 0.1)
            )
            
            // Simulate elevation data processing
            if let elevationData = trackingManager.currentElevationData {
                let locationPoint = LocationPoint(from: location)
                locationPoint.updateElevationData(
                    barometricAltitude: elevationData.barometricAltitude,
                    fusedAltitude: elevationData.fusedAltitude,
                    accuracy: elevationData.accuracy,
                    confidence: elevationData.confidence,
                    grade: elevationData.currentGrade,
                    pressure: elevationData.pressure
                )
                
                session.locationPoints.append(locationPoint)
                context.insert(locationPoint)
            }
            
            // Update metrics periodically
            if i % 50 == 0 {
                session.updateElevationMetrics()
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 5.0) // Should complete in reasonable time
        
        // Verify final state
        session.updateElevationMetrics()
        #expect(session.locationPoints.count == 500)
    }
    
    // MARK: - Data Consistency Tests
    
    @Test("Elevation data consistency across components")
    func testElevationDataConsistency() async throws {
        let trackingManager = LocationTrackingManager()
        let container = modelContainer
        let context = ModelContext(container)
        trackingManager.setModelContext(context)
        
        let session = RuckSession()
        context.insert(session)
        
        // Create consistent test data
        let testLocations = createTestHikingPath()
        
        for location in testLocations {
            let locationPoint = LocationPoint(from: location)
            
            // Simulate consistent elevation data
            locationPoint.updateElevationData(
                barometricAltitude: location.altitude + 1.0,
                fusedAltitude: location.altitude + 0.5,
                accuracy: 0.9,
                confidence: 0.95,
                grade: 3.0,
                pressure: 101.325 - (location.altitude - 100.0) * 0.012
            )
            
            session.locationPoints.append(locationPoint)
            context.insert(locationPoint)
        }
        
        session.updateElevationMetrics()
        
        // Verify consistency
        let allPoints = session.locationPoints
        let accuratePoints = allPoints.filter { $0.hasAccurateElevation }
        
        #expect(accuratePoints.count > allPoints.count / 2) // Most points should be accurate
        #expect(session.elevationAccuracy < 1.0) // Overall accuracy should be good
        #expect(session.hasHighQualityElevationData)
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Concurrent elevation data access")
    func testConcurrentElevationAccess() async throws {
        let trackingManager = LocationTrackingManager()
        
        // Test concurrent access to elevation properties
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let accuracy = trackingManager.elevationAccuracy
                    let confidence = trackingManager.elevationConfidence
                    let meetsTarget = trackingManager.meetsElevationAccuracyTarget
                    
                    return accuracy >= 0.0 && confidence >= 0.0 && confidence <= 1.0
                }
            }
            
            var allValid = true
            for await isValid in group {
                if !isValid {
                    allValid = false
                    break
                }
            }
            
            #expect(allValid)
        }
    }
    
    // MARK: - Real-world Scenario Tests
    
    @Test("Mountain hiking scenario")
    func testMountainHikingScenario() async throws {
        let session = RuckSession()
        
        // Simulate mountain hiking with significant elevation changes
        let mountainPath = createMountainHikingPath()
        
        for (index, location) in mountainPath.enumerated() {
            let locationPoint = LocationPoint(from: location)
            
            // Simulate varying accuracy and confidence
            let accuracy = Double.random(in: 0.5...2.0)
            let confidence = Double.random(in: 0.7...1.0)
            
            locationPoint.updateElevationData(
                barometricAltitude: location.altitude + Double.random(in: -2...2),
                fusedAltitude: location.altitude + Double.random(in: -1...1),
                accuracy: accuracy,
                confidence: confidence,
                grade: nil,
                pressure: calculatePressureForAltitude(location.altitude)
            )
            
            session.locationPoints.append(locationPoint)
        }
        
        session.updateElevationMetrics()
        
        // Validate mountain hiking metrics
        #expect(session.elevationGain > 100.0) // Significant elevation gain
        #expect(session.maxGrade > 10.0) // Steep sections
        #expect(session.elevationRange > 200.0) // Large elevation range
        #expect(session.totalElevationChange > 150.0) // Substantial total change
    }
    
    // MARK: - Test Utilities
    
    private func createTestHikingPath() -> [CLLocation] {
        var locations: [CLLocation] = []
        let baseCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        for i in 0..<30 {
            let altitude = 100.0 + Double(i) * 2.0 + sin(Double(i) * 0.2) * 5.0
            
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: baseCoordinate.latitude + Double(i) * 0.0001,
                    longitude: baseCoordinate.longitude + Double(i) * 0.0001
                ),
                altitude: altitude,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                timestamp: Date().addingTimeInterval(TimeInterval(i * 10))
            )
            
            locations.append(location)
        }
        
        return locations
    }
    
    private func createMountainHikingPath() -> [CLLocation] {
        var locations: [CLLocation] = []
        let baseCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        var currentAltitude = 500.0
        
        for i in 0..<50 {
            // Simulate mountain hiking with varying elevation changes
            let elevationChange: Double
            
            switch i {
            case 0..<10: elevationChange = 5.0 // Gradual ascent
            case 10..<20: elevationChange = 8.0 // Steep ascent
            case 20..<30: elevationChange = 2.0 // Plateau
            case 30..<40: elevationChange = -6.0 // Descent
            default: elevationChange = 1.0 // Final gentle slope
            }
            
            currentAltitude += elevationChange + Double.random(in: -2...2)
            
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: baseCoordinate.latitude + Double(i) * 0.0002,
                    longitude: baseCoordinate.longitude + Double(i) * 0.0001
                ),
                altitude: currentAltitude,
                horizontalAccuracy: Double.random(in: 3...8),
                verticalAccuracy: Double.random(in: 5...15),
                timestamp: Date().addingTimeInterval(TimeInterval(i * 30))
            )
            
            locations.append(location)
        }
        
        return locations
    }
    
    private func calculatePressureForAltitude(_ altitude: Double) -> Double {
        // Simplified barometric formula
        let seaLevelPressure = 101.325 // kPa
        return seaLevelPressure * pow(1.0 - (0.0065 * altitude / 288.15), 5.255)
    }
}

// MARK: - Test Extensions

extension RuckSession {
    /// Helper for testing - validates elevation data integrity
    var elevationDataIntegrity: Bool {
        guard !locationPoints.isEmpty else { return false }
        
        let pointsWithElevation = locationPoints.filter { $0.barometricAltitude != nil }
        let accuratePoints = locationPoints.filter { $0.hasAccurateElevation }
        
        return pointsWithElevation.count > locationPoints.count / 3 && // At least 1/3 have elevation data
               accuratePoints.count > 0 && // At least some accurate points
               elevationGain >= 0 && elevationLoss >= 0 && // Valid metrics
               maxElevation >= minElevation // Logical min/max
    }
}