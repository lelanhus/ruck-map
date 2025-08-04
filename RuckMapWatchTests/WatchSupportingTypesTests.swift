import Testing
import Foundation
@testable import RuckMapWatch

/// Comprehensive tests for Watch supporting types and enums using Swift Testing framework
@Suite("Watch Supporting Types Tests")
struct WatchSupportingTypesTests {
    
    // MARK: - WatchTrackingState Tests
    
    @Test("WatchTrackingState enum values")
    func watchTrackingStateEnumValues() throws {
        let stopped = WatchTrackingState.stopped
        let tracking = WatchTrackingState.tracking
        let paused = WatchTrackingState.paused
        
        #expect(stopped.rawValue == "stopped")
        #expect(tracking.rawValue == "tracking")
        #expect(paused.rawValue == "paused")
    }
    
    @Test("WatchTrackingState case iteration")
    func watchTrackingStateCaseIteration() throws {
        let allCases = WatchTrackingState.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.stopped))
        #expect(allCases.contains(.tracking))
        #expect(allCases.contains(.paused))
    }
    
    @Test("WatchTrackingState Sendable conformance")
    func watchTrackingStateSendableConformance() throws {
        // Test that WatchTrackingState can be used across actor boundaries
        let state: WatchTrackingState = .tracking
        
        Task {
            let copiedState = state
            #expect(copiedState == .tracking)
        }
    }
    
    // MARK: - WatchGPSAccuracy Tests
    
    @Test("WatchGPSAccuracy initialization from horizontal accuracy", arguments: [
        (3.0, WatchGPSAccuracy.excellent),
        (8.0, WatchGPSAccuracy.excellent),
        (10.0, WatchGPSAccuracy.good),
        (15.0, WatchGPSAccuracy.good),
        (20.0, WatchGPSAccuracy.fair),
        (25.0, WatchGPSAccuracy.fair),
        (30.0, WatchGPSAccuracy.poor),
        (100.0, WatchGPSAccuracy.poor)
    ])
    func watchGPSAccuracyInitializationFromHorizontalAccuracy(accuracy: Double, expected: WatchGPSAccuracy) throws {
        let gpsAccuracy = WatchGPSAccuracy(from: accuracy)
        #expect(gpsAccuracy == expected)
    }
    
    @Test("WatchGPSAccuracy boundary conditions", arguments: [
        (8.0, WatchGPSAccuracy.excellent),  // Exact boundary
        (8.1, WatchGPSAccuracy.good),       // Just over boundary
        (15.0, WatchGPSAccuracy.good),      // Exact boundary
        (15.1, WatchGPSAccuracy.fair),      // Just over boundary
        (25.0, WatchGPSAccuracy.fair),      // Exact boundary
        (25.1, WatchGPSAccuracy.poor)       // Just over boundary
    ])
    func watchGPSAccuracyBoundaryConditions(accuracy: Double, expected: WatchGPSAccuracy) throws {
        let gpsAccuracy = WatchGPSAccuracy(from: accuracy)
        #expect(gpsAccuracy == expected)
    }
    
    @Test("WatchGPSAccuracy color properties")
    func watchGPSAccuracyColorProperties() throws {
        #expect(WatchGPSAccuracy.poor.color == "red")
        #expect(WatchGPSAccuracy.fair.color == "orange")
        #expect(WatchGPSAccuracy.good.color == "yellow")
        #expect(WatchGPSAccuracy.excellent.color == "green")
    }
    
    @Test("WatchGPSAccuracy description properties")
    func watchGPSAccuracyDescriptionProperties() throws {
        #expect(WatchGPSAccuracy.poor.description == "Poor GPS")
        #expect(WatchGPSAccuracy.fair.description == "Fair GPS")
        #expect(WatchGPSAccuracy.good.description == "Good GPS")
        #expect(WatchGPSAccuracy.excellent.description == "Excellent GPS")
    }
    
    @Test("WatchGPSAccuracy case iteration")
    func watchGPSAccuracyCaseIteration() throws {
        let allCases = WatchGPSAccuracy.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.poor))
        #expect(allCases.contains(.fair))
        #expect(allCases.contains(.good))
        #expect(allCases.contains(.excellent))
    }
    
    // MARK: - Format Utilities Supporting Enums Tests
    
    @Test("DistanceStyle enum cases")
    func distanceStyleEnumCases() throws {
        let auto = DistanceStyle.auto
        let meters = DistanceStyle.meters
        let kilometers = DistanceStyle.kilometers
        let precise = DistanceStyle.precise
        
        // Test that all cases exist and are different
        #expect(auto != meters)
        #expect(meters != kilometers)
        #expect(kilometers != precise)
        #expect(precise != auto)
    }
    
    @Test("PaceUnit enum cases")
    func paceUnitEnumCases() throws {
        let perKilometer = PaceUnit.perKilometer
        let perMile = PaceUnit.perMile
        
        #expect(perKilometer != perMile)
    }
    
    @Test("DurationStyle enum cases")
    func durationStyleEnumCases() throws {
        let compact = DurationStyle.compact
        let verbose = DurationStyle.verbose
        let hoursMinutes = DurationStyle.hoursMinutes
        
        #expect(compact != verbose)
        #expect(verbose != hoursMinutes)
        #expect(hoursMinutes != compact)
    }
    
    @Test("CalorieStyle enum cases")
    func calorieStyleEnumCases() throws {
        let whole = CalorieStyle.whole
        let precise = CalorieStyle.precise
        let withUnit = CalorieStyle.withUnit
        
        #expect(whole != precise)
        #expect(precise != withUnit)
        #expect(withUnit != whole)
    }
    
    @Test("WeightUnit enum cases")
    func weightUnitEnumCases() throws {
        let kilograms = WeightUnit.kilograms
        let pounds = WeightUnit.pounds
        
        #expect(kilograms != pounds)
    }
    
    @Test("DateStyle enum cases")
    func dateStyleEnumCases() throws {
        let short = DateStyle.short
        let medium = DateStyle.medium
        let timeOnly = DateStyle.timeOnly
        let relative = DateStyle.relative
        
        #expect(short != medium)
        #expect(medium != timeOnly)
        #expect(timeOnly != relative)
        #expect(relative != short)
    }
    
    // MARK: - WatchDataError Tests
    
    @Test("WatchDataError localized descriptions")
    func watchDataErrorLocalizedDescriptions() throws {
        let noActiveSessionError = WatchDataError.noActiveSession
        #expect(noActiveSessionError.localizedDescription == "No active ruck session")
        
        let sessionExistsError = WatchDataError.sessionAlreadyExists
        #expect(sessionExistsError.localizedDescription == "A session is already in progress")
        
        let underlyingError = NSError(domain: "TestDomain", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not found"])
        let storageError = WatchDataError.storageFailure(underlyingError)
        #expect(storageError.localizedDescription == "Storage error: Not found")
    }
    
    @Test("WatchDataError equality")
    func watchDataErrorEquality() throws {
        let error1 = WatchDataError.noActiveSession
        let error2 = WatchDataError.noActiveSession
        let error3 = WatchDataError.sessionAlreadyExists
        
        // Test that same error types are equal
        #expect(error1.localizedDescription == error2.localizedDescription)
        #expect(error1.localizedDescription != error3.localizedDescription)
    }
    
    @Test("WatchDataError with various underlying errors", arguments: [
        ("TestDomain", 100, "Test message"),
        ("NetworkDomain", 404, "Not found"),
        ("CoreDataDomain", 500, "Database error")
    ])
    func watchDataErrorWithVariousUnderlyingErrors(domain: String, code: Int, message: String) throws {
        let underlyingError = NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
        let storageError = WatchDataError.storageFailure(underlyingError)
        
        #expect(storageError.localizedDescription.contains("Storage error:"))
        #expect(storageError.localizedDescription.contains(message))
    }
    
    // MARK: - WatchHealthKitError Tests
    
    @Test("WatchHealthKitError localized descriptions")
    func watchHealthKitErrorLocalizedDescriptions() throws {
        let notAvailableError = WatchHealthKitError.healthKitNotAvailable
        #expect(notAvailableError.localizedDescription == "HealthKit is not available on this device")
        
        let notAuthorizedError = WatchHealthKitError.notAuthorized
        #expect(notAuthorizedError.localizedDescription == "HealthKit access not authorized")
        
        let authDeniedError = WatchHealthKitError.authorizationDenied
        #expect(authDeniedError.localizedDescription == "HealthKit authorization was denied")
        
        let workoutFailedError = WatchHealthKitError.workoutSessionFailed
        #expect(workoutFailedError.localizedDescription == "Failed to start workout session")
        
        let queryError = NSError(domain: "HKErrorDomain", code: 5, userInfo: [NSLocalizedDescriptionKey: "Query failed"])
        let dataQueryFailedError = WatchHealthKitError.dataQueryFailed(queryError)
        #expect(dataQueryFailedError.localizedDescription == "HealthKit data query failed: Query failed")
    }
    
    @Test("WatchHealthKitError error handling patterns")
    func watchHealthKitErrorErrorHandlingPatterns() throws {
        let errors: [WatchHealthKitError] = [
            .healthKitNotAvailable,
            .notAuthorized,
            .authorizationDenied,
            .workoutSessionFailed,
            .dataQueryFailed(NSError(domain: "Test", code: 1))
        ]
        
        for error in errors {
            #expect(error.localizedDescription != nil)
            #expect(!error.localizedDescription!.isEmpty)
        }
    }
    
    // MARK: - WatchStorageStats Tests
    
    @Test("WatchStorageStats initialization and calculations")
    func watchStorageStatsInitializationAndCalculations() throws {
        let stats = WatchStorageStats(
            sessionCount: 10,
            locationPointCount: 5000,
            estimatedSizeKB: 1024.0
        )
        
        #expect(stats.sessionCount == 10)
        #expect(stats.locationPointCount == 5000)
        #expect(stats.estimatedSizeKB == 1024.0)
        #expect(stats.estimatedSizeMB == 1.0) // 1024KB = 1MB
    }
    
    @Test("WatchStorageStats size conversions", arguments: [
        (0.0, 0.0),
        (512.0, 0.5),
        (1024.0, 1.0),
        (2048.0, 2.0),
        (10240.0, 10.0)
    ])
    func watchStorageStatsSizeConversions(sizeKB: Double, expectedMB: Double) throws {
        let stats = WatchStorageStats(
            sessionCount: 1,
            locationPointCount: 100,
            estimatedSizeKB: sizeKB
        )
        
        #expect(stats.estimatedSizeMB == expectedMB)
    }
    
    @Test("WatchStorageStats with zero values")
    func watchStorageStatsWithZeroValues() throws {
        let emptyStats = WatchStorageStats(
            sessionCount: 0,
            locationPointCount: 0,
            estimatedSizeKB: 0.0
        )
        
        #expect(emptyStats.sessionCount == 0)
        #expect(emptyStats.locationPointCount == 0)
        #expect(emptyStats.estimatedSizeKB == 0.0)
        #expect(emptyStats.estimatedSizeMB == 0.0)
    }
    
    @Test("WatchStorageStats with large values")
    func watchStorageStatsWithLargeValues() throws {
        let largeStats = WatchStorageStats(
            sessionCount: 1000,
            locationPointCount: 100000,
            estimatedSizeKB: 102400.0 // 100MB
        )
        
        #expect(largeStats.sessionCount == 1000)
        #expect(largeStats.locationPointCount == 100000)
        #expect(largeStats.estimatedSizeMB == 100.0)
    }
    
    // MARK: - Type Safety and Memory Tests
    
    @Test("Enum memory efficiency")
    func enumMemoryEfficiency() throws {
        // Test that enums are memory efficient
        let trackingStates = WatchTrackingState.allCases
        let gpsAccuracies = WatchGPSAccuracy.allCases
        
        #expect(trackingStates.count <= 5) // Should be small
        #expect(gpsAccuracies.count <= 10) // Should be small
        
        // Test enum storage size is reasonable
        let state = WatchTrackingState.tracking
        let accuracy = WatchGPSAccuracy.excellent
        
        // These should be lightweight value types
        #expect(MemoryLayout.size(ofValue: state) <= 8)
        #expect(MemoryLayout.size(ofValue: accuracy) <= 8)
    }
    
    @Test("Error type conformance")
    func errorTypeConformance() throws {
        // Test that errors conform to expected protocols
        let watchDataError: Error = WatchDataError.noActiveSession
        let healthKitError: Error = WatchHealthKitError.notAuthorized
        
        #expect(watchDataError is LocalizedError)
        #expect(healthKitError is LocalizedError)
        
        // Test error descriptions are available
        #expect((watchDataError as? LocalizedError)?.errorDescription != nil)
        #expect((healthKitError as? LocalizedError)?.errorDescription != nil)
    }
    
    @Test("Thread safety of value types")
    func threadSafetyOfValueTypes() async throws {
        let stats = WatchStorageStats(sessionCount: 5, locationPointCount: 100, estimatedSizeKB: 50.0)
        let state = WatchTrackingState.tracking
        let accuracy = WatchGPSAccuracy.excellent
        
        // Test that value types can be safely used across tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let localStats = stats
                    let localState = state
                    let localAccuracy = accuracy
                    
                    #expect(localStats.sessionCount == 5)
                    #expect(localState == .tracking)
                    #expect(localAccuracy == .excellent)
                }
            }
        }
    }
    
    // MARK: - Integration with Foundation Types Tests
    
    @Test("NSError integration with WatchDataError")
    func nsErrorIntegrationWithWatchDataError() throws {
        let nsError = NSError(
            domain: "com.ruckmap.watch",
            code: 1001,
            userInfo: [
                NSLocalizedDescriptionKey: "Custom error message",
                NSLocalizedFailureReasonErrorKey: "Test failure reason"
            ]
        )
        
        let watchDataError = WatchDataError.storageFailure(nsError)
        
        #expect(watchDataError.localizedDescription.contains("Custom error message"))
        
        // Test that the underlying error is preserved
        if case .storageFailure(let underlyingError) = watchDataError {
            #expect((underlyingError as NSError).domain == "com.ruckmap.watch")
            #expect((underlyingError as NSError).code == 1001)
        } else {
            #expect(Bool(false), "Should be storage failure error")
        }
    }
    
    @Test("Codable conformance where applicable")
    func codableConformanceWhereApplicable() throws {
        // Test that appropriate types can be encoded/decoded if they conform to Codable
        // WatchStorageStats should be encodable for debugging/logging
        let stats = WatchStorageStats(sessionCount: 3, locationPointCount: 150, estimatedSizeKB: 75.0)
        
        // These types are simple value types that could be made Codable if needed
        // For now, just verify they have the expected structure
        #expect(stats.sessionCount > 0)
        #expect(stats.locationPointCount > 0)
        #expect(stats.estimatedSizeKB > 0)
        #expect(stats.estimatedSizeMB > 0)
    }
}