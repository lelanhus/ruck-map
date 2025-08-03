import SwiftUI
import SwiftData

/// Home screen providing quick ruck start functionality and session overview
/// Handles both inactive state and active tracking transitions
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [RuckSession]
    @State var locationManager: LocationTrackingManager
    @State private var currentWeight: Double = 35.0
    @AppStorage("preferredUnits") private var preferredUnits = "imperial"
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    /// Optional navigation action for switching to history tab
    var onViewAllTapped: (() -> Void)?
    
    private var recentSessions: [RuckSession] {
        sessions
            .filter { $0.endDate != nil }
            .sorted { $0.startDate > $1.startDate }
            .prefix(3)
            .map { $0 }
    }
    
    private var totalDistance: Double {
        sessions.reduce(0) { $0 + $1.totalDistance }
    }
    
    private var totalSessions: Int {
        sessions.filter { $0.endDate != nil }.count
    }
    
    var body: some View {
        NavigationStack {
            if locationManager.trackingState == .stopped {
                // Home view when not tracking
                ScrollView {
                    VStack(spacing: 24) {
                        // Header section
                        headerSection
                        
                        // Quick stats overview
                        quickStatsSection
                        
                        // Start ruck section
                        startRuckSection
                        
                        // Recent sessions
                        if !recentSessions.isEmpty {
                            recentSessionsSection
                        }
                    }
                    .padding()
                }
                .navigationTitle("RuckMap")
                .navigationBarTitleDisplayMode(.large)
                .background(Color.ruckMapBackground)
            } else {
                // Active tracking view
                ActiveTrackingView(locationManager: locationManager)
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.rucking")
                .font(.system(size: 64))
                .foregroundColor(.armyGreenPrimary)
                .accessibilityLabel("RuckMap app icon")
            
            VStack(spacing: 4) {
                Text("RuckMap")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Track your rucks with precision")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 16)
    }
    
    private var quickStatsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total Sessions",
                value: "\(totalSessions)",
                icon: "list.bullet.circle.fill",
                color: .blue
            )
            
            StatCard(
                title: "Total Distance",
                value: FormatUtilities.formatDistance(totalDistance, units: preferredUnits),
                icon: "map.circle.fill",
                color: .green
            )
        }
    }
    
    private var startRuckSection: some View {
        VStack(spacing: 16) {
            // Weight adjustment
            VStack(spacing: 12) {
                HStack {
                    Text("Load Weight")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(Int(currentWeight)) lbs")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.armyGreenPrimary)
                }
                
                HStack {
                    Button(action: { adjustWeight(-5) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.armyGreenPrimary)
                    }
                    .disabled(currentWeight <= 0)
                    .accessibilityLabel("Decrease weight by 5 pounds")
                    
                    Slider(value: $currentWeight, in: 0...200, step: 5)
                        .tint(.armyGreenPrimary)
                        .accessibilityLabel("Load weight slider")
                        .accessibilityValue("\(Int(currentWeight)) pounds")
                    
                    Button(action: { adjustWeight(5) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.armyGreenPrimary)
                    }
                    .disabled(currentWeight >= 200)
                    .accessibilityLabel("Increase weight by 5 pounds")
                }
            }
            .padding()
            .background(Color.ruckMapSecondaryBackground)
            .cornerRadius(12)
            
            // Start button
            Button(action: startQuickRuck) {
                Label("Start Ruck", systemImage: "play.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.armyGreenPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Start new ruck session with \(Int(currentWeight)) pound load")
            .sensoryFeedback(.selection, trigger: currentWeight)
        }
    }
    
    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Sessions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    onViewAllTapped?()
                }
                .font(.subheadline)
                .foregroundColor(.armyGreenPrimary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(recentSessions, id: \.id) { session in
                    RecentSessionRow(session: session)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func adjustWeight(_ change: Double) {
        let newWeight = currentWeight + change
        if newWeight >= 0 && newWeight <= 200 {
            currentWeight = newWeight
        }
    }
    
    private func startQuickRuck() {
        let session = RuckSession()
        session.loadWeight = FormatUtilities.poundsToKilograms(currentWeight)
        modelContext.insert(session)
        
        do {
            try modelContext.save()
            locationManager.startTracking(with: session)
        } catch {
            errorMessage = "Unable to start your ruck session. Please check your device storage and try again. If the problem persists, restart the app."
            showingErrorAlert = true
        }
    }
}

// MARK: - Supporting Views

/// Quick stat display card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.ruckMapSecondaryBackground)
        .cornerRadius(12)
    }
}

/// Recent session row display
struct RecentSessionRow: View {
    let session: RuckSession
    @AppStorage("preferredUnits") private var preferredUnits = "imperial"
    
    private var formattedDistance: String {
        FormatUtilities.formatDistancePrecise(session.totalDistance, units: preferredUnits)
    }
    
    private var formattedDuration: String {
        FormatUtilities.formatDuration(session.totalDuration)
    }
    
    private var formattedDate: String {
        FormatUtilities.formatSessionDate(session.startDate)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Session icon
            Image(systemName: "figure.rucking")
                .font(.title3)
                .foregroundColor(.armyGreenPrimary)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(formattedDistance)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 16) {
                    Label(formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(FormatUtilities.formatWeight(session.loadWeight, units: preferredUnits), systemImage: "backpack")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.ruckMapSecondaryBackground)
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ruck session: \(formattedDistance), \(formattedDuration), on \(formattedDate)")
    }
}

#Preview {
    HomeView(locationManager: LocationTrackingManager())
        .modelContainer(for: RuckSession.self, inMemory: true)
}