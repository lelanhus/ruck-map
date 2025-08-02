import Testing
import Foundation
import CoreLocation
@testable import RuckMap

@Suite("Elevation and Grade Integration Tests")
struct ElevationGradeIntegrationTests {
    
    @Test("ElevationManager integrates with GradeCalculator")
    func testElevationManagerGradeIntegration() async throws {
        let elevationManager = ElevationManager(configuration: .precise)
        
        // Create location points for a realistic hiking scenario
        let baseTime = Date()
        let locations = createHikingTrail(startTime: baseTime)
        
        var gradeResults: [GradeCalculator.GradeResult] = []
        
        // Process each location point
        for i in 1..<locations.count {
            if let gradeResult = await elevationManager.processLocationPoint(locations[i]) {
                gradeResults.append(gradeResult)
            }
        }
        
        #expect(!gradeResults.isEmpty, "Should generate grade results")
        
        // Verify cumulative metrics are tracked
        let (totalGain, totalLoss) = await elevationManager.elevationMetrics
        #expect(totalGain > 0, "Should track total elevation gain")
        #expect(totalLoss > 0, "Should track total elevation loss")
        
        // Verify grade statistics
        let (instantaneous, smoothed) = await elevationManager.currentGradeMetrics
        #expect(abs(instantaneous) <= 25.0, "Grade should be within reasonable bounds")
        #expect(abs(smoothed) <= 25.0, "Smoothed grade should be within reasonable bounds")
        
        // Verify precision target is met for high-quality results
        let highQualityResults = gradeResults.filter { $0.confidence > 0.8 }
        let precisionTargetMet = highQualityResults.filter { $0.meetsPrecisionTarget }
        let precisionRate = Double(precisionTargetMet.count) / Double(highQualityResults.count)
        
        #expect(precisionRate > 0.7, "Should meet 0.5% precision target for most high-quality data")
    }
    
    @Test("RuckSession calculates enhanced grade statistics")
    func testRuckSessionGradeStatistics() async throws {
        let session = RuckSession()
        
        // Add location points to session
        let locations = createHikingTrail(startTime: Date())
        session.locationPoints = locations
        
        // Update elevation metrics
        await session.updateElevationMetrics()
        
        // Verify basic metrics are calculated
        #expect(session.elevationGain > 0, "Session should have elevation gain")
        #expect(session.elevationLoss > 0, "Session should have elevation loss")
        #expect(session.maxElevation > session.minElevation, "Should have elevation range")
        
        // Test enhanced grade statistics
        guard let stats = await session.calculateEnhancedGradeStatistics() else {
            Issue.record("Enhanced grade statistics calculation failed")
            return
        }
        
        #expect(abs(stats.averageGrade) <= 20.0, "Average grade should be reasonable")
        #expect(stats.maxGrade >= stats.averageGrade, "Max grade should be >= average")
        #expect(stats.minGrade <= stats.averageGrade, "Min grade should be <= average")
        #expect(stats.gradeVariability >= 0, "Grade variability should be non-negative")
        
        // For a varied hiking trail, variability should be significant
        #expect(stats.gradeVariability > 1.0, "Varied terrain should have noticeable grade variability")
    }
    
    @Test("Real-time grade calculation performance")
    func testRealTimeGradePerformance() async throws {
        let elevationManager = ElevationManager(configuration: .balanced)
        
        // Simulate real-time location updates
        let startTime = CFAbsoluteTimeGetCurrent()
        let numUpdates = 100
        
        let baseTime = Date()
        var lastResult: GradeCalculator.GradeResult?
        
        for i in 0..<numUpdates {
            let location = LocationPoint(
                timestamp: baseTime.addingTimeInterval(Double(i) * 2),
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194,
                altitude: 100.0 + sin(Double(i) * 0.1) * 10.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 2.0,
                speed: 1.4,
                course: 0.0
            )
            
            location.updateElevationData(
                barometricAltitude: location.altitude,
                fusedAltitude: location.altitude,
                accuracy: 1.0,
                confidence: 0.9,
                grade: nil,
                pressure: 101.325
            )
            
            lastResult = await elevationManager.processLocationPoint(location)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(numUpdates)
        
        // Should process updates quickly for real-time use
        #expect(averageTime < 0.01, "Average processing time should be < 10ms per update")
        #expect(lastResult != nil, "Should successfully process all location updates")
    }
    
    @Test("Grade multiplier impacts calorie calculations")
    func testGradeMultiplierIntegration() async throws {
        let calculator = GradeCalculator(configuration: .standard)
        
        // Test different terrain types
        let terrainTypes = [
            ("flat", 0.0, 1.0),
            ("moderate_uphill", 5.0, 1.175),
            ("steep_uphill", 15.0, 1.65),
            ("moderate_downhill", -5.0, 1.108),
            ("steep_downhill", -15.0, 1.98)
        ]
        
        for (terrain, elevationChange, expectedMultiplier) in terrainTypes {
            let startLocation = createLocationPoint(elevation: 100.0, time: Date())
            let endLocation = createLocationPoint(
                elevation: 100.0 + elevationChange,
                time: Date().addingTimeInterval(60),
                latOffset: 0.001
            )
            
            let result = await calculator.calculateGrade(from: startLocation, to: endLocation)
            
            // Verify multiplier is appropriate for terrain
            let tolerance = 0.2
            #expect(
                abs(result.gradeMultiplier - expectedMultiplier) <= tolerance,
                "Grade multiplier for \(terrain) should be approximately \(expectedMultiplier)"
            )
            
            // Verify multiplier is suitable for calorie calculations
            #expect(result.gradeMultiplier > 0.5, "Multiplier should be positive")
            #expect(result.gradeMultiplier < 5.0, "Multiplier should be reasonable for calorie calculations")
        }
    }
    
    @Test("Elevation profile data for visualization")
    func testElevationProfileData() async throws {
        let elevationManager = ElevationManager(configuration: .precise)
        
        // Create elevation profile with known characteristics
        let locations = createMountainProfile(startTime: Date())
        
        // Process all locations
        for location in locations {
            _ = await elevationManager.processLocationPoint(location)
        }
        
        // Get elevation profile data
        let profileData = await elevationManager.getElevationProfile()
        
        #expect(!profileData.isEmpty, "Should have elevation profile data")
        #expect(profileData.count <= locations.count, "Profile data should not exceed input locations")
        
        // Verify profile data characteristics
        var previousDistance = 0.0
        for point in profileData {
            #expect(point.cumulativeDistance >= previousDistance, "Cumulative distance should be non-decreasing")
            #expect(point.confidence >= 0.0 && point.confidence <= 1.0, "Confidence should be in valid range")
            previousDistance = point.cumulativeDistance
        }
        
        // Test grade history
        let gradeHistory = await elevationManager.getRecentGradeHistory()
        #expect(!gradeHistory.isEmpty, "Should have grade history")
        
        for gradePoint in gradeHistory {
            #expect(abs(gradePoint.instantaneousGrade) <= 25.0, "Grade should be within bounds")
            #expect(gradePoint.confidence >= 0.0, "Confidence should be non-negative")
            #expect(gradePoint.gradeMultiplier > 0.0, "Grade multiplier should be positive")
        }
    }
    
    @Test("Noise filtering effectiveness")
    func testNoiseFiltering() async throws {
        let elevationManager = ElevationManager(configuration: .precise)
        
        // Create noisy elevation data
        let baseTime = Date()
        let cleanElevations = [100.0, 102.0, 104.0, 106.0, 108.0, 110.0]
        let noiseLevels = [0.0, 0.15, -0.12, 0.08, -0.18, 0.05] // Sub-threshold noise
        
        var locations: [LocationPoint] = []
        for i in 0..<cleanElevations.count {
            let noisyElevation = cleanElevations[i] + noiseLevels[i]
            let location = createLocationPoint(
                elevation: noisyElevation,
                time: baseTime.addingTimeInterval(Double(i) * 10),
                latOffset: Double(i) * 0.0001
            )
            locations.append(location)
        }
        
        // Process locations and track results
        var gradeResults: [GradeCalculator.GradeResult] = []
        for i in 1..<locations.count {
            if let result = await elevationManager.processLocationPoint(locations[i]) {
                gradeResults.append(result)
            }
        }
        
        // Verify noise is filtered from cumulative metrics
        let (totalGain, totalLoss) = await elevationManager.elevationMetrics
        
        // Expected clean gain: 10 meters (100 -> 110)
        let expectedGain = 10.0
        let gainTolerance = 1.0
        
        #expect(abs(totalGain - expectedGain) <= gainTolerance, "Noise filtering should maintain accurate cumulative gain")
        #expect(totalLoss < 1.0, "Minor elevation noise should not contribute significantly to loss")
    }
    
    @Test("Thread safety with concurrent access")
    func testConcurrentAccess() async throws {
        let elevationManager = ElevationManager(configuration: .balanced)
        
        // Create concurrent tasks accessing elevation data
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Process location updates
            group.addTask {
                for i in 0..<20 {
                    let location = createLocationPoint(
                        elevation: 100.0 + Double(i),
                        time: Date().addingTimeInterval(Double(i)),
                        latOffset: Double(i) * 0.0001
                    )
                    _ = await elevationManager.processLocationPoint(location)
                }
            }
            
            // Task 2: Read elevation metrics
            group.addTask {
                for _ in 0..<10 {
                    _ = await elevationManager.elevationMetrics
                    _ = await elevationManager.currentGradeMetrics
                    try? await Task.sleep(for: .milliseconds(10))
                }
            }
            
            // Task 3: Read profile data
            group.addTask {
                for _ in 0..<10 {
                    _ = await elevationManager.getElevationProfile()
                    _ = await elevationManager.getRecentGradeHistory()
                    try? await Task.sleep(for: .milliseconds(10))
                }
            }
        }
        
        // Verify system remains consistent after concurrent access
        let (finalGain, finalLoss) = await elevationManager.elevationMetrics
        #expect(finalGain >= 0, "Elevation gain should remain non-negative")
        #expect(finalLoss >= 0, "Elevation loss should remain non-negative")
    }
    
    // MARK: - Helper Methods
    
    private func createLocationPoint(
        elevation: Double,
        time: Date,
        latOffset: Double = 0.0
    ) -> LocationPoint {
        let location = LocationPoint(
            timestamp: time,
            latitude: 37.7749 + latOffset,
            longitude: -122.4194,
            altitude: elevation,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 2.0,
            speed: 1.4,
            course: 0.0
        )
        
        location.updateElevationData(
            barometricAltitude: elevation,
            fusedAltitude: elevation,
            accuracy: 1.0,
            confidence: 0.9,
            grade: nil,
            pressure: 101.325
        )
        
        return location
    }
    
    private func createHikingTrail(startTime: Date) -> [LocationPoint] {
        var locations: [LocationPoint] = []
        
        // Simulate a 2km hiking trail with varied elevation
        let trailPoints = 50
        let baseElevation = 500.0
        
        for i in 0..<trailPoints {
            let progress = Double(i) / Double(trailPoints)
            
            // Create varied elevation profile
            let elevation = baseElevation + 
                sin(progress * 4 * .pi) * 50.0 + // Rolling hills
                progress * 100.0 + // Overall ascent
                (Double.random(in: -2.0...2.0)) // Small random variations
            
            let location = LocationPoint(
                timestamp: startTime.addingTimeInterval(Double(i) * 30),
                latitude: 37.7749 + progress * 0.01,
                longitude: -122.4194 + sin(progress * 2 * .pi) * 0.005,
                altitude: elevation,
                horizontalAccuracy: Double.random(in: 3.0...8.0),
                verticalAccuracy: Double.random(in: 1.0...3.0),
                speed: Double.random(in: 1.0...2.0),
                course: progress * 90.0
            )
            
            location.updateElevationData(
                barometricAltitude: elevation + Double.random(in: -0.5...0.5),
                fusedAltitude: elevation + Double.random(in: -0.2...0.2),
                accuracy: Double.random(in: 0.5...1.5),
                confidence: Double.random(in: 0.7...0.95),
                grade: nil,
                pressure: 101.325 - elevation * 0.012
            )
            
            locations.append(location)
        }
        
        return locations
    }
    
    private func createMountainProfile(startTime: Date) -> [LocationPoint] {
        var locations: [LocationPoint] = []
        
        // Simulate mountain ascent and descent
        let totalPoints = 30
        let baseElevation = 1000.0
        let peakElevation = 1500.0
        
        for i in 0..<totalPoints {
            let progress = Double(i) / Double(totalPoints - 1)
            
            // Create mountain profile: ascent then descent
            let elevation: Double
            if progress <= 0.6 {
                // Ascent
                let ascentProgress = progress / 0.6
                elevation = baseElevation + (peakElevation - baseElevation) * ascentProgress
            } else {
                // Descent
                let descentProgress = (progress - 0.6) / 0.4
                elevation = peakElevation - (peakElevation - baseElevation) * 0.8 * descentProgress
            }
            
            let location = LocationPoint(
                timestamp: startTime.addingTimeInterval(Double(i) * 60),
                latitude: 37.7749 + progress * 0.005,
                longitude: -122.4194,
                altitude: elevation,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 2.0,
                speed: 1.2,
                course: 0.0
            )
            
            location.updateElevationData(
                barometricAltitude: elevation,
                fusedAltitude: elevation,
                accuracy: 1.0,
                confidence: 0.9,
                grade: nil,
                pressure: 101.325 - elevation * 0.012
            )
            
            locations.append(location)
        }
        
        return locations
    }
}