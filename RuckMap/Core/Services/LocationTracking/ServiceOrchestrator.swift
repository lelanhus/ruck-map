import Foundation
import CoreLocation
import os.log

/// Orchestrates all tracking-related services
@MainActor
final class ServiceOrchestrator: ObservableObject {
    private let logger = Logger(subsystem: "com.ruckmap", category: "ServiceOrchestrator")
    
    // Services
    let adaptiveGPSManager: AdaptiveGPSManager
    let motionLocationManager: MotionLocationManager
    let elevationManager: ElevationManager
    let terrainDetectionManager: TerrainDetectionManager
    let weatherService: WeatherService
    let calorieCalculator: CalorieCalculator
    let batteryOptimizationManager: BatteryOptimizationManager
    
    // Current session
    private var currentSession: RuckSession?
    
    init() {
        // Initialize all services
        self.adaptiveGPSManager = AdaptiveGPSManager()
        self.motionLocationManager = MotionLocationManager()
        self.elevationManager = ElevationManager()
        self.terrainDetectionManager = TerrainDetectionManager()
        self.weatherService = WeatherService()
        self.calorieCalculator = CalorieCalculator()
        self.batteryOptimizationManager = BatteryOptimizationManager()
        
        logger.info("Service orchestrator initialized")
    }
    
    /// Start all services for a session
    func startServices(for session: RuckSession) async {
        currentSession = session
        
        // Start services concurrently
        async let startGPS: Void = adaptiveGPSManager.startTracking()
        async let startMotion: Void = motionLocationManager.start()
        async let startElevation: Void = elevationManager.startUpdating()
        async let startTerrain: Void = terrainDetectionManager.startDetection()
        async let startBattery: Void = batteryOptimizationManager.startMonitoring()
        
        // Wait for all to start
        _ = await (startGPS, startMotion, startElevation, startTerrain, startBattery)
        
        logger.info("All services started for session")
    }
    
    /// Stop all services
    func stopServices() async {
        // Stop services concurrently
        async let stopGPS: Void = adaptiveGPSManager.stopTracking()
        async let stopMotion: Void = motionLocationManager.stop()
        async let stopElevation: Void = elevationManager.stopUpdating()
        async let stopTerrain: Void = terrainDetectionManager.stopDetection()
        async let stopBattery: Void = batteryOptimizationManager.stopMonitoring()
        
        // Wait for all to stop
        _ = await (stopGPS, stopMotion, stopElevation, stopTerrain, stopBattery)
        
        currentSession = nil
        logger.info("All services stopped")
    }
    
    /// Update all services with new location
    func updateServices(with location: CLLocation) async throws {
        guard let session = currentSession else { return }
        
        // Update services concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Elevation update
            group.addTask { [weak self] in
                guard let self = self else { return }
                _ = try await self.elevationManager.processLocationUpdate(location)
            }
            
            // Terrain detection
            group.addTask { [weak self] in
                guard let self = self else { return }
                let terrain = try await self.terrainDetectionManager.detectTerrain(
                    at: location,
                    using: session
                )
                if terrain.confidence > 0.7 {
                    await self.handleTerrainUpdate(terrain, for: session)
                }
            }
            
            // Weather update (less frequent)
            if shouldUpdateWeather() {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    try await self.weatherService.updateWeather(for: location, session: session)
                }
            }
            
            // Motion analysis
            group.addTask { [weak self] in
                guard let self = self else { return }
                await self.motionLocationManager.updateWithLocation(location)
            }
            
            try await group.waitForAll()
        }
    }
    
    /// Update GPS configuration based on conditions
    func updateGPSConfiguration() async {
        let batteryState = await batteryOptimizationManager.getCurrentState()
        let config = await adaptiveGPSManager.adjustConfiguration(
            batteryLevel: batteryState.level,
            isCharging: batteryState.isCharging
        )
        
        logger.info("Updated GPS configuration: \(config)")
    }
    
    /// Get debug information from all services
    func getDebugInfo() async -> String {
        let gpsInfo = await adaptiveGPSManager.getDebugInfo()
        let elevationInfo = await elevationManager.getDebugInfo()
        let terrainInfo = await terrainDetectionManager.getDebugInfo()
        let batteryInfo = await batteryOptimizationManager.getDebugInfo()
        
        return """
        === Service Orchestrator Debug Info ===
        
        GPS Manager:
        \(gpsInfo)
        
        Elevation Manager:
        \(elevationInfo)
        
        Terrain Detection:
        \(terrainInfo)
        
        Battery Optimization:
        \(batteryInfo)
        """
    }
    
    // MARK: - Private Methods
    
    private func handleTerrainUpdate(_ terrain: DetectedTerrain, for session: RuckSession) async {
        // Update session with terrain info
        // This would typically update the session's terrain segments
        logger.info("Terrain updated: \(terrain.type.displayName) with confidence \(terrain.confidence)")
    }
    
    private var lastWeatherUpdate = Date.distantPast
    private func shouldUpdateWeather() -> Bool {
        // Update weather every 5 minutes
        Date().timeIntervalSince(lastWeatherUpdate) > 300
    }
}