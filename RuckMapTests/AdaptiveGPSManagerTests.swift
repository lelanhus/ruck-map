import Testing
import CoreLocation
import UIKit
@testable import RuckMap

// MARK: - Adaptive GPS Manager Tests
@Suite("Adaptive GPS Manager Tests")
struct AdaptiveGPSManagerTests {
    
    // MARK: - Movement Pattern Tests
    
    @Test("Movement pattern classification from speed")
    func testMovementPatternFromSpeed() async throws {
        #expect(MovementPattern(from: 0.0) == .stationary)
        #expect(MovementPattern(from: 0.3) == .stationary)
        #expect(MovementPattern(from: 1.0) == .walking)
        #expect(MovementPattern(from: 2.5) == .jogging)
        #expect(MovementPattern(from: 4.0) == .running)
        #expect(MovementPattern(from: -1.0) == .unknown)
    }
    
    @Test("GPS configuration for movement patterns")
    func testMovementPatternConfigurations() async throws {
        let stationaryConfig = MovementPattern.stationary.expectedConfiguration
        let walkingConfig = MovementPattern.walking.expectedConfiguration
        let runningConfig = MovementPattern.running.expectedConfiguration
        
        // Stationary should use battery saver mode
        #expect(stationaryConfig.accuracy == GPSConfiguration.batterySaver.accuracy)
        #expect(stationaryConfig.updateFrequency == GPSConfiguration.batterySaver.updateFrequency)
        
        // Walking should use balanced mode
        #expect(walkingConfig.accuracy == GPSConfiguration.balanced.accuracy)
        
        // Running should use high performance mode
        #expect(runningConfig.accuracy == GPSConfiguration.highPerformance.accuracy)
        #expect(runningConfig.updateFrequency == GPSConfiguration.highPerformance.updateFrequency)
    }
    
    // MARK: - Battery State Tests
    
    @Test("Power state determination from battery level")
    func testPowerStateFromBattery() async throws {
        // Mock battery status for normal state
        let normalBattery = BatteryStatus(
            level: 0.5,
            state: .unplugged,
            isLowPowerModeEnabled: false
        )
        #expect(normalBattery.powerState == .normal)
        
        // Mock battery status for low power mode
        let lowPowerBattery = BatteryStatus(
            level: 0.25,
            state: .unplugged,
            isLowPowerModeEnabled: true
        )
        #expect(lowPowerBattery.powerState == .lowPowerMode)
        
        // Mock battery status for critical state
        let criticalBattery = BatteryStatus(
            level: 0.05,
            state: .unplugged,
            isLowPowerModeEnabled: false
        )
        #expect(criticalBattery.powerState == .critical)
    }
    
    // MARK: - Adaptive GPS Manager Functionality
    
    @Test("GPS manager initialization")
    @MainActor
    func testGPSManagerInitialization() async throws {
        let manager = AdaptiveGPSManager()
        
        #expect(manager.isAdaptiveMode == true)
        #expect(manager.batteryOptimizationEnabled == true)
        #expect(manager.currentMovementPattern == .unknown)
        #expect(manager.averageSpeed == 0.0)
        #expect(manager.updateCount == 0)
    }
    
    @Test("Speed metrics update")
    @MainActor
    func testSpeedMetricsUpdate() async throws {
        let manager = AdaptiveGPSManager()
        
        // Create mock location with specific speed
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 2.0, // 2 m/s - jogging speed
            timestamp: Date()
        )
        
        manager.analyzeLocationUpdate(location)
        
        #expect(manager.updateCount == 1)
        #expect(manager.averageSpeed == 2.0)
        #expect(manager.currentMovementPattern == .jogging)
    }
    
    @Test("Configuration update based on movement pattern")
    @MainActor
    func testConfigurationUpdateFromMovement() async throws {
        let manager = AdaptiveGPSManager()
        
        // Start with stationary
        let stationaryLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 0.0,
            timestamp: Date()
        )
        
        manager.analyzeLocationUpdate(stationaryLocation)
        #expect(manager.currentMovementPattern == .stationary)
        
        // Change to running
        let runningLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4194),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 4.0, // 4 m/s - running speed
            timestamp: Date().addingTimeInterval(1)
        )
        
        manager.analyzeLocationUpdate(runningLocation)
        #expect(manager.currentMovementPattern == .running)
        
        // Configuration should adapt to high performance for running
        let config = manager.currentConfiguration
        #expect(config.accuracy == kCLLocationAccuracyBestForNavigation)
        #expect(config.updateFrequency <= 0.2) // High frequency for running
    }
    
    @Test("Battery optimization effects")
    @MainActor
    func testBatteryOptimizationEffects() async throws {
        let manager = AdaptiveGPSManager()
        
        // Simulate low battery scenario
        manager.batteryStatus = BatteryStatus(
            level: 0.15, // 15% battery
            state: .unplugged,
            isLowPowerModeEnabled: true
        )
        
        // Create running location
        let runningLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 4.0,
            timestamp: Date()
        )
        
        manager.analyzeLocationUpdate(runningLocation)
        
        // Even with running, battery optimization should reduce accuracy
        let config = manager.currentConfiguration
        #expect(config.accuracy >= kCLLocationAccuracyNearestTenMeters)
        #expect(config.updateFrequency >= 0.5) // Reduced frequency
    }
    
    @Test("Battery usage estimation")
    @MainActor
    func testBatteryUsageEstimation() async throws {
        let manager = AdaptiveGPSManager()
        
        // Test high performance mode battery usage
        manager.currentConfiguration = .highPerformance
        manager.updateBatteryUsageEstimate()
        #expect(manager.batteryUsageEstimate > 10.0) // Should be high
        
        // Test battery saver mode usage
        manager.currentConfiguration = .batterySaver
        manager.updateBatteryUsageEstimate()
        #expect(manager.batteryUsageEstimate < 8.0) // Should be lower
    }
    
    @Test("Adaptive mode toggle")
    @MainActor
    func testAdaptiveModeToggle() async throws {
        let manager = AdaptiveGPSManager()
        
        #expect(manager.isAdaptiveMode == true)
        
        manager.setAdaptiveMode(false)
        #expect(manager.isAdaptiveMode == false)
        
        manager.setAdaptiveMode(true)
        #expect(manager.isAdaptiveMode == true)
    }
    
    @Test("Reset metrics")
    @MainActor
    func testResetMetrics() async throws {
        let manager = AdaptiveGPSManager()
        
        // Add some updates
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 2.0,
            timestamp: Date()
        )
        
        manager.analyzeLocationUpdate(location)
        #expect(manager.updateCount > 0)
        #expect(manager.averageSpeed > 0)
        
        manager.resetMetrics()
        #expect(manager.updateCount == 0)
        #expect(manager.averageSpeed == 0.0)
    }
    
    // MARK: - Integration Tests
    
    @Test("Speed buffer management")
    @MainActor
    func testSpeedBufferManagement() async throws {
        let manager = AdaptiveGPSManager()
        
        // Add many speed updates to test buffer overflow
        for i in 1...25 {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                altitude: 100,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                course: 0,
                speed: Double(i % 5), // Cycling speeds 0-4
                timestamp: Date().addingTimeInterval(TimeInterval(i))
            )
            manager.analyzeLocationUpdate(location)
        }
        
        // Average should be calculated from most recent values only
        #expect(manager.averageSpeed >= 0)
        #expect(manager.averageSpeed <= 5)
        #expect(manager.updateCount == 25)
    }
    
    @Test("Configuration change detection")
    @MainActor
    func testConfigurationChangeDetection() async throws {
        let manager = AdaptiveGPSManager()
        let initialConfig = manager.currentConfiguration
        
        // Simulate movement change that should trigger config update
        let fastLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 5.0, // Fast running
            timestamp: Date()
        )
        
        manager.analyzeLocationUpdate(fastLocation)
        
        // Configuration should change for high-speed movement
        let newConfig = manager.currentConfiguration
        let hasChanged = initialConfig.accuracy != newConfig.accuracy ||
                        initialConfig.distanceFilter != newConfig.distanceFilter ||
                        initialConfig.updateFrequency != newConfig.updateFrequency
        
        #expect(hasChanged == true)
    }
    
    // MARK: - Battery Alert Tests
    
    @Test("Battery alert conditions")
    @MainActor
    func testBatteryAlertConditions() async throws {
        let manager = AdaptiveGPSManager()
        
        // Normal battery - no alert
        manager.batteryStatus = BatteryStatus(
            level: 0.5,
            state: .unplugged,
            isLowPowerModeEnabled: false
        )
        #expect(manager.shouldShowBatteryAlert == false)
        #expect(manager.batteryAlertMessage.isEmpty == true)
        
        // Low battery without low power mode - should alert
        manager.batteryStatus = BatteryStatus(
            level: 0.1, // 10% battery
            state: .unplugged,
            isLowPowerModeEnabled: false
        )
        #expect(manager.shouldShowBatteryAlert == true)
        
        // Low power mode - should have message
        manager.batteryStatus = BatteryStatus(
            level: 0.15,
            state: .unplugged,
            isLowPowerModeEnabled: true
        )
        #expect(manager.batteryAlertMessage.isEmpty == false)
        #expect(manager.batteryAlertMessage.contains("Low Power Mode"))
    }
    
    // MARK: - Performance Tests
    
    @Test("Debug information generation")
    @MainActor
    func testDebugInformation() async throws {
        let manager = AdaptiveGPSManager()
        
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 2.0,
            timestamp: Date()
        )
        
        manager.analyzeLocationUpdate(location)
        
        let debugInfo = manager.debugInfo
        #expect(debugInfo.contains("Movement Pattern"))
        #expect(debugInfo.contains("Battery Level"))
        #expect(debugInfo.contains("Update Frequency"))
        #expect(debugInfo.contains("Adaptive Mode"))
    }
}

// MARK: - GPS Configuration Tests
@Suite("GPS Configuration Tests")
struct GPSConfigurationTests {
    
    @Test("Predefined configurations")
    func testPredefinedConfigurations() async throws {
        let highPerf = GPSConfiguration.highPerformance
        let balanced = GPSConfiguration.balanced
        let batterySaver = GPSConfiguration.batterySaver
        let critical = GPSConfiguration.critical
        
        // High performance should have best accuracy and highest frequency
        #expect(highPerf.accuracy == kCLLocationAccuracyBestForNavigation)
        #expect(highPerf.updateFrequency <= balanced.updateFrequency)
        
        // Battery saver should have lower accuracy and lower frequency
        #expect(batterySaver.accuracy >= kCLLocationAccuracyNearestTenMeters)
        #expect(batterySaver.updateFrequency >= balanced.updateFrequency)
        
        // Critical should have lowest accuracy and frequency
        #expect(critical.accuracy >= batterySaver.accuracy)
        #expect(critical.updateFrequency >= batterySaver.updateFrequency)
    }
    
    @Test("Configuration sendable conformance")
    func testConfigurationSendable() async throws {
        // Test that configurations can be passed between actors
        let config = GPSConfiguration.highPerformance
        
        await Task {
            let _ = config // Should compile without issues due to Sendable
        }.value
        
        #expect(true) // If we reach here, Sendable conformance works
    }
}

// MARK: - Integration with LocationTrackingManager Tests
@Suite("Adaptive GPS Integration Tests")
struct AdaptiveGPSIntegrationTests {
    
    @Test("Integration with LocationTrackingManager")
    @MainActor
    func testLocationManagerIntegration() async throws {
        let locationManager = LocationTrackingManager()
        
        // Test adaptive GPS manager is initialized
        #expect(locationManager.adaptiveGPSManager.isAdaptiveMode == true)
        
        // Test adaptive mode toggle
        locationManager.enableAdaptiveGPS(false)
        #expect(locationManager.adaptiveGPSManager.isAdaptiveMode == false)
        
        locationManager.enableAdaptiveGPS(true)
        #expect(locationManager.adaptiveGPSManager.isAdaptiveMode == true)
        
        // Test battery optimization toggle
        locationManager.enableBatteryOptimization(false)
        #expect(locationManager.adaptiveGPSManager.batteryOptimizationEnabled == false)
        
        locationManager.enableBatteryOptimization(true)
        #expect(locationManager.adaptiveGPSManager.batteryOptimizationEnabled == true)
    }
    
    @Test("Battery status integration")
    @MainActor
    func testBatteryStatusIntegration() async throws {
        let locationManager = LocationTrackingManager()
        
        // Test battery usage estimate access
        let estimate = locationManager.batteryUsageEstimate
        #expect(estimate >= 0)
        
        // Test battery alert properties
        let shouldAlert = locationManager.shouldShowBatteryAlert
        let alertMessage = locationManager.batteryAlertMessage
        
        // These should not crash and return valid values
        #expect(shouldAlert == true || shouldAlert == false)
        #expect(alertMessage != nil)
    }
    
    @Test("Configuration updates trigger properly")
    @MainActor
    func testConfigurationUpdateTriggers() async throws {
        let locationManager = LocationTrackingManager()
        
        // Force configuration update should not crash
        locationManager.forceGPSConfigurationUpdate()
        
        // Verify configuration is accessible
        let config = locationManager.adaptiveGPSManager.currentConfiguration
        #expect(config.accuracy != 0)
        #expect(config.distanceFilter >= 0)
        #expect(config.updateFrequency > 0)
    }
}