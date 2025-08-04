import Foundation
import SwiftUI
import CoreLocation
import SwiftData
import os.log

/// Coordinates the tracking session lifecycle
@MainActor
final class TrackingSessionCoordinator: ObservableObject {
    private let logger = Logger(subsystem: "com.ruckmap", category: "TrackingSessionCoordinator")
    
    // Published state
    @Published var trackingState: TrackingState = .stopped
    @Published var currentSession: RuckSession?
    @Published var sessionMetrics: SessionMetrics?
    @Published var currentLocation: CLLocation?
    @Published var isAutoPaused = false
    
    // Actors
    private let locationCore: LocationCore
    private let locationProcessor: LocationProcessor
    private let metricsCalculator: MetricsCalculator
    
    // Services
    private let serviceOrchestrator: ServiceOrchestrator
    
    // Tracking task
    private var trackingTask: Task<Void, Error>?
    private var modelContext: ModelContext?
    
    init() {
        self.locationCore = LocationCore()
        self.locationProcessor = LocationProcessor()
        self.metricsCalculator = MetricsCalculator()
        self.serviceOrchestrator = ServiceOrchestrator()
        
        Task {
            await locationCore.initialize()
        }
    }
    
    /// Set the model context
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// Request location authorization
    func requestAuthorization() async -> CLAuthorizationStatus {
        await locationCore.requestAuthorization()
    }
    
    /// Start tracking with a session
    func startTracking(with session: RuckSession) async throws {
        guard trackingState == .stopped else {
            logger.warning("Cannot start tracking - already active")
            return
        }
        
        currentSession = session
        trackingState = .tracking
        
        // Start all components
        await locationCore.startLocationUpdates()
        await metricsCalculator.startSession()
        await serviceOrchestrator.startServices(for: session)
        
        // Start the tracking loop
        trackingTask = Task {
            try await runTrackingLoop()
        }
        
        logger.info("Started tracking session")
    }
    
    /// Pause tracking
    func pauseTracking() async {
        guard trackingState == .tracking else { return }
        
        trackingState = .paused
        await metricsCalculator.pause()
        await locationCore.stopLocationUpdates()
        
        logger.info("Paused tracking")
    }
    
    /// Resume tracking
    func resumeTracking() async {
        guard trackingState == .paused else { return }
        
        trackingState = .tracking
        await metricsCalculator.resume()
        await locationCore.startLocationUpdates()
        
        logger.info("Resumed tracking")
    }
    
    /// Stop tracking
    func stopTracking() async {
        trackingTask?.cancel()
        trackingTask = nil
        
        await locationCore.stopLocationUpdates()
        await serviceOrchestrator.stopServices()
        
        // Finalize session
        if let session = currentSession {
            session.endDate = Date()
            
            if let metrics = await metricsCalculator.getCurrentMetrics() {
                session.totalDistance = metrics.totalDistance
                session.totalDuration = metrics.totalDuration
                session.averagePace = metrics.averagePace
            }
            
            // Save final state
            if let context = modelContext {
                do {
                    try context.save()
                } catch {
                    logger.error("Failed to save final session state: \(error)")
                }
            }
        }
        
        trackingState = .stopped
        currentSession = nil
        sessionMetrics = nil
        
        logger.info("Stopped tracking")
    }
    
    // MARK: - Private Methods
    
    private func runTrackingLoop() async throws {
        while !Task.isCancelled && trackingState != .stopped {
            // Get recent locations
            let locations = await locationCore.getRecentLocations()
            
            for location in locations {
                // Process location
                if let result = await locationProcessor.processLocation(location) {
                    // Update metrics
                    let metrics = await metricsCalculator.updateMetrics(with: result)
                    sessionMetrics = metrics
                    isAutoPaused = result.isAutoPaused
                    
                    // Update current location
                    currentLocation = location
                    
                    // Update services
                    try await serviceOrchestrator.updateServices(with: location)
                    
                    // Update session
                    if let session = currentSession {
                        updateSession(session, with: location, metrics: metrics)
                    }
                }
            }
            
            // Update GPS configuration periodically
            await serviceOrchestrator.updateGPSConfiguration()
            
            // Small delay to prevent tight loop
            try await Task.sleep(for: .seconds(1))
        }
    }
    
    private func updateSession(_ session: RuckSession, with location: CLLocation, metrics: SessionMetrics) {
        // Create location point
        let locationPoint = LocationPoint(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            speed: location.speed,
            course: location.course
        )
        
        session.locationPoints.append(locationPoint)
        
        // Update session metrics
        session.totalDistance = metrics.totalDistance
        session.totalDuration = metrics.totalDuration
        session.averagePace = metrics.averagePace
        session.currentLatitude = location.coordinate.latitude
        session.currentLongitude = location.coordinate.longitude
        session.currentPace = metrics.currentPace
        
        // Periodic save
        if session.locationPoints.count % 10 == 0 {
            if let context = modelContext {
                do {
                    try context.save()
                } catch {
                    logger.error("Failed to save location points: \(error)")
                }
            }
        }
    }
}

/// Tracking state enumeration
enum TrackingState: String, Sendable {
    case stopped = "stopped"
    case tracking = "tracking"
    case paused = "paused"
}