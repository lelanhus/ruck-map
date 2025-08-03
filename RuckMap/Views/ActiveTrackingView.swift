import SwiftUI
import SwiftData
import MapKit

struct ActiveTrackingView: View {
    @State var locationManager: LocationTrackingManager
    @Environment(\.modelContext) private var modelContext
    @State private var showEndConfirmation = false
    @State private var currentGrade: Double = 0.0
    @State private var totalElevationGain: Double = 0.0
    @State private var totalElevationLoss: Double = 0.0
    @AppStorage("showCalorieImpact") private var showCalorieImpact = true
    
    private var formattedDistance: String {
        let miles = locationManager.totalDistance / 1609.34
        return String(format: "%.2f mi", miles)
    }
    
    private var formattedPace: String {
        guard locationManager.currentPace > 0 else { return "--:--" }
        let minutes = Int(locationManager.currentPace)
        let seconds = Int((locationManager.currentPace - Double(minutes)) * 60)
        return String(format: "%d:%02d /mi", Int(locationManager.currentPace * 1.60934), seconds)
    }
    
    private var formattedDuration: String {
        guard let session = locationManager.currentSession else { return "00:00" }
        let duration = session.duration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private var formattedGrade: String {
        let absGrade = abs(currentGrade)
        let sign = currentGrade >= 0 ? "+" : "-"
        return String(format: "%@%.1f%%", sign, absGrade)
    }
    
    private var formattedElevationGain: String {
        let feet = totalElevationGain * 3.28084
        return String(format: "%.0f ft", feet)
    }
    
    private var formattedElevationLoss: String {
        let feet = totalElevationLoss * 3.28084
        return String(format: "%.0f ft", feet)
    }
    
    private var formattedCalories: String {
        let calories = locationManager.totalCaloriesBurned
        return String(format: "%.0f cal", calories)
    }
    
    private var formattedCalorieBurnRate: String {
        let rate = locationManager.currentCalorieBurnRate
        return String(format: "%.1f cal/min", rate)
    }
    
    private var weatherImpactPercentage: Int {
        guard let conditions = locationManager.currentWeatherConditions else { return 0 }
        let adjustmentFactor = conditions.temperatureAdjustmentFactor
        return Int((adjustmentFactor - 1.0) * 100)
    }
    
    private var gradeColor: Color {
        let absGrade = abs(currentGrade)
        switch absGrade {
        case 0..<3:
            return .green
        case 3..<8:
            return .orange
        case 8..<15:
            return .red
        default:
            return .purple
        }
    }
    
    private var batteryUsageColor: Color {
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
    
    private var motionActivityIcon: String {
        switch locationManager.getMotionActivity() {
        case .stationary:
            return "figure.stand"
        case .walking:
            return "figure.walk"
        case .running:
            return "figure.run"
        case .cycling:
            return "bicycle"
        case .automotive:
            return "car.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private var motionActivityColor: Color {
        let confidence = locationManager.motionConfidence
        switch locationManager.getMotionActivity() {
        case .stationary:
            return confidence > 0.7 ? .gray : .secondary
        case .walking:
            return confidence > 0.7 ? .green : .secondary
        case .running:
            return confidence > 0.7 ? .orange : .secondary
        case .cycling:
            return confidence > 0.7 ? .blue : .secondary
        case .automotive:
            return confidence > 0.7 ? .purple : .secondary
        case .unknown:
            return .secondary
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with GPS status and adaptive info
            VStack(spacing: 4) {
                HStack {
                    Label(locationManager.gpsAccuracy.description, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(Color(locationManager.gpsAccuracy.color))
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    // Adaptive GPS indicator
                    if locationManager.adaptiveGPSManager.isAdaptiveMode {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .font(.caption)
                            Text("ADAPTIVE")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                    }
                    
                    if locationManager.isAutoPaused {
                        Text("AUTO-PAUSED")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.horizontal)
                    }
                }
                
                // Motion and battery status
                HStack {
                    // Motion activity indicator
                    HStack(spacing: 2) {
                        Image(systemName: motionActivityIcon)
                            .font(.caption2)
                        Text(locationManager.getMotionActivity().description.uppercased())
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(motionActivityColor)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Battery usage estimate
                    HStack(spacing: 2) {
                        Image(systemName: "battery.25")
                            .font(.caption2)
                        Text("\(String(format: "%.1f", locationManager.batteryUsageEstimate))%/hr")
                            .font(.caption2)
                    }
                    .foregroundColor(batteryUsageColor)
                    .padding(.horizontal)
                }
                
                // Technical status row
                HStack {
                    // Location suppression status
                    if locationManager.isLocationUpdatesSuppressed {
                        HStack(spacing: 2) {
                            Image(systemName: "pause.circle.fill")
                                .font(.caption2)
                            Text("SUPPRESSED")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Movement pattern
                    Text(locationManager.adaptiveGPSManager.currentMovementPattern.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Update frequency
                    Text("\(String(format: "%.1f", locationManager.adaptiveGPSManager.currentUpdateFrequencyHz))Hz")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                // Battery alert if needed
                if locationManager.shouldShowBatteryAlert {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text(locationManager.batteryAlertMessage)
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                    .padding(.top, 2)
                }
                
                // Weather alerts
                ForEach(locationManager.weatherAlerts, id: \.title) { alert in
                    HStack {
                        Image(systemName: weatherAlertIcon(alert.severity))
                            .font(.caption2)
                        Text(alert.title)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(weatherAlertColor(alert.severity))
                    .padding(.horizontal)
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Main metrics
            ScrollView {
                VStack(spacing: 20) {
                    // Distance card
                    MetricCard(
                        title: "DISTANCE",
                        value: formattedDistance,
                        icon: "map",
                        color: .blue
                    )
                    
                    // Time card
                    MetricCard(
                        title: "TIME",
                        value: formattedDuration,
                        icon: "clock",
                        color: .green
                    )
                    
                    // Pace card
                    MetricCard(
                        title: "PACE",
                        value: formattedPace,
                        icon: "speedometer",
                        color: .orange
                    )
                    
                    // Load weight card
                    if let session = locationManager.currentSession {
                        MetricCard(
                            title: "LOAD",
                            value: String(format: "%.0f lbs", session.loadWeight * 2.20462),
                            icon: "backpack",
                            color: .purple
                        )
                    }
                    
                    // Current grade card
                    MetricCard(
                        title: "GRADE",
                        value: formattedGrade,
                        icon: currentGrade >= 0 ? "arrow.up.right" : "arrow.down.right",
                        color: gradeColor
                    )
                    
                    // Calorie metrics row
                    HStack(spacing: 12) {
                        CalorieMetricCard(
                            title: "CALORIES",
                            value: formattedCalories,
                            icon: "flame.fill",
                            color: .red,
                            weatherImpact: showCalorieImpact ? weatherImpactPercentage : nil
                        )
                        
                        MetricCard(
                            title: "BURN RATE",
                            value: formattedCalorieBurnRate,
                            icon: "speedometer",
                            color: .orange
                        )
                    }
                    
                    // Elevation metrics row
                    HStack(spacing: 12) {
                        ElevationMetricCard(
                            title: "GAIN",
                            value: formattedElevationGain,
                            icon: "arrow.up",
                            color: .green
                        )
                        
                        ElevationMetricCard(
                            title: "LOSS",
                            value: formattedElevationLoss,
                            icon: "arrow.down",
                            color: .red
                        )
                    }
                    
                    // Weather information
                    if let weather = locationManager.currentWeatherConditions {
                        WeatherCard(
                            conditions: weather,
                            showCalorieImpact: showCalorieImpact
                        )
                    }
                }
                .padding()
            }
            
            // Control buttons
            VStack(spacing: 15) {
                // Pause/Resume button
                Button(action: { locationManager.togglePause() }) {
                    HStack {
                        Image(systemName: locationManager.trackingState == .paused ? "play.fill" : "pause.fill")
                        Text(locationManager.trackingState == .paused ? "Resume" : "Pause")
                    }
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(locationManager.trackingState == .paused ? Color.green : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Stop button
                Button(action: { showEndConfirmation = true }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("End Ruck")
                    }
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topTrailing) {
            // Terrain override overlay
            if locationManager.trackingState == .tracking {
                TerrainOverlayCompat(locationManager: locationManager)
            }
        }
        .alert("End Ruck?", isPresented: $showEndConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) {
                locationManager.stopTracking()
                try? modelContext.save()
            }
        } message: {
            Text("Are you sure you want to end this ruck session?")
        }
        .task {
            // Update elevation metrics periodically
            while !Task.isCancelled {
                totalElevationGain = locationManager.elevationManager.elevationGain
                totalElevationLoss = locationManager.elevationManager.elevationLoss
                currentGrade = locationManager.elevationManager.currentGrade
                
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func weatherAlertIcon(_ severity: WeatherAlertSeverity) -> String {
        switch severity {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon"
        }
    }
    
    private func weatherAlertColor(_ severity: WeatherAlertSeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct ElevationMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

struct CalorieMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let weatherImpact: Int?
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    // Weather impact indicator
                    if let impact = weatherImpact, impact != 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "cloud.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("\(impact >= 0 ? "+" : "")\(impact)%")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(impact > 0 ? .orange : .green)
                        }
                    }
                }
            }
            
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Weather Card Component

struct WeatherCard: View {
    let conditions: WeatherConditions
    let showCalorieImpact: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "cloud.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weather")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(conditions.temperatureFahrenheit))°F")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                if showCalorieImpact {
                    calorieImpactBadge
                }
            }
            
            HStack(spacing: 16) {
                weatherDetail(
                    icon: "humidity.fill",
                    value: "\(Int(conditions.humidity))%"
                )
                
                weatherDetail(
                    icon: "wind.circle.fill",
                    value: "\(Int(conditions.windSpeedMPH)) mph"
                )
                
                if let description = conditions.weatherDescription {
                    Text(description.prefix(10))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var calorieImpactBadge: some View {
        let adjustmentFactor = conditions.temperatureAdjustmentFactor
        let percentage = Int((adjustmentFactor - 1.0) * 100)
        
        return VStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.caption2)
                .foregroundColor(.orange)
            
            Text("\(percentage >= 0 ? "+" : "")\(percentage)%")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(percentage > 0 ? .orange : .green)
        }
    }
    
    private func weatherDetail(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.blue)
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ActiveTrackingView(locationManager: LocationTrackingManager())
        .modelContainer(for: RuckSession.self, inMemory: true)
}