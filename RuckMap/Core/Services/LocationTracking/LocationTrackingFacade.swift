import Foundation
import SwiftUI
import CoreLocation
import SwiftData
import os.log

/// Facade that maintains backward compatibility with the original LocationTrackingManager API
/// while delegating to the new actor-based architecture
@MainActor
final class LocationTrackingFacade: ObservableObject {
    private let logger = Logger(subsystem: "com.ruckmap", category: "LocationTrackingFacade")
    
    // MARK: - Published Properties (matching original API)
    
    @Published var trackingState: TrackingState = .stopped
    @Published var currentLocation: CLLocation?
    @Published var totalDistance: Double = 0
    @Published var currentPace: Double = 0
    @Published var averagePace: Double = 0
    @Published var instantaneousSpeed: Double = 0
    @Published var duration: TimeInterval = 0
    @Published var elevationGain: Double = 0
    @Published var elevationLoss: Double = 0
    @Published var currentGrade: Double = 0
    @Published var currentElevation: Double = 0
    @Published var terrainType: TerrainType = .pavedRoad
    @Published var terrainConfidence: Double = 0
    @Published var isAutoPaused: Bool = false
    @Published var currentSession: RuckSession?
    @Published var currentCalories: Double = 0
    @Published var currentHeartRate: Double?
    @Published var isGPSWeak: Bool = false
    @Published var lastGPSAccuracy: Double = 0
    @Published var weatherDescription: String = "Checking weather..."
    @Published var temperature: Double = 20.0
    @Published var humidity: Double = 50.0
    @Published var windSpeed: Double = 0
    
    // MARK: - Internal Components
    
    private let coordinator: TrackingSessionCoordinator
    private var observationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    override init() {
        self.coordinator = TrackingSessionCoordinator()
        super.init()
        
        // Start observing coordinator state
        startObservingCoordinator()
    }
    
    // MARK: - Public API (matching original LocationTrackingManager)
    
    func setModelContext(_ context: ModelContext) {
        coordinator.setModelContext(context)
    }
    
    func requestLocationPermission() {
        Task {
            _ = await coordinator.requestAuthorization()
        }
    }
    
    func startTracking(with session: RuckSession) {
        Task {
            do {
                try await coordinator.startTracking(with: session)
            } catch {
                logger.error("Failed to start tracking: \(error)")
            }
        }
    }
    
    func pauseTracking() {
        Task {
            await coordinator.pauseTracking()
        }
    }
    
    func resumeTracking() {
        Task {
            await coordinator.resumeTracking()
        }
    }
    
    func stopTracking() {
        Task {
            await coordinator.stopTracking()
        }
    }
    
    func updateBatteryOptimization(level: Float, state: UIDevice.BatteryState) {
        // This would be handled by the ServiceOrchestrator
        logger.info("Battery optimization update: \(level), \(state.rawValue)")
    }
    
    func overrideTerrain(to terrainType: TerrainType) {
        // This would be handled by the TerrainDetectionManager
        self.terrainType = terrainType
        self.terrainConfidence = 1.0
    }
    
    func getDebugInfo() -> String {
        // Synchronously return cached debug info
        return """
        === Location Tracking Debug Info ===
        State: \(trackingState.rawValue)
        Distance: \(String(format: "%.2f", totalDistance))m
        Current Pace: \(String(format: "%.2f", currentPace)) min/km
        GPS Accuracy: \(String(format: "%.1f", lastGPSAccuracy))m
        Terrain: \(terrainType.displayName) (\(Int(terrainConfidence * 100))%)
        Auto-paused: \(isAutoPaused)
        """
    }
    
    func exportDebugLog() -> URL? {
        // This would gather logs from all components
        logger.info("Debug log export requested")
        return nil
    }
    
    // MARK: - Private Methods
    
    private func startObservingCoordinator() {
        observationTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Observe coordinator state changes
            for await _ in Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().values {
                await self.updateFromCoordinator()
                
                if Task.isCancelled {
                    break
                }
            }
        }
    }
    
    private func updateFromCoordinator() async {
        // Update published properties from coordinator
        self.trackingState = coordinator.trackingState
        self.currentSession = coordinator.currentSession
        self.currentLocation = coordinator.currentLocation
        self.isAutoPaused = coordinator.isAutoPaused
        
        // Update metrics
        if let metrics = coordinator.sessionMetrics {
            self.totalDistance = metrics.totalDistance
            self.duration = metrics.totalDuration
            self.currentPace = metrics.currentPace
            self.averagePace = metrics.averagePace
            self.instantaneousSpeed = metrics.instantaneousSpeed
        }
        
        // Update session data
        if let session = coordinator.currentSession {
            self.elevationGain = session.elevationGain
            self.elevationLoss = session.elevationLoss
            self.currentGrade = session.currentGrade
            self.currentElevation = session.currentElevation
            self.currentCalories = session.totalCalories
        }
        
        // Update GPS quality
        if let location = currentLocation {
            self.lastGPSAccuracy = location.horizontalAccuracy
            self.isGPSWeak = location.horizontalAccuracy > 20
        }
    }
    
    deinit {
        observationTask?.cancel()
    }
}

// MARK: - Migration Helper

extension LocationTrackingFacade {
    /// Creates a facade instance to replace LocationTrackingManager
    static func replacementForLocationTrackingManager() -> LocationTrackingFacade {
        LocationTrackingFacade()
    }
}