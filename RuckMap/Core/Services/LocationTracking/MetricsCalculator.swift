import Foundation
import CoreLocation
import os.log

/// Calculates real-time metrics from location data
actor MetricsCalculator {
    private let logger = Logger(subsystem: "com.ruckmap", category: "MetricsCalculator")
    
    // Metrics state
    private var totalDistance: CLLocationDistance = 0
    private var totalDuration: TimeInterval = 0
    private var activeDuration: TimeInterval = 0
    private var currentPace: Double = 0
    private var averagePace: Double = 0
    private var instantaneousSpeed: CLLocationSpeed = 0
    
    // Pace calculation
    private var recentPaceData: [(distance: Double, time: TimeInterval)] = []
    private let paceWindowSize = 5
    
    // Session timing
    private var sessionStartTime: Date?
    private var lastUpdateTime: Date?
    private var pauseStartTime: Date?
    
    /// Start a new metrics session
    func startSession() {
        sessionStartTime = Date()
        lastUpdateTime = Date()
        totalDistance = 0
        totalDuration = 0
        activeDuration = 0
        currentPace = 0
        averagePace = 0
        instantaneousSpeed = 0
        recentPaceData.removeAll()
        
        logger.info("Started metrics session")
    }
    
    /// Update metrics with processed location
    func updateMetrics(with result: ProcessedLocationResult) async -> SessionMetrics {
        let now = Date()
        
        // Update distance
        if result.distance > 0 {
            totalDistance += result.distance
        }
        
        // Update timing
        if let lastTime = lastUpdateTime {
            let timeDelta = now.timeIntervalSince(lastTime)
            totalDuration += timeDelta
            
            if !result.isAutoPaused {
                activeDuration += timeDelta
            }
        }
        
        // Handle auto-pause state changes
        if result.autoPauseStateChanged {
            if result.isAutoPaused {
                pauseStartTime = now
                logger.info("Auto-pause activated")
            } else {
                pauseStartTime = nil
                logger.info("Auto-pause deactivated")
            }
        }
        
        // Update speed and pace
        instantaneousSpeed = result.speed
        updatePaceCalculations(distance: result.distance, time: now.timeIntervalSince(lastUpdateTime ?? now))
        
        lastUpdateTime = now
        
        return SessionMetrics(
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            activeDuration: activeDuration,
            currentPace: currentPace,
            averagePace: averagePace,
            instantaneousSpeed: instantaneousSpeed,
            isAutoPaused: result.isAutoPaused
        )
    }
    
    /// Pause metrics calculation
    func pause() {
        pauseStartTime = Date()
        logger.info("Metrics paused")
    }
    
    /// Resume metrics calculation
    func resume() {
        if let pauseStart = pauseStartTime {
            let pauseDuration = Date().timeIntervalSince(pauseStart)
            // Don't count pause time in active duration
            logger.info("Resumed after pause of \(pauseDuration) seconds")
        }
        pauseStartTime = nil
        lastUpdateTime = Date()
    }
    
    /// Get current metrics
    func getCurrentMetrics() -> SessionMetrics {
        SessionMetrics(
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            activeDuration: activeDuration,
            currentPace: currentPace,
            averagePace: averagePace,
            instantaneousSpeed: instantaneousSpeed,
            isAutoPaused: pauseStartTime != nil
        )
    }
    
    // MARK: - Private Methods
    
    private func updatePaceCalculations(distance: Double, time: TimeInterval) {
        guard distance > 0 && time > 0 else { return }
        
        // Add to recent pace data
        recentPaceData.append((distance: distance, time: time))
        
        // Keep only recent data
        if recentPaceData.count > paceWindowSize {
            recentPaceData.removeFirst()
        }
        
        // Calculate current pace (min/km) from recent data
        let recentDistance = recentPaceData.reduce(0) { $0 + $1.distance }
        let recentTime = recentPaceData.reduce(0) { $0 + $1.time }
        
        if recentDistance >= 10 { // At least 10m for pace calculation
            currentPace = (recentTime / 60) / (recentDistance / 1000) // min/km
        }
        
        // Calculate average pace
        if totalDistance >= 100 { // At least 100m for average
            averagePace = (activeDuration / 60) / (totalDistance / 1000) // min/km
        }
    }
}

/// Current session metrics
struct SessionMetrics: Sendable {
    let totalDistance: CLLocationDistance
    let totalDuration: TimeInterval
    let activeDuration: TimeInterval
    let currentPace: Double
    let averagePace: Double
    let instantaneousSpeed: CLLocationSpeed
    let isAutoPaused: Bool
}