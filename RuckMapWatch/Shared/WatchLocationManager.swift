import Foundation
import CoreLocation
import Observation
import HealthKit
import OSLog

// MARK: - Watch Location Tracking Manager

/// Standalone location tracking manager optimized for Apple Watch
@MainActor
@Observable
final class WatchLocationManager: NSObject {
    
    // MARK: - Constants
    
    private enum Constants {
        static let distanceFilterMeters: CLLocationDistance = 10.0
        static let maxRecentLocations: Int = 5
        static let autoPauseDistanceThreshold: Double = 5.0 // meters
        static let autoPauseTimeThreshold: TimeInterval = 30.0 // seconds
        static let accuracyThreshold: Double = 10.0 // meters
        static let updateInterval: TimeInterval = 2.0 // seconds
        static let cleanupTimerInterval: TimeInterval = 3600 // 1 hour
    }
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.ruckmap.watch", category: "LocationManager")
    
    // MARK: - Published Properties
    var currentLocation: CLLocation?
    var trackingState: WatchTrackingState = .stopped
    var gpsAccuracy: WatchGPSAccuracy = .poor
    var currentSession: WatchRuckSession?
    
    // Distance & Pace
    var totalDistance: Double = 0 // meters
    var currentPace: Double = 0 // min/km
    var averagePace: Double = 0 // min/km
    
    // Elevation
    var currentElevation: Double = 0
    var elevationGain: Double = 0
    var elevationLoss: Double = 0
    var currentGrade: Double = 0
    
    // Auto-pause
    var isAutoPaused: Bool = false
    var lastMovementTime: Date?
    
    // Calories
    var currentCalorieBurnRate: Double = 0 // kcal/min
    var totalCalories: Double = 0
    
    // Heart Rate
    var currentHeartRate: Double?
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let dataManager: WatchDataManager
    private let calorieCalculator: WatchCalorieCalculator
    private let healthKitManager: WatchHealthKitManager?
    
    private var recentLocations: [CLLocation] = []
    private let maxRecentLocations = 5 // Reduced for Watch memory constraints
    
    // Timers
    private var autoPauseTimer: Timer?
    private var metricsUpdateTimer: Timer?
    
    // Constants optimized for Watch
    private let minimumUpdateInterval: TimeInterval = 2.0 // Slower updates for battery
    private let minimumDistanceThreshold: Double = 2.0 // meters
    private let autoPauseThreshold: TimeInterval = 45.0 // seconds (longer for Watch)
    private let autoPauseDistanceThreshold: Double = 3.0 // meters
    
    // Battery optimization
    private var isLowPowerMode: Bool = false
    private var lastGPSConfigUpdate: Date = Date()
    
    // MARK: - Initialization
    
    init(dataManager: WatchDataManager, healthKitManager: WatchHealthKitManager? = nil) {
        self.dataManager = dataManager
        self.healthKitManager = healthKitManager
        self.calorieCalculator = WatchCalorieCalculator()
        
        super.init()
        setupLocationManager()
        setupHealthKitCallbacks()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 3.0 // Larger filter for Watch
        locationManager.allowsBackgroundLocationUpdates = true
        // These properties are not available on watchOS
        #if !os(watchOS)
        locationManager.pausesLocationUpdatesAutomatically = false // We handle auto-pause
        locationManager.showsBackgroundLocationIndicator = false // Watch doesn't show indicator
        #endif
    }
    
    private func setupHealthKitCallbacks() {
        healthKitManager?.onHeartRateUpdate = { [weak self] heartRate in
            Task { @MainActor in
                self?.updateHeartRate(heartRate)
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Request location permission
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Start tracking with a new session
    func startTracking(loadWeight: Double = 0.0) async throws {
        guard trackingState == .stopped else { return }
        
        // Create new session
        let session = try dataManager.createSession(loadWeight: loadWeight)
        currentSession = session
        
        // Reset state
        trackingState = .tracking
        totalDistance = 0
        elevationGain = 0
        elevationLoss = 0
        totalCalories = 0
        isAutoPaused = false
        recentLocations.removeAll()
        
        // Start HealthKit workout session
        try await healthKitManager?.startWorkoutSession()
        
        // Start heart rate monitoring
        try await healthKitManager?.startHeartRateMonitoring()
        
        // Start location updates
        locationManager.startUpdatingLocation()
        
        // Start auto-pause monitoring
        startAutoPauseMonitoring()
        
        // Start metrics update timer
        startMetricsTimer()
        
        // Initialize calorie calculation
        calorieCalculator.startCalculation(
            bodyWeight: await getBodyWeight(),
            loadWeight: loadWeight
        )
    }
    
    /// Pause tracking
    func pauseTracking() {
        guard trackingState == .tracking else { return }
        
        trackingState = .paused
        
        // Keep location updates for resume detection but reduce frequency
        adjustLocationAccuracyForPause(true)
        
        // Stop metrics timer
        stopMetricsTimer()
        
        // Pause calorie calculation
        calorieCalculator.pauseCalculation()
        
        // Update session
        do {
            try dataManager.pauseCurrentSession()
        } catch {
            print("Failed to pause session: \(error)")
        }
    }
    
    /// Resume tracking
    func resumeTracking() {
        guard trackingState == .paused else { return }
        
        trackingState = .tracking
        
        // Restore location accuracy
        adjustLocationAccuracyForPause(false)
        
        // Restart metrics timer
        startMetricsTimer()
        
        // Resume calorie calculation
        calorieCalculator.resumeCalculation()
        
        // Update session
        do {
            try dataManager.resumeCurrentSession()
        } catch {
            print("Failed to resume session: \(error)")
        }
    }
    
    /// Stop tracking and complete session
    func stopTracking() async {
        guard trackingState != .stopped else { return }
        
        // Stop location updates
        locationManager.stopUpdatingLocation()
        
        // Stop timers
        stopAutoPauseMonitoring()
        stopMetricsTimer()
        
        // Stop calorie calculation
        calorieCalculator.stopCalculation()
        totalCalories = calorieCalculator.totalCalories
        
        // Complete session with final metrics
        if let session = currentSession {
            session.totalDistance = totalDistance
            session.totalCalories = totalCalories
            session.averagePace = averagePace
            session.elevationGain = elevationGain
            session.elevationLoss = elevationLoss
            
            do {
                try dataManager.completeCurrentSession()
            } catch {
                print("Failed to complete session: \(error)")
            }
        }
        
        // Stop HealthKit session
        await healthKitManager?.endWorkoutSession()
        healthKitManager?.stopHeartRateMonitoring()
        
        // Reset state
        trackingState = .stopped
        currentSession = nil
        isAutoPaused = false
        recentLocations.removeAll()
    }
    
    /// Toggle pause/resume
    func togglePause() {
        switch trackingState {
        case .tracking:
            pauseTracking()
        case .paused:
            resumeTracking()
        case .stopped:
            break
        }
    }
    
    // MARK: - Private Implementation
    
    private func processLocationUpdate(_ location: CLLocation) async {
        // Update GPS accuracy
        gpsAccuracy = WatchGPSAccuracy(from: location.horizontalAccuracy)
        
        // Filter poor quality locations (more lenient on Watch)
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy < 30 else { return }
        
        // Check minimum update interval
        if let lastLocation = recentLocations.last {
            let timeSinceLastUpdate = location.timestamp.timeIntervalSince(lastLocation.timestamp)
            guard timeSinceLastUpdate >= minimumUpdateInterval else { return }
        }
        
        // Update current location
        currentLocation = location
        currentElevation = location.altitude
        
        // Check for movement (for auto-pause)
        checkForMovement(location)
        
        // Update distance and pace
        if let lastLocation = recentLocations.last {
            let distance = location.distance(from: lastLocation)
            
            // Only count distance if moving and above threshold
            if !isAutoPaused && distance > minimumDistanceThreshold {
                totalDistance += distance
                
                // Update elevation metrics
                updateElevationMetrics(from: lastLocation, to: location)
                
                // Calculate pace
                updatePace(from: location)
                
                // Update session
                updateCurrentSession(with: location)
            }
        }
        
        // Save location point
        if let session = currentSession, !isAutoPaused {
            do {
                try dataManager.addLocationPoint(from: location)
                
                // Update heart rate if available
                if let heartRate = currentHeartRate,
                   let lastPoint = session.locationPoints.last {
                    lastPoint.updateHeartRate(heartRate)
                }
                
            } catch {
                print("Failed to save location point: \(error)")
            }
        }
        
        // Update recent locations
        recentLocations.append(location)
        if recentLocations.count > maxRecentLocations {
            recentLocations.removeFirst()
        }
        
        // Update calorie calculation
        calorieCalculator.updateLocation(location, grade: currentGrade)
    }
    
    private func updateElevationMetrics(from previous: CLLocation, to current: CLLocation) {
        let elevationChange = current.altitude - previous.altitude
        
        if elevationChange > 0 {
            elevationGain += elevationChange
        } else {
            elevationLoss += abs(elevationChange)
        }
        
        // Calculate grade
        let horizontalDistance = current.distance(from: previous)
        if horizontalDistance > 0 {
            currentGrade = (elevationChange / horizontalDistance) * 100.0
            currentGrade = max(-20.0, min(20.0, currentGrade)) // Clamp to ±20%
        }
    }
    
    private func updatePace(from location: CLLocation) {
        // Calculate current pace from speed
        if location.speed > 0 {
            // Convert m/s to min/km
            currentPace = (1000.0 / location.speed) / 60.0
        }
        
        // Calculate average pace
        if totalDistance > 0, let session = currentSession {
            let elapsedTime = Date().timeIntervalSince(session.startDate)
            let elapsedMinutes = elapsedTime / 60.0
            let distanceKm = totalDistance / 1000.0
            
            if distanceKm > 0 {
                averagePace = elapsedMinutes / distanceKm
            }
        }
    }
    
    private func updateCurrentSession(with location: CLLocation) {
        guard let session = currentSession else { return }
        
        session.totalDistance = totalDistance
        session.currentLatitude = location.coordinate.latitude
        session.currentLongitude = location.coordinate.longitude
        session.currentElevation = currentElevation
        session.currentGrade = currentGrade
        session.currentPace = currentPace
        session.averagePace = averagePace
        session.elevationGain = elevationGain
        session.elevationLoss = elevationLoss
        session.totalCalories = calorieCalculator.totalCalories
    }
    
    private func updateHeartRate(_ heartRate: Double) {
        currentHeartRate = heartRate
        
        // Update most recent location point with heart rate
        if let session = currentSession,
           let lastPoint = session.locationPoints.last {
            lastPoint.updateHeartRate(heartRate)
        }
    }
    
    // MARK: - Auto-Pause
    
    private func startAutoPauseMonitoring() {
        stopAutoPauseMonitoring()
        
        autoPauseTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAutoPause()
            }
        }
    }
    
    private func stopAutoPauseMonitoring() {
        autoPauseTimer?.invalidate()
        autoPauseTimer = nil
    }
    
    private func checkAutoPause() {
        guard trackingState == .tracking,
              let lastMovement = lastMovementTime else { return }
        
        let timeSinceMovement = Date().timeIntervalSince(lastMovement)
        
        if timeSinceMovement > autoPauseThreshold && !isAutoPaused {
            // Auto-pause triggered
            isAutoPaused = true
            adjustLocationAccuracyForPause(true)
        } else if timeSinceMovement < 10.0 && isAutoPaused {
            // Movement detected, auto-resume
            isAutoPaused = false
            adjustLocationAccuracyForPause(false)
        }
    }
    
    private func checkForMovement(_ location: CLLocation) {
        guard let lastLocation = recentLocations.last else {
            lastMovementTime = Date()
            return
        }
        
        let distance = location.distance(from: lastLocation)
        if distance > autoPauseDistanceThreshold {
            lastMovementTime = Date()
        }
    }
    
    private func adjustLocationAccuracyForPause(_ isPaused: Bool) {
        if isPaused {
            // Reduce accuracy when paused to save battery
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = Constants.distanceFilterMeters
        } else {
            // Restore full accuracy when active
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 3.0
        }
    }
    
    // MARK: - Metrics Timer
    
    private func startMetricsTimer() {
        stopMetricsTimer()
        
        metricsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
    }
    
    private func stopMetricsTimer() {
        metricsUpdateTimer?.invalidate()
        metricsUpdateTimer = nil
    }
    
    private func updateMetrics() {
        // Update calorie burn rate
        currentCalorieBurnRate = calorieCalculator.currentMetabolicRate
        totalCalories = calorieCalculator.totalCalories
        
        // Update current session if active
        if let session = currentSession {
            session.totalCalories = totalCalories
        }
    }
    
    // MARK: - Helpers
    
    private func getBodyWeight() async -> Double {
        if let healthKitManager = healthKitManager {
            do {
                let (weight, _) = try await healthKitManager.loadBodyMetrics()
                return weight ?? 70.0 // Default 70kg
            } catch {
                return 70.0
            }
        }
        return 70.0
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Process locations synchronously to prevent race conditions
        Task { @MainActor in
            // Process most recent location only to avoid overwhelming the system
            if let location = locations.last {
                await processLocationUpdate(location)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("Location manager failed: \(error.localizedDescription)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            logger.info("Location authorization changed: \(status.rawValue)")
        }
    }
}

// MARK: - Supporting Types

enum WatchTrackingState: String, CaseIterable, Sendable {
    case stopped
    case tracking
    case paused
}

enum WatchGPSAccuracy: String, CaseIterable {
    case poor
    case fair
    case good
    case excellent
    
    init(from horizontalAccuracy: Double) {
        switch horizontalAccuracy {
        case ...8:
            self = .excellent
        case ...15:
            self = .good
        case ...25:
            self = .fair
        default:
            self = .poor
        }
    }
    
    var color: String {
        switch self {
        case .poor: return "red"
        case .fair: return "orange"
        case .good: return "yellow"
        case .excellent: return "green"
        }
    }
    
    var description: String {
        switch self {
        case .poor: return "Poor GPS"
        case .fair: return "Fair GPS"
        case .good: return "Good GPS"
        case .excellent: return "Excellent GPS"
        }
    }
}