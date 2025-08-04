import SwiftUI
import SwiftData

/// Profile tab view - user stats and settings
struct ProfileTabView: View {
    @Query private var sessions: [RuckSession]
    @AppStorage("preferredUnits") private var preferredUnits = "imperial"
    @AppStorage("enableHaptics") private var enableHaptics = true
    @AppStorage("showCalorieImpact") private var showCalorieImpact = true
    @State private var showingSettingsSheet = false

    private var completedSessions: [RuckSession] {
        sessions.filter { $0.endDate != nil }
    }

    private var totalDistance: Double {
        completedSessions.reduce(0) { $0 + $1.totalDistance }
    }

    private var totalDuration: TimeInterval {
        completedSessions.reduce(0) { $0 + $1.totalDuration }
    }

    private var averageDistance: Double {
        guard !completedSessions.isEmpty else { return 0 }
        return totalDistance / Double(completedSessions.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile header
                profileHeader

                // Quick stats grid
                quickStatsGrid

                // Settings section
                settingsSection
            }
            .padding()
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showingSettingsSheet) {
            NavigationStack {
                Form {
                    Section("Units & Display") {
                        Picker("Distance Units", selection: $preferredUnits) {
                            Text("Imperial (miles)").tag("imperial")
                            Text("Metric (kilometers)").tag("metric")
                        }

                        Toggle("Haptic Feedback", isOn: $enableHaptics)
                        Toggle("Show Weather Impact", isOn: $showCalorieImpact)
                    }
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingSettingsSheet = false
                        }
                    }
                }
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.armyGreenPrimary, Color.armyGreenSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)

                Image(systemName: "figure.rucking")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            VStack(spacing: 4) {
                Text("Ruck Tracker")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Member since \(memberSinceDate)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var quickStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 16) {
            ProfileStatCard(
                title: "Total Distance",
                value: FormatUtilities.formatDistance(totalDistance, units: preferredUnits),
                subtitle: "All time",
                icon: "map.circle.fill",
                color: .blue
            )

            ProfileStatCard(
                title: "Total Time",
                value: FormatUtilities.formatTotalDuration(totalDuration),
                subtitle: "Moving time",
                icon: "clock.circle.fill",
                color: .green
            )

            ProfileStatCard(
                title: "Sessions",
                value: "\(completedSessions.count)",
                subtitle: "Completed",
                icon: "list.bullet.circle.fill",
                color: .orange
            )

            ProfileStatCard(
                title: "Avg Distance",
                value: FormatUtilities.formatDistance(averageDistance, units: preferredUnits),
                subtitle: "Per session",
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                color: .purple
            )
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Settings")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                SettingRow(
                    icon: "ruler",
                    title: "Units",
                    value: preferredUnits.capitalized,
                    color: .blue
                ) {
                    preferredUnits = preferredUnits == "imperial" ? "metric" : "imperial"
                }

                Divider()
                    .padding(.leading, 44)

                SettingToggleRow(
                    icon: "iphone.radiowaves.left.and.right",
                    title: "Haptic Feedback",
                    isOn: $enableHaptics,
                    color: .green
                )

                Divider()
                    .padding(.leading, 44)

                SettingToggleRow(
                    icon: "thermometer.sun",
                    title: "Weather Impact",
                    isOn: $showCalorieImpact,
                    color: .orange
                )
            }
            .padding()
            .background(Color.ruckMapSecondaryBackground)
            .cornerRadius(12)
        }
    }

    private var memberSinceDate: String {
        guard let firstSession = completedSessions.min(by: { $0.startDate < $1.startDate }) else {
            return formatMemberSince(Date())
        }
        return formatMemberSince(firstSession.startDate)
    }
    
    private func formatMemberSince(_ date: Date) -> String {
        FormatUtilities.formatMemberSince(date)
    }
}

// MARK: - Supporting Views

/// Profile statistics card
struct ProfileStatCard: View {
    let title: String
    let value: String
    let subtitle: String
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
                    .foregroundColor(.secondary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.ruckMapSecondaryBackground)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(subtitle)")
    }
}

/// Settings row with tap action
struct SettingRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 28)

                Text(title)
                    .foregroundColor(.primary)

                Spacer()

                Text(value)
                    .foregroundColor(.secondary)
                    .font(.subheadline)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.tertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

/// Settings row with toggle
struct SettingToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 28)

            Text(title)
                .foregroundColor(.primary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }
}