import Foundation
import CoreLocation
import CoreMotion
import SwiftData
import Observation
import UIKit

// MARK: - Tracking State
enum TrackingState: String, CaseIterable, Sendable {
    case stopped
    case tracking
    case paused
}

// MARK: - GPS Accuracy
enum GPSAccuracy: String, CaseIterable {
    case poor
    case fair
    case good
    case excellent
    
    init(from horizontalAccuracy: Double) {
        switch horizontalAccuracy {
        case ...5:
            self = .excellent
        case ...10:
            self = .good
        case ...20:
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

// MARK: - Location Tracking Manager
@Observable
@MainActor
final class LocationTrackingManager: NSObject {
    // MARK: - Published Properties
    var currentLocation: CLLocation?
    var trackingState: TrackingState = .stopped
    var gpsAccuracy: GPSAccuracy = .poor
    var currentSession: RuckSession?
    
    // Distance & Pace
    var totalDistance: Double = 0 // meters
    var currentPace: Double = 0 // min/km
    var averagePace: Double = 0 // min/km
    
    // Auto-pause
    var isAutoPaused: Bool = false
    var lastMovementTime: Date?
    
    // Significant location change mode
    var isUsingSignificantLocationChanges: Bool = false
    
    // Adaptive GPS
    private(set) var adaptiveGPSManager: AdaptiveGPSManager
    
    // Motion-based location optimization
    private(set) var motionLocationManager: MotionLocationManager
    
    // Elevation tracking
    private(set) var elevationManager: ElevationManager
    
    // Battery optimization
    private(set) var batteryOptimizationManager: BatteryOptimizationManager
    
    // Calorie calculation
    private(set) var calorieCalculator: CalorieCalculator
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var modelContext: ModelContext?
    private var recentLocations: [CLLocation] = []
    private let maxRecentLocations = 10
    
    // Constants
    private let minimumUpdateInterval: TimeInterval = 1.0
    private let minimumDistanceThreshold: Double = 1.0 // meters
    private let autoPauseThreshold: TimeInterval = 30.0 // seconds
    private let autoPauseDistanceThreshold: Double = 2.0 // meters
    
    // Auto-pause
    private var autoPauseTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        // Initialize dependencies
        self.adaptiveGPSManager = AdaptiveGPSManager()
        self.motionLocationManager = MotionLocationManager()
        self.elevationManager = ElevationManager()
        self.batteryOptimizationManager = BatteryOptimizationManager()
        self.calorieCalculator = CalorieCalculator()
        
        super.init()
        setupLocationManager()
        setupMotionLocationManager()
        setupElevationManager()
        setupBatteryOptimization()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // Start with Best instead of BestForNavigation
        locationManager.distanceFilter = 5.0 // Start with reasonable distance filter
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = true // Allow iOS to optimize
        locationManager.showsBackgroundLocationIndicator = true
    }
    
    private func setupMotionLocationManager() {
        motionLocationManager.setAdaptiveGPSManager(adaptiveGPSManager)
    }
    
    private func setupElevationManager() {
        // Elevation manager setup is handled in its initialization
        // Additional configuration can be added here if needed
    }
    
    private func setupBatteryOptimization() {
        batteryOptimizationManager.configure(
            adaptiveGPS: adaptiveGPSManager,
            motionLocation: motionLocationManager,
            elevation: elevationManager
        )
    }
    
    private func applyGPSConfiguration(_ config: GPSConfiguration) {
        locationManager.desiredAccuracy = config.accuracy
        locationManager.distanceFilter = config.distanceFilter
        locationManager.activityType = config.activityType
    }
    
    // MARK: - Public Methods
    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    private func shouldUpdateConfiguration() -> Bool {
        // Check if enough time has passed since last configuration update
        return true
    }
    
    func startTracking(with session: RuckSession) {
        guard trackingState == .stopped else { return }
        
        currentSession = session
        trackingState = .tracking
        totalDistance = 0
        currentPace = 0
        averagePace = 0
        isAutoPaused = false
        recentLocations.removeAll()
        
        // Reset calorie calculation for new session
        calorieCalculator.reset()
        
        // Initialize battery optimization for session
        batteryOptimizationManager.startSession(optimizationLevel: .balanced)
        
        // Start location updates
        locationManager.startUpdatingLocation()
        
        // Start motion tracking with battery optimization
        motionLocationManager.startMotionTracking()
        motionLocationManager.setBatteryOptimizedMode(true)
        
        // Start elevation tracking
        elevationManager.startTracking()
        
        // Start calorie calculation if session has load weight
        if session.loadWeight > 0 {
            startCalorieTracking(bodyWeight: 70.0, loadWeight: session.loadWeight) // TODO: Get actual body weight from user profile
        }
        
        // Start auto-pause monitoring
        startAutoPauseMonitoring()
    }
    
    func pauseTracking() {
        guard trackingState == .tracking else { return }
        
        trackingState = .paused
        locationManager.stopUpdatingLocation()
        motionLocationManager.stopMotionTracking()
        elevationManager.stopTracking()
        calorieCalculator.stopContinuousCalculation()
        stopAutoPauseMonitoring()
    }
    
    func resumeTracking() {
        guard trackingState == .paused else { return }
        
        trackingState = .tracking
        locationManager.startUpdatingLocation()
        motionLocationManager.startMotionTracking()
        elevationManager.startTracking()
        
        // Resume calorie calculation if session has load weight
        if let session = currentSession, session.loadWeight > 0 {
            startCalorieTracking(bodyWeight: 70.0, loadWeight: session.loadWeight) // TODO: Get actual body weight from user profile
        }
        
        startAutoPauseMonitoring()
    }
    
    func stopTracking() {
        guard trackingState != .stopped else { return }
        
        // Stop location updates
        locationManager.stopUpdatingLocation()
        
        // Stop motion tracking
        motionLocationManager.stopMotionTracking()
        
        // Stop elevation tracking
        elevationManager.stopTracking()
        
        // Stop calorie calculation
        calorieCalculator.stopContinuousCalculation()
        
        // Stop auto-pause monitoring
        stopAutoPauseMonitoring()
        
        // Update session final data
        if let session = currentSession {
            session.endDate = Date()
            session.totalDistance = totalDistance
            session.distance = totalDistance
            session.averagePace = averagePace
            session.totalCalories = calorieCalculator.totalCalories
            // isActive is computed property, don't need to set
            
            // Save context
            do {
                try modelContext?.save()
            } catch {
                print("Failed to save session: \(error)")
            }
        }
        
        // Reset state
        trackingState = .stopped
        currentSession = nil
        totalDistance = 0
        currentPace = 0
        averagePace = 0
        isAutoPaused = false
        recentLocations.removeAll()
        
        // End battery optimization session
        batteryOptimizationManager.endSession()
        
        // Reset managers
        adaptiveGPSManager.resetMetrics()
        // Reset motion location manager state
        // motionLocationManager doesn't have resetMetrics, but state resets automatically
        elevationManager.reset()
    }
    
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
    
    // MARK: - Auto-Pause
    private func startAutoPauseMonitoring() {
        stopAutoPauseMonitoring()
        
        autoPauseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
            
            // Switch to significant location changes for battery savings
            if timeSinceMovement > 120.0 { // 2 minutes of no movement
                enableSignificantLocationChanges(true)
            }
        } else if timeSinceMovement < 5.0 && isAutoPaused {
            // Movement detected, auto-resume
            isAutoPaused = false
            enableSignificantLocationChanges(false)
        }
    }
    
    /// Enable or disable significant location changes mode
    private func enableSignificantLocationChanges(_ enabled: Bool) {
        guard enabled != isUsingSignificantLocationChanges else { return }
        
        isUsingSignificantLocationChanges = enabled
        adaptiveGPSManager.enableSignificantLocationChanges(enabled)
        
        if enabled {
            // Stop regular location updates and start significant changes
            locationManager.stopUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
        } else {
            // Resume regular location updates
            locationManager.stopMonitoringSignificantLocationChanges()
            locationManager.startUpdatingLocation()
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
    
    // MARK: - Location Processing
    private func processLocationUpdate(_ location: CLLocation) async {
        // Update GPS accuracy
        gpsAccuracy = GPSAccuracy(from: location.horizontalAccuracy)
        
        // Filter poor quality locations
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy < 20 else { return }
        
        // Apply motion-based filtering
        let filteredLocation = await motionLocationManager.processLocationUpdate(location)
        
        // Check minimum update interval
        if let lastLocation = recentLocations.last {
            let timeSinceLastUpdate = filteredLocation.timestamp.timeIntervalSince(lastLocation.timestamp)
            guard timeSinceLastUpdate >= minimumUpdateInterval else { return }
        }
        
        // Update adaptive GPS manager
        adaptiveGPSManager.analyzeLocationUpdate(filteredLocation)
        
        // Apply adaptive GPS configuration if changed
        if shouldUpdateConfiguration() {
            applyGPSConfiguration(adaptiveGPSManager.currentConfiguration)
        }
        
        // Process elevation data
        let elevationData = await elevationManager.processLocationUpdate(filteredLocation)
        
        // Update current location
        currentLocation = filteredLocation
        
        // Check for movement (for auto-pause)
        checkForMovement(filteredLocation)
        
        // Update distance and pace
        if let lastLocation = recentLocations.last {
            let distance = filteredLocation.distance(from: lastLocation)
            
            // Only count distance if moving and above threshold
            if !isAutoPaused && distance > minimumDistanceThreshold {
                totalDistance += distance
                
                // Update current session
                if let session = currentSession {
                    session.totalDistance = totalDistance
            session.distance = totalDistance
                    session.currentLatitude = filteredLocation.coordinate.latitude
                    session.currentLongitude = filteredLocation.coordinate.longitude
                    
                    // Update elevation metrics
                    session.currentElevation = elevationData.fusedElevation
                    session.elevationGain = elevationManager.elevationGain
                    session.elevationLoss = elevationManager.elevationLoss
                    session.currentGrade = elevationData.grade ?? 0
                }
                
                // Calculate pace
                updatePace(from: filteredLocation)
            }
        }
        
        // Create and save location point
        if let session = currentSession, !isAutoPaused {
            let locationPoint = LocationPoint(
                timestamp: filteredLocation.timestamp,
                latitude: filteredLocation.coordinate.latitude,
                longitude: filteredLocation.coordinate.longitude,
                altitude: filteredLocation.altitude,
                horizontalAccuracy: filteredLocation.horizontalAccuracy,
                verticalAccuracy: filteredLocation.verticalAccuracy,
                speed: filteredLocation.speed,
                course: filteredLocation.course
            )
            
            // Add barometric altitude if available
            if elevationData.barometricRelativeAltitude != nil {
                locationPoint.barometricAltitude = elevationData.fusedElevation
            }
            
            session.locationPoints.append(locationPoint)
            
            // Save periodically (every 10 points)
            if session.locationPoints.count % 10 == 0 {
                try? modelContext?.save()
            }
        }
        
        // Update recent locations
        recentLocations.append(filteredLocation)
        if recentLocations.count > maxRecentLocations {
            recentLocations.removeFirst()
        }
    }
    
    private func updatePace(from location: CLLocation) {
        // Calculate current pace from speed
        if location.speed > 0 {
            // Convert m/s to min/km
            currentPace = (1000.0 / location.speed) / 60.0
            
            // Update session with current pace
            currentSession?.currentPace = currentPace
        }
        
        // Calculate average pace
        if totalDistance > 0, let session = currentSession {
            let elapsedTime = Date().timeIntervalSince(session.startDate)
            let elapsedMinutes = elapsedTime / 60.0
            let distanceKm = totalDistance / 1000.0
            
            if distanceKm > 0 {
                averagePace = elapsedMinutes / distanceKm
                session.averagePace = averagePace
            }
        }
    }
    
    // MARK: - Public API Extensions
    
    /// Enable or disable adaptive GPS
    func enableAdaptiveGPS(_ enabled: Bool) {
        adaptiveGPSManager.setAdaptiveMode(enabled)
    }
    
    /// Enable or disable battery optimization
    func enableBatteryOptimization(_ enabled: Bool) {
        adaptiveGPSManager.setBatteryOptimization(enabled)
    }
    
    /// Force GPS configuration update
    func forceGPSConfigurationUpdate() {
        adaptiveGPSManager.forceConfigurationUpdate()
    }
    
    /// Get current battery usage estimate
    var batteryUsageEstimate: Double {
        adaptiveGPSManager.batteryUsageEstimate
    }
    
    /// Check if battery alert should be shown
    var shouldShowBatteryAlert: Bool {
        adaptiveGPSManager.shouldShowBatteryAlert
    }
    
    /// Get battery alert message
    var batteryAlertMessage: String {
        adaptiveGPSManager.batteryAlertMessage
    }
    
    /// Get current motion activity
    func getMotionActivity() -> MotionActivityType {
        return motionLocationManager.currentMotionActivity
    }
    
    /// Get motion confidence
    var motionConfidence: Double {
        motionLocationManager.motionConfidence
    }
    
    /// Check if location updates are being suppressed
    var isLocationUpdatesSuppressed: Bool {
        motionLocationManager.suppressLocationUpdates
    }
    
    /// Get stationary duration
    var stationaryDuration: TimeInterval {
        motionLocationManager.stationaryDuration
    }
    
    /// Enable motion prediction
    func enableMotionPrediction(_ enabled: Bool) {
        motionLocationManager.enableMotionPrediction(enabled)
    }
    
    /// Set battery optimized mode
    func setBatteryOptimizedMode(_ enabled: Bool) {
        motionLocationManager.setBatteryOptimizedMode(enabled)
        adaptiveGPSManager.setBatteryOptimization(enabled)
    }
    
    /// Set battery optimization level
    func setBatteryOptimizationLevel(_ level: BatteryOptimizationManager.OptimizationLevel) {
        batteryOptimizationManager.setOptimizationLevel(level)
    }
    
    /// Get current battery usage estimate
    func getBatteryUsageEstimate() -> Double {
        return batteryOptimizationManager.currentBatteryUsage
    }
    
    /// Get optimization recommendations
    func getOptimizationRecommendations() -> [String] {
        return batteryOptimizationManager.getOptimizationRecommendations()
    }
    
    /// Get comprehensive optimization report
    func getBatteryOptimizationReport() -> String {
        return batteryOptimizationManager.getOptimizationReport()
    }
    
    /// Start calorie tracking with body and load weight
    private func startCalorieTracking(bodyWeight: Double, loadWeight: Double) {
        calorieCalculator.startContinuousCalculation(
            bodyWeight: bodyWeight,
            loadWeight: loadWeight,
            locationProvider: { @MainActor [weak self] in
                guard let self = self else { 
                    return (location: nil, grade: nil, terrain: nil)
                }
                
                let location = self.currentLocation
                let grade = self.elevationManager.currentGrade
                
                // Determine terrain type from current session's terrain segments
                let terrain = self.getCurrentTerrain()
                
                return (location: location, grade: grade, terrain: terrain)
            },
            weatherProvider: { @MainActor [weak self] in
                guard let conditions = self?.currentSession?.weatherConditions else { 
                    return nil
                }
                return WeatherData(from: conditions)
            }
        )
    }
    
    /// Get current terrain type based on session terrain segments
    private func getCurrentTerrain() -> TerrainType? {
        guard let session = currentSession else { return nil }
        
        let now = Date()
        
        // Find the most recent terrain segment that contains the current time
        let currentTerrain = session.terrainSegments
            .filter { $0.startTime <= now && $0.endTime >= now }
            .max(by: { $0.startTime < $1.startTime })
        
        return currentTerrain?.terrainType ?? .trail // Default to trail if no specific terrain set
    }
    
    /// Enable or disable auto-optimization
    func setAutoOptimization(_ enabled: Bool) {
        batteryOptimizationManager.setAutoOptimization(enabled)
    }
    
    /// Get current calorie burn rate (kcal/min)
    var currentCalorieBurnRate: Double {
        calorieCalculator.currentMetabolicRate
    }
    
    /// Get total calories burned in current session
    var totalCaloriesBurned: Double {
        calorieCalculator.totalCalories
    }
    
    /// Get average calorie burn rate over recent period
    func getAverageCalorieBurnRate(overLastMinutes minutes: Double = 5.0) -> Double {
        calorieCalculator.getAverageMetabolicRate(overLastMinutes: minutes)
    }
    
    /// Get calorie calculation history
    var calorieCalculationHistory: [CalorieCalculationResult] {
        calorieCalculator.getCalculationHistory()
    }
    
    /// Reset calorie calculation (useful for new sessions)
    func resetCalorieCalculation() {
        calorieCalculator.reset()
    }
    
    /// Get debug information
    func getDebugInfo() -> String {
        return """
        === Location Tracking Debug ===
        State: \(trackingState.rawValue)
        GPS Accuracy: \(gpsAccuracy.description)
        Distance: \(String(format: "%.2f", totalDistance))m
        Current Pace: \(String(format: "%.2f", currentPace)) min/km
        Auto-Paused: \(isAutoPaused)
        Significant Location: \(isUsingSignificantLocationChanges)
        
        === Battery Optimization ===
        Level: \(batteryOptimizationManager.currentOptimizationLevel.rawValue)
        Usage: \(String(format: "%.1f", batteryOptimizationManager.currentBatteryUsage))%/hr
        Target: \(String(format: "%.1f", batteryOptimizationManager.targetBatteryUsage))%/hr
        Status: \(batteryOptimizationManager.batteryHealthStatus)
        \(batteryOptimizationManager.optimizationSummary)
        
        === Adaptive GPS ===
        Mode: \(adaptiveGPSManager.isAdaptiveMode ? "Adaptive" : "Manual")
        Pattern: \(adaptiveGPSManager.currentMovementPattern.rawValue)
        Update Frequency: \(String(format: "%.1f", adaptiveGPSManager.currentUpdateFrequencyHz))Hz
        Ultra Low Power: \(adaptiveGPSManager.isUltraLowPowerModeEnabled)
        Battery Alert: \(shouldShowBatteryAlert)
        
        === Motion Tracking ===
        Activity: \(motionLocationManager.currentMotionActivity.rawValue)
        Confidence: \(String(format: "%.0f", motionConfidence * 100))%
        Suppressing: \(isLocationUpdatesSuppressed)
        Stationary: \(String(format: "%.0f", stationaryDuration))s
        Battery Mode: \(motionLocationManager.batteryOptimizedMode)
        
        === Elevation ===
        Current: \(String(format: "%.1f", elevationManager.currentElevation))m
        Gain: \(String(format: "%.1f", elevationManager.elevationGain))m
        Loss: \(String(format: "%.1f", elevationManager.elevationLoss))m
        Grade: \(String(format: "%.1f", elevationManager.currentGrade))%
        Confidence: \(String(format: "%.0f", elevationManager.elevationConfidence * 100))%
        Battery Mode: \(elevationManager.batteryOptimizedMode)
        Barometer: \(elevationManager.isBarometerAvailable ? "Available" : "Unavailable")
        
        === Calorie Calculation ===
        Current Rate: \(String(format: "%.2f", calorieCalculator.currentMetabolicRate)) kcal/min
        Total Calories: \(String(format: "%.1f", calorieCalculator.totalCalories)) kcal
        Calculating: \(calorieCalculator.isCalculating ? "Yes" : "No")
        History Points: \(calorieCalculator.getCalculationHistory().count)
        """
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationTrackingManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations {
                await processLocationUpdate(location)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("Location authorization changed: \(status.rawValue)")
    }
}
