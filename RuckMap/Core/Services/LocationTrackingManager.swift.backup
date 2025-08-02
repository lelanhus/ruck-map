import Foundation
import CoreLocation
import CoreMotion
import SwiftData
import Observation
import UIKit

// MARK: - Motion Activity Type (Temporary inline definition)
enum MotionActivityType: String, CaseIterable, Sendable {
    case stationary
    case walking
    case running
    case cycling
    case automotive
    case unknown
    
    var description: String {
        switch self {
        case .stationary: return "Stationary"
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .automotive: return "Driving"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - GPS Configuration (Temporary inline definition)
struct GPSConfiguration: Sendable {
    let accuracy: CLLocationAccuracy
    let distanceFilter: CLLocationDistance
    let updateFrequency: TimeInterval
    let activityType: CLActivityType
    
    static let highPerformance = GPSConfiguration(
        accuracy: kCLLocationAccuracyBestForNavigation,
        distanceFilter: 5.0,
        updateFrequency: 0.1,
        activityType: .fitness
    )
    
    static let balanced = GPSConfiguration(
        accuracy: kCLLocationAccuracyBest,
        distanceFilter: 7.0,
        updateFrequency: 0.5,
        activityType: .fitness
    )
    
    static let batterySaver = GPSConfiguration(
        accuracy: kCLLocationAccuracyNearestTenMeters,
        distanceFilter: 10.0,
        updateFrequency: 1.0,
        activityType: .fitness
    )
}

// MARK: - Movement Pattern (Temporary inline definition)
enum MovementPattern: String, CaseIterable, Sendable {
    case stationary
    case walking
    case jogging
    case running
    case unknown
}

// MARK: - Simplified Adaptive GPS Manager (Temporary inline)
@Observable
@MainActor
final class AdaptiveGPSManager: NSObject {
    var currentConfiguration: GPSConfiguration = .balanced
    var currentMovementPattern: MovementPattern = .unknown
    var isAdaptiveMode: Bool = true
    var batteryOptimizationEnabled: Bool = true
    var batteryUsageEstimate: Double = 5.0
    var shouldShowBatteryAlert: Bool = false
    var batteryAlertMessage: String = ""
    var isHighPerformanceMode: Bool = false
    var currentUpdateFrequencyHz: Double = 2.0
    
    func analyzeLocationUpdate(_ location: CLLocation) {}
    func forceConfigurationUpdate() {}
    func resetMetrics() {}
    func setAdaptiveMode(_ enabled: Bool) {
        isAdaptiveMode = enabled
    }
    func setBatteryOptimization(_ enabled: Bool) {
        batteryOptimizationEnabled = enabled
    }
    
    var debugInfo: String {
        "Adaptive GPS Manager - Simplified Version"
    }
}

// MARK: - Simplified Motion Location Manager (Temporary inline)
@Observable  
@MainActor
final class MotionLocationManager: NSObject {
    var currentMotionActivity: MotionActivityType = .unknown
    var motionConfidence: Double = 0.0
    var suppressLocationUpdates: Bool = false
    var motionPredictedLocation: CLLocation?
    var stationaryDuration: TimeInterval = 0.0
    
    func startMotionTracking() {}
    func stopMotionTracking() {}
    func processLocationUpdate(_ location: CLLocation) async -> CLLocation {
        return location
    }
    func setAdaptiveGPSManager(_ manager: AdaptiveGPSManager) {}
    func setBatteryOptimizedMode(_ enabled: Bool) {}
    func enableMotionPrediction(_ enabled: Bool) {}
    
    var debugInfo: String {
        "Motion Location Manager - Simplified Version"
    }
}

// MARK: - Tracking State
enum TrackingState: String, CaseIterable, Sendable {
    case stopped
    case tracking
    case paused
    
    var isActive: Bool {
        self != .stopped
    }
}

// MARK: - GPS Accuracy
enum GPSAccuracy: String, CaseIterable, Sendable {
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
    
    // Adaptive GPS
    private(set) var adaptiveGPSManager: AdaptiveGPSManager
    
    // Motion-based location optimization
    private(set) var motionLocationManager: MotionLocationManager
    
    // Elevation tracking
    private(set) var elevationManager: ElevationManager
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var locations: [CLLocation] = []
    private var lastDistanceCalculation: CLLocation?
    private var paceBuffer: [Double] = [] // For rolling average
    private let paceBufferSize = 10
    private var modelContext: ModelContext?
    
    // Auto-pause settings
    private let autoPauseThreshold: TimeInterval = 30 // seconds
    private let movementThreshold: Double = 2.0 // meters
    private var autoPauseTimer: Timer?
    
    // Adaptive update timing
    private var lastLocationUpdate: Date?
    private var updateThrottleTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        // Initialize dependencies
        self.adaptiveGPSManager = AdaptiveGPSManager()
        self.motionLocationManager = MotionLocationManager()
        self.elevationManager = ElevationManager()
        
        super.init()
        setupLocationManager()
        setupMotionLocationManager()
        setupElevationManager()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        
        // Apply initial adaptive GPS configuration
        applyGPSConfiguration(adaptiveGPSManager.currentConfiguration)
    }
    
    private func setupMotionLocationManager() {
        // Connect motion location manager with adaptive GPS manager
        motionLocationManager.setAdaptiveGPSManager(adaptiveGPSManager)
        
        // Configure battery optimization based on adaptive GPS settings
        motionLocationManager.setBatteryOptimizedMode(adaptiveGPSManager.batteryOptimizationEnabled)
    }
    
    private func setupElevationManager() {
        // Elevation manager setup is handled in its initialization
        // Additional configuration can be added here if needed
    }
    
    private func applyGPSConfiguration(_ config: GPSConfiguration) {
        locationManager.desiredAccuracy = config.accuracy
        locationManager.distanceFilter = config.distanceFilter
        locationManager.activityType = config.activityType
    }
    
    // MARK: - Public Methods
    func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startTracking(with session: RuckSession) {
        guard trackingState == .stopped else { return }
        
        currentSession = session
        trackingState = .tracking
        locations.removeAll()
        totalDistance = 0
        currentPace = 0
        averagePace = 0
        paceBuffer.removeAll()
        isAutoPaused = false
        lastMovementTime = Date()
        
        // Reset adaptive GPS metrics for new session
        adaptiveGPSManager.resetMetrics()
        
        // Apply current adaptive GPS configuration
        applyGPSConfiguration(adaptiveGPSManager.currentConfiguration)
        
        // Start location updates
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        
        // Start motion tracking for enhanced accuracy
        motionLocationManager.startMotionTracking()
        
        // Start elevation tracking with advanced sensor fusion
        Task {
            do {
                try await elevationManager.startTracking()
            } catch {
                print("Failed to start elevation tracking: \(error.localizedDescription)")
            }
        }
        
        // Start auto-pause monitoring
        startAutoPauseMonitoring()
    }
    
    func pauseTracking() {
        guard trackingState == .tracking else { return }
        trackingState = .paused
        stopAutoPauseMonitoring()
    }
    
    func resumeTracking() {
        guard trackingState == .paused else { return }
        trackingState = .tracking
        lastMovementTime = Date()
        isAutoPaused = false
        startAutoPauseMonitoring()
    }
    
    func stopTracking() {
        guard trackingState != .stopped else { return }
        
        // Update session with final values
        if let session = currentSession {
            session.endDate = Date()
            session.totalDistance = totalDistance
            session.averagePace = averagePace
            session.totalDuration = session.duration
        }
        
        // Stop all tracking
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        motionLocationManager.stopMotionTracking()
        elevationManager.stopTracking()
        stopAutoPauseMonitoring()
        
        // Reset state
        trackingState = .stopped
        currentSession = nil
        locations.removeAll()
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
    
    // MARK: - Private Methods
    private func processLocationUpdate(_ location: CLLocation) {
        // Process location through motion-based optimization
        Task { @MainActor in
            let optimizedLocation = await motionLocationManager.processLocationUpdate(location)
            await processOptimizedLocation(optimizedLocation, originalLocation: location)
        }
    }
    
    private func processOptimizedLocation(_ location: CLLocation, originalLocation: CLLocation) async {
        // Adaptive GPS frequency throttling
        if shouldThrottleUpdate(for: location) {
            return
        }
        
        lastLocationUpdate = Date()
        currentLocation = location
        gpsAccuracy = GPSAccuracy(from: location.horizontalAccuracy)
        
        // Update adaptive GPS manager with original location data for metrics
        adaptiveGPSManager.analyzeLocationUpdate(originalLocation)
        
        // Apply configuration changes if needed
        let previousConfig = adaptiveGPSManager.currentConfiguration
        if hasConfigurationChanged(previousConfig) {
            applyGPSConfiguration(adaptiveGPSManager.currentConfiguration)
            
            // Update motion location manager with new battery optimization settings
            motionLocationManager.setBatteryOptimizedMode(adaptiveGPSManager.batteryOptimizationEnabled)
        }
        
        // Only process if tracking and location is valid
        guard trackingState == .tracking,
              location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= 20 else { return }
        
        // Check for movement (for auto-pause)
        checkForMovement(location)
        
        // Process location through elevation manager for sensor fusion
        Task {
            await elevationManager.processLocationUpdate(location)
        }
        
        // Add location to session with comprehensive elevation and grade data
        if let session = currentSession, let context = modelContext {
            let locationPoint = LocationPoint(from: location)
            
            // Update with elevation data if available
            if let elevationData = elevationManager.currentElevationData {
                locationPoint.updateElevationData(
                    barometricAltitude: elevationData.barometricAltitude,
                    fusedAltitude: elevationData.fusedAltitude,
                    accuracy: elevationData.accuracy,
                    confidence: elevationData.confidence,
                    grade: elevationData.currentGrade,
                    pressure: elevationData.pressure
                )
            }
            
            session.locationPoints.append(locationPoint)
            context.insert(locationPoint)
            
            // Process through enhanced grade calculator for real-time metrics
            Task {
                if let gradeResult = await elevationManager.processLocationPoint(locationPoint) {
                    // Update real-time metrics based on grade calculation results
                    if gradeResult.meetsPrecisionTarget {
                        // Store high-precision grade data
                        locationPoint.instantaneousGrade = gradeResult.smoothedGrade
                    }
                }
            }
            
            // Update session elevation metrics periodically with enhanced calculation
            if session.locationPoints.count % 10 == 0 {
                Task {
                    await session.updateElevationMetrics()
                }
            }
        }
        
        // Calculate distance
        if let lastLocation = lastDistanceCalculation {
            let distance = location.distance(from: lastLocation)
            if distance > 1 { // Only count if moved more than 1 meter
                totalDistance += distance
                lastDistanceCalculation = location
                
                // Update session
                currentSession?.totalDistance = totalDistance
            }
        } else {
            lastDistanceCalculation = location
        }
        
        // Calculate pace
        updatePace(from: location)
        
        locations.append(location)
    }
    
    private func updatePace(from location: CLLocation) {
        guard location.speed > 0 else {
            currentPace = 0
            return
        }
        
        // Convert m/s to min/km
        let paceMinPerKm = 1000.0 / (location.speed * 60.0)
        
        // Add to rolling buffer
        paceBuffer.append(paceMinPerKm)
        if paceBuffer.count > paceBufferSize {
            paceBuffer.removeFirst()
        }
        
        // Calculate rolling average
        currentPace = paceBuffer.reduce(0, +) / Double(paceBuffer.count)
        
        // Update overall average pace
        if totalDistance > 0 {
            let elapsedTime = currentSession?.duration ?? 0
            averagePace = (elapsedTime / 60.0) / (totalDistance / 1000.0)
            currentSession?.averagePace = averagePace
        }
    }
    
    
    // MARK: - Auto-pause
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
    
    private func checkForMovement(_ location: CLLocation) {
        guard let lastLocation = locations.last else { return }
        
        let distance = location.distance(from: lastLocation)
        if distance >= movementThreshold {
            lastMovementTime = Date()
            
            // Resume if auto-paused
            if isAutoPaused {
                isAutoPaused = false
                resumeTracking()
            }
        }
    }
    
    private func checkAutoPause() {
        guard trackingState == .tracking,
              !isAutoPaused,
              let lastMovement = lastMovementTime else { return }
        
        let timeSinceMovement = Date().timeIntervalSince(lastMovement)
        if timeSinceMovement >= autoPauseThreshold {
            isAutoPaused = true
            pauseTracking()
        }
    }
    
    // MARK: - Adaptive GPS Helper Methods
    
    private func shouldThrottleUpdate(for location: CLLocation) -> Bool {
        guard let lastUpdate = lastLocationUpdate else { return false }
        
        let requiredInterval = adaptiveGPSManager.currentConfiguration.updateFrequency
        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
        
        return timeSinceLastUpdate < requiredInterval
    }
    
    private func hasConfigurationChanged(_ previousConfig: GPSConfiguration) -> Bool {
        let currentConfig = adaptiveGPSManager.currentConfiguration
        return previousConfig.accuracy != currentConfig.accuracy ||
               previousConfig.distanceFilter != currentConfig.distanceFilter ||
               previousConfig.activityType != currentConfig.activityType
    }
    
    // MARK: - Public Adaptive GPS Methods
    
    func enableAdaptiveGPS(_ enabled: Bool) {
        adaptiveGPSManager.setAdaptiveMode(enabled)
        if enabled {
            applyGPSConfiguration(adaptiveGPSManager.currentConfiguration)
        } else {
            // Revert to high performance mode when adaptive is disabled
            applyGPSConfiguration(.highPerformance)
        }
    }
    
    func enableBatteryOptimization(_ enabled: Bool) {
        adaptiveGPSManager.setBatteryOptimization(enabled)
        motionLocationManager.setBatteryOptimizedMode(enabled)
        applyGPSConfiguration(adaptiveGPSManager.currentConfiguration)
    }
    
    func forceGPSConfigurationUpdate() {
        adaptiveGPSManager.forceConfigurationUpdate()
        applyGPSConfiguration(adaptiveGPSManager.currentConfiguration)
    }
    
    // MARK: - Motion-Based Optimization Controls
    
    func enableMotionPrediction(_ enabled: Bool) {
        motionLocationManager.enableMotionPrediction(enabled)
    }
    
    func getMotionActivity() -> MotionActivityType {
        return motionLocationManager.currentMotionActivity
    }
    
    func getMotionConfidence() -> Double {
        return motionLocationManager.motionConfidence
    }
    
    var isLocationUpdatesSuppressed: Bool {
        return motionLocationManager.suppressLocationUpdates
    }
    
    var stationaryDuration: TimeInterval {
        return motionLocationManager.stationaryDuration
    }
    
    var motionPredictedLocation: CLLocation? {
        return motionLocationManager.motionPredictedLocation
    }
    
    // MARK: - Elevation Management
    
    /// Calibrates elevation to a known reference point
    func calibrateElevation(to knownElevation: Double) async throws {
        try await elevationManager.calibrateToKnownElevation(knownElevation)
    }
    
    /// Returns current elevation data
    var currentElevationData: ElevationData? {
        return elevationManager.currentElevationData
    }
    
    /// Returns elevation accuracy metrics
    var elevationAccuracy: Double {
        return elevationManager.currentElevationData?.accuracy ?? Double.infinity
    }
    
    /// Returns elevation confidence score
    var elevationConfidence: Double {
        return elevationManager.currentElevationData?.confidence ?? 0.0
    }
    
    /// Returns whether elevation data meets accuracy target (±1 meter)
    var meetsElevationAccuracyTarget: Bool {
        return elevationManager.currentElevationData?.meetsAccuracyTarget ?? false
    }
    
    /// Returns current grade percentage from the enhanced grade calculator
    func getCurrentGrade() async -> Double {
        let (instantaneous, _) = await elevationManager.currentGradeMetrics
        return instantaneous
    }
    
    /// Returns smoothed grade percentage for more stable display
    func getSmoothedGrade() async -> Double {
        let (_, smoothed) = await elevationManager.currentGradeMetrics
        return smoothed
    }
    
    /// Returns cumulative elevation gain and loss from enhanced tracking
    func getCumulativeElevation() async -> (gain: Double, loss: Double) {
        return await elevationManager.elevationMetrics
    }
    
    /// Returns elevation profile data for visualization
    func getElevationProfile() async -> [GradeCalculator.ElevationPoint] {
        return await elevationManager.getElevationProfile()
    }
    
    /// Returns recent grade history for analysis
    func getGradeHistory() async -> [GradeCalculator.GradePoint] {
        return await elevationManager.getRecentGradeHistory()
    }
    
    /// Calculates average grade over current session for enhanced precision
    func calculateSessionAverageGrade() async -> GradeCalculator.GradeResult? {
        guard let session = currentSession, !session.locationPoints.isEmpty else { return nil }
        return await elevationManager.calculateAverageGrade(over: session.locationPoints)
    }
    
    /// Updates elevation tracking configuration
    func updateElevationConfiguration(_ configuration: ElevationConfiguration) {
        elevationManager.updateConfiguration(configuration)
    }
    
    /// Resets elevation metrics
    func resetElevationMetrics() {
        elevationManager.resetMetrics()
    }
    
    // MARK: - Battery Status
    
    var batteryUsageEstimate: Double {
        adaptiveGPSManager.batteryUsageEstimate
    }
    
    var shouldShowBatteryAlert: Bool {
        adaptiveGPSManager.shouldShowBatteryAlert
    }
    
    var batteryAlertMessage: String {
        adaptiveGPSManager.batteryAlertMessage
    }
    
    // MARK: - Enhanced Debug Information
    
    var extendedDebugInfo: String {
        """
        \(adaptiveGPSManager.debugInfo)
        
        \(motionLocationManager.debugInfo)
        
        \(elevationManager.debugInfo)
        """
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationTrackingManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            processLocationUpdate(location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("Location authorization changed: \(status.rawValue)")
    }
}