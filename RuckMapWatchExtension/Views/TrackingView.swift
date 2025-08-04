import SwiftUI
import CoreLocation

struct TrackingView: View {
    @Environment(WatchAppCoordinator.self) var appCoordinator
    @State private var showingLoadWeightInput = false
    @State private var loadWeight: Double = 20.0 // Default 20kg
    @State private var showingConfirmStop = false
    
    private var locationManager: WatchLocationManager? {
        appCoordinator.locationManager
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                headerSection
                
                // Main metrics
                if locationManager?.trackingState != .stopped {
                    activeMetricsSection
                } else {
                    startTrackingSection
                }
                
                // Control buttons
                controlButtonsSection
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("RuckMap")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLoadWeightInput) {
            LoadWeightInputView(loadWeight: $loadWeight) {
                startTracking()
            }
        }
        .alert("Stop Tracking", isPresented: $showingConfirmStop) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                stopTracking()
            }
        } message: {
            Text("Are you sure you want to stop this ruck session?")
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(spacing: 2) {
            HStack {
                // GPS Status Indicator
                Circle()
                    .fill(gpsStatusColor)
                    .frame(width: 8, height: 8)
                
                Text(gpsStatusText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Session Duration
                if let session = locationManager?.currentSession {
                    Text(formatDuration(session.duration))
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
            }
            
            // Auto-pause indicator
            if locationManager?.isAutoPaused == true {
                HStack {
                    Image(systemName: "pause.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption2)
                    
                    Text("Auto-Paused")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    private var activeMetricsSection: some View {
        VStack(spacing: 12) {
            // Primary metrics row
            HStack(spacing: 16) {
                MetricCard(
                    title: "Distance",
                    value: formatDistance(locationManager?.totalDistance ?? 0),
                    icon: "figure.walk"
                )
                
                MetricCard(
                    title: "Pace",
                    value: formatPace(locationManager?.currentPace ?? 0),
                    icon: "speedometer"
                )
            }
            
            // Secondary metrics row
            HStack(spacing: 16) {
                MetricCard(
                    title: "Calories",
                    value: "\(Int(locationManager?.totalCalories ?? 0))",
                    icon: "flame.fill"
                )
                
                MetricCard(
                    title: "Elevation",
                    value: formatElevation(locationManager?.currentElevation ?? 0),
                    icon: "mountain.2.fill"
                )
            }
            
            // Heart rate and additional metrics
            if let heartRate = locationManager?.currentHeartRate {
                HStack(spacing: 16) {
                    MetricCard(
                        title: "Heart Rate",
                        value: "\(Int(heartRate)) BPM",
                        icon: "heart.fill"
                    )
                    
                    MetricCard(
                        title: "Grade",
                        value: formatGrade(locationManager?.currentGrade ?? 0),
                        icon: "angle"
                    )
                }
            }
        }
    }
    
    private var startTrackingSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Ready to Ruck")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Tap Start to begin tracking your ruck march")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var controlButtonsSection: some View {
        VStack(spacing: 8) {
            switch locationManager?.trackingState {
            case .stopped:
                Button("Start Ruck") {
                    showingLoadWeightInput = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
            case .tracking:
                HStack(spacing: 12) {
                    Button("Pause") {
                        locationManager?.pauseTracking()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    
                    Button("Stop") {
                        showingConfirmStop = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.regular)
                }
                
            case .paused:
                HStack(spacing: 12) {
                    Button("Resume") {
                        locationManager?.resumeTracking()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    
                    Button("Stop") {
                        showingConfirmStop = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.regular)
                }
                
            case .none:
                EmptyView()
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Computed Properties
    
    private var gpsStatusColor: Color {
        switch locationManager?.gpsAccuracy {
        case .excellent: return .green
        case .good: return .yellow
        case .fair: return .orange
        case .poor: return .red
        case .none: return .gray
        }
    }
    
    private var gpsStatusText: String {
        locationManager?.gpsAccuracy.description ?? "No GPS"
    }
    
    // MARK: - Actions
    
    private func startTracking() {
        Task {
            do {
                try await locationManager?.startTracking(loadWeight: loadWeight)
            } catch {
                print("Failed to start tracking: \(error)")
            }
        }
    }
    
    private func stopTracking() {
        Task {
            await locationManager?.stopTracking()
        }
    }
}

// MARK: - Metric Card View

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Load Weight Input View

struct LoadWeightInputView: View {
    @Binding var loadWeight: Double
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Load Weight")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    Text("\(Int(loadWeight)) kg")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        Button("-5") {
                            loadWeight = max(0, loadWeight - 5)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("-1") {
                            loadWeight = max(0, loadWeight - 1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("+1") {
                            loadWeight = min(100, loadWeight + 1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("+5") {
                            loadWeight = min(100, loadWeight + 5)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                Button("Start Ruck") {
                    onStart()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Formatting Helpers

private func formatDistance(_ distance: Double) -> String {
    if distance < 1000 {
        return "\(Int(distance))m"
    } else {
        return String(format: "%.2fkm", distance / 1000)
    }
}

private func formatPace(_ pace: Double) -> String {
    guard pace > 0 && pace.isFinite else { return "--:--" }
    
    let minutes = Int(pace)
    let seconds = Int((pace - Double(minutes)) * 60)
    
    return String(format: "%d:%02d", minutes, seconds)
}

private func formatElevation(_ elevation: Double) -> String {
    return "\(Int(elevation))m"
}

private func formatGrade(_ grade: Double) -> String {
    return String(format: "%.1f%%", grade)
}

private func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    let seconds = Int(duration) % 60
    
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    TrackingView()
        .environment(WatchAppCoordinator())
}