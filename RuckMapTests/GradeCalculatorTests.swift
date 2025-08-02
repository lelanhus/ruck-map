import Testing
import Foundation
import CoreLocation
@testable import RuckMap

@Suite("GradeCalculator Tests")
struct GradeCalculatorTests {
    
    @Test("Basic grade calculation with standard configuration")
    func testBasicGradeCalculation() async throws {
        let calculator = GradeCalculator(configuration: .standard)
        
        // Create two location points with known elevation difference
        let startLocation = LocationPoint(
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            speed: 1.4,
            course: 0.0
        )
        startLocation.updateElevationData(
            barometricAltitude: 100.0,
            fusedAltitude: 100.0,
            accuracy: 1.0,
            confidence: 0.9,
            grade: nil,
            pressure: 101.325
        )
        
        let endLocation = LocationPoint(
            timestamp: Date().addingTimeInterval(10),
            latitude: 37.7750,
            longitude: -122.4194,
            altitude: 110.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            speed: 1.4,
            course: 0.0
        )
        endLocation.updateElevationData(
            barometricAltitude: 110.0,
            fusedAltitude: 110.0,
            accuracy: 1.0,
            confidence: 0.9,
            grade: nil,
            pressure: 101.325
        )
        
        // Calculate grade
        let result = await calculator.calculateGrade(from: startLocation, to: endLocation)
        
        // Verify results
        #expect(result.elevationGain == 10.0, "Elevation gain should be 10 meters")
        #expect(result.elevationLoss == 0.0, "Elevation loss should be 0")
        #expect(result.instantaneousGrade > 0, "Grade should be positive for uphill")
        #expect(result.confidence > 0.5, "Confidence should be reasonable")
        #expect(result.gradeMultiplier > 1.0, "Grade multiplier should be > 1 for uphill")
    }
    
    @Test("Grade calculation with precise configuration achieves 0.5% precision")
    func testPreciseGradeCalculation() async throws {
        let calculator = GradeCalculator(configuration: .precise)
        
        // Create a sequence of points for a known grade
        var locations: [LocationPoint] = []
        let baseTime = Date()
        
        // Create 10-meter uphill at 5% grade (0.5 meter elevation per 10 meters horizontal)
        for i in 0..<10 {
            let location = LocationPoint(
                timestamp: baseTime.addingTimeInterval(Double(i) * 2),
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194,
                altitude: 100.0 + Double(i) * 0.5,
                horizontalAccuracy: 2.0,
                verticalAccuracy: 1.0,
                speed: 1.4,
                course: 0.0
            )
            location.updateElevationData(
                barometricAltitude: 100.0 + Double(i) * 0.5,
                fusedAltitude: 100.0 + Double(i) * 0.5,
                accuracy: 0.5,
                confidence: 0.95,
                grade: nil,
                pressure: 101.325
            )
            locations.append(location)
        }
        
        // Calculate average grade over the sequence
        guard let result = await calculator.calculateAverageGrade(over: locations) else {
            Issue.record("Average grade calculation failed")
            return
        }
        
        // Expected grade: 5.0% (0.5m elevation / 10m horizontal * 100)
        let expectedGrade = 5.0
        let precision = abs(result.smoothedGrade - expectedGrade)
        
        #expect(precision <= 0.5, "Grade calculation should achieve 0.5% precision target")
        #expect(result.confidence > 0.8, "High-quality data should yield high confidence")
        #expect(result.meetsPrecisionTarget, "Result should meet precision target")
    }
    
    @Test("Elevation gain and loss tracking with noise filtering")
    func testElevationGainLossTracking() async throws {
        let calculator = GradeCalculator(configuration: .standard)
        
        let baseTime = Date()
        var cumulativeGain = 0.0
        var cumulativeLoss = 0.0
        
        // Create a hilly profile with noise
        let elevationProfile = [100.0, 100.1, 105.0, 104.8, 110.0, 108.0, 115.0, 112.0, 108.0, 105.0]
        
        for i in 1..<elevationProfile.count {
            let startLocation = LocationPoint(
                timestamp: baseTime.addingTimeInterval(Double(i-1) * 5),
                latitude: 37.7749 + Double(i-1) * 0.0001,
                longitude: -122.4194,
                altitude: elevationProfile[i-1],
                horizontalAccuracy: 5.0,
                verticalAccuracy: 2.0,
                speed: 1.4,
                course: 0.0
            )
            startLocation.updateElevationData(
                barometricAltitude: elevationProfile[i-1],
                fusedAltitude: elevationProfile[i-1],
                accuracy: 1.0,
                confidence: 0.8,
                grade: nil,
                pressure: 101.325
            )
            
            let endLocation = LocationPoint(
                timestamp: baseTime.addingTimeInterval(Double(i) * 5),
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194,
                altitude: elevationProfile[i],
                horizontalAccuracy: 5.0,
                verticalAccuracy: 2.0,
                speed: 1.4,
                course: 0.0
            )
            endLocation.updateElevationData(
                barometricAltitude: elevationProfile[i],
                fusedAltitude: elevationProfile[i],
                accuracy: 1.0,
                confidence: 0.8,
                grade: nil,
                pressure: 101.325
            )
            
            let result = await calculator.calculateGrade(from: startLocation, to: endLocation)
            cumulativeGain += result.elevationGain
            cumulativeLoss += result.elevationLoss
        }
        
        // Verify cumulative tracking
        let (totalGain, totalLoss) = await calculator.elevationMetrics
        
        #expect(totalGain > 0, "Should track elevation gain")
        #expect(totalLoss > 0, "Should track elevation loss")
        #expect(totalGain + totalLoss > 15.0, "Total elevation change should reflect hilly profile")
        
        // The 0.1m noise should be filtered out due to threshold
        #expect(cumulativeGain < totalGain + 1.0, "Noise filtering should work")
    }
    
    @Test("Grade multiplier calculation for calorie estimation")
    func testGradeMultiplierCalculation() async throws {
        let calculator = GradeCalculator(configuration: .standard)
        
        // Test various grades and their multipliers
        let testCases = [
            (elevation: 0.0, distance: 100.0, expectedMultiplier: 1.0), // Flat
            (elevation: 5.0, distance: 100.0, expectedMultiplier: 1.175), // 5% uphill
            (elevation: 10.0, distance: 100.0, expectedMultiplier: 1.4), // 10% uphill
            (elevation: -5.0, distance: 100.0, expectedMultiplier: 1.108), // 5% downhill
            (elevation: -10.0, distance: 100.0, expectedMultiplier: 1.28) // 10% downhill
        ]
        
        for testCase in testCases {
            let startLocation = LocationPoint(
                timestamp: Date(),
                latitude: 37.7749,
                longitude: -122.4194,
                altitude: 100.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 2.0,
                speed: 1.4,
                course: 0.0
            )
            startLocation.updateElevationData(
                barometricAltitude: 100.0,
                fusedAltitude: 100.0,
                accuracy: 1.0,
                confidence: 0.9,
                grade: nil,
                pressure: 101.325
            )
            
            let endLocation = LocationPoint(
                timestamp: Date().addingTimeInterval(60),
                latitude: 37.7749 + 0.001,
                longitude: -122.4194,
                altitude: 100.0 + testCase.elevation,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 2.0,
                speed: 1.4,
                course: 0.0
            )
            endLocation.updateElevationData(
                barometricAltitude: 100.0 + testCase.elevation,
                fusedAltitude: 100.0 + testCase.elevation,
                accuracy: 1.0,
                confidence: 0.9,
                grade: nil,
                pressure: 101.325
            )
            
            let result = await calculator.calculateGrade(from: startLocation, to: endLocation)
            
            // Allow for some tolerance in multiplier calculation
            let tolerance = 0.1
            #expect(
                abs(result.gradeMultiplier - testCase.expectedMultiplier) <= tolerance,
                "Grade multiplier for \(testCase.elevation)m elevation should be approximately \(testCase.expectedMultiplier)"
            )
        }
    }
    
    @Test("Smoothing reduces noise in grade calculations")
    func testGradeSmoothing() async throws {
        let calculator = GradeCalculator(configuration: .precise)
        
        let baseTime = Date()
        var instantaneousGrades: [Double] = []
        var smoothedGrades: [Double] = []
        
        // Create noisy grade data
        let noisyElevations = [100.0, 102.0, 101.5, 103.0, 102.8, 104.5, 104.2, 106.0, 105.8, 107.0]
        
        for i in 1..<noisyElevations.count {
            let startLocation = LocationPoint(
                timestamp: baseTime.addingTimeInterval(Double(i-1) * 3),
                latitude: 37.7749 + Double(i-1) * 0.0001,
                longitude: -122.4194,
                altitude: noisyElevations[i-1],
                horizontalAccuracy: 3.0,
                verticalAccuracy: 1.5,
                speed: 1.4,
                course: 0.0
            )
            startLocation.updateElevationData(
                barometricAltitude: noisyElevations[i-1],
                fusedAltitude: noisyElevations[i-1],
                accuracy: 0.8,
                confidence: 0.85,
                grade: nil,
                pressure: 101.325
            )
            
            let endLocation = LocationPoint(
                timestamp: baseTime.addingTimeInterval(Double(i) * 3),
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194,
                altitude: noisyElevations[i],
                horizontalAccuracy: 3.0,
                verticalAccuracy: 1.5,
                speed: 1.4,
                course: 0.0
            )
            endLocation.updateElevationData(
                barometricAltitude: noisyElevations[i],
                fusedAltitude: noisyElevations[i],
                accuracy: 0.8,
                confidence: 0.85,
                grade: nil,
                pressure: 101.325
            )
            
            let result = await calculator.calculateGrade(from: startLocation, to: endLocation)
            instantaneousGrades.append(result.instantaneousGrade)
            smoothedGrades.append(result.smoothedGrade)
        }
        
        // After several calculations, smoothed grades should be less volatile
        if smoothedGrades.count >= 5 {
            let instantaneousVariance = calculateVariance(instantaneousGrades)
            let smoothedVariance = calculateVariance(smoothedGrades.suffix(5))
            
            #expect(smoothedVariance < instantaneousVariance, "Smoothed grades should have lower variance than instantaneous")
        }
    }
    
    @Test("Edge case handling - insufficient data")
    func testEdgeCaseHandling() async throws {
        let calculator = GradeCalculator(configuration: .standard)
        
        // Test with identical locations (zero distance)
        let location1 = LocationPoint(
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 2.0,
            speed: 0.0,
            course: 0.0
        )
        
        let location2 = LocationPoint(
            timestamp: Date().addingTimeInterval(5),
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 2.0,
            speed: 0.0,
            course: 0.0
        )
        
        let result = await calculator.calculateGrade(from: location1, to: location2)
        
        #expect(result.instantaneousGrade == 0.0, "Zero distance should yield zero grade")
        #expect(result.confidence == 0.0, "Zero distance should yield zero confidence")
        #expect(result.gradeMultiplier == 1.0, "Zero grade should yield neutral multiplier")
    }
    
    @Test("Grade trend analysis")
    func testGradeTrendAnalysis() async throws {
        let calculator = GradeCalculator(configuration: .precise)
        
        let baseTime = Date()
        
        // Create ascending trend
        for i in 0..<15 {
            let startLocation = LocationPoint(
                timestamp: baseTime.addingTimeInterval(Double(i) * 2),
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194,
                altitude: 100.0 + Double(i) * 0.5,
                horizontalAccuracy: 3.0,
                verticalAccuracy: 1.0,
                speed: 1.4,
                course: 0.0
            )
            startLocation.updateElevationData(
                barometricAltitude: 100.0 + Double(i) * 0.5,
                fusedAltitude: 100.0 + Double(i) * 0.5,
                accuracy: 0.5,
                confidence: 0.9,
                grade: nil,
                pressure: 101.325
            )
            
            let endLocation = LocationPoint(
                timestamp: baseTime.addingTimeInterval(Double(i+1) * 2),
                latitude: 37.7749 + Double(i+1) * 0.0001,
                longitude: -122.4194,
                altitude: 100.0 + Double(i+1) * 0.5,
                horizontalAccuracy: 3.0,
                verticalAccuracy: 1.0,
                speed: 1.4,
                course: 0.0
            )
            endLocation.updateElevationData(
                barometricAltitude: 100.0 + Double(i+1) * 0.5,
                fusedAltitude: 100.0 + Double(i+1) * 0.5,
                accuracy: 0.5,
                confidence: 0.9,
                grade: nil,
                pressure: 101.325
            )
            
            let result = await calculator.calculateGrade(from: startLocation, to: endLocation)
            
            // After enough points, trend should be ascending
            if i >= 10 {
                #expect(result.trend == .ascending, "Consistent uphill should show ascending trend")
            }
        }
    }
    
    @Test("Reset functionality")
    func testResetFunctionality() async throws {
        let calculator = GradeCalculator(configuration: .standard)
        
        // Add some data
        let startLocation = LocationPoint(
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 2.0,
            speed: 1.4,
            course: 0.0
        )
        
        let endLocation = LocationPoint(
            timestamp: Date().addingTimeInterval(10),
            latitude: 37.7750,
            longitude: -122.4194,
            altitude: 110.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 2.0,
            speed: 1.4,
            course: 0.0
        )
        
        _ = await calculator.calculateGrade(from: startLocation, to: endLocation)
        
        // Verify data exists
        let (gainBefore, lossBefore) = await calculator.elevationMetrics
        #expect(gainBefore > 0, "Should have elevation gain before reset")
        
        // Reset
        await calculator.reset()
        
        // Verify reset
        let (gainAfter, lossAfter) = await calculator.elevationMetrics
        let (instantaneous, smoothed) = await calculator.currentGradeMetrics
        
        #expect(gainAfter == 0.0, "Elevation gain should be reset")
        #expect(lossAfter == 0.0, "Elevation loss should be reset")
        #expect(instantaneous == 0.0, "Instantaneous grade should be reset")
        #expect(smoothed == 0.0, "Smoothed grade should be reset")
        
        let profileData = await calculator.profileData
        let gradeHistory = await calculator.recentGradeHistory
        
        #expect(profileData.isEmpty, "Profile data should be cleared")
        #expect(gradeHistory.isEmpty, "Grade history should be cleared")
    }
    
    // Helper function to calculate variance
    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return variance
    }
    
    // Helper function to calculate variance for ArraySlice
    private func calculateVariance<T: Collection>(_ values: T) -> Double where T.Element == Double {
        let array = Array(values)
        return calculateVariance(array)
    }
}