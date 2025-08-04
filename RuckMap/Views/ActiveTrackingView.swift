import CoreHaptics
import MapKit
import SwiftData
import SwiftUI

// Temporary MapView stub for build verification
// TODO: Remove when MapView.swift is properly included in target
struct MapView: View {
    @State var locationManager: LocationTrackingManager
    let showCurrentLocation: Bool
    let followUser: Bool
    let showTerrain: Bool
    let interactionModes: MapInteractionModes
    
    var body: some View {
        Map()
            .overlay(
                Text("Map Integration\n(Build Verification)")
                    .font(.caption)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(),
                alignment: .topTrailing
            )
    }
}

struct MapInteractionModes: OptionSet {
    let rawValue: Int
    static let all = MapInteractionModes(rawValue: 1)
}

struct ActiveTrackingView: View {
    @State var locationManager: LocationTrackingManager
    @Environment(\.modelContext)
    private var modelContext
    @State private var showEndConfirmation = false
    @State private var showSaveError = false
    @State private var currentGrade: Double = 0.0
    @State private var totalElevationGain: Double = 0.0
    @State private var totalElevationLoss: Double = 0.0
    @State private var showLoadWeightAdjustment = false
    @State private var isLoading = false
    @State private var animatedDistance: Double = 0.0
    @State private var animatedCalories: Double = 0.0
    @State private var animatedPace: Double = 0.0
    @State private var lastGPSUpdate: Date?
    @State private var hapticEngine: CHHapticEngine?
    @State private var selectedTrackingTab: TrackingTab = .metrics
    @State private var tabTransition: AnyTransition = .slide
    @AppStorage("showCalorieImpact")
    private var showCalorieImpact = true
    
    enum TrackingTab: String, CaseIterable {
        case metrics = "Metrics"
        case map = "Map"
        
        var icon: String {
            switch self {
            case .metrics: return "chart.bar.fill"
            case .map: return "map.fill"
            }
        }
        
        var iconUnselected: String {
            switch self {
            case .metrics: return "chart.bar"
            case .map: return "map"
            }
        }
    }

    private var formattedDistance: String {
        let miles = locationManager.totalDistance / FormatUtilities.ConversionConstants.metersToMiles
        return String(format: "%.2f mi", miles)
    }

    private var formattedPace: String {
        guard locationManager.currentPace > 0 else {
            return "--:--"
        }
        // Convert pace from min/km to min/mi
        let paceInMinPerMile = locationManager.currentPace * 1.60934
        let minutes = Int(paceInMinPerMile)
        let seconds = Int((paceInMinPerMile - Double(minutes)) * 60)
        return String(format: "%d:%02d /mi", minutes, seconds)
    }

    private var formattedDuration: String {
        guard let session = locationManager.currentSession else {
            return "00:00"
        }
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
        let feet = totalElevationGain * FormatUtilities.ConversionConstants.metersToFeet
        return String(format: "%.0f ft", feet)
    }

    private var formattedElevationLoss: String {
        let feet = totalElevationLoss * FormatUtilities.ConversionConstants.metersToFeet
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
        guard let conditions = locationManager.currentWeatherConditions else {
            return 0
        }
        let adjustmentFactor = conditions.temperatureAdjustmentFactor
        return Int((adjustmentFactor - 1.0) * 100)
    }

    private var gradeColor: Color {
        let absGrade = abs(currentGrade)
        switch absGrade {
        case 0 ..< 3:
            return .green
        case 3 ..< 8:
            return .orange
        case 8 ..< 15:
            return .red
        default:
            return .purple
        }
    }

    private var batteryUsageColor: Color {
        let usage = locationManager.batteryUsageEstimate
        switch usage {
        case 0 ..< 5:
            return .green
        case 5 ..< 10:
            return .blue
        case 10 ..< 15:
            return .orange
        default:
            return .red
        }
    }

    private var motionActivityIcon: String {
        switch locationManager.getMotionActivity() {
        case .stationary:
            "figure.stand"
        case .walking:
            "figure.walk"
        case .running:
            "figure.run"
        case .cycling:
            "bicycle"
        case .automotive:
            "car.fill"
        case .unknown:
            "questionmark.circle"
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
            statusHeaderView
            
            // Tab view for metrics and map with optimized transitions
            TabView(selection: $selectedTrackingTab) {
                // Metrics Tab with performance optimization
                metricsTabView
                    .tabItem {
                        Label(
                            TrackingTab.metrics.rawValue,
                            systemImage: selectedTrackingTab == .metrics ? 
                                TrackingTab.metrics.icon : TrackingTab.metrics.iconUnselected
                        )
                    }
                    .tag(TrackingTab.metrics)
                    .accessibilityLabel("Metrics tab")
                    .accessibilityHint("Shows detailed tracking metrics including distance, pace, and elevation")
                
                // Map Tab with performance optimization
                mapTabView
                    .tabItem {
                        Label(
                            TrackingTab.map.rawValue,
                            systemImage: selectedTrackingTab == .map ? 
                                TrackingTab.map.icon : TrackingTab.map.iconUnselected
                        )
                    }
                    .tag(TrackingTab.map)
                    .accessibilityLabel("Map tab")
                    .accessibilityHint("Shows real-time route map with terrain overlays and location tracking")
            }
            .tint(.blue)
            
            // Control buttons (always visible)
            controlButtonsView
        }
        .navigationBarHidden(true)
        .alert("End Ruck?", isPresented: $showEndConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("End", role: .destructive) {
                locationManager.stopTracking()
                do {
                    try modelContext.save()
                } catch {
                    // Log error - in production app, show user-friendly error
                    showSaveError = true
                }
            }
        } message: {
            Text("Are you sure you want to end this ruck session?")
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK") {}
        } message: {
            Text("Failed to save ruck session. Please try again.")
        }
        .task { [weak locationManager] in
            // Optimized updates with adaptive frequency
            while !Task.isCancelled {
                guard let locationManager else { break }

                // Batch state updates for better performance
                await MainActor.run {
                    totalElevationGain = locationManager.elevationManager.elevationGain
                    totalElevationLoss = locationManager.elevationManager.elevationLoss
                    currentGrade = locationManager.elevationManager.currentGrade
                    
                    // Update GPS timestamp when we have a current location
                    if locationManager.currentLocation != nil {
                        lastGPSUpdate = Date()
                    }
                }

                // Adaptive update frequency based on tracking state
                let sleepDuration: Duration = locationManager.trackingState == .tracking ? .seconds(1) : .seconds(3)
                try? await Task.sleep(for: sleepDuration)
            }
        }
        .onAppear {
            setupHaptics()
            startAnimations()
        }
        .onDisappear {
            // Ensure haptic engine is properly stopped
            hapticEngine?.stop()
            hapticEngine = nil
        }
        .sheet(isPresented: $showLoadWeightAdjustment) {
            if let session = locationManager.currentSession {
                LoadWeightAdjustmentView(
                    currentWeight: session.loadWeight,
                    onSave: { newWeight in
                        triggerHapticFeedback(.success)
                        updateLoadWeight(newWeight)
                        showLoadWeightAdjustment = false
                    },
                    onCancel: {
                        triggerHapticFeedback(.light)
                        showLoadWeightAdjustment = false
                    }
                )
            }
        }
        .task {
            // High-frequency UI updates for 60fps
            while !Task.isCancelled {
                await updateAnimatedMetrics()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    // MARK: - View Components
    
    private var statusHeaderView: some View {
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
                Text(
                    locationManager.adaptiveGPSManager.currentMovementPattern.rawValue
                        .uppercased()
                )
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal)

                // Update frequency
                Text(
                    "\(String(format: "%.1f", locationManager.adaptiveGPSManager.currentUpdateFrequencyHz))Hz"
                )
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
    }
    
    private var metricsTabView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
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
                    LoadWeightCard(
                        currentWeight: session.loadWeight,
                        onAdjustTapped: {
                            triggerHapticFeedback(.light)
                            showLoadWeightAdjustment = true
                        }
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

                // Weather information with conditional rendering
                if let weather = locationManager.currentWeatherConditions {
                    WeatherCard(
                        conditions: weather,
                        showCalorieImpact: showCalorieImpact
                    )
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: weather.id)
                }
            }
            .padding()
        }
    }
    
    private var mapTabView: some View {
        ZStack {
            // Main map view
            MapView(
                locationManager: locationManager,
                showCurrentLocation: true,
                followUser: true,
                showTerrain: true,
                interactionModes: .all
            )
            
            // Floating metrics overlay on map
            VStack {
                HStack {
                    Spacer()
                    compactMetricsOverlay
                }
                Spacer()
            }
            .padding()
            
            // Terrain override overlay
            if locationManager.trackingState == .tracking {
                VStack {
                    HStack {
                        Spacer()
                        TerrainOverlayCompat(locationManager: locationManager)
                    }
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private var compactMetricsOverlay: some View {
        VStack(spacing: 8) {
            // Essential metrics overlay with optimized layout
            VStack(spacing: 6) {
                // Distance and time row
                HStack(spacing: 12) {
                    CompactMetric(
                        icon: "map",
                        value: formattedDistance,
                        color: .blue
                    )
                    
                    CompactMetric(
                        icon: "clock",
                        value: formattedDuration,
                        color: .green
                    )
                }
                
                // Pace and elevation row
                HStack(spacing: 12) {
                    CompactMetric(
                        icon: "speedometer",
                        value: formattedPace,
                        color: .orange
                    )
                    
                    CompactMetric(
                        icon: currentGrade >= 0 ? "arrow.up.right" : "arrow.down.right",
                        value: formattedGrade,
                        color: gradeColor
                    )
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Quick metrics: \(formattedDistance), \(formattedDuration), \(formattedPace), \(formattedGrade)")
        }
    }
    
    private var controlButtonsView: some View {
        VStack(spacing: 15) {
            // Pause/Resume button
            Button(action: {
                triggerHapticFeedback(.impact)
                locationManager.togglePause()
            }) {
                HStack {
                    Image(
                        systemName: locationManager
                            .trackingState == .paused ? "play.fill" : "pause.fill"
                    )
                    Text(locationManager.trackingState == .paused ? "Resume" : "Pause")
                }
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    locationManager.trackingState == .paused ? Color.green : Color
                        .orange
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            // Stop button
            Button(action: {
                triggerHapticFeedback(.warning)
                showEndConfirmation = true
            }) {
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

    // MARK: - Helper Functions

    private func weatherAlertIcon(_ severity: WeatherAlertSeverity) -> String {
        switch severity {
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .critical: "exclamationmark.octagon"
        }
    }

    private func weatherAlertColor(_ severity: WeatherAlertSeverity) -> Color {
        switch severity {
        case .info: .blue
        case .warning: .orange
        case .critical: .red
        }
    }

    // MARK: - Enhanced Methods

    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            // Device doesn't support haptics - gracefully degrade
            return
        }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()

            // Set up handlers for engine reset
            hapticEngine?.resetHandler = { [self] in
                // Attempt to restart the engine
                do {
                    try hapticEngine?.start()
                } catch {
                    // Haptics unavailable - continue without them
                    hapticEngine = nil
                }
            }

            hapticEngine?.stoppedHandler = { _ in
                // Engine stopped - haptics will be unavailable
                // In production, could log this for debugging
            }
        } catch {
            // Failed to start haptic engine - continue without haptics
            hapticEngine = nil
        }
    }

    private func triggerHapticFeedback(_ type: HapticFeedbackType) {
        switch type {
        case .light:
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        case .impact:
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        case .warning:
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.warning)
        case .success:
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
    }

    private func startAnimations() {
        animatedDistance = locationManager.totalDistance
        animatedCalories = locationManager.totalCaloriesBurned
        animatedPace = locationManager.currentPace
    }

    @MainActor
    private func updateAnimatedMetrics() async {
        let targetDistance = locationManager.totalDistance
        let targetCalories = locationManager.totalCaloriesBurned
        let targetPace = locationManager.currentPace

        // Smooth interpolation for metrics
        let interpolationFactor = 0.1

        withAnimation(.easeOut(duration: 0.5)) {
            animatedDistance += (targetDistance - animatedDistance) * interpolationFactor
            animatedCalories += (targetCalories - animatedCalories) * interpolationFactor
            animatedPace += (targetPace - animatedPace) * interpolationFactor
        }
    }

    private func updateLoadWeight(_ newWeight: Double) {
        guard let session = locationManager.currentSession else {
            return
        }

        isLoading = true

        Task {
            // Update the session load weight
            session.loadWeight = newWeight

            // Note: Calorie recalculation will happen automatically on next update cycle
            // as the calorie calculator uses the current session's weight

            await MainActor.run {
                isLoading = false
            }
        }
    }

    // MARK: - Haptic Feedback Types

    enum HapticFeedbackType {
        case light
        case impact
        case warning
        case success
    }
}

// MARK: - Enhanced Components

struct LoadWeightCard: View {
    let currentWeight: Double
    let onAdjustTapped: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "backpack")
                    .font(.title2)
                    .foregroundColor(.purple)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("LOAD")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Button(action: onAdjustTapped) {
                        HStack(spacing: 4) {
                            Text("ADJUST")
                                .font(.caption2)
                                .fontWeight(.bold)
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption2)
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.purple.opacity(0.1))
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .accessibilityLabel("Adjust load weight")
                    .accessibilityHint("Double tap to change the carried weight")
                }
            }

            Text(String(format: "%.0f lbs", currentWeight * FormatUtilities.ConversionConstants.kilogramsToPounds))
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

struct LoadWeightAdjustmentView: View {
    @State private var weight: Double
    let onSave: (Double) -> Void
    let onCancel: () -> Void

    init(
        currentWeight: Double,
        onSave: @escaping (Double) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _weight = State(initialValue: currentWeight)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Adjust Load Weight")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("This will recalculate your calories burned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    Text(String(format: "%.0f lbs", weight * FormatUtilities.ConversionConstants.kilogramsToPounds))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)

                    HStack {
                        Text("5 lbs")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Slider(
                            value: $weight,
                            in: 2.27 ... 68,
                            step: 2.27
                        ) // 5-150 lbs in 5 lb increments
                        .tint(.purple)

                        Text("150 lbs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Validate weight is realistic (at least 5 lbs / 2.27 kg)
                        let validatedWeight = max(2.27, weight)
                        onSave(validatedWeight)
                    }
                    .fontWeight(.semibold)
                    .disabled(weight < 2.27) // Disable if less than 5 lbs
                }
            }
            .navigationTitle("Load Weight")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EnhancedMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isAnimating: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .symbolEffect(.pulse, isActive: isAnimating)
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
                .contentTransition(.numericText())
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

struct EnhancedCalorieMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let weatherImpact: Int?
    let isAnimating: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .symbolEffect(.pulse, isActive: isAnimating)
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
                        .accessibilityLabel("Weather impact: \(impact) percent")
                    }
                }
            }

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.numericText())
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(title): \(value)" +
                (weatherImpact.map { ", weather impact \($0) percent" } ?? "")
        )
    }
}

struct EnhancedElevationMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isAnimating: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .symbolEffect(.bounce, value: isAnimating)
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
                .contentTransition(.numericText())
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Elevation \(title.lowercased()): \(value)")
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

// MARK: - Compact Metric Component

/// Optimized compact metric display for map overlay
struct CompactMetric: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value)")
        .contentTransition(.numericText())
    }
}

#Preview {
    ActiveTrackingView(locationManager: LocationTrackingManager())
        .modelContainer(for: RuckSession.self, inMemory: true)
}
