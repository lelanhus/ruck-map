import Foundation
import CoreLocation
import os.log

/// Core location management actor that handles CLLocationManager interactions
actor LocationCore: NSObject {
    private let logger = Logger(subsystem: "com.ruckmap", category: "LocationCore")
    private var locationManager: CLLocationManager?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var currentLocation: CLLocation?
    private var recentLocations: [CLLocation] = []
    private let maxRecentLocations = 10
    
    override init() {
        super.init()
    }
    
    /// Initialize the location manager on the main thread
    @MainActor
    func initialize() async {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.activityType = .fitness
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.pausesLocationUpdatesAutomatically = false
        locationManager?.showsBackgroundLocationIndicator = true
    }
    
    /// Request location authorization
    func requestAuthorization() async -> CLAuthorizationStatus {
        await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            Task { @MainActor in
                locationManager?.requestWhenInUseAuthorization()
            }
        }
    }
    
    /// Start location updates
    @MainActor
    func startLocationUpdates() {
        locationManager?.startUpdatingLocation()
        logger.info("Started location updates")
    }
    
    /// Stop location updates
    @MainActor
    func stopLocationUpdates() {
        locationManager?.stopUpdatingLocation()
        logger.info("Stopped location updates")
    }
    
    /// Get current location
    func getCurrentLocation() -> CLLocation? {
        currentLocation
    }
    
    /// Get recent locations
    func getRecentLocations() -> [CLLocation] {
        recentLocations
    }
    
    /// Update location (called from delegate)
    func updateLocation(_ location: CLLocation) {
        currentLocation = location
        recentLocations.append(location)
        
        if recentLocations.count > maxRecentLocations {
            recentLocations.removeFirst()
        }
        
        logger.debug("Updated location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    /// Update GPS configuration
    @MainActor
    func updateConfiguration(desiredAccuracy: CLLocationAccuracy, distanceFilter: CLLocationDistance) {
        locationManager?.desiredAccuracy = desiredAccuracy
        locationManager?.distanceFilter = distanceFilter
        logger.info("Updated GPS configuration - accuracy: \(desiredAccuracy), filter: \(distanceFilter)")
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationCore: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task {
            for location in locations {
                await updateLocation(location)
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task {
            await handleAuthorizationChange(manager.authorizationStatus)
        }
    }
    
    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        logger.info("Authorization status changed: \(String(describing: status))")
        authorizationContinuation?.resume(returning: status)
        authorizationContinuation = nil
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task {
            await handleLocationError(error)
        }
    }
    
    private func handleLocationError(_ error: Error) {
        logger.error("Location error: \(error.localizedDescription)")
    }
}