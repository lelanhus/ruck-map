import Foundation
import CoreLocation
import os.log

/// Processes and filters location data
actor LocationProcessor {
    private let logger = Logger(subsystem: "com.ruckmap", category: "LocationProcessor")
    
    // Processing configuration
    private let minHorizontalAccuracy: CLLocationAccuracy = 50.0
    private let minDistanceBetweenPoints: CLLocationDistance = 2.0
    private let maxSpeedThreshold: CLLocationSpeed = 10.0 // m/s (~22 mph)
    private let autoPauseSpeedThreshold: CLLocationSpeed = 0.5 // m/s
    private let autoPauseTimeThreshold: TimeInterval = 30.0
    
    // State
    private var lastProcessedLocation: CLLocation?
    private var lastMovementTime: Date = Date()
    private var isAutoPaused = false
    
    /// Process a new location update
    func processLocation(_ location: CLLocation) async -> ProcessedLocationResult? {
        // Validate location quality
        guard isLocationValid(location) else {
            logger.debug("Location rejected - poor quality")
            return nil
        }
        
        // Check for unrealistic speed
        if let lastLocation = lastProcessedLocation {
            let speed = calculateSpeed(from: lastLocation, to: location)
            if speed > maxSpeedThreshold {
                logger.warning("Location rejected - unrealistic speed: \(speed) m/s")
                return nil
            }
        }
        
        // Check minimum distance
        if let lastLocation = lastProcessedLocation {
            let distance = location.distance(from: lastLocation)
            if distance < minDistanceBetweenPoints {
                logger.debug("Location rejected - too close to last point: \(distance)m")
                return nil
            }
        }
        
        // Auto-pause detection
        let currentSpeed = location.speed >= 0 ? location.speed : 0
        let wasAutoPaused = isAutoPaused
        
        if currentSpeed < autoPauseSpeedThreshold {
            let timeSinceLastMovement = Date().timeIntervalSince(lastMovementTime)
            if timeSinceLastMovement > autoPauseTimeThreshold {
                isAutoPaused = true
            }
        } else {
            isAutoPaused = false
            lastMovementTime = Date()
        }
        
        // Calculate additional metrics
        let distance = lastProcessedLocation?.distance(from: location) ?? 0
        let timeDelta = lastProcessedLocation?.timestamp.distance(to: location.timestamp) ?? 0
        let calculatedSpeed = timeDelta > 0 ? distance / timeDelta : 0
        
        lastProcessedLocation = location
        
        return ProcessedLocationResult(
            location: location,
            distance: distance,
            speed: calculatedSpeed,
            isAutoPaused: isAutoPaused,
            autoPauseStateChanged: wasAutoPaused != isAutoPaused
        )
    }
    
    /// Reset processor state
    func reset() {
        lastProcessedLocation = nil
        lastMovementTime = Date()
        isAutoPaused = false
        logger.info("Location processor reset")
    }
    
    /// Check if location meets quality criteria
    private func isLocationValid(_ location: CLLocation) -> Bool {
        // Check horizontal accuracy
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy <= minHorizontalAccuracy else {
            return false
        }
        
        // Check timestamp (not older than 5 seconds)
        let age = Date().timeIntervalSince(location.timestamp)
        guard age < 5.0 else {
            return false
        }
        
        return true
    }
    
    /// Calculate speed between two locations
    private func calculateSpeed(from: CLLocation, to: CLLocation) -> CLLocationSpeed {
        let distance = to.distance(from: from)
        let timeDelta = to.timestamp.timeIntervalSince(from.timestamp)
        
        guard timeDelta > 0 else { return 0 }
        return distance / timeDelta
    }
}

/// Result of location processing
struct ProcessedLocationResult: Sendable {
    let location: CLLocation
    let distance: CLLocationDistance
    let speed: CLLocationSpeed
    let isAutoPaused: Bool
    let autoPauseStateChanged: Bool
}