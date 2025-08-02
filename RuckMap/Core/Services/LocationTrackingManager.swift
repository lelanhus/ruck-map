import Foundation
import CoreLocation
import CoreMotion
import SwiftData
import Observation

// MARK: - Tracking State
enum TrackingState: String, CaseIterable {
    case stopped
    case tracking
    case paused
    
    var isActive: Bool {
        self != .stopped
    }
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
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let altimeter = CMAltimeter()
    private var locations: [CLLocation] = []
    private var lastDistanceCalculation: CLLocation?
    private var paceBuffer: [Double] = [] // For rolling average
    private let paceBufferSize = 10
    private var modelContext: ModelContext?
    
    // Auto-pause settings
    private let autoPauseThreshold: TimeInterval = 30 // seconds
    private let movementThreshold: Double = 2.0 // meters
    private var autoPauseTimer: Timer?
    
    // Battery optimization
    private var lastLocationUpdate: Date?
    private let minimumUpdateInterval: TimeInterval = 1.0 // seconds
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
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
        
        // Start location updates
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        
        // Start altimeter if available
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
                guard let self = self, let data = data, error == nil else { return }
                self.processAltitudeUpdate(data)
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
        altimeter.stopRelativeAltitudeUpdates()
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
        // Battery optimization: limit update frequency
        if let lastUpdate = lastLocationUpdate,
           Date().timeIntervalSince(lastUpdate) < minimumUpdateInterval {
            return
        }
        
        lastLocationUpdate = Date()
        currentLocation = location
        gpsAccuracy = GPSAccuracy(from: location.horizontalAccuracy)
        
        // Only process if tracking and location is valid
        guard trackingState == .tracking,
              location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= 20 else { return }
        
        // Check for movement (for auto-pause)
        checkForMovement(location)
        
        // Add location to session
        if let session = currentSession, let context = modelContext {
            let locationPoint = LocationPoint(from: location)
            session.locationPoints.append(locationPoint)
            context.insert(locationPoint)
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
    
    private func processAltitudeUpdate(_ data: CMAltitudeData) {
        // Update the last location point with barometric altitude
        if let session = currentSession,
           let lastPoint = session.locationPoints.last {
            lastPoint.barometricAltitude = data.relativeAltitude.doubleValue
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