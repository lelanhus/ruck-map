import Foundation
import HealthKit
import Observation

// MARK: - Watch HealthKit Manager

/// Simplified HealthKit manager optimized for Apple Watch
@MainActor
@Observable
final class WatchHealthKitManager {
    
    // MARK: - Published Properties
    private(set) var isAuthorized: Bool = false
    private(set) var authorizationStatus: HKAuthorizationStatus = .notDetermined
    private(set) var currentHeartRate: Double?
    private(set) var workoutSession: HKWorkoutSession?
    
    // MARK: - Callback Properties
    var onHeartRateUpdate: ((Double) -> Void)?
    var onBodyMetricsUpdate: ((Double?, Double?) -> Void)?
    
    // MARK: - Private Properties
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    // Data types we need access to
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .height)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
    ]
    
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
    ]
    
    // MARK: - Initialization
    
    init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    /// Check current authorization status
    func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available on this device")
            return
        }
        
        // Check authorization for heart rate (most important for Watch)
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        authorizationStatus = healthStore.authorizationStatus(for: heartRateType)
        isAuthorized = authorizationStatus == .sharingAuthorized
    }
    
    /// Request HealthKit authorization
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WatchHealthKitError.healthKitNotAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
        
        // Update authorization status
        checkAuthorizationStatus()
        
        if !isAuthorized {
            throw WatchHealthKitError.authorizationDenied
        }
    }
    
    // MARK: - Body Metrics
    
    /// Load body weight and height from HealthKit
    func loadBodyMetrics() async throws -> (weight: Double?, height: Double?) {
        guard isAuthorized else {
            throw WatchHealthKitError.notAuthorized
        }
        
        async let weight = loadMostRecentBodyMass()
        async let height = loadMostRecentHeight()
        
        let (bodyWeight, bodyHeight) = try await (weight, height)
        
        // Call callback if available
        onBodyMetricsUpdate?(bodyWeight, bodyHeight)
        
        return (bodyWeight, bodyHeight)
    }
    
    private func loadMostRecentBodyMass() async throws -> Double? {
        let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let completionQuery = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let sample = samples?.first as? HKQuantitySample {
                    let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    continuation.resume(returning: weightInKg)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(completionQuery)
        }
    }
    
    private func loadMostRecentHeight() async throws -> Double? {
        let heightType = HKQuantityType.quantityType(forIdentifier: .height)!
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let sample = samples?.first as? HKQuantitySample {
                    let heightInMeters = sample.quantity.doubleValue(for: HKUnit.meter())
                    continuation.resume(returning: heightInMeters)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Heart Rate Monitoring
    
    /// Start heart rate monitoring
    func startHeartRateMonitoring() async throws {
        guard isAuthorized else {
            throw WatchHealthKitError.notAuthorized
        }
        
        stopHeartRateMonitoring() // Stop any existing query
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                if let error = error {
                    print("Heart rate query error: \(error)")
                    return
                }
                
                self?.processHeartRateSamples(samples)
            }
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                if let error = error {
                    print("Heart rate update error: \(error)")
                    return
                }
                
                self?.processHeartRateSamples(samples)
            }
        }
        
        heartRateQuery = query
        healthStore.execute(query)
    }
    
    /// Stop heart rate monitoring
    func stopHeartRateMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample],
              let latestSample = samples.last else { return }
        
        let heartRate = latestSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        
        currentHeartRate = heartRate
        onHeartRateUpdate?(heartRate)
    }
    
    // MARK: - Workout Session
    
    /// Start a workout session
    func startWorkoutSession() async throws {
        guard isAuthorized else {
            throw WatchHealthKitError.notAuthorized
        }
        
        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking // Closest to rucking
        configuration.locationType = .outdoor
        
        // Create workout session
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        
        // Create workout builder
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        
        // Start the session
        session.startActivity(with: Date())
        try await builder.beginCollection(at: Date())
        
        workoutSession = session
        workoutBuilder = builder
    }
    
    /// End the workout session
    func endWorkoutSession() async {
        guard let session = workoutSession,
              let builder = workoutBuilder else { return }
        
        // End the session
        session.end()
        
        do {
            // Finish collecting data
            try await builder.endCollection(at: Date())
            
            // Finalize the workout
            let workout = try await builder.finishWorkout()
            print("Workout saved: \(workout)")
            
        } catch {
            print("Failed to end workout session: \(error)")
        }
        
        workoutSession = nil
        workoutBuilder = nil
    }
    
    /// Add sample data to the workout
    func addSampleToWorkout(_ sample: HKSample) {
        guard let builder = workoutBuilder else { return }
        
        builder.add([sample]) { (success, error) in
            if let error = error {
                print("Failed to add sample to workout: \(error)")
            }
        }
    }
    
    /// Create and add heart rate sample
    func addHeartRateSample(_ heartRate: Double, at date: Date) async {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let heartRateQuantity = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: heartRate)
        
        let heartRateSample = HKQuantitySample(
            type: heartRateType,
            quantity: heartRateQuantity,
            start: date,
            end: date
        )
        
        await addSampleToWorkout(heartRateSample)
    }
    
    /// Create and add distance sample
    func addDistanceSample(_ distance: Double, at date: Date) async {
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let distanceQuantity = HKQuantity(unit: HKUnit.meter(), doubleValue: distance)
        
        let distanceSample = HKQuantitySample(
            type: distanceType,
            quantity: distanceQuantity,
            start: date,
            end: date
        )
        
        await addSampleToWorkout(distanceSample)
    }
    
    /// Create and add calorie sample
    func addCalorieSample(_ calories: Double, at date: Date) async {
        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let calorieQuantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: calories)
        
        let calorieSample = HKQuantitySample(
            type: calorieType,
            quantity: calorieQuantity,
            start: date,
            end: date
        )
        
        await addSampleToWorkout(calorieSample)
    }
}

// MARK: - Error Types

enum WatchHealthKitError: LocalizedError {
    case healthKitNotAvailable
    case notAuthorized
    case authorizationDenied
    case workoutSessionFailed
    case dataQueryFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit access not authorized"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .workoutSessionFailed:
            return "Failed to start workout session"
        case .dataQueryFailed(let error):
            return "HealthKit data query failed: \(error.localizedDescription)"
        }
    }
}