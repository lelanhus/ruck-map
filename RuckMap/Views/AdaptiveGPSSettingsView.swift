import SwiftUI
import CoreLocation

// MARK: - Adaptive GPS Settings View
struct AdaptiveGPSSettingsView: View {
    @Bindable var locationManager: LocationTrackingManager
    @State private var showDebugInfo = false
    
    var body: some View {
        NavigationView {
            List {
                // Adaptive GPS Controls
                adaptiveControlsSection
                
                // Current Status
                statusSection
                
                // Battery Information
                batterySection
                
                // Performance Metrics
                metricsSection
                
                // Debug Information
                if showDebugInfo {
                    debugSection
                }
            }
            .navigationTitle("Adaptive GPS")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Debug") {
                        showDebugInfo.toggle()
                    }
                }
            }
        }
    }
    
    // MARK: - Adaptive Controls Section
    
    private var adaptiveControlsSection: some View {
        Section("Adaptive GPS Controls") {
            Toggle("Adaptive GPS Mode", isOn: Binding(
                get: { locationManager.adaptiveGPSManager.isAdaptiveMode },
                set: { locationManager.enableAdaptiveGPS($0) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .green))
            
            Toggle("Battery Optimization", isOn: Binding(
                get: { locationManager.adaptiveGPSManager.batteryOptimizationEnabled },
                set: { locationManager.enableBatteryOptimization($0) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .orange))
            .disabled(!locationManager.adaptiveGPSManager.isAdaptiveMode)
            
            Button("Force Configuration Update") {
                locationManager.forceGPSConfigurationUpdate()
            }
            .disabled(!locationManager.adaptiveGPSManager.isAdaptiveMode)
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        Section("Current Status") {
            HStack {
                Text("Movement Pattern")
                Spacer()
                Text(locationManager.adaptiveGPSManager.currentMovementPattern.rawValue.capitalized)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Average Speed")
                Spacer()
                Text("\(String(format: "%.1f", locationManager.adaptiveGPSManager.averageSpeed)) m/s")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("GPS Accuracy")
                Spacer()
                Text(accuracyDescription)
                    .foregroundColor(accuracyColor)
            }
            
            HStack {
                Text("Update Frequency")
                Spacer()
                Text("\(String(format: "%.1f", locationManager.adaptiveGPSManager.currentUpdateFrequencyHz)) Hz")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Distance Filter")
                Spacer()
                Text("\(String(format: "%.0f", locationManager.adaptiveGPSManager.currentConfiguration.distanceFilter))m")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Battery Section
    
    private var batterySection: some View {
        Section("Battery Information") {
            HStack {
                Text("Battery Level")
                Spacer()
                HStack {
                    Text("\(String(format: "%.0f", locationManager.adaptiveGPSManager.batteryStatus.level * 100))%")
                    Image(systemName: batteryIconName)
                        .foregroundColor(batteryColor)
                }
                .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Power State")
                Spacer()
                Text(locationManager.adaptiveGPSManager.batteryStatus.powerState.rawValue.capitalized)
                    .foregroundColor(powerStateColor)
            }
            
            HStack {
                Text("Estimated Usage")
                Spacer()
                Text("\(String(format: "%.1f", locationManager.batteryUsageEstimate))%/hour")
                    .foregroundColor(usageColor)
            }
            
            if locationManager.shouldShowBatteryAlert {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(locationManager.batteryAlertMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Metrics Section
    
    private var metricsSection: some View {
        Section("Performance Metrics") {
            HStack {
                Text("Total Updates")
                Spacer()
                Text("\(locationManager.adaptiveGPSManager.updateCount)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Average Update Interval")
                Spacer()
                Text("\(String(format: "%.2f", locationManager.adaptiveGPSManager.averageUpdateInterval))s")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Performance Mode")
                Spacer()
                HStack {
                    if locationManager.adaptiveGPSManager.isHighPerformanceMode {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                        Text("High Performance")
                            .foregroundColor(.green)
                    } else if locationManager.adaptiveGPSManager.isBatterySaverMode {
                        Image(systemName: "battery.25")
                            .foregroundColor(.orange)
                        Text("Battery Saver")
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "dial.max")
                            .foregroundColor(.blue)
                        Text("Balanced")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    // MARK: - Debug Section
    
    private var debugSection: some View {
        Section("Debug Information") {
            VStack(alignment: .leading, spacing: 8) {
                Text(locationManager.adaptiveGPSManager.debugInfo)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Computed Properties
    
    private var accuracyDescription: String {
        switch locationManager.adaptiveGPSManager.currentConfiguration.accuracy {
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
    
    private var accuracyColor: Color {
        switch locationManager.adaptiveGPSManager.currentConfiguration.accuracy {
        case kCLLocationAccuracyBestForNavigation, kCLLocationAccuracyBest:
            return .green
        case kCLLocationAccuracyNearestTenMeters:
            return .blue
        case kCLLocationAccuracyHundredMeters:
            return .orange
        default:
            return .red
        }
    }
    
    private var batteryIconName: String {
        let level = locationManager.adaptiveGPSManager.batteryStatus.level
        switch level {
        case 0.75...:
            return "battery.100"
        case 0.5..<0.75:
            return "battery.75"
        case 0.25..<0.5:
            return "battery.50"
        case 0.1..<0.25:
            return "battery.25"
        default:
            return "battery.0"
        }
    }
    
    private var batteryColor: Color {
        let level = locationManager.adaptiveGPSManager.batteryStatus.level
        if locationManager.adaptiveGPSManager.batteryStatus.isLowPowerModeEnabled {
            return .orange
        }
        switch level {
        case 0.5...:
            return .green
        case 0.2..<0.5:
            return .orange
        default:
            return .red
        }
    }
    
    private var powerStateColor: Color {
        switch locationManager.adaptiveGPSManager.batteryStatus.powerState {
        case .normal:
            return .green
        case .lowPowerMode:
            return .orange
        case .critical:
            return .red
        }
    }
    
    private var usageColor: Color {
        let usage = locationManager.batteryUsageEstimate
        switch usage {
        case 0..<5:
            return .green
        case 5..<10:
            return .blue
        case 10..<15:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Preview
#Preview {
    AdaptiveGPSSettingsView(locationManager: LocationTrackingManager())
}