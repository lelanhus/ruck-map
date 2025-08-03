import SwiftUI
import SwiftData

/// Home tab view - handles ruck starting and active tracking
struct HomeTabView: View {
    @State var locationManager: LocationTrackingManager
    @Binding var currentWeight: Double
    @Query private var sessions: [RuckSession]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: ContentView.Tab
    @AppStorage("preferredUnits") private var preferredUnits = "imperial"
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    private var recentSessions: [RuckSession] {
        sessions
            .filter { $0.endDate != nil }
            .sorted { $0.startDate > $1.startDate }
            .prefix(3)
            .map(\.self)
    }

    private var totalDistance: Double {
        sessions.reduce(0) { $0 + $1.totalDistance }
    }

    private var totalSessions: Int {
        sessions.filter { $0.endDate != nil }.count
    }

    var body: some View {
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
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        } else {
            // Active tracking view
            ActiveTrackingView(locationManager: locationManager)
                .alert("Error", isPresented: $showingErrorAlert) {
                    Button("OK") { }
                } message: {
                    Text(errorMessage)
                }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.rucking")
                .font(.system(size: 64))
                .foregroundStyle(Color.armyGreenPrimary)
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
                        .foregroundColor(Color.armyGreenPrimary)
                }

                HStack {
                    Button(action: { adjustWeight(-5) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.armyGreenPrimary)
                    }
                    .disabled(currentWeight <= 0)
                    .accessibilityLabel("Decrease weight by 5 pounds")

                    Slider(value: $currentWeight, in: 0...200, step: 5)
                        .tint(Color.armyGreenPrimary)
                        .accessibilityLabel("Load weight slider")
                        .accessibilityValue("\(Int(currentWeight)) pounds")

                    Button(action: { adjustWeight(5) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.armyGreenPrimary)
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
                    selectedTab = .history
                }
                .font(.subheadline)
                .foregroundColor(Color.armyGreenPrimary)
            }

            LazyVStack(spacing: 8) {
                ForEach(recentSessions, id: \.id) { session in
                    RecentSessionRow(session: session)
                }
            }
        }
    }

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
            errorMessage = "Failed to start ruck: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}

/// Recent session row view
struct RecentSessionRow: View {
    let session: RuckSession
    @AppStorage("preferredUnits") private var preferredUnits = "imperial"

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 16) {
                    Label(
                        FormatUtilities.formatDistance(session.totalDistance, units: preferredUnits),
                        systemImage: "figure.walk"
                    )
                    .font(.caption)

                    Label(
                        FormatUtilities.formatDuration(session.totalDuration),
                        systemImage: "clock"
                    )
                    .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.ruckMapSecondaryBackground)
        .cornerRadius(8)
    }
}

/// Statistics card component
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
                .accessibilityHidden(true)

            VStack(spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.ruckMapSecondaryBackground)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}