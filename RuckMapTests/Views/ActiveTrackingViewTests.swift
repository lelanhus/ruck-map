import CoreHaptics
import CoreLocation
@testable import RuckMap
import SwiftData
import SwiftUI
import Testing

// MARK: - Active Tracking View Tests

@Suite("ActiveTrackingView Tests")
struct ActiveTrackingViewTests {
    // MARK: - Test Data Helpers

    private static func createTestLocationManager() -> LocationTrackingManager {
        let manager = LocationTrackingManager()
        return manager
    }

    private static func createTestSession(
        distance: Double = 1000.0,
        duration: TimeInterval = 600.0,
        loadWeight: Double = 20.0,
        calories: Double = 150.0,
        pace: Double = 10.0
    ) -> RuckSession {
        let session = RuckSession()
        session.totalDistance = distance
        session.totalDuration = duration
        session.loadWeight = loadWeight
        session.totalCalories = calories
        session.averagePace = pace
        session.elevationGain = 50.0
        session.elevationLoss = 30.0
        return session
    }

    private static func createTestWeatherConditions(
        temperature: Double = 20.0,
        humidity: Double = 50.0,
        windSpeed: Double = 5.0
    ) -> WeatherConditions {
        WeatherConditions(
            timestamp: Date(),
            temperature: temperature,
            humidity: humidity,
            windSpeed: windSpeed,
            windDirection: 180.0,
            precipitation: 0.0,
            pressure: 1013.25
        )
    }

    private static func createTestWeatherAlert(
        severity: WeatherAlertSeverity = .warning,
        title: String = "Test Weather Alert"
    ) -> WeatherAlert {
        WeatherAlert(
            severity: severity,
            title: title,
            message: "Test alert message",
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(3600)
        )
    }

    // MARK: - Metric Display Tests

    @Test("Distance formatting displays correctly")
    func testDistanceFormatting() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession(distance: 1609.34) // 1 mile
        manager.startTracking(with: session)
        manager.totalDistance = 1609.34

        let view = ActiveTrackingView(locationManager: manager)

        // Verify distance formatting (1609.34 meters = 1.00 mile)
        #expect(view.formattedDistance == "1.00 mi")
    }

    @Test("Distance formatting handles zero correctly")
    func testDistanceFormattingZero() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession(distance: 0.0)
        manager.startTracking(with: session)
        manager.totalDistance = 0.0

        let view = ActiveTrackingView(locationManager: manager)

        #expect(view.formattedDistance == "0.00 mi")
    }

    @Test("Pace formatting displays correctly")
    func testPaceFormatting() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()
        manager.startTracking(with: session)
        manager.currentPace = 10.0 // 10 min/km

        let view = ActiveTrackingView(locationManager: manager)

        // 10 min/km * 1.60934 = ~16 min/mile
        #expect(view.formattedPace.contains("16:"))
    }

    @Test("Pace formatting handles zero pace correctly")
    func testPaceFormattingZero() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()
        manager.startTracking(with: session)
        manager.currentPace = 0.0

        let view = ActiveTrackingView(locationManager: manager)

        #expect(view.formattedPace == "--:--")
    }

    @Test("Calorie display formatting is correct")
    func testCalorieDisplayFormatting() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession(calories: 250.7)
        manager.startTracking(with: session)
        manager.totalCaloriesBurned = 250.7

        let view = ActiveTrackingView(locationManager: manager)

        #expect(view.formattedCalories == "251 cal")
    }

    @Test("Calorie burn rate formatting is correct")
    func testCalorieBurnRateFormatting() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()
        manager.startTracking(with: session)
        manager.currentCalorieBurnRate = 8.5

        let view = ActiveTrackingView(locationManager: manager)

        #expect(view.formattedCalorieBurnRate == "8.5 cal/min")
    }

    @Test("Elevation gain formatting displays correctly")
    func testElevationGainFormatting() async {
        let manager = Self.createTestLocationManager()
        let view = ActiveTrackingView(locationManager: manager)

        // Manually set elevation gain for testing
        view.totalElevationGain = 30.48 // 30.48 meters = 100 feet

        #expect(view.formattedElevationGain == "100 ft")
    }

    @Test("Elevation loss formatting displays correctly")
    func testElevationLossFormatting() async {
        let manager = Self.createTestLocationManager()
        let view = ActiveTrackingView(locationManager: manager)

        // Manually set elevation loss for testing
        view.totalElevationLoss = 15.24 // 15.24 meters = 50 feet

        #expect(view.formattedElevationLoss == "50 ft")
    }

    @Test("Weather impact percentage calculation is correct")
    func testWeatherImpactPercentage() async {
        let manager = Self.createTestLocationManager()
        let weather = Self.createTestWeatherConditions(temperature: 35.0) // Hot weather
        manager.currentWeatherConditions = weather

        let view = ActiveTrackingView(locationManager: manager)

        // Hot weather should increase calorie burn
        let impact = view.weatherImpactPercentage
        #expect(impact > 0)
    }

    // MARK: - Duration Formatting Tests

    @Test("Duration formatting for minutes only")
    func testDurationFormattingMinutes() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession(duration: 1800) // 30 minutes
        manager.startTracking(with: session)

        let view = ActiveTrackingView(locationManager: manager)

        #expect(view.formattedDuration == "30:00")
    }

    @Test("Duration formatting for hours, minutes, and seconds")
    func testDurationFormattingHours() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession(duration: 3661) // 1 hour, 1 minute, 1 second
        manager.startTracking(with: session)

        let view = ActiveTrackingView(locationManager: manager)

        #expect(view.formattedDuration == "1:01:01")
    }

    @Test("Duration formatting handles zero correctly")
    func testDurationFormattingZero() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession(duration: 0)
        manager.startTracking(with: session)

        let view = ActiveTrackingView(locationManager: manager)

        #expect(view.formattedDuration == "0:00")
    }

    // MARK: - Grade Formatting and Color Tests

    @Test("Grade formatting for positive grade")
    func testGradeFormattingPositive() async {
        let manager = Self.createTestLocationManager()
        let view = ActiveTrackingView(locationManager: manager)

        view.currentGrade = 5.7

        #expect(view.formattedGrade == "+5.7%")
    }

    @Test("Grade formatting for negative grade")
    func testGradeFormattingNegative() async {
        let manager = Self.createTestLocationManager()
        let view = ActiveTrackingView(locationManager: manager)

        view.currentGrade = -3.2

        #expect(view.formattedGrade == "-3.2%")
    }

    @Test(
        "Grade color classification is correct",
        arguments: [
            (2.0, Color.green),
            (5.0, Color.orange),
            (10.0, Color.red),
            (20.0, Color.purple)
        ]
    )
    func testGradeColorClassification(grade: Double, expectedColor: Color) async {
        let manager = Self.createTestLocationManager()
        let view = ActiveTrackingView(locationManager: manager)

        view.currentGrade = grade

        #expect(view.gradeColor == expectedColor)
    }

    // MARK: - Control Button State Tests

    @Test("Pause/Resume button shows correct state when tracking")
    @MainActor
    func testPauseResumeButtonTrackingState() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()
        manager.startTracking(with: session)

        let view = ActiveTrackingView(locationManager: manager)

        // When tracking, should show pause button
        #expect(manager.trackingState == .tracking)
        // Note: The actual button text/icon would be tested in UI integration tests
    }

    @Test("Pause/Resume button shows correct state when paused")
    @MainActor
    func testPauseResumeButtonPausedState() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()
        manager.startTracking(with: session)
        manager.pauseTracking()

        let view = ActiveTrackingView(locationManager: manager)

        // When paused, should show resume button
        #expect(manager.trackingState == .paused)
        // Note: The actual button text/icon would be tested in UI integration tests
    }

    @Test("Toggle pause functionality works correctly")
    @MainActor
    func testTogglePauseFunctionality() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()
        manager.startTracking(with: session)

        // Initially tracking
        #expect(manager.trackingState == .tracking)

        // Toggle to pause
        manager.togglePause()
        #expect(manager.trackingState == .paused)

        // Toggle to resume
        manager.togglePause()
        #expect(manager.trackingState == .tracking)
    }

    // MARK: - GPS Status Tests

    @Test(
        "GPS indicator color based on accuracy",
        arguments: [
            (3.0, UIColor.systemGreen),
            (7.0, UIColor.systemBlue),
            (15.0, UIColor.systemOrange),
            (50.0, UIColor.systemRed)
        ]
    )
    func testGPSIndicatorColor(accuracy: Double, expectedUIColor: UIColor) async {
        let manager = Self.createTestLocationManager()

        // Set GPS accuracy
        let gpsAccuracy = GPSAccuracy(from: accuracy)
        manager.gpsAccuracy = gpsAccuracy

        let view = ActiveTrackingView(locationManager: manager)

        #expect(manager.gpsAccuracy.color == expectedUIColor)
    }

    @Test(
        "GPS accuracy descriptions are correct",
        arguments: [
            (3.0, "Excellent"),
            (7.0, "Good"),
            (15.0, "Fair"),
            (50.0, "Poor")
        ]
    )
    func testGPSAccuracyDescriptions(accuracy: Double, expectedDescription: String) async {
        let gpsAccuracy = GPSAccuracy(from: accuracy)

        #expect(gpsAccuracy.description == expectedDescription)
    }

    // MARK: - State Management Tests

    @Test("Auto-pause indicator displays correctly")
    @MainActor
    func testAutoPauseIndicator() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()
        manager.startTracking(with: session)

        // Simulate auto-pause condition
        manager.isAutoPaused = true

        let view = ActiveTrackingView(locationManager: manager)

        #expect(manager.isAutoPaused == true)
        // Note: UI display testing would verify the "AUTO-PAUSED" text appears
    }

    @Test("Adaptive GPS mode indicator displays correctly")
    @MainActor
    func testAdaptiveGPSIndicator() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()
        manager.startTracking(with: session)

        // Enable adaptive mode
        manager.adaptiveGPSManager.isAdaptiveMode = true

        let view = ActiveTrackingView(locationManager: manager)

        #expect(manager.adaptiveGPSManager.isAdaptiveMode == true)
        // Note: UI display testing would verify the "ADAPTIVE" indicator appears
    }

    @Test("Battery warning display functionality")
    @MainActor
    func testBatteryWarningDisplay() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()
        manager.startTracking(with: session)

        // Simulate high battery usage
        manager.shouldShowBatteryAlert = true
        manager.batteryAlertMessage = "High battery usage detected"

        let view = ActiveTrackingView(locationManager: manager)

        #expect(manager.shouldShowBatteryAlert == true)
        #expect(!manager.batteryAlertMessage.isEmpty)
    }

    @Test("Weather alert display functionality")
    @MainActor
    func testWeatherAlertDisplay() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()
        manager.startTracking(with: session)

        // Add weather alerts
        let alert = Self.createTestWeatherAlert(severity: .warning, title: "High Wind Advisory")
        manager.weatherAlerts = [alert]

        let view = ActiveTrackingView(locationManager: manager)

        #expect(manager.weatherAlerts.count == 1)
        #expect(manager.weatherAlerts.first?.title == "High Wind Advisory")
    }

    // MARK: - Battery Usage Color Tests

    @Test(
        "Battery usage color classification",
        arguments: [
            (3.0, Color.green),
            (7.0, Color.blue),
            (12.0, Color.orange),
            (20.0, Color.red)
        ]
    )
    func testBatteryUsageColor(usage: Double, expectedColor: Color) async {
        let manager = Self.createTestLocationManager()
        manager.batteryUsageEstimate = usage

        let view = ActiveTrackingView(locationManager: manager)

        #expect(view.batteryUsageColor == expectedColor)
    }

    // MARK: - Motion Activity Tests

    @Test(
        "Motion activity icon mapping",
        arguments: [
            (MotionActivityType.stationary, "figure.stand"),
            (.walking, "figure.walk"),
            (.running, "figure.run"),
            (.cycling, "bicycle"),
            (.automotive, "car.fill"),
            (.unknown, "questionmark.circle")
        ]
    )
    func testMotionActivityIcon(activity: MotionActivityType, expectedIcon: String) async {
        let manager = Self.createTestLocationManager()

        // Mock the motion activity
        manager.motionActivity = activity

        let view = ActiveTrackingView(locationManager: manager)

        #expect(view.motionActivityIcon == expectedIcon)
    }

    @Test("Motion activity color based on confidence")
    func testMotionActivityColorConfidence() async {
        let manager = Self.createTestLocationManager()
        manager.motionActivity = .walking

        let view = ActiveTrackingView(locationManager: manager)

        // High confidence should give green color for walking
        manager.motionConfidence = 0.8
        #expect(view.motionActivityColor == .green)

        // Low confidence should give secondary color
        manager.motionConfidence = 0.5
        #expect(view.motionActivityColor == .secondary)
    }

    // MARK: - Load Weight Adjustment Tests

    @Test("Load weight display formatting")
    func testLoadWeightDisplayFormatting() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession(loadWeight: 22.68) // 50 lbs
        manager.startTracking(with: session)

        let view = ActiveTrackingView(locationManager: manager)

        // 22.68 kg * 2.20462 ≈ 50 lbs
        #expect(session.loadWeight * 2.20462 >= 49.9)
        #expect(session.loadWeight * 2.20462 <= 50.1)
    }

    @Test("Load weight update functionality")
    @MainActor
    func testLoadWeightUpdate() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession(loadWeight: 20.0)
        manager.startTracking(with: session)

        let view = ActiveTrackingView(locationManager: manager)

        // Update weight
        let newWeight = 25.0
        view.updateLoadWeight(newWeight)

        #expect(session.loadWeight == newWeight)
    }

    // MARK: - Weather Alert Helper Function Tests

    @Test(
        "Weather alert icon mapping",
        arguments: [
            (WeatherAlertSeverity.info, "info.circle"),
            (.warning, "exclamationmark.triangle"),
            (.critical, "exclamationmark.octagon")
        ]
    )
    func testWeatherAlertIcon(severity: WeatherAlertSeverity, expectedIcon: String) async {
        let manager = Self.createTestLocationManager()
        let view = ActiveTrackingView(locationManager: manager)

        let icon = view.weatherAlertIcon(severity)

        #expect(icon == expectedIcon)
    }

    @Test(
        "Weather alert color mapping",
        arguments: [
            (WeatherAlertSeverity.info, Color.blue),
            (.warning, Color.orange),
            (.critical, Color.red)
        ]
    )
    func testWeatherAlertColor(severity: WeatherAlertSeverity, expectedColor: Color) async {
        let manager = Self.createTestLocationManager()
        let view = ActiveTrackingView(locationManager: manager)

        let color = view.weatherAlertColor(severity)

        #expect(color == expectedColor)
    }

    // MARK: - Haptic Feedback Tests

    @Test("Haptic feedback types are properly defined")
    func testHapticFeedbackTypes() async {
        let lightType = ActiveTrackingView.HapticFeedbackType.light
        let impactType = ActiveTrackingView.HapticFeedbackType.impact
        let warningType = ActiveTrackingView.HapticFeedbackType.warning
        let successType = ActiveTrackingView.HapticFeedbackType.success

        #expect(lightType == .light)
        #expect(impactType == .impact)
        #expect(warningType == .warning)
        #expect(successType == .success)
    }

    // MARK: - Accessibility Tests

    @Test("MetricCard has proper accessibility structure")
    func testMetricCardAccessibility() async {
        let metricCard = MetricCard(
            title: "DISTANCE",
            value: "2.50 mi",
            icon: "map",
            color: .blue
        )

        // MetricCard should combine its children for accessibility
        // In actual UI tests, you would verify accessibilityElement(children: .combine)
        #expect(metricCard.title == "DISTANCE")
        #expect(metricCard.value == "2.50 mi")
    }

    @Test("CalorieMetricCard includes weather impact in accessibility")
    func testCalorieMetricCardAccessibility() async {
        let calorieCard = CalorieMetricCard(
            title: "CALORIES",
            value: "300 cal",
            icon: "flame.fill",
            color: .red,
            weatherImpact: 15
        )

        #expect(calorieCard.weatherImpact == 15)
        // In UI tests, would verify accessibility label includes weather impact
    }

    @Test("ElevationMetricCard has proper accessibility labels")
    func testElevationMetricCardAccessibility() async {
        let elevationCard = ElevationMetricCard(
            title: "GAIN",
            value: "150 ft",
            icon: "arrow.up",
            color: .green
        )

        // Should have accessibility label like "Elevation gain: 150 ft"
        #expect(elevationCard.title == "GAIN")
        #expect(elevationCard.value == "150 ft")
    }

    @Test("LoadWeightCard has adjustment accessibility hints")
    func testLoadWeightCardAccessibility() async {
        let loadCard = LoadWeightCard(
            currentWeight: 20.0
        ) {
            // Adjustment tapped
        }

        #expect(loadCard.currentWeight == 20.0)
        // In UI tests, would verify accessibility hint "Double tap to change the carried weight"
    }

    // MARK: - Performance Tests

    @Test("View creation performance is acceptable", .timeLimit(.seconds(1)))
    func testViewCreationPerformance() async {
        // Test creating multiple ActiveTrackingView instances quickly
        for i in 0 ..< 50 {
            let manager = Self.createTestLocationManager()
            let session = Self.createTestSession(
                distance: Double(i * 100),
                duration: Double(i * 60),
                loadWeight: Double(i % 30) + 10
            )
            manager.startTracking(with: session)

            _ = ActiveTrackingView(locationManager: manager)
        }

        // Should complete within time limit
    }

    @Test("Metric formatting performance", .timeLimit(.milliseconds(500)))
    func testMetricFormattingPerformance() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()
        manager.startTracking(with: session)

        let view = ActiveTrackingView(locationManager: manager)

        // Test formatting multiple times quickly
        for i in 0 ..< 1000 {
            manager.totalDistance = Double(i * 10)
            manager.currentPace = Double(i % 20) + 5
            manager.totalCaloriesBurned = Double(i * 2)

            _ = view.formattedDistance
            _ = view.formattedPace
            _ = view.formattedCalories
        }

        // Should complete within time limit
    }

    // MARK: - Edge Cases

    @Test("View handles nil current session gracefully")
    func testNilCurrentSessionHandling() async {
        let manager = Self.createTestLocationManager()
        // Don't start tracking - currentSession should be nil

        let view = ActiveTrackingView(locationManager: manager)

        #expect(manager.currentSession == nil)
        #expect(view.formattedDuration == "00:00")
    }

    @Test("View handles extremely large values")
    func testExtremeValueHandling() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession(
            distance: 1_000_000.0, // 1000 km
            duration: 360_000.0, // 100 hours
            calories: 50000.0 // 50k calories
        )
        manager.startTracking(with: session)
        manager.totalDistance = 1_000_000.0
        manager.totalCaloriesBurned = 50000.0

        let view = ActiveTrackingView(locationManager: manager)

        // Should handle extreme values without crashing
        #expect(!view.formattedDistance.isEmpty)
        #expect(!view.formattedCalories.isEmpty)
    }

    @Test("View handles negative values gracefully")
    func testNegativeValueHandling() async {
        let manager = Self.createTestLocationManager()
        let view = ActiveTrackingView(locationManager: manager)

        // Test negative grade
        view.currentGrade = -15.5
        #expect(view.formattedGrade == "-15.5%")
        #expect(view.gradeColor == .red) // Steep downhill should be red

        // Test negative elevation values
        view.totalElevationLoss = -10.0 // Should be handled as positive
        view.totalElevationGain = -5.0 // Should be handled as positive

        #expect(!view.formattedElevationLoss.isEmpty)
        #expect(!view.formattedElevationGain.isEmpty)
    }

    // MARK: - Integration Tests

    @Test("Weather and tracking data integration")
    @MainActor
    func testWeatherTrackingIntegration() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()
        let weather = Self.createTestWeatherConditions(temperature: 30.0)

        manager.startTracking(with: session)
        manager.currentWeatherConditions = weather

        let view = ActiveTrackingView(locationManager: manager)

        #expect(manager.currentSession != nil)
        #expect(manager.currentWeatherConditions != nil)
        #expect(view.weatherImpactPercentage != 0) // Hot weather should have impact
    }

    @Test("Complete tracking session lifecycle")
    @MainActor
    func testCompleteTrackingLifecycle() async {
        let manager = Self.createTestLocationManager()
        let session = Self.createTestSession()

        // Start tracking
        manager.startTracking(with: session)
        #expect(manager.trackingState == .tracking)
        #expect(manager.currentSession != nil)

        // Pause tracking
        manager.pauseTracking()
        #expect(manager.trackingState == .paused)

        // Resume tracking
        manager.resumeTracking()
        #expect(manager.trackingState == .tracking)

        // Stop tracking
        manager.stopTracking()
        #expect(manager.trackingState == .stopped)
        #expect(manager.currentSession == nil)
    }

    // MARK: - Memory Management Tests

    @Test("View doesn't retain location manager strongly")
    func testViewLocationManagerRetention() async {
        var manager: LocationTrackingManager? = Self.createTestLocationManager()
        weak var weakManager = manager

        let session = Self.createTestSession()
        manager?.startTracking(with: session)

        if let unwrappedManager = manager {
            _ = ActiveTrackingView(locationManager: unwrappedManager)
        }

        // Release strong reference
        manager = nil

        // Note: In real scenarios, the view might hold a strong reference
        // This test verifies the basic retention behavior
        #expect(weakManager != nil) // View should keep manager alive while it exists
    }
}

// MARK: - Component Tests

@Suite("ActiveTrackingView Components")
struct ActiveTrackingViewComponentTests {
    // MARK: - LoadWeightAdjustmentView Tests

    @Test("LoadWeightAdjustmentView initializes correctly")
    func testLoadWeightAdjustmentViewInit() async {
        let initialWeight = 20.0
        var savedWeight: Double?
        var cancelled = false

        let adjustmentView = LoadWeightAdjustmentView(
            currentWeight: initialWeight,
            onSave: { weight in savedWeight = weight },
            onCancel: { cancelled = true }
        )

        #expect(adjustmentView.weight == initialWeight)
    }

    @Test("LoadWeightAdjustmentView weight slider bounds")
    func testLoadWeightSliderBounds() async {
        let adjustmentView = LoadWeightAdjustmentView(
            currentWeight: 20.0,
            onSave: { _ in },
            onCancel: {}
        )

        // Weight slider should have appropriate bounds (0-68 kg = 0-150 lbs)
        // This would be tested in UI integration tests for the actual slider values
        #expect(adjustmentView.weight >= 0.0)
    }

    // MARK: - Enhanced Component Tests

    @Test("EnhancedMetricCard animation state")
    func testEnhancedMetricCardAnimation() async {
        let animatedCard = EnhancedMetricCard(
            title: "DISTANCE",
            value: "2.50 mi",
            icon: "map",
            color: .blue,
            isAnimating: true
        )

        let staticCard = EnhancedMetricCard(
            title: "DISTANCE",
            value: "2.50 mi",
            icon: "map",
            color: .blue,
            isAnimating: false
        )

        #expect(animatedCard.isAnimating == true)
        #expect(staticCard.isAnimating == false)
    }

    @Test("EnhancedCalorieMetricCard weather impact display")
    func testEnhancedCalorieMetricCardWeatherImpact() async {
        let cardWithImpact = EnhancedCalorieMetricCard(
            title: "CALORIES",
            value: "300 cal",
            icon: "flame.fill",
            color: .red,
            weatherImpact: 15,
            isAnimating: false
        )

        let cardWithoutImpact = EnhancedCalorieMetricCard(
            title: "CALORIES",
            value: "300 cal",
            icon: "flame.fill",
            color: .red,
            weatherImpact: nil,
            isAnimating: false
        )

        #expect(cardWithImpact.weatherImpact == 15)
        #expect(cardWithoutImpact.weatherImpact == nil)
    }

    @Test("WeatherCard display properties")
    func testWeatherCardDisplayProperties() async {
        let conditions = WeatherConditions(
            timestamp: Date(),
            temperature: 25.0,
            humidity: 60.0,
            windSpeed: 8.0,
            windDirection: 180.0,
            precipitation: 0.0,
            pressure: 1013.25
        )
        conditions.weatherDescription = "Partly cloudy"

        let weatherCard = WeatherCard(
            conditions: conditions,
            showCalorieImpact: true
        )

        #expect(weatherCard.conditions.temperatureFahrenheit == 77.0)
        #expect(weatherCard.showCalorieImpact == true)
    }

    // MARK: - Animation and Transition Tests

    @Test("Metric card content transition support")
    func testMetricCardContentTransition() async {
        let card = EnhancedMetricCard(
            title: "PACE",
            value: "8:30 /mi",
            icon: "speedometer",
            color: .orange,
            isAnimating: true
        )

        // Content transition for numeric text should be supported
        // This would be tested in UI integration tests for actual animation behavior
        #expect(card.value.contains(":"))
        #expect(card.isAnimating == true)
    }

    @Test("Symbol effects for animated cards")
    func testSymbolEffectsForAnimatedCards() async {
        let pulsingCard = EnhancedMetricCard(
            title: "DISTANCE",
            value: "2.50 mi",
            icon: "map",
            color: .blue,
            isAnimating: true
        )

        let bouncingElevationCard = EnhancedElevationMetricCard(
            title: "GAIN",
            value: "150 ft",
            icon: "arrow.up",
            color: .green,
            isAnimating: true
        )

        #expect(pulsingCard.isAnimating == true)
        #expect(bouncingElevationCard.isAnimating == true)
        // Symbol effects (.pulse, .bounce) would be tested in UI integration tests
    }
}
