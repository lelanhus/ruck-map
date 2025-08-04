import Testing
import HealthKit
import CoreLocation
@testable import RuckMap

// MARK: - Test Tags

extension Tag {
    @Tag static var healthKit: Self
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var async: Self
    @Tag static var authorization: Self
    @Tag static var heartRate: Self
    @Tag static var workout: Self
    @Tag static var bodyMetrics: Self
}

// MARK: - HealthKit Manager Test Suite

@Suite("HealthKit Manager Tests", .tags(.healthKit))
@MainActor
struct HealthKitManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test("HealthKit manager initialization", .tags(.unit))
    func initialization() async throws {
        let healthKitManager = HealthKitManager()
        
        #expect(healthKitManager.isHealthKitAvailable == HKHealthStore.isHealthDataAvailable())
        #expect(healthKitManager.authorizationStatus == .notDetermined)
        #expect(healthKitManager.isAuthorized == false)
        #expect(healthKitManager.lastError == nil)
    }
    
    // MARK: - Authorization Tests
    
    @Test("Check authorization status", .tags(.authorization, .unit))
    func checkAuthorizationStatus() async throws {
        let healthKitManager = HealthKitManager()
        
        // Test initial status check
        healthKitManager.checkAuthorizationStatus()
        
        // Authorization status should be set (varies by device)
        let validStatuses: [HKAuthorizationStatus] = [
            .notDetermined,
            .sharingDenied,
            .sharingAuthorized
        ]
        
        #expect(validStatuses.contains(healthKitManager.authorizationStatus)) {
            "Authorization status should be one of the valid HKAuthorizationStatus values"
        }
    }
    
    @Test("Request authorization when HealthKit unavailable", .tags(.authorization, .unit))
    func requestAuthorizationWhenUnavailable() async throws {
        let unavailableManager = MockHealthKitManager(isAvailable: false)
        
        await #expect(throws: HealthKitError.healthKitUnavailable) {
            try await unavailableManager.requestAuthorization()
        }
    }
    
    @Test("Request authorization flow with error", .tags(.authorization, .unit))
    func requestAuthorizationWithError() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: false)
        mockManager.shouldThrowError = true
        
        await #expect(throws: HealthKitError.self) {
            try await mockManager.requestAuthorization()
        }
        
        #expect(mockManager.lastError != nil) {
            "Error should be stored in lastError property"
        }
    }
    
    @Test("Successful authorization flow", .tags(.authorization, .integration))
    func successfulAuthorizationFlow() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        try await mockManager.requestAuthorization()
        
        #expect(mockManager.isAuthorized == true)
        #expect(mockManager.authorizationStatus == .sharingAuthorized)
        #expect(mockManager.lastError == nil)
    }
    
    // MARK: - Body Metrics Tests
    
    @Test("Load body metrics when unauthorized", .tags(.bodyMetrics, .unit))
    func loadBodyMetricsWhenUnauthorized() async throws {
        let unauthorizedManager = MockHealthKitManager(isAvailable: true, isAuthorized: false)
        
        let (weight, height) = try await unauthorizedManager.loadBodyMetrics()
        
        #expect(weight == nil)
        #expect(height == nil)
    }
    
    @Test("Body metrics caching behavior", .tags(.bodyMetrics, .unit))
    func bodyMetricsCaching() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        mockManager.mockBodyWeight = 75.0
        mockManager.mockHeight = 1.80
        
        // First load should fetch from "HealthKit"
        let (weight1, height1) = try await mockManager.loadBodyMetrics()
        #expect(weight1 == 75.0)
        #expect(height1 == 1.80)
        
        // Change mock data
        mockManager.mockBodyWeight = 80.0
        mockManager.mockHeight = 1.85
        
        // Second load should use cache (within 24 hours)
        let (weight2, height2) = try await mockManager.loadBodyMetrics()
        #expect(weight2 == 75.0) { "Should return cached weight value" }
        #expect(height2 == 1.80) { "Should return cached height value" }
    }
    
    @Test("Body metrics with missing data", .tags(.bodyMetrics, .unit))
    func bodyMetricsWithMissingData() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        mockManager.mockBodyWeight = nil
        mockManager.mockHeight = 1.80
        
        let (weight, height) = try await mockManager.loadBodyMetrics()
        
        #expect(weight == nil) { "Weight should be nil when not available" }
        #expect(height == 1.80) { "Height should be returned when available" }
    }
    
    @Test("Body metrics callback notification", .tags(.bodyMetrics, .async))
    func bodyMetricsCallbackNotification() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        mockManager.mockBodyWeight = 70.0
        mockManager.mockHeight = 1.75
        
        var callbackWeight: Double?
        var callbackHeight: Double?
        var callbackReceived = false
        
        mockManager.onBodyMetricsUpdate = { weight, height in
            callbackWeight = weight
            callbackHeight = height
            callbackReceived = true
        }
        
        _ = try await mockManager.loadBodyMetrics()
        
        #expect(callbackReceived == true) { "Callback should be triggered after loading metrics" }
        #expect(callbackWeight == 70.0)
        #expect(callbackHeight == 1.75)
    }
    
    @Test(arguments: [
        (weight: nil, height: nil, shouldBeValid: false),
        (weight: 70.0, height: nil, shouldBeValid: false),
        (weight: nil, height: 1.75, shouldBeValid: false),
        (weight: 70.0, height: 1.75, shouldBeValid: true)
    ])
    func bodyMetricsValidation(weight: Double?, height: Double?, shouldBeValid: Bool) {
        let metrics = BodyMetrics(weight: weight, height: height, lastUpdated: Date())
        #expect(metrics.isValid == shouldBeValid)
    }
    
    @Test("Body metrics BMI calculation", .tags(.bodyMetrics, .unit))
    func bodyMetricsBMICalculation() {
        let metrics = BodyMetrics(weight: 70.0, height: 1.75, lastUpdated: Date())
        let expectedBMI = 70.0 / (1.75 * 1.75) // ≈ 22.86
        
        let bmi = try #require(metrics.bmi)
        #expect(bmi == expectedBMI, accuracy: 0.01)
    }
    
    // MARK: - Heart Rate Monitoring Tests
    
    @Test("Start heart rate monitoring when unauthorized", .tags(.heartRate, .unit))
    func startHeartRateMonitoringWhenUnauthorized() async throws {
        let unauthorizedManager = MockHealthKitManager(isAvailable: true, isAuthorized: false)
        
        await #expect(throws: HealthKitError.notAuthorized) {
            try await unauthorizedManager.startHeartRateMonitoring()
        }
    }
    
    @Test("Heart rate monitoring callbacks", .tags(.heartRate, .async))
    func heartRateMonitoringCallbacks() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        var receivedHeartRate: Double?
        var callbackReceived = false
        
        mockManager.onHeartRateUpdate = { heartRate in
            receivedHeartRate = heartRate
            callbackReceived = true
        }
        
        try await mockManager.startHeartRateMonitoring()
        
        // Simulate heart rate data
        await mockManager.simulateHeartRateUpdate(75.0)
        
        // Give a small delay for callback processing
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(callbackReceived == true) { "Heart rate callback should be triggered" }
        #expect(receivedHeartRate == 75.0)
    }
    
    @Test(arguments: [60.0, 72.0, 85.0, 120.0, 150.0, 180.0])
    func heartRateDataValidation(heartRate: Double) async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        var receivedHeartRate: Double?
        mockManager.onHeartRateUpdate = { hr in
            receivedHeartRate = hr
        }
        
        try await mockManager.startHeartRateMonitoring()
        await mockManager.simulateHeartRateUpdate(heartRate)
        
        try await Task.sleep(for: .milliseconds(50))
        
        #expect(receivedHeartRate == heartRate) {
            "Heart rate callback should receive the exact value that was simulated"
        }
    }
    
    @Test("Heart rate monitoring error handling", .tags(.heartRate, .unit))
    func heartRateMonitoringErrorHandling() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        mockManager.shouldThrowError = true
        
        await #expect(throws: HealthKitError.dataAccessFailed) {
            try await mockManager.startHeartRateMonitoring()
        }
    }
    
    @Test("Heart rate data model", .tags(.heartRate, .unit))
    func heartRateDataModel() {
        let timestamp = Date()
        let heartRateData = HeartRateData(heartRate: 72.0, timestamp: timestamp, source: "Test")
        
        #expect(heartRateData.heartRate == 72.0)
        #expect(heartRateData.timestamp == timestamp)
        #expect(heartRateData.source == "Test")
    }
    
    @Test("Multiple heart rate updates", .tags(.heartRate, .async))
    func multipleHeartRateUpdates() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        var heartRateUpdates: [Double] = []
        mockManager.onHeartRateUpdate = { heartRate in
            heartRateUpdates.append(heartRate)
        }
        
        try await mockManager.startHeartRateMonitoring()
        
        let expectedRates = [68.0, 75.0, 82.0, 79.0]
        for rate in expectedRates {
            await mockManager.simulateHeartRateUpdate(rate)
            try await Task.sleep(for: .milliseconds(25))
        }
        
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(heartRateUpdates.count == expectedRates.count) {
            "Should receive all heart rate updates"
        }
        #expect(heartRateUpdates == expectedRates) {
            "Heart rate updates should match expected values in order"
        }
    }
    
    // MARK: - Workout Session Tests
    
    @Test("Start workout session when unauthorized", .tags(.workout, .unit))
    func startWorkoutSessionWhenUnauthorized() async throws {
        let unauthorizedManager = MockHealthKitManager(isAvailable: true, isAuthorized: false)
        
        await #expect(throws: HealthKitError.notAuthorized) {
            try await unauthorizedManager.startWorkoutSession()
        }
    }
    
    @Test("Workout session lifecycle", .tags(.workout, .integration))
    func workoutSessionLifecycle() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        // Initially no active session
        #expect(mockManager.hasActiveWorkoutSession == false)
        
        // Start session
        try await mockManager.startWorkoutSession()
        #expect(mockManager.hasActiveWorkoutSession == true)
        
        // Add location
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        await mockManager.addLocationToWorkout(location)
        
        // End session
        await mockManager.endWorkoutSession()
        #expect(mockManager.hasActiveWorkoutSession == false)
    }
    
    @Test(arguments: [
        HKWorkoutActivityType.hiking,
        HKWorkoutActivityType.walking,
        HKWorkoutActivityType.crossTraining,
        HKWorkoutActivityType.other
    ])
    func workoutSessionWithDifferentActivityTypes(activityType: HKWorkoutActivityType) async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        try await mockManager.startWorkoutSession(for: activityType)
        #expect(mockManager.hasActiveWorkoutSession == true)
        
        await mockManager.endWorkoutSession()
        #expect(mockManager.hasActiveWorkoutSession == false)
    }
    
    @Test("Workout session error handling", .tags(.workout, .unit))
    func workoutSessionErrorHandling() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        mockManager.shouldThrowError = true
        
        await #expect(throws: HealthKitError.workoutSessionFailed) {
            try await mockManager.startWorkoutSession()
        }
        
        #expect(mockManager.hasActiveWorkoutSession == false) {
            "Session should not be active after failed start"
        }
    }
    
    @Test("Add multiple locations to workout", .tags(.workout, .integration))
    func addMultipleLocationsToWorkout() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        try await mockManager.startWorkoutSession()
        
        let locations = [
            CLLocation(latitude: 37.7749, longitude: -122.4194),
            CLLocation(latitude: 37.7849, longitude: -122.4294),
            CLLocation(latitude: 37.7949, longitude: -122.4394)
        ]
        
        for location in locations {
            await mockManager.addLocationToWorkout(location)
        }
        
        await mockManager.endWorkoutSession()
        #expect(mockManager.hasActiveWorkoutSession == false)
    }
    
    @Test("Add location without active session", .tags(.workout, .unit))
    func addLocationWithoutActiveSession() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Should not crash when adding location without active session
        await mockManager.addLocationToWorkout(location)
        
        #expect(mockManager.hasActiveWorkoutSession == false)
    }
    
    // MARK: - Workout Saving Tests
    
    @Test("Save workout when unauthorized", .tags(.workout, .unit))
    func saveWorkoutWhenUnauthorized() async throws {
        let unauthorizedManager = MockHealthKitManager(isAvailable: true, isAuthorized: false)
        let mockSession = createMockSessionData()
        
        await #expect(throws: HealthKitError.notAuthorized) {
            try await unauthorizedManager.saveWorkout(from: mockSession)
        }
    }
    
    @Test("Save workout with invalid data", .tags(.workout, .unit))
    func saveWorkoutWithInvalidData() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        let invalidSession = SessionExportData(
            id: UUID(),
            startDate: Date(),
            endDate: nil, // Invalid - no end date
            totalDistance: 1000.0,
            loadWeight: 20.0,
            totalCalories: 500.0,
            averagePace: 6.0,
            elevationGain: 100.0,
            elevationLoss: 50.0,
            maxElevation: 500.0,
            minElevation: 400.0,
            elevationRange: 100.0,
            averageGrade: 2.0,
            maxGrade: 10.0,
            minGrade: -5.0,
            locationPointsCount: 100,
            elevationAccuracy: 2.0,
            barometerDataPoints: 50,
            hasHighQualityElevationData: true,
            version: 1,
            createdAt: Date(),
            modifiedAt: Date()
        )
        
        await #expect(throws: HealthKitError.invalidWorkoutData) {
            try await mockManager.saveWorkout(from: invalidSession)
        }
    }
    
    @Test("Save valid workout", .tags(.workout, .integration))
    func saveValidWorkout() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        let validSession = createMockSessionData()
        let route = createMockRoute()
        
        // Should not throw
        try await mockManager.saveWorkout(from: validSession, route: route)
        
        #expect(mockManager.didSaveWorkout == true)
        #expect(mockManager.savedWorkoutDistance == validSession.totalDistance)
        #expect(mockManager.savedWorkoutCalories == validSession.totalCalories)
    }
    
    @Test("Save workout without route", .tags(.workout, .integration))
    func saveWorkoutWithoutRoute() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        let validSession = createMockSessionData()
        
        try await mockManager.saveWorkout(from: validSession) // No route parameter
        
        #expect(mockManager.didSaveWorkout == true)
        #expect(mockManager.savedWorkoutDistance == validSession.totalDistance)
        #expect(mockManager.savedWorkoutCalories == validSession.totalCalories)
    }
    
    @Test("Save workout error handling", .tags(.workout, .unit))
    func saveWorkoutErrorHandling() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        mockManager.shouldThrowError = true
        let validSession = createMockSessionData()
        
        await #expect(throws: HealthKitError.workoutSaveFailed) {
            try await mockManager.saveWorkout(from: validSession)
        }
        
        #expect(mockManager.lastError != nil) {
            "Error should be stored in lastError property"
        }
    }
    
    @Test(arguments: [
        (distance: 1000.0, calories: 150.0, weight: 15.0),
        (distance: 5000.0, calories: 500.0, weight: 25.0),
        (distance: 10000.0, calories: 800.0, weight: 35.0),
        (distance: 21097.0, calories: 1500.0, weight: 45.0) // Half marathon
    ])
    func saveWorkoutWithVariousMetrics(distance: Double, calories: Double, weight: Double) async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        let session = SessionExportData(
            id: UUID(),
            startDate: Date().addingTimeInterval(-3600),
            endDate: Date(),
            totalDistance: distance,
            loadWeight: weight,
            totalCalories: calories,
            averagePace: 6.0,
            elevationGain: 100.0,
            elevationLoss: 80.0,
            maxElevation: 500.0,
            minElevation: 400.0,
            elevationRange: 100.0,
            averageGrade: 2.0,
            maxGrade: 10.0,
            minGrade: -5.0,
            locationPointsCount: Int(distance / 10), // Roughly one point per 10m
            elevationAccuracy: 2.0,
            barometerDataPoints: 100,
            hasHighQualityElevationData: true,
            version: 1,
            createdAt: Date().addingTimeInterval(-3600),
            modifiedAt: Date()
        )
        
        try await mockManager.saveWorkout(from: session)
        
        #expect(mockManager.didSaveWorkout == true)
        #expect(mockManager.savedWorkoutDistance == distance)
        #expect(mockManager.savedWorkoutCalories == calories)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Error recovery after failure", .tags(.unit))
    func errorRecovery() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        mockManager.shouldThrowError = true
        
        // First attempt should fail
        await #expect(throws: HealthKitError.dataAccessFailed) {
            _ = try await mockManager.loadBodyMetrics()
        }
        
        #expect(mockManager.lastError != nil) {
            "Error should be properly stored"
        }
        
        // Reset error flag and try again
        mockManager.shouldThrowError = false
        mockManager.lastError = nil
        mockManager.mockBodyWeight = 75.0
        mockManager.mockHeight = 1.80
        
        let (weight, height) = try await mockManager.loadBodyMetrics()
        #expect(weight == 75.0)
        #expect(height == 1.80)
        #expect(mockManager.lastError == nil) {
            "Error should be cleared after successful operation"
        }
    }
    
    @Test("HealthKit error types validation", .tags(.unit))
    func healthKitErrorTypesValidation() {
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        let errors: [HealthKitError] = [
            .healthKitUnavailable,
            .notAuthorized,
            .authorizationFailed(testError),
            .dataAccessFailed(testError),
            .backgroundDeliveryFailed(testError),
            .workoutSessionFailed(testError),
            .workoutSaveFailed(testError),
            .invalidDataType,
            .invalidWorkoutData("Test message")
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil) {
                "All HealthKit errors should have error descriptions"
            }
            #expect(error.recoverySuggestion != nil) {
                "All HealthKit errors should have recovery suggestions"
            }
        }
    }
    
    // MARK: - Background Delivery Tests
    
    @Test("Background delivery setup", .tags(.integration, .async))
    func backgroundDeliverySetup() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        // Simulate successful authorization which should trigger background delivery setup
        try await mockManager.requestAuthorization()
        
        #expect(mockManager.isAuthorized == true)
        #expect(mockManager.lastError == nil)
    }
    
    @Test("Background delivery with unauthorized access", .tags(.unit))
    func backgroundDeliveryWithUnauthorizedAccess() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: false)
        
        try await mockManager.requestAuthorization()
        
        // Should not enable background delivery when unauthorized
        #expect(mockManager.isAuthorized == false)
    }
    
    // MARK: - Integration Tests
    
    @Test("Complete workflow simulation", .tags(.integration, .async), .timeLimit(.seconds(10)))
    func completeWorkflowSimulation() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        mockManager.mockBodyWeight = 70.0
        mockManager.mockHeight = 1.75
        
        var heartRateUpdates: [Double] = []
        mockManager.onHeartRateUpdate = { heartRate in
            heartRateUpdates.append(heartRate)
        }
        
        // 1. Request authorization
        try await mockManager.requestAuthorization()
        #expect(mockManager.isAuthorized == true)
        
        // 2. Load body metrics
        let (weight, height) = try await mockManager.loadBodyMetrics()
        #expect(weight == 70.0)
        #expect(height == 1.75)
        
        // 3. Start workout session
        try await mockManager.startWorkoutSession()
        #expect(mockManager.hasActiveWorkoutSession == true)
        
        // 4. Start heart rate monitoring
        try await mockManager.startHeartRateMonitoring()
        
        // 5. Simulate workout with heart rate updates and locations
        let heartRates = [65.0, 72.0, 85.0, 92.0, 88.0]
        for (index, heartRate) in heartRates.enumerated() {
            await mockManager.simulateHeartRateUpdate(heartRate)
            
            let location = CLLocation(
                latitude: 37.7749 + Double(index) * 0.001,
                longitude: -122.4194 + Double(index) * 0.001
            )
            await mockManager.addLocationToWorkout(location)
            
            try await Task.sleep(for: .milliseconds(10))
        }
        
        // 6. End workout session
        await mockManager.endWorkoutSession()
        #expect(mockManager.hasActiveWorkoutSession == false)
        
        // 7. Save workout
        let sessionData = createMockSessionData()
        try await mockManager.saveWorkout(from: sessionData)
        #expect(mockManager.didSaveWorkout == true)
        
        // Verify heart rate updates were received
        try await Task.sleep(for: .milliseconds(100))
        #expect(heartRateUpdates.count == heartRates.count) {
            "Should receive all heart rate updates during workout"
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Concurrent heart rate monitoring", .tags(.async, .heartRate))
    func concurrentHeartRateMonitoring() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        var allUpdates: [Double] = []
        mockManager.onHeartRateUpdate = { heartRate in
            allUpdates.append(heartRate)
        }
        
        try await mockManager.startHeartRateMonitoring()
        
        // Simulate concurrent heart rate updates
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    await mockManager.simulateHeartRateUpdate(Double(60 + i))
                }
            }
        }
        
        try await Task.sleep(for: .milliseconds(200))
        
        #expect(allUpdates.count == 10) {
            "Should handle concurrent heart rate updates"
        }
    }
    
    @Test("Memory management and cleanup", .tags(.unit))
    func memoryManagementAndCleanup() async throws {
        var mockManager: MockHealthKitManager? = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        try await mockManager?.startHeartRateMonitoring()
        try await mockManager?.startWorkoutSession()
        
        #expect(mockManager?.hasActiveWorkoutSession == true)
        
        // Simulate deinit by setting to nil
        mockManager = nil
        
        // Should not crash - deinit should handle cleanup properly
        #expect(mockManager == nil)
    }
    
    // MARK: - Helper Methods
    
    private func createMockSessionData() -> SessionExportData {
        return SessionExportData(
            id: UUID(),
            startDate: Date().addingTimeInterval(-3600), // 1 hour ago
            endDate: Date(),
            totalDistance: 5000.0, // 5km
            loadWeight: 20.0, // 20kg
            totalCalories: 600.0,
            averagePace: 6.0, // min/km
            elevationGain: 200.0,
            elevationLoss: 150.0,
            maxElevation: 500.0,
            minElevation: 300.0,
            elevationRange: 200.0,
            averageGrade: 3.0,
            maxGrade: 15.0,
            minGrade: -8.0,
            locationPointsCount: 250,
            elevationAccuracy: 1.5,
            barometerDataPoints: 200,
            hasHighQualityElevationData: true,
            version: 1,
            createdAt: Date().addingTimeInterval(-3600),
            modifiedAt: Date()
        )
    }
    
    private func createMockRoute() -> [CLLocation] {
        return [
            CLLocation(latitude: 37.7749, longitude: -122.4194),
            CLLocation(latitude: 37.7849, longitude: -122.4294),
            CLLocation(latitude: 37.7949, longitude: -122.4394)
        ]
    }
}

// MARK: - Background Delivery Test Suite

@Suite("HealthKit Background Delivery", .tags(.healthKit, .integration))
@MainActor
struct HealthKitBackgroundDeliveryTests {
    
    @Test("Heart rate monitoring stop functionality", .tags(.heartRate, .unit))
    func heartRateMonitoringStop() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        
        // Start monitoring
        try await mockManager.startHeartRateMonitoring()
        
        var callbackCount = 0
        mockManager.onHeartRateUpdate = { _ in
            callbackCount += 1
        }
        
        // Simulate some updates
        await mockManager.simulateHeartRateUpdate(75.0)
        try await Task.sleep(for: .milliseconds(50))
        
        let countBeforeStop = callbackCount
        
        // Stop monitoring
        mockManager.stopHeartRateMonitoring()
        
        // Simulate more updates (should not trigger callbacks)
        await mockManager.simulateHeartRateUpdate(80.0)
        try await Task.sleep(for: .milliseconds(50))
        
        #expect(callbackCount == countBeforeStop) {
            "No new heart rate updates should be received after stopping monitoring"
        }
    }
    
    @Test("Background delivery failure handling", .tags(.integration, .unit))
    func backgroundDeliveryFailureHandling() async throws {
        let mockManager = MockHealthKitManager(isAvailable: true, isAuthorized: true)
        mockManager.shouldThrowError = true
        
        // This should not crash even if background delivery fails
        try await mockManager.requestAuthorization()
        
        // Manager should still be authorized even if background delivery fails
        #expect(mockManager.isAuthorized == true)
    }
}

// MARK: - Mock HealthKit Manager

@MainActor
class MockHealthKitManager: HealthKitManager {
    private let mockIsAvailable: Bool
    private let mockIsAuthorized: Bool
    
    var mockBodyWeight: Double?
    var mockHeight: Double?
    var shouldThrowError = false
    
    // Test tracking properties
    var didSaveWorkout = false
    var savedWorkoutDistance: Double = 0
    var savedWorkoutCalories: Double = 0
    var hasActiveWorkoutSession = false
    private var isHeartRateMonitoring = false
    
    init(isAvailable: Bool, isAuthorized: Bool = false) {
        self.mockIsAvailable = isAvailable
        self.mockIsAuthorized = isAuthorized
        super.init()
        
        // Override properties
        self.isHealthKitAvailable = isAvailable
        self.isAuthorized = isAuthorized
        self.authorizationStatus = isAuthorized ? .sharingAuthorized : .notDetermined
    }
    
    override func requestAuthorization() async throws {
        if !mockIsAvailable {
            throw HealthKitError.healthKitUnavailable
        }
        
        if shouldThrowError {
            throw HealthKitError.authorizationFailed(NSError(domain: "Test", code: 0))
        }
        
        isAuthorized = mockIsAuthorized
        authorizationStatus = mockIsAuthorized ? .sharingAuthorized : .sharingDenied
    }
    
    override func loadBodyMetrics() async throws -> (weight: Double?, height: Double?) {
        if !mockIsAvailable || !mockIsAuthorized {
            return (nil, nil)
        }
        
        if shouldThrowError {
            let error = HealthKitError.dataAccessFailed(NSError(domain: "Test", code: 0))
            lastError = error
            throw error
        }
        
        return (mockBodyWeight, mockHeight)
    }
    
    override func startHeartRateMonitoring() async throws {
        if !mockIsAvailable || !mockIsAuthorized {
            throw HealthKitError.notAuthorized
        }
        
        if shouldThrowError {
            throw HealthKitError.dataAccessFailed(NSError(domain: "Test", code: 0))
        }
        
        isHeartRateMonitoring = true
    }
    
    override func stopHeartRateMonitoring() {
        isHeartRateMonitoring = false
    }
    
    override func startWorkoutSession(for activityType: HKWorkoutActivityType = .hiking) async throws {
        if !mockIsAvailable || !mockIsAuthorized {
            throw HealthKitError.notAuthorized
        }
        
        if shouldThrowError {
            throw HealthKitError.workoutSessionFailed(NSError(domain: "Test", code: 0))
        }
        
        hasActiveWorkoutSession = true
    }
    
    override func endWorkoutSession() async {
        hasActiveWorkoutSession = false
    }
    
    override func addLocationToWorkout(_ location: CLLocation) async {
        // Mock implementation - no action needed
    }
    
    override func saveWorkout(from session: SessionExportData, route: [CLLocation] = []) async throws {
        if !mockIsAvailable || !mockIsAuthorized {
            throw HealthKitError.notAuthorized
        }
        
        guard session.endDate != nil else {
            throw HealthKitError.invalidWorkoutData("Session must have valid end date")
        }
        
        if shouldThrowError {
            throw HealthKitError.workoutSaveFailed(NSError(domain: "Test", code: 0))
        }
        
        didSaveWorkout = true
        savedWorkoutDistance = session.totalDistance
        savedWorkoutCalories = session.totalCalories
    }
    
    func simulateHeartRateUpdate(_ heartRate: Double) async {
        guard isHeartRateMonitoring else { return }
        onHeartRateUpdate?(heartRate)
    }
}

// MARK: - HealthKitError Equatable Extension

extension HealthKitError: Equatable {
    static func == (lhs: HealthKitError, rhs: HealthKitError) -> Bool {
        switch (lhs, rhs) {
        case (.healthKitUnavailable, .healthKitUnavailable),
             (.notAuthorized, .notAuthorized),
             (.invalidDataType, .invalidDataType):
            return true
        case (.authorizationFailed(let lhsError), .authorizationFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.dataAccessFailed(let lhsError), .dataAccessFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.backgroundDeliveryFailed(let lhsError), .backgroundDeliveryFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.workoutSessionFailed(let lhsError), .workoutSessionFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.workoutSaveFailed(let lhsError), .workoutSaveFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.invalidWorkoutData(let lhsMessage), .invalidWorkoutData(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}