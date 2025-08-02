import Foundation
import CoreLocation
import UIKit
import Observation

// MARK: - Power Management State
enum PowerState: String, CaseIterable, Sendable {
    case normal
    case lowPowerMode
    case critical
    
    var batteryThreshold: Double {
        switch self {
        case .normal: return 0.3 // 30%
        case .lowPowerMode: return 0.2 // 20%
        case .critical: return 0.1 // 10%
        }
    }
}

// MARK: - GPS Configuration
struct GPSConfiguration: Sendable {
    let accuracy: CLLocationAccuracy
    let distanceFilter: CLLocationDistance
    let updateFrequency: TimeInterval // seconds between updates
    let activityType: CLActivityType
    
    static let highPerformance = GPSConfiguration(
        accuracy: kCLLocationAccuracyBestForNavigation,
        distanceFilter: 5.0,
        updateFrequency: 0.1, // 10Hz
        activityType: .fitness
    )
    
    static let balanced = GPSConfiguration(
        accuracy: kCLLocationAccuracyBest,
        distanceFilter: 7.0,
        updateFrequency: 0.5, // 2Hz
        activityType: .fitness
    )
    
    static let batterySaver = GPSConfiguration(
        accuracy: kCLLocationAccuracyNearestTenMeters,
        distanceFilter: 10.0,
        updateFrequency: 1.0, // 1Hz
        activityType: .fitness
    )
    
    static let critical = GPSConfiguration(
        accuracy: kCLLocationAccuracyHundredMeters,
        distanceFilter: 15.0,
        updateFrequency: 2.0, // 0.5Hz
        activityType: .fitness
    )
}

// MARK: - Movement Pattern
enum MovementPattern: String, CaseIterable, Sendable {
    case stationary
    case walking
    case jogging
    case running
    case unknown
    
    init(from speed: Double) {
        switch speed {
        case 0..<0.5:
            self = .stationary
        case 0.5..<2.0:
            self = .walking
        case 2.0..<3.5:
            self = .jogging
        case 3.5...:
            self = .running
        default:
            self = .unknown
        }
    }
    
    var expectedConfiguration: GPSConfiguration {
        switch self {
        case .stationary:
            return .batterySaver
        case .walking:
            return .balanced
        case .jogging, .running:
            return .highPerformance
        case .unknown:
            return .balanced
        }
    }
}

// MARK: - Battery Status
struct BatteryStatus: Sendable {
    let level: Float
    let state: UIDevice.BatteryState
    let isLowPowerModeEnabled: Bool
    
    var powerState: PowerState {
        if isLowPowerModeEnabled || level <= PowerState.lowPowerMode.batteryThreshold {
            return level <= PowerState.critical.batteryThreshold ? .critical : .lowPowerMode
        }
        return .normal
    }
    
    static var current: BatteryStatus {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        
        return BatteryStatus(
            level: device.batteryLevel,
            state: device.batteryState,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}

// MARK: - Adaptive GPS Manager Actor
@Observable
@MainActor
final class AdaptiveGPSManager: NSObject {
    // MARK: - Published Properties
    var currentConfiguration: GPSConfiguration = .balanced
    var currentMovementPattern: MovementPattern = .unknown
    var batteryStatus: BatteryStatus = .current
    var averageSpeed: Double = 0.0
    var isAdaptiveMode: Bool = true
    var batteryOptimizationEnabled: Bool = true
    
    // Performance metrics
    var updateCount: Int = 0
    var batteryUsageEstimate: Double = 0.0 // Estimated percentage per hour
    
    // MARK: - Private Properties
    private var speedBuffer: [Double] = []
    private let speedBufferSize = 20
    private var lastConfigurationUpdate: Date?
    private let configurationUpdateInterval: TimeInterval = 5.0 // seconds
    
    // Battery monitoring
    private var batteryObserver: NSObjectProtocol?
    private var lowPowerModeObserver: NSObjectProtocol?
    
    // Update frequency tracking
    private var lastUpdateTime: Date?
    private var updateFrequencyBuffer: [TimeInterval] = []
    private let updateFrequencyBufferSize = 10
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupBatteryMonitoring()
        updateBatteryStatus()
    }
    
    deinit {
        cleanupBatteryMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Analyzes location update and determines optimal GPS configuration
    func analyzeLocationUpdate(_ location: CLLocation) {
        guard isAdaptiveMode else { return }
        
        updateCount += 1
        updateSpeedMetrics(location.speed)
        updateFrequencyTracking()
        
        // Update movement pattern
        let newPattern = MovementPattern(from: averageSpeed)
        if newPattern != currentMovementPattern {
            currentMovementPattern = newPattern
        }
        
        // Check if configuration needs updating
        if shouldUpdateConfiguration() {
            updateConfiguration()
        }
        
        // Update battery usage estimate
        updateBatteryUsageEstimate()
    }
    
    /// Forces a configuration update based on current conditions
    func forceConfigurationUpdate() {
        updateBatteryStatus()
        updateConfiguration()
    }
    
    /// Resets all tracking metrics
    func resetMetrics() {
        speedBuffer.removeAll()
        updateFrequencyBuffer.removeAll()
        updateCount = 0
        batteryUsageEstimate = 0.0
        averageSpeed = 0.0
        lastUpdateTime = nil
        lastConfigurationUpdate = nil
    }
    
    /// Gets recommended configuration for manual override
    func getRecommendedConfiguration() -> GPSConfiguration {
        let baseConfig = currentMovementPattern.expectedConfiguration
        return adjustConfigurationForBattery(baseConfig)
    }
    
    /// Enables or disables adaptive mode
    func setAdaptiveMode(_ enabled: Bool) {
        isAdaptiveMode = enabled
        if enabled {
            forceConfigurationUpdate()
        }
    }
    
    /// Enables or disables battery optimization
    func setBatteryOptimization(_ enabled: Bool) {
        batteryOptimizationEnabled = enabled
        if enabled {
            forceConfigurationUpdate()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBatteryMonitoring() {
        // Monitor battery level changes
        batteryObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryStatus()
            }
        }
        
        // Monitor low power mode changes
        lowPowerModeObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryStatus()
                self?.forceConfigurationUpdate()
            }
        }
    }
    
    private func cleanupBatteryMonitoring() {
        if let observer = batteryObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = lowPowerModeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func updateBatteryStatus() {
        batteryStatus = .current
    }
    
    private func updateSpeedMetrics(_ speed: Double) {
        // Only track positive speeds
        let validSpeed = max(0, speed)
        
        speedBuffer.append(validSpeed)
        if speedBuffer.count > speedBufferSize {
            speedBuffer.removeFirst()
        }
        
        // Calculate rolling average
        averageSpeed = speedBuffer.reduce(0, +) / Double(speedBuffer.count)
    }
    
    private func updateFrequencyTracking() {
        let now = Date()
        if let lastUpdate = lastUpdateTime {
            let interval = now.timeIntervalSince(lastUpdate)
            updateFrequencyBuffer.append(interval)
            
            if updateFrequencyBuffer.count > updateFrequencyBufferSize {
                updateFrequencyBuffer.removeFirst()
            }
        }
        lastUpdateTime = now
    }
    
    private func shouldUpdateConfiguration() -> Bool {
        guard let lastUpdate = lastConfigurationUpdate else { return true }
        return Date().timeIntervalSince(lastUpdate) >= configurationUpdateInterval
    }
    
    private func updateConfiguration() {
        let baseConfig = currentMovementPattern.expectedConfiguration
        let optimizedConfig = batteryOptimizationEnabled ? 
            adjustConfigurationForBattery(baseConfig) : baseConfig
        
        if configurationChanged(from: currentConfiguration, to: optimizedConfig) {
            currentConfiguration = optimizedConfig
            lastConfigurationUpdate = Date()
        }
    }
    
    private func adjustConfigurationForBattery(_ config: GPSConfiguration) -> GPSConfiguration {
        switch batteryStatus.powerState {
        case .normal:
            return config
        case .lowPowerMode:
            return GPSConfiguration(
                accuracy: max(config.accuracy, kCLLocationAccuracyNearestTenMeters),
                distanceFilter: max(config.distanceFilter, 8.0),
                updateFrequency: max(config.updateFrequency, 0.5),
                activityType: config.activityType
            )
        case .critical:
            return .critical
        }
    }
    
    private func configurationChanged(from old: GPSConfiguration, to new: GPSConfiguration) -> Bool {
        return old.accuracy != new.accuracy ||
               old.distanceFilter != new.distanceFilter ||
               abs(old.updateFrequency - new.updateFrequency) > 0.01
    }
    
    func updateBatteryUsageEstimate() {
        // Simplified battery usage estimation based on configuration
        let baseUsage: Double
        
        switch currentConfiguration.accuracy {
        case kCLLocationAccuracyBestForNavigation:
            baseUsage = 12.0 // 12% per hour
        case kCLLocationAccuracyBest:
            baseUsage = 8.0 // 8% per hour
        case kCLLocationAccuracyNearestTenMeters:
            baseUsage = 5.0 // 5% per hour
        case kCLLocationAccuracyHundredMeters:
            baseUsage = 3.0 // 3% per hour
        default:
            baseUsage = 6.0 // 6% per hour
        }
        
        // Adjust for update frequency (more frequent = more battery)
        let frequencyMultiplier = currentConfiguration.updateFrequency < 0.5 ? 1.5 : 1.0
        
        batteryUsageEstimate = baseUsage * frequencyMultiplier
    }
    
    // MARK: - Public Configuration Properties
    
    var isHighPerformanceMode: Bool {
        currentConfiguration.accuracy == kCLLocationAccuracyBestForNavigation
    }
    
    var isBatterySaverMode: Bool {
        currentConfiguration.accuracy >= kCLLocationAccuracyNearestTenMeters
    }
    
    var currentUpdateFrequencyHz: Double {
        1.0 / currentConfiguration.updateFrequency
    }
    
    var averageUpdateInterval: TimeInterval {
        guard !updateFrequencyBuffer.isEmpty else { return 1.0 }
        return updateFrequencyBuffer.reduce(0, +) / Double(updateFrequencyBuffer.count)
    }
    
    // MARK: - Battery Alerts
    
    var shouldShowBatteryAlert: Bool {
        batteryStatus.level <= 0.15 && !batteryStatus.isLowPowerModeEnabled
    }
    
    var batteryAlertMessage: String {
        switch batteryStatus.powerState {
        case .normal:
            return ""
        case .lowPowerMode:
            return "Low Power Mode: GPS accuracy reduced to preserve battery"
        case .critical:
            return "Critical battery: GPS switched to minimal accuracy mode"
        }
    }
}

// MARK: - Debug Information
extension AdaptiveGPSManager {
    var debugInfo: String {
        """
        Adaptive GPS Manager Debug Info:
        - Movement Pattern: \(currentMovementPattern.rawValue)
        - Average Speed: \(String(format: "%.2f", averageSpeed)) m/s
        - Battery Level: \(String(format: "%.0f", batteryStatus.level * 100))%
        - Power State: \(batteryStatus.powerState.rawValue)
        - Current Accuracy: \(accuracyDescription)
        - Distance Filter: \(currentConfiguration.distanceFilter)m
        - Update Frequency: \(String(format: "%.1f", currentUpdateFrequencyHz))Hz
        - Battery Usage Estimate: \(String(format: "%.1f", batteryUsageEstimate))%/hour
        - Update Count: \(updateCount)
        - Adaptive Mode: \(isAdaptiveMode ? "ON" : "OFF")
        """
    }
    
    private var accuracyDescription: String {
        switch currentConfiguration.accuracy {
        case kCLLocationAccuracyBestForNavigation:
            return "Best for Navigation"
        case kCLLocationAccuracyBest:
            return "Best"
        case kCLLocationAccuracyNearestTenMeters:
            return "10 meters"
        case kCLLocationAccuracyHundredMeters:
            return "100 meters"
        case kCLLocationAccuracyKilometer:
            return "1 kilometer"
        case kCLLocationAccuracyThreeKilometers:
            return "3 kilometers"
        default:
            return "Unknown"
        }
    }
}