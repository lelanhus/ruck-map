import Foundation
import HealthKit
import CoreLocation
import OSLog
import Observation

/// Manages all HealthKit operations for RuckMap including permissions, data reading, and workout saving
@Observable
@MainActor
final class HealthKitManager: Sendable {
    private let logger = Logger(subsystem: "com.ruckmap.app", category: "HealthKitManager")
    private let healthStore = HKHealthStore()
    
    // MARK: - Constants
    
    private enum Constants {
        static let heartRateHistoryWindow: TimeInterval = 300 // 5 minutes
        static let bodyCacheExpiration: TimeInterval = 86400 // 24 hours
        static let sampleInterval: TimeInterval = 300 // 5 minutes
        static let minValidWeight: Double = 20 // kg
        static let maxValidWeight: Double = 300 // kg
        static let minValidHeight: Double = 0.5 // meters
        static let maxValidHeight: Double = 2.5 // meters
        static let minValidHeartRate: Double = 30 // bpm
        static let maxValidHeartRate: Double = 250 // bpm
    }
    
    // Published state
    var isHealthKitAvailable: Bool = false
    var authorizationStatus: HKAuthorizationStatus = .notDetermined
    var isAuthorized: Bool = false
    var lastError: HealthKitError?
    
    // Body metrics cache
    private var cachedBodyMass: Double?
    private var cachedHeight: Double?
    private var lastBodyMetricsUpdate: Date?
    
    // Heart rate monitoring
    private var heartRateObserver: HKObserverQuery?
    private var currentHeartRateQuery: HKAnchoredObjectQuery?
    private var backgroundDeliveryEnabled = false
    private var lastHeartRateUpdateTime: Date?
    private let heartRateUpdateInterval: TimeInterval = 1.0 // Minimum 1 second between updates
    
    // Workout session tracking
    private var activeWorkoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var workoutRouteBuilder: HKWorkoutRouteBuilder?
    
    // Callbacks for real-time data
    var onHeartRateUpdate: ((Double) -> Void)?
    var onBodyMetricsUpdate: ((Double?, Double?) -> Void)?
    
    init() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
        if isHealthKitAvailable {
            logger.info("HealthKit is available on this device")
        } else {
            logger.warning("HealthKit is not available on this device")
        }
        
        // TODO: Future enhancement - Battery usage monitoring
        // Track battery level changes during workouts to validate <10%/hour target
        // Implementation would use UIDevice.current.batteryLevel monitoring
        // and correlate with workout duration for performance metrics
    }
    
    // MARK: - Authorization
    
    /// Request HealthKit permissions with detailed explanations
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.healthKitUnavailable
        }
        
        logger.info("Requesting HealthKit authorization")
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            
            // Check individual permissions
            let heartRateStatus = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .heartRate)!)
            let bodyMassStatus = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .bodyMass)!)
            let workoutStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
            
            authorizationStatus = heartRateStatus
            isAuthorized = heartRateStatus == .sharingAuthorized && workoutStatus != .sharingDenied
            
            logger.info("HealthKit authorization completed - Heart Rate: \(heartRateStatus.rawValue), Body Mass: \(bodyMassStatus.rawValue), Workout: \(workoutStatus.rawValue)")
            
            if isAuthorized {
                await setupBackgroundDelivery()
                await loadInitialBodyMetrics()
            }
            
        } catch {
            logger.error("HealthKit authorization failed: \(error.localizedDescription)")
            lastError = HealthKitError.authorizationFailed(error)
            throw HealthKitError.authorizationFailed(error)
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() {
        guard isHealthKitAvailable else {
            authorizationStatus = .notDetermined
            isAuthorized = false
            return
        }
        
        let heartRateStatus = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .heartRate)!)
        let workoutStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        
        authorizationStatus = heartRateStatus
        isAuthorized = heartRateStatus == .sharingAuthorized && workoutStatus != .sharingDenied
        
        logger.debug("Authorization status check - Heart Rate: \(heartRateStatus.rawValue), Authorized: \(isAuthorized)")
    }
    
    // MARK: - Body Metrics
    
    /// Load current body metrics (weight and height)
    func loadBodyMetrics() async throws -> (weight: Double?, height: Double?) {
        guard isHealthKitAvailable && isAuthorized else {
            logger.warning("Cannot load body metrics - HealthKit not available or authorized")
            return (nil, nil)
        }
        
        // Check cache first (refresh every 24 hours)
        if let lastUpdate = lastBodyMetricsUpdate,
           Date().timeIntervalSince(lastUpdate) < Constants.bodyCacheExpiration,
           let cachedWeight = cachedBodyMass,
           let cachedHeight = cachedHeight {
            logger.debug("Returning cached body metrics")
            return (cachedWeight, cachedHeight)
        }
        
        logger.info("Loading body metrics from HealthKit")
        
        async let weight = loadMostRecentBodyMass()
        async let height = loadMostRecentHeight()
        
        let (weightResult, heightResult) = await (weight, height)
        
        // Cache results
        cachedBodyMass = weightResult
        cachedHeight = heightResult
        lastBodyMetricsUpdate = Date()
        
        // Notify observers
        onBodyMetricsUpdate?(weightResult, heightResult)
        
        logger.info("Body metrics loaded - Weight: \(weightResult?.description ?? "nil") kg, Height: \(heightResult?.description ?? "nil") m")
        
        return (weightResult, heightResult)
    }
    
    private func loadMostRecentBodyMass() async -> Double? {
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return nil }
        
        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    self.logger.error("Failed to load body mass: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                
                // Validate reasonable weight range (20kg - 300kg)
                guard weightInKg > Constants.minValidWeight && weightInKg < Constants.maxValidWeight else {
                    self.logger.warning("Invalid body weight from HealthKit: \(weightInKg)kg")
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: weightInKg)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func loadMostRecentHeight() async -> Double? {
        guard let heightType = HKObjectType.quantityType(forIdentifier: .height) else { return nil }
        
        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: heightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    self.logger.error("Failed to load height: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let heightInMeters = sample.quantity.doubleValue(for: HKUnit.meter())
                
                // Validate reasonable height range (0.5m - 2.5m)
                guard heightInMeters > Constants.minValidHeight && heightInMeters < Constants.maxValidHeight else {
                    self.logger.warning("Invalid height from HealthKit: \(heightInMeters)m")
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: heightInMeters)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func loadInitialBodyMetrics() async {
        do {
            let (weight, height) = try await loadBodyMetrics()
            logger.info("Initial body metrics loaded successfully")
        } catch {
            logger.error("Failed to load initial body metrics: \(error.localizedDescription)")
            lastError = HealthKitError.dataAccessFailed(error)
        }
    }
    
    // MARK: - Heart Rate Monitoring
    
    /// Start real-time heart rate monitoring during active workout
    func startHeartRateMonitoring() async throws {
        guard isHealthKitAvailable && isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.invalidDataType
        }
        
        logger.info("Starting heart rate monitoring")
        
        // Stop existing query if running
        if let existingQuery = currentHeartRateQuery {
            healthStore.stop(existingQuery)
        }
        
        // Create predicate for recent heart rate data
        let now = Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: now.addingTimeInterval(-300), // Last 5 minutes
            end: nil,
            options: .strictEndDate
        )
        
        currentHeartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            if let error = error {
                self?.logger.error("Heart rate query failed: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.lastError = HealthKitError.dataAccessFailed(error)
                }
                return
            }
            
            guard let samples = samples as? [HKQuantitySample] else { return }
            
            // Get most recent heart rate
            if let latestSample = samples.sorted(by: { $0.endDate > $1.endDate }).first {
                let heartRate = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                
                // Validate heart rate is within reasonable bounds
                guard heartRate >= Constants.minValidHeartRate && heartRate <= Constants.maxValidHeartRate else {
                    self?.logger.warning("Invalid heart rate reading: \(heartRate) bpm")
                    return
                }
                
                // Rate limiting - prevent UI flooding
                if let lastUpdate = self?.lastHeartRateUpdateTime,
                   Date().timeIntervalSince(lastUpdate) < (self?.heartRateUpdateInterval ?? 1.0) {
                    return
                }
                
                self?.lastHeartRateUpdateTime = Date()
                self?.logger.debug("Received heart rate update: \(heartRate) bpm")
                
                Task { @MainActor in
                    self?.onHeartRateUpdate?(heartRate)
                }
            }
        }
        
        // Set update handler for real-time updates
        currentHeartRateQuery?.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            if let error = error {
                self?.logger.error("Heart rate update failed: \(error.localizedDescription)")
                return
            }
            
            guard let samples = samples as? [HKQuantitySample] else { return }
            
            for sample in samples.sorted(by: { $0.endDate > $1.endDate }) {
                let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                
                // Validate heart rate is within reasonable bounds
                guard heartRate >= Constants.minValidHeartRate && heartRate <= Constants.maxValidHeartRate else {
                    self?.logger.warning("Invalid real-time heart rate reading: \(heartRate) bpm")
                    continue
                }
                
                // Rate limiting - prevent UI flooding
                if let lastUpdate = self?.lastHeartRateUpdateTime,
                   Date().timeIntervalSince(lastUpdate) < (self?.heartRateUpdateInterval ?? 1.0) {
                    continue
                }
                
                self?.lastHeartRateUpdateTime = Date()
                self?.logger.debug("Real-time heart rate update: \(heartRate) bpm")
                
                Task { @MainActor in
                    self?.onHeartRateUpdate?(heartRate)
                }
                break // Only use most recent valid reading
            }
        }
        
        guard let query = currentHeartRateQuery else {
            logger.error("Heart rate query is nil when trying to execute")
            throw HealthKitError.invalidDataType
        }
        
        healthStore.execute(query)
    }
    
    /// Stop heart rate monitoring
    func stopHeartRateMonitoring() {
        logger.info("Stopping heart rate monitoring")
        
        if let query = currentHeartRateQuery {
            healthStore.stop(query)
            currentHeartRateQuery = nil
        }
    }
    
    // MARK: - Background Delivery
    
    private func setupBackgroundDelivery() async {
        guard isHealthKitAvailable && isAuthorized else { return }
        guard !backgroundDeliveryEnabled else { return }
        
        logger.info("Setting up background delivery for heart rate")
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            logger.error("Unable to create heart rate type for background delivery")
            return
        }
        
        do {
            try await healthStore.enableBackgroundDelivery(
                for: heartRateType,
                frequency: .immediate
            )
            
            backgroundDeliveryEnabled = true
            logger.info("Background delivery enabled for heart rate")
            
        } catch {
            logger.error("Failed to enable background delivery: \(error.localizedDescription)")
            lastError = HealthKitError.backgroundDeliveryFailed(error)
        }
    }
    
    private func disableBackgroundDelivery() async {
        guard backgroundDeliveryEnabled else { return }
        
        logger.info("Disabling background delivery")
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        do {
            try await healthStore.disableBackgroundDelivery(for: heartRateType)
            backgroundDeliveryEnabled = false
            logger.info("Background delivery disabled")
        } catch {
            logger.error("Failed to disable background delivery: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Workout Management
    
    /// Start a workout session for active tracking
    func startWorkoutSession(for activityType: HKWorkoutActivityType = .hiking) async throws {
        guard isHealthKitAvailable && isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        logger.info("Starting workout session for activity type: \(activityType.rawValue)")
        
        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor
        
        do {
            // Create workout session
            activeWorkoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            
            // Create workout builder
            workoutBuilder = activeWorkoutSession?.associatedWorkoutBuilder()
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            // Create route builder for GPS tracking
            workoutRouteBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
            
            // Start the session
            activeWorkoutSession?.startActivity(with: Date())
            try await workoutBuilder?.beginCollection(at: Date())
            
            logger.info("Workout session started successfully")
            
        } catch {
            logger.error("Failed to start workout session: \(error.localizedDescription)")
            lastError = HealthKitError.workoutSessionFailed(error)
            throw HealthKitError.workoutSessionFailed(error)
        }
    }
    
    /// Add location data to the active workout route
    func addLocationToWorkout(_ location: CLLocation) async {
        guard let routeBuilder = workoutRouteBuilder else {
            logger.warning("No active route builder to add location")
            return
        }
        
        do {
            try await routeBuilder.insertRouteData([location])
            logger.debug("Added location to workout route")
        } catch {
            logger.error("Failed to add location to workout route: \(error.localizedDescription)")
        }
    }
    
    /// End the active workout session
    func endWorkoutSession() async {
        guard let session = activeWorkoutSession,
              let builder = workoutBuilder else {
            logger.warning("No active workout session to end")
            return
        }
        
        logger.info("Ending workout session")
        
        // End the session
        session.end()
        
        do {
            // End collection and finalize workout
            try await builder.endCollection(at: Date())
            
            activeWorkoutSession = nil
            workoutBuilder = nil
            workoutRouteBuilder = nil
            
            logger.info("Workout session ended successfully")
            
        } catch {
            logger.error("Failed to end workout session: \(error.localizedDescription)")
            lastError = HealthKitError.workoutSessionFailed(error)
        }
    }
    
    // MARK: - Workout Saving
    
    /// Save a completed RuckSession as an HKWorkout
    func saveWorkout(from session: SessionExportData, route: [CLLocation] = []) async throws {
        guard isHealthKitAvailable && isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        guard let startDate = session.startDate as Date?,
              let endDate = session.endDate else {
            throw HealthKitError.invalidWorkoutData("Session must have valid start and end dates")
        }
        
        logger.info("Saving workout to HealthKit for session: \(session.id)")
        
        // Create workout
        let workout = HKWorkout(
            activityType: .hiking, // Rucking is closest to hiking
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: session.totalCalories),
            totalDistance: HKQuantity(unit: .meter(), doubleValue: session.totalDistance),
            device: HKDevice.local(),
            metadata: createWorkoutMetadata(from: session)
        )
        
        var samplesToSave: [HKSample] = [workout]
        
        // Create energy burned samples
        let energySamples = createEnergySamples(
            totalCalories: session.totalCalories,
            startDate: startDate,
            endDate: endDate
        )
        samplesToSave.append(contentsOf: energySamples)
        
        // Create distance samples
        let distanceSamples = createDistanceSamples(
            totalDistance: session.totalDistance,
            startDate: startDate,
            endDate: endDate
        )
        samplesToSave.append(contentsOf: distanceSamples)
        
        // Create workout route if we have location data
        if !route.isEmpty {
            do {
                let workoutRoute = try await createWorkoutRoute(from: route, workout: workout)
                samplesToSave.append(workoutRoute)
                logger.info("Successfully created workout route with \(route.count) locations")
            } catch {
                logger.warning("Failed to create workout route: \(error.localizedDescription)")
                // Store partial error but continue with workout save
                // This allows the workout to be saved even if route creation fails
                lastError = HealthKitError.workoutSaveFailed(error)
                
                // Consider storing route data separately for later retry
                logger.info("Workout will be saved without route data")
            }
        }
        
        // Save all samples
        do {
            try await healthStore.save(samplesToSave)
            logger.info("Successfully saved workout to HealthKit with \(samplesToSave.count) samples")
        } catch {
            logger.error("Failed to save workout to HealthKit: \(error.localizedDescription)")
            lastError = HealthKitError.workoutSaveFailed(error)
            throw HealthKitError.workoutSaveFailed(error)
        }
    }
    
    private func createWorkoutMetadata(from session: SessionExportData) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        // Add custom rucking metadata
        metadata[HKMetadataKeyWorkoutBrandName] = "RuckMap"
        metadata["RuckLoadWeight"] = session.loadWeight
        metadata["ElevationGain"] = session.elevationGain
        metadata["ElevationLoss"] = session.elevationLoss
        metadata["AverageGrade"] = session.averageGrade
        metadata["MaxGrade"] = session.maxGrade
        metadata["ElevationAccuracy"] = session.elevationAccuracy
        metadata["HasHighQualityElevationData"] = session.hasHighQualityElevationData
        
        // Add weather data if available
        if session.averagePace > 0 {
            metadata[HKMetadataKeyAverageMETs] = calculateMETs(
                pace: session.averagePace,
                loadWeight: session.loadWeight
            )
        }
        
        return metadata
    }
    
    private func calculateMETs(pace: Double, loadWeight: Double) -> Double {
        // Approximate METs calculation for rucking
        let baseRunningMETs = 8.0 // Base for moderate hiking
        let loadFactor = 1.0 + (loadWeight / 50.0) // Additional effort per 50kg
        return baseRunningMETs * loadFactor
    }
    
    private func createEnergySamples(totalCalories: Double, startDate: Date, endDate: Date) -> [HKQuantitySample] {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return []
        }
        
        let duration = endDate.timeIntervalSince(startDate)
        let samplesCount = max(1, Int(duration / Constants.sampleInterval)) // One sample every 5 minutes
        let caloriesPerSample = totalCalories / Double(samplesCount)
        
        var samples: [HKQuantitySample] = []
        
        for i in 0..<samplesCount {
            let sampleStart = startDate.addingTimeInterval(Double(i) * duration / Double(samplesCount))
            let sampleEnd = startDate.addingTimeInterval(Double(i + 1) * duration / Double(samplesCount))
            
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: caloriesPerSample)
            let sample = HKQuantitySample(
                type: energyType,
                quantity: quantity,
                start: sampleStart,
                end: sampleEnd
            )
            
            samples.append(sample)
        }
        
        return samples
    }
    
    private func createDistanceSamples(totalDistance: Double, startDate: Date, endDate: Date) -> [HKQuantitySample] {
        guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return []
        }
        
        let duration = endDate.timeIntervalSince(startDate)
        let samplesCount = max(1, Int(duration / Constants.sampleInterval)) // One sample every 5 minutes
        let distancePerSample = totalDistance / Double(samplesCount)
        
        var samples: [HKQuantitySample] = []
        
        for i in 0..<samplesCount {
            let sampleStart = startDate.addingTimeInterval(Double(i) * duration / Double(samplesCount))
            let sampleEnd = startDate.addingTimeInterval(Double(i + 1) * duration / Double(samplesCount))
            
            let quantity = HKQuantity(unit: .meter(), doubleValue: distancePerSample)
            let sample = HKQuantitySample(
                type: distanceType,
                quantity: quantity,
                start: sampleStart,
                end: sampleEnd
            )
            
            samples.append(sample)
        }
        
        return samples
    }
    
    private func createWorkoutRoute(from locations: [CLLocation], workout: HKWorkout) async throws -> HKWorkoutRoute {
        let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
        
        try await routeBuilder.insertRouteData(locations)
        let route = try await routeBuilder.finishRoute(with: workout, metadata: nil)
        
        return route
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Synchronous cleanup only
        if let query = currentHeartRateQuery {
            healthStore.stop(query)
        }
        
        if let observer = heartRateObserver {
            healthStore.stop(observer)
        }
        
        // Note: Background delivery cannot be disabled synchronously
        // It will be re-enabled on next app launch if needed
        logger.info("HealthKitManager deinitialized")
    }
}

// MARK: - Error Types

enum HealthKitError: LocalizedError, Sendable {
    case healthKitUnavailable
    case notAuthorized
    case authorizationFailed(Error)
    case dataAccessFailed(Error)
    case backgroundDeliveryFailed(Error)
    case workoutSessionFailed(Error)
    case workoutSaveFailed(Error)
    case invalidDataType
    case invalidWorkoutData(String)
    
    var errorDescription: String? {
        switch self {
        case .healthKitUnavailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit access is not authorized"
        case .authorizationFailed(let error):
            return "HealthKit authorization failed: \(error.localizedDescription)"
        case .dataAccessFailed(let error):
            return "Failed to access HealthKit data: \(error.localizedDescription)"
        case .backgroundDeliveryFailed(let error):
            return "Failed to set up background delivery: \(error.localizedDescription)"
        case .workoutSessionFailed(let error):
            return "Workout session failed: \(error.localizedDescription)"
        case .workoutSaveFailed(let error):
            return "Failed to save workout: \(error.localizedDescription)"
        case .invalidDataType:
            return "Invalid HealthKit data type"
        case .invalidWorkoutData(let message):
            return "Invalid workout data: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .healthKitUnavailable:
            return "HealthKit features will not be available on this device"
        case .notAuthorized:
            return "Please grant HealthKit permissions in Settings to enable fitness tracking features"
        case .authorizationFailed:
            return "Try granting permissions again in the app settings"
        case .dataAccessFailed:
            return "Check your HealthKit permissions and try again"
        case .backgroundDeliveryFailed:
            return "Real-time heart rate monitoring may not work properly"
        case .workoutSessionFailed:
            return "Try starting a new workout session"
        case .workoutSaveFailed:
            return "Your workout data is saved locally and can be exported manually"
        case .invalidDataType:
            return "This is a technical error - please report it to support"
        case .invalidWorkoutData:
            return "Complete your workout session to save to HealthKit"
        }
    }
}

// MARK: - Supporting Types

/// Body metrics data from HealthKit
struct BodyMetrics: Sendable {
    let weight: Double? // kg
    let height: Double? // meters
    let lastUpdated: Date
    
    var isValid: Bool {
        weight != nil && height != nil
    }
    
    var bmi: Double? {
        guard let weight = weight, let height = height, height > 0 else { return nil }
        return weight / (height * height)
    }
}

/// Heart rate data from HealthKit
struct HeartRateData: Sendable {
    let heartRate: Double // bpm
    let timestamp: Date
    let source: String
    
    init(heartRate: Double, timestamp: Date = Date(), source: String = "HealthKit") {
        self.heartRate = heartRate
        self.timestamp = timestamp
        self.source = source
    }
}