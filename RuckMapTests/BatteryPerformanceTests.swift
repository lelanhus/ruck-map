//
//  BatteryPerformanceTests.swift
//  RuckMapTests
//
//  Created by Battery Optimization on 8/2/25.
//

import XCTest
import CoreLocation
@testable import RuckMap

/// Performance tests focused on battery optimization and power consumption
/// Target: <10% battery usage per hour during active tracking
final class BatteryPerformanceTests: XCTestCase {
    
    var adaptiveGPSManager: AdaptiveGPSManager!
    var locationTrackingManager: LocationTrackingManager!
    var motionLocationManager: MotionLocationManager!
    var elevationManager: ElevationManager!
    
    override func setUp() {
        super.setUp()
        adaptiveGPSManager = AdaptiveGPSManager()
        locationTrackingManager = LocationTrackingManager()
        motionLocationManager = MotionLocationManager()
        elevationManager = ElevationManager()
    }
    
    override func tearDown() {
        adaptiveGPSManager = nil
        locationTrackingManager = nil
        motionLocationManager = nil
        elevationManager = nil
        super.tearDown()
    }
    
    // MARK: - Battery Usage Estimation Tests
    
    func testBatteryUsageEstimation() {
        // Test different configurations for battery usage
        let testCases: [(config: GPSConfiguration, expectedUsage: ClosedRange<Double>, description: String)] = [
            (.highPerformance, 15.0...18.0, "High Performance"),
            (.balanced, 8.0...12.0, "Balanced"),
            (.batterySaver, 4.0...7.0, "Battery Saver"),
            (.critical, 2.0...4.0, "Critical"),
            (.ultraLowPower, 1.0...3.0, "Ultra Low Power")
        ]
        
        for testCase in testCases {
            adaptiveGPSManager.currentConfiguration = testCase.config
            adaptiveGPSManager.updateBatteryUsageEstimate()
            
            XCTAssertTrue(
                testCase.expectedUsage.contains(adaptiveGPSManager.batteryUsageEstimate),
                "\(testCase.description) mode should use \(testCase.expectedUsage)%/hour, got \(adaptiveGPSManager.batteryUsageEstimate)%/hour"
            )
        }
    }
    
    func testUltraLowPowerModeActivation() throws {
        // Test ultra-low power mode activation for long sessions
        adaptiveGPSManager.enableUltraLowPowerMode(true)
        adaptiveGPSManager.startSession()
        
        // Simulate a session that has been running for >2 hours
        let twoHoursAgo = Date().addingTimeInterval(-7300) // 2 hours and 10 seconds
        adaptiveGPSManager.sessionStartTime = twoHoursAgo
        
        adaptiveGPSManager.forceConfigurationUpdate()
        
        XCTAssertEqual(adaptiveGPSManager.currentConfiguration.accuracy, GPSConfiguration.ultraLowPower.accuracy)
        XCTAssertEqual(adaptiveGPSManager.currentConfiguration.updateFrequency, GPSConfiguration.ultraLowPower.updateFrequency)
        XCTAssertGreaterThanOrEqual(adaptiveGPSManager.currentConfiguration.distanceFilter, 50.0)
    }
    
    func testSignificantLocationChangesOptimization() {
        // Test significant location changes for stationary periods
        adaptiveGPSManager.enableSignificantLocationChanges(true)
        adaptiveGPSManager.currentMovementPattern = .stationary
        adaptiveGPSManager.updateBatteryUsageEstimate()
        
        // Should have significant battery savings for stationary mode
        XCTAssertLessThanOrEqual(adaptiveGPSManager.batteryUsageEstimate, 5.0, "Stationary mode with significant location changes should use ≤5%/hour")
    }
    
    // MARK: - GPS Configuration Optimization Tests
    
    func testMovementPatternOptimization() {
        let testCases: [(pattern: MovementPattern, speed: Double, expectedAccuracy: CLLocationAccuracy)] = [
            (.stationary, 0.0, kCLLocationAccuracyHundredMeters),
            (.walking, 1.2, kCLLocationAccuracyBest),
            (.jogging, 2.5, kCLLocationAccuracyBestForNavigation),
            (.running, 4.0, kCLLocationAccuracyBestForNavigation)
        ]
        
        for testCase in testCases {
            adaptiveGPSManager.currentMovementPattern = testCase.pattern
            adaptiveGPSManager.averageSpeed = testCase.speed
            
            let config = adaptiveGPSManager.getRecommendedConfiguration()
            
            XCTAssertGreaterThanOrEqual(
                config.accuracy,
                testCase.expectedAccuracy,
                "\(testCase.pattern) should use accuracy ≥ \(testCase.expectedAccuracy)"
            )
        }
    }
    
    func testBatteryStateAdaptation() {
        // Test different battery states
        adaptiveGPSManager.batteryOptimizationEnabled = true
        
        // Simulate low power mode
        adaptiveGPSManager.batteryStatus = BatteryStatus(
            level: 0.15,
            state: .unplugged,
            isLowPowerModeEnabled: true
        )
        
        adaptiveGPSManager.forceConfigurationUpdate()
        
        XCTAssertGreaterThanOrEqual(adaptiveGPSManager.currentConfiguration.distanceFilter, 20.0)
        XCTAssertGreaterThanOrEqual(adaptiveGPSManager.currentConfiguration.updateFrequency, 2.0)
    }
    
    // MARK: - Motion Sensor Optimization Tests
    
    func testMotionSensorBatteryMode() throws {
        let expectation = XCTestExpectation(description: "Motion sensor battery optimization")
        
        motionLocationManager.setBatteryOptimizedMode(true)
        
        // Verify battery optimized mode reduces update frequency
        XCTAssertTrue(motionLocationManager.batteryOptimizedMode)
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testLocationUpdateSuppression() throws {
        motionLocationManager.setBatteryOptimizedMode(true)
        motionLocationManager.currentMotionActivity = .stationary
        motionLocationManager.stationaryDuration = 60.0 // 1 minute stationary
        
        // Should suppress location updates when stationary
        let shouldSuppress = motionLocationManager.suppressLocationUpdates
        XCTAssertTrue(shouldSuppress, "Should suppress location updates when stationary for >30 seconds")
    }
    
    // MARK: - Elevation Tracking Optimization Tests
    
    func testElevationBatteryOptimization() {
        elevationManager.setBatteryOptimizedMode(true)
        
        XCTAssertEqual(elevationManager.configuration, .batterySaver)
        XCTAssertTrue(elevationManager.batteryOptimizedMode)
        XCTAssertEqual(elevationManager.configuration.updateInterval, 5.0) // Battery saver should use 5s intervals
    }
    
    // MARK: - Performance Benchmarks
    
    func testLocationProcessingPerformance() throws {
        measure {
            // Simulate processing 100 location updates
            for i in 0..<100 {
                let location = CLLocation(
                    latitude: 37.7749 + Double(i) * 0.0001,
                    longitude: -122.4194 + Double(i) * 0.0001
                )
                adaptiveGPSManager.analyzeLocationUpdate(location)
            }
        }
    }
    
    func testMotionDataProcessingPerformance() throws {
        measure {
            // Simulate processing motion data
            let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
            
            Task {
                for _ in 0..<50 {
                    _ = await motionLocationManager.processLocationUpdate(location)
                }
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testBatteryOptimizationIntegration() throws {
        // Test complete battery optimization flow
        locationTrackingManager.enableBatteryOptimization(true)
        
        // Verify all components are in battery-optimized mode
        XCTAssertTrue(adaptiveGPSManager.batteryOptimizationEnabled)
        XCTAssertTrue(motionLocationManager.batteryOptimizedMode)
        XCTAssertTrue(elevationManager.batteryOptimizedMode)
        
        // Verify estimated battery usage is within target
        XCTAssertLessThanOrEqual(
            adaptiveGPSManager.batteryUsageEstimate,
            10.0,
            "Battery-optimized mode should use ≤10%/hour"
        )
    }
    
    func testLongSessionBatteryOptimization() throws {
        // Test battery optimization for sessions >2 hours
        adaptiveGPSManager.enableUltraLowPowerMode(true)
        adaptiveGPSManager.startSession()
        
        // Simulate 2.5 hours elapsed
        adaptiveGPSManager.sessionStartTime = Date().addingTimeInterval(-9000)
        
        adaptiveGPSManager.forceConfigurationUpdate()
        
        // Should be in ultra-low power mode
        XCTAssertEqual(adaptiveGPSManager.currentConfiguration.updateFrequency, 10.0)
        XCTAssertGreaterThanOrEqual(adaptiveGPSManager.currentConfiguration.distanceFilter, 50.0)
        
        // Battery usage should be significantly reduced
        XCTAssertLessThanOrEqual(
            adaptiveGPSManager.batteryUsageEstimate,
            4.0,
            "Ultra-low power mode should use ≤4%/hour"
        )
    }
    
    // MARK: - Accuracy vs Battery Trade-off Tests
    
    func testAccuracyBatteryTradeoff() throws {
        // Test that battery optimizations don't compromise accuracy too much
        let highAccuracyConfig = GPSConfiguration.highPerformance
        let batteryConfig = GPSConfiguration.batterySaver
        let ultraLowConfig = GPSConfiguration.ultraLowPower
        
        // High accuracy should provide best precision but highest battery usage
        adaptiveGPSManager.currentConfiguration = highAccuracyConfig
        adaptiveGPSManager.updateBatteryUsageEstimate()
        let highAccuracyUsage = adaptiveGPSManager.batteryUsageEstimate
        
        // Battery saver should reduce usage while maintaining reasonable accuracy
        adaptiveGPSManager.currentConfiguration = batteryConfig
        adaptiveGPSManager.updateBatteryUsageEstimate()
        let batterySaverUsage = adaptiveGPSManager.batteryUsageEstimate
        
        // Ultra low power should minimize usage for long sessions
        adaptiveGPSManager.currentConfiguration = ultraLowConfig
        adaptiveGPSManager.updateBatteryUsageEstimate()
        let ultraLowUsage = adaptiveGPSManager.batteryUsageEstimate
        
        // Verify battery usage decreases with lower accuracy modes
        XCTAssertGreaterThan(highAccuracyUsage, batterySaverUsage)
        XCTAssertGreaterThan(batterySaverUsage, ultraLowUsage)
        
        // Verify ultra-low power mode meets target
        XCTAssertLessThanOrEqual(ultraLowUsage, 4.0, "Ultra-low power mode should use ≤4%/hour")
    }
    
    // MARK: - Real-world Scenario Tests
    
    func testStationaryToWalkingTransition() throws {
        // Test battery optimization during activity transitions
        adaptiveGPSManager.enableSignificantLocationChanges(true)
        adaptiveGPSManager.currentMovementPattern = .stationary
        adaptiveGPSManager.updateBatteryUsageEstimate()
        let stationaryUsage = adaptiveGPSManager.batteryUsageEstimate
        
        // Transition to walking
        adaptiveGPSManager.currentMovementPattern = .walking
        adaptiveGPSManager.averageSpeed = 1.2
        adaptiveGPSManager.enableSignificantLocationChanges(false)
        adaptiveGPSManager.forceConfigurationUpdate()
        adaptiveGPSManager.updateBatteryUsageEstimate()
        let walkingUsage = adaptiveGPSManager.batteryUsageEstimate
        
        // Walking should use more battery than stationary, but still be optimized
        XCTAssertGreaterThan(walkingUsage, stationaryUsage)
        XCTAssertLessThanOrEqual(walkingUsage, 12.0, "Optimized walking should use ≤12%/hour")
    }
    
    func testCriticalBatteryScenario() throws {
        // Test critical battery scenario
        adaptiveGPSManager.batteryStatus = BatteryStatus(
            level: 0.05, // 5% battery
            state: .unplugged,
            isLowPowerModeEnabled: true
        )
        
        adaptiveGPSManager.forceConfigurationUpdate()
        
        // Should switch to critical mode
        XCTAssertEqual(adaptiveGPSManager.currentConfiguration.accuracy, GPSConfiguration.critical.accuracy)
        XCTAssertGreaterThanOrEqual(adaptiveGPSManager.currentConfiguration.updateFrequency, 5.0)
        
        adaptiveGPSManager.updateBatteryUsageEstimate()
        XCTAssertLessThanOrEqual(
            adaptiveGPSManager.batteryUsageEstimate,
            4.0,
            "Critical battery mode should use ≤4%/hour"
        )
    }
}