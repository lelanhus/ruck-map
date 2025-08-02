//
//  BatteryOptimizationManager.swift
//  RuckMap
//
//  Created by Battery Optimization on 8/2/25.
//

import Foundation
import CoreLocation
import UIKit
import Observation

/// Centralized battery optimization manager that coordinates all power-saving features
/// Target: Achieve <10% battery usage per hour during active tracking
@Observable
@MainActor
final class BatteryOptimizationManager {
    
    // MARK: - Types
    
    enum OptimizationLevel: String, CaseIterable, Sendable {
        case maximum = "Maximum Performance"
        case balanced = "Balanced"
        case batterySaver = "Battery Saver"
        case ultraLowPower = "Ultra Low Power"
        
        var estimatedBatteryUsage: ClosedRange<Double> {
            switch self {
            case .maximum: return 12.0...18.0
            case .balanced: return 8.0...12.0
            case .batterySaver: return 5.0...8.0
            case .ultraLowPower: return 2.0...5.0
            }
        }
        
        var description: String {
            switch self {
            case .maximum: return "Best accuracy, highest battery usage"
            case .balanced: return "Good accuracy, moderate battery usage"
            case .batterySaver: return "Reduced accuracy, extended battery life"
            case .ultraLowPower: return "Basic tracking, maximum battery life"
            }
        }
    }
    
    struct OptimizationMetrics: Sendable {
        let batteryUsageEstimate: Double
        let gpsUpdateFrequency: Double
        let motionUpdateFrequency: Double
        let elevationUpdateFrequency: Double
        let activeOptimizations: [String]
        let timestamp: Date
        
        var summary: String {
            """
            Battery Usage: \(String(format: "%.1f", batteryUsageEstimate))%/hour
            GPS Updates: \(String(format: "%.1f", gpsUpdateFrequency))Hz
            Motion Updates: \(String(format: "%.1f", motionUpdateFrequency))Hz
            Elevation Updates: Every \(String(format: "%.1f", elevationUpdateFrequency))s
            Active Optimizations: \(activeOptimizations.joined(separator: ", "))
            """
        }
    }
    
    // MARK: - Properties
    
    var currentOptimizationLevel: OptimizationLevel = .balanced
    var isAutoOptimizationEnabled: Bool = true
    var targetBatteryUsage: Double = 10.0 // 10% per hour target
    var currentBatteryUsage: Double = 0.0
    var sessionStartTime: Date?
    
    // Optimization flags
    var isUltraLowPowerModeActive: Bool = false
    var isSignificantLocationChangesActive: Bool = false
    var isAdaptiveFrequencyActive: Bool = true
    var isMotionBasedOptimizationActive: Bool = true
    
    // Dependencies
    private weak var adaptiveGPSManager: AdaptiveGPSManager?
    private weak var motionLocationManager: MotionLocationManager?
    private weak var elevationManager: ElevationManager?
    
    // Metrics tracking
    private var metricsHistory: [OptimizationMetrics] = []
    private let maxMetricsHistorySize = 100
    
    // MARK: - Initialization
    
    init() {
        setupBatteryMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Set up dependencies
    func configure(
        adaptiveGPS: AdaptiveGPSManager,
        motionLocation: MotionLocationManager,
        elevation: ElevationManager
    ) {
        self.adaptiveGPSManager = adaptiveGPS
        self.motionLocationManager = motionLocation
        self.elevationManager = elevation
        
        // Apply current optimization level
        applyOptimizationLevel(currentOptimizationLevel)
    }
    
    /// Start a new tracking session with optimization
    func startSession(optimizationLevel: OptimizationLevel? = nil) {
        sessionStartTime = Date()
        
        if let level = optimizationLevel {
            currentOptimizationLevel = level
        }
        
        applyOptimizationLevel(currentOptimizationLevel)
        
        // Enable auto-optimization for long sessions
        if isAutoOptimizationEnabled {
            scheduleAutoOptimization()
        }
    }
    
    /// End tracking session
    func endSession() {
        sessionStartTime = nil
        isUltraLowPowerModeActive = false
        isSignificantLocationChangesActive = false
        
        // Reset to balanced mode
        if isAutoOptimizationEnabled {
            applyOptimizationLevel(.balanced)
        }
    }
    
    /// Manually set optimization level
    func setOptimizationLevel(_ level: OptimizationLevel) {
        currentOptimizationLevel = level
        applyOptimizationLevel(level)
    }
    
    /// Enable or disable auto-optimization
    func setAutoOptimization(_ enabled: Bool) {
        isAutoOptimizationEnabled = enabled
        
        if enabled {
            scheduleAutoOptimization()
        }
    }
    
    /// Force optimization update based on current conditions
    func updateOptimizations() {
        guard isAutoOptimizationEnabled else { return }
        
        let batteryLevel = UIDevice.current.batteryLevel
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        let sessionDuration = sessionStartTime?.timeIntervalSinceNow ?? 0
        
        // Auto-adjust optimization level
        let recommendedLevel = calculateRecommendedOptimizationLevel(
            batteryLevel: batteryLevel,
            isLowPowerMode: isLowPowerMode,
            sessionDuration: abs(sessionDuration)
        )
        
        if recommendedLevel != currentOptimizationLevel {
            setOptimizationLevel(recommendedLevel)
        }
        
        // Update metrics
        updateMetrics()
    }
    
    /// Get current optimization metrics
    func getCurrentMetrics() -> OptimizationMetrics {
        let gpsFreq = 1.0 / (adaptiveGPSManager?.currentConfiguration.updateFrequency ?? 1.0)
        let motionFreq = motionLocationManager?.batteryOptimizedMode == true ? 2.0 : 5.0
        let elevationFreq = elevationManager?.configuration.updateInterval ?? 2.0
        
        var optimizations: [String] = []
        if isUltraLowPowerModeActive { optimizations.append("Ultra Low Power") }
        if isSignificantLocationChangesActive { optimizations.append("Significant Location Changes") }
        if isAdaptiveFrequencyActive { optimizations.append("Adaptive Frequency") }
        if isMotionBasedOptimizationActive { optimizations.append("Motion-Based Optimization") }
        
        return OptimizationMetrics(
            batteryUsageEstimate: adaptiveGPSManager?.batteryUsageEstimate ?? 0.0,
            gpsUpdateFrequency: gpsFreq,
            motionUpdateFrequency: motionFreq,
            elevationUpdateFrequency: elevationFreq,
            activeOptimizations: optimizations,
            timestamp: Date()
        )
    }
    
    /// Get optimization recommendations
    func getOptimizationRecommendations() -> [String] {
        var recommendations: [String] = []
        
        let currentUsage = adaptiveGPSManager?.batteryUsageEstimate ?? 0.0
        
        if currentUsage > targetBatteryUsage {
            if !isSignificantLocationChangesActive && adaptiveGPSManager?.currentMovementPattern == .stationary {
                recommendations.append("Enable significant location changes for stationary periods")
            }
            
            if currentOptimizationLevel == .maximum {
                recommendations.append("Switch to Balanced mode to reduce battery usage")
            } else if currentOptimizationLevel == .balanced && currentUsage > 12.0 {
                recommendations.append("Switch to Battery Saver mode")
            }
            
            if let sessionStart = sessionStartTime,
               Date().timeIntervalSince(sessionStart) > 7200, // 2 hours
               !isUltraLowPowerModeActive {
                recommendations.append("Enable Ultra Low Power mode for long sessions")
            }
        }
        
        return recommendations
    }
    
    // MARK: - Private Methods
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateOptimizations()
        }
        
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateOptimizations()
        }
    }
    
    private func applyOptimizationLevel(_ level: OptimizationLevel) {
        switch level {
        case .maximum:
            applyMaximumPerformanceSettings()
        case .balanced:
            applyBalancedSettings()
        case .batterySaver:
            applyBatterySaverSettings()
        case .ultraLowPower:
            applyUltraLowPowerSettings()
        }
        
        updateMetrics()
    }
    
    private func applyMaximumPerformanceSettings() {
        adaptiveGPSManager?.setBatteryOptimization(false)
        adaptiveGPSManager?.enableUltraLowPowerMode(false)
        adaptiveGPSManager?.enableSignificantLocationChanges(false)
        
        motionLocationManager?.setBatteryOptimizedMode(false)
        motionLocationManager?.enableMotionPrediction(true)
        
        elevationManager?.setBatteryOptimizedMode(false)
        
        isUltraLowPowerModeActive = false
        isSignificantLocationChangesActive = false
    }
    
    private func applyBalancedSettings() {
        adaptiveGPSManager?.setBatteryOptimization(true)
        adaptiveGPSManager?.enableUltraLowPowerMode(false)
        adaptiveGPSManager?.enableSignificantLocationChanges(false)
        
        motionLocationManager?.setBatteryOptimizedMode(false)
        motionLocationManager?.enableMotionPrediction(true)
        
        elevationManager?.setBatteryOptimizedMode(false)
        
        isUltraLowPowerModeActive = false
        isSignificantLocationChangesActive = false
    }
    
    private func applyBatterySaverSettings() {
        adaptiveGPSManager?.setBatteryOptimization(true)
        adaptiveGPSManager?.enableUltraLowPowerMode(false)
        
        motionLocationManager?.setBatteryOptimizedMode(true)
        motionLocationManager?.enableMotionPrediction(true)
        
        elevationManager?.setBatteryOptimizedMode(true)
        
        // Enable significant location changes for stationary periods
        if adaptiveGPSManager?.currentMovementPattern == .stationary {
            adaptiveGPSManager?.enableSignificantLocationChanges(true)
            isSignificantLocationChangesActive = true
        }
        
        isUltraLowPowerModeActive = false
    }
    
    private func applyUltraLowPowerSettings() {
        adaptiveGPSManager?.setBatteryOptimization(true)
        adaptiveGPSManager?.enableUltraLowPowerMode(true)
        adaptiveGPSManager?.enableSignificantLocationChanges(true)
        
        motionLocationManager?.setBatteryOptimizedMode(true)
        motionLocationManager?.enableMotionPrediction(false) // Disable prediction to save battery
        
        elevationManager?.setBatteryOptimizedMode(true)
        
        isUltraLowPowerModeActive = true
        isSignificantLocationChangesActive = true
    }
    
    private func calculateRecommendedOptimizationLevel(
        batteryLevel: Float,
        isLowPowerMode: Bool,
        sessionDuration: TimeInterval
    ) -> OptimizationLevel {
        
        // Critical battery level
        if batteryLevel <= 0.1 || isLowPowerMode {
            return .ultraLowPower
        }
        
        // Long session (>2 hours) - automatically switch to ultra low power
        if sessionDuration > 7200 {
            return .ultraLowPower
        }
        
        // Low battery level
        if batteryLevel <= 0.2 {
            return .batterySaver
        }
        
        // Medium battery level or moderate session duration
        if batteryLevel <= 0.5 || sessionDuration > 3600 {
            return .batterySaver
        }
        
        // Good battery level
        return .balanced
    }
    
    private func scheduleAutoOptimization() {
        // Update optimizations every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateOptimizations()
            }
        }
    }
    
    private func updateMetrics() {
        let metrics = getCurrentMetrics()
        currentBatteryUsage = metrics.batteryUsageEstimate
        
        metricsHistory.append(metrics)
        if metricsHistory.count > maxMetricsHistorySize {
            metricsHistory.removeFirst()
        }
    }
    
    // MARK: - Debug and Analysis
    
    func getOptimizationReport() -> String {
        let currentMetrics = getCurrentMetrics()
        let recommendations = getOptimizationRecommendations()
        
        var report = """
        === Battery Optimization Report ===
        Current Level: \(currentOptimizationLevel.rawValue)
        Target Usage: \(targetBatteryUsage)%/hour
        Current Usage: \(String(format: "%.1f", currentBatteryUsage))%/hour
        Status: \(currentBatteryUsage <= targetBatteryUsage ? "✅ On Target" : "⚠️ Above Target")
        
        \(currentMetrics.summary)
        
        """
        
        if !recommendations.isEmpty {
            report += """
            
            === Recommendations ===
            \(recommendations.map { "• \($0)" }.joined(separator: "\n"))
            """
        }
        
        if let sessionStart = sessionStartTime {
            let duration = Date().timeIntervalSince(sessionStart)
            report += """
            
            === Session Info ===
            Duration: \(String(format: "%.1f", duration / 3600)) hours
            Auto-Optimization: \(isAutoOptimizationEnabled ? "Enabled" : "Disabled")
            """
        }
        
        return report
    }
    
    func exportMetricsHistory() -> [OptimizationMetrics] {
        return metricsHistory
    }
}

// MARK: - Extensions

extension BatteryOptimizationManager {
    
    /// Quick battery health check
    var batteryHealthStatus: String {
        let batteryLevel = UIDevice.current.batteryLevel
        let usage = currentBatteryUsage
        
        if batteryLevel <= 0.1 {
            return "🔴 Critical Battery"
        } else if batteryLevel <= 0.2 {
            return "🟠 Low Battery"
        } else if usage > targetBatteryUsage * 1.5 {
            return "🟡 High Usage"
        } else if usage <= targetBatteryUsage {
            return "🟢 Optimal"
        } else {
            return "🟡 Above Target"
        }
    }
    
    /// Quick optimization summary
    var optimizationSummary: String {
        let activeCount = [
            isUltraLowPowerModeActive,
            isSignificantLocationChangesActive,
            isAdaptiveFrequencyActive,
            isMotionBasedOptimizationActive
        ].filter { $0 }.count
        
        return "\(activeCount)/4 optimizations active"
    }
}