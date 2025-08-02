import SwiftUI
import SwiftData
import MapKit

struct ActiveTrackingView: View {
    @Bindable var locationManager: LocationTrackingManager
    @Environment(\.modelContext) private var modelContext
    @State private var showEndConfirmation = false
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with GPS status
            HStack {
                Label(locationManager.gpsAccuracy.description, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundColor(Color(locationManager.gpsAccuracy.color))
                    .padding(.horizontal)
                
                Spacer()
                
                if locationManager.isAutoPaused {
                    Text("AUTO-PAUSED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
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
        .alert("End Ruck?", isPresented: $showEndConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) {
                locationManager.stopTracking()
                try? modelContext.save()
            }
        } message: {
            Text("Are you sure you want to end this ruck session?")
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

#Preview {
    ActiveTrackingView(locationManager: LocationTrackingManager())
        .modelContainer(for: RuckSession.self, inMemory: true)
}