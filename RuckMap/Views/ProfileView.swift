import SwiftUI
import SwiftData

/// Profile view displaying user statistics, achievements, and app settings
/// Provides comprehensive user data overview and customization options
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSessions: [RuckSession]
    @AppStorage("preferredUnits") private var preferredUnits = "imperial"
    @AppStorage("enableHaptics") private var enableHaptics = true
    @AppStorage("showCalorieImpact") private var showCalorieImpact = true
    @AppStorage("userWeight") private var userWeight: Double = 150.0 // lbs
    @AppStorage("userHeight") private var userHeight: Double = 70.0 // inches
    @AppStorage("userAge") private var userAge: Double = 30.0
    @AppStorage("userGender") private var userGender = "male"
    @State private var showingSettingsSheet = false
    @State private var showingStatsDetail = false
    
    // Computed properties for statistics
    private var completedSessions: [RuckSession] {
        allSessions.filter { $0.endDate != nil }
    }
    
    private var profileStats: ProfileStatistics {
        ProfileStatistics(sessions: completedSessions)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile header
                    profileHeader
                    
                    // Quick stats grid
                    quickStatsGrid
                    
                    // Achievements section
                    achievementsSection
                    
                    // Recent performance
                    recentPerformanceSection
                    
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
                SettingsSheet(
                    preferredUnits: $preferredUnits,
                    enableHaptics: $enableHaptics,
                    showCalorieImpact: $showCalorieImpact,
                    userWeight: $userWeight,
                    userHeight: $userHeight,
                    userAge: $userAge,
                    userGender: $userGender
                )
            }
        }
    }
    
    // MARK: - View Components
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.armyGreenPrimary, .armyGreenSecondary],
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
            GridItem(.flexible())
        ], spacing: 16) {
            ProfileStatCard(
                title: "Total Distance",
                value: FormatUtilities.formatDistance(profileStats.totalDistance, units: preferredUnits),
                subtitle: "All time",
                icon: "map.circle.fill",
                color: .blue
            )
            
            ProfileStatCard(
                title: "Total Time",
                value: FormatUtilities.formatTotalDuration(profileStats.totalDuration),
                subtitle: "Moving time",
                icon: "clock.circle.fill",
                color: .green
            )
            
            ProfileStatCard(
                title: "Sessions",
                value: "\(profileStats.totalSessions)",
                subtitle: "Completed",
                icon: "list.bullet.circle.fill",
                color: .orange
            )
            
            ProfileStatCard(
                title: "Avg Distance",
                value: FormatUtilities.formatDistance(profileStats.averageDistance, units: preferredUnits),
                subtitle: "Per session",
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                color: .purple
            )
        }
    }
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingStatsDetail = true
                }
                .font(.subheadline)
                .foregroundColor(.armyGreenPrimary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(achievements, id: \.id) { achievement in
                        AchievementBadge(achievement: achievement)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var recentPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Performance")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                PerformanceRow(
                    title: "This Week",
                    distance: FormatUtilities.formatDistance(profileStats.thisWeekDistance, units: preferredUnits),
                    sessions: profileStats.thisWeekSessions,
                    icon: "calendar.day.timeline.left"
                )
                
                PerformanceRow(
                    title: "This Month",
                    distance: FormatUtilities.formatDistance(profileStats.thisMonthDistance, units: preferredUnits),
                    sessions: profileStats.thisMonthSessions,
                    icon: "calendar"
                )
                
                PerformanceRow(
                    title: "Personal Best",
                    distance: FormatUtilities.formatDistance(profileStats.longestDistance, units: preferredUnits),
                    sessions: 1,
                    icon: "star.circle.fill"
                )
            }
            .padding()
            .background(Color.ruckMapSecondaryBackground)
            .cornerRadius(12)
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
    
    // MARK: - Computed Properties
    
    private var memberSinceDate: String {
        guard let firstSession = completedSessions.min(by: { $0.startDate < $1.startDate }) else {
            return DateFormatter().string(from: Date())
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: firstSession.startDate)
    }
    
    private var achievements: [Achievement] {
        var achievements: [Achievement] = []
        
        // Distance milestones
        let totalMiles = profileStats.totalDistance / FormatUtilities.ConversionConstants.metersToMiles
        if totalMiles >= 1000 {
            achievements.append(Achievement(
                id: "1000miles",
                title: "Centurion",
                description: "1000+ miles rucked",
                icon: "star.fill",
                color: .yellow,
                isEarned: true
            ))
        } else if totalMiles >= 500 {
            achievements.append(Achievement(
                id: "500miles",
                title: "Half Centurion",
                description: "500+ miles rucked",
                icon: "star.circle.fill",
                color: .orange,
                isEarned: true
            ))
        } else if totalMiles >= 100 {
            achievements.append(Achievement(
                id: "100miles",
                title: "Century",
                description: "100+ miles rucked",
                icon: "star.circle",
                color: .blue,
                isEarned: true
            ))
        }
        
        // Session milestones
        if profileStats.totalSessions >= 100 {
            achievements.append(Achievement(
                id: "100sessions",
                title: "Dedicated",
                description: "100+ sessions completed",
                icon: "checkmark.seal.fill",
                color: .green,
                isEarned: true
            ))
        } else if profileStats.totalSessions >= 50 {
            achievements.append(Achievement(
                id: "50sessions",
                title: "Committed",
                description: "50+ sessions completed",
                icon: "checkmark.seal",
                color: .blue,
                isEarned: true
            ))
        }
        
        // Consistency achievements
        if profileStats.thisWeekSessions >= 3 {
            achievements.append(Achievement(
                id: "consistent",
                title: "Consistent",
                description: "3+ sessions this week",
                icon: "flame.fill",
                color: .red,
                isEarned: true
            ))
        }
        
        return achievements
    }
    
    // MARK: - Helper Methods
    
}

// MARK: - Supporting Types and Views

/// Profile statistics calculation helper
struct ProfileStatistics {
    let sessions: [RuckSession]
    
    var totalSessions: Int {
        sessions.count
    }
    
    var totalDistance: Double {
        sessions.reduce(0) { $0 + $1.totalDistance }
    }
    
    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.totalDuration }
    }
    
    var averageDistance: Double {
        guard totalSessions > 0 else { return 0 }
        return totalDistance / Double(totalSessions)
    }
    
    var longestDistance: Double {
        sessions.map { $0.totalDistance }.max() ?? 0
    }
    
    var thisWeekSessions: Int {
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date.distantPast
        return sessions.filter { $0.startDate >= weekAgo }.count
    }
    
    var thisWeekDistance: Double {
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date.distantPast
        return sessions.filter { $0.startDate >= weekAgo }.reduce(0) { $0 + $1.totalDistance }
    }
    
    var thisMonthSessions: Int {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date.distantPast
        return sessions.filter { $0.startDate >= monthAgo }.count
    }
    
    var thisMonthDistance: Double {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date.distantPast
        return sessions.filter { $0.startDate >= monthAgo }.reduce(0) { $0 + $1.totalDistance }
    }
}

/// Achievement data structure
struct Achievement {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isEarned: Bool
}

/// Profile statistic card
struct ProfileStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.ruckMapSecondaryBackground)
        .cornerRadius(12)
    }
}

/// Achievement badge
struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundColor(achievement.color)
            }
            
            VStack(spacing: 2) {
                Text(achievement.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(achievement.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 80)
        .opacity(achievement.isEarned ? 1.0 : 0.5)
    }
}

/// Performance row display
struct PerformanceRow: View {
    let title: String
    let distance: String
    let sessions: Int
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.armyGreenPrimary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(distance)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(sessions) session\(sessions == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Settings row with action
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
                    .font(.subheadline)
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

/// Settings toggle row
struct SettingToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.armyGreenPrimary)
        }
        .padding(.vertical, 8)
    }
}

/// Settings sheet for detailed configuration
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var preferredUnits: String
    @Binding var enableHaptics: Bool
    @Binding var showCalorieImpact: Bool
    @Binding var userWeight: Double
    @Binding var userHeight: Double
    @Binding var userAge: Double
    @Binding var userGender: String
    
    var body: some View {
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
                
                Section("Personal Information") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        Text("\(Int(userWeight)) lbs")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $userWeight, in: 80...300, step: 5)
                    
                    HStack {
                        Text("Height")
                        Spacer()
                        Text("\(Int(userHeight / 12))' \(Int(userHeight.truncatingRemainder(dividingBy: 12)))\"")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $userHeight, in: 48...84, step: 1)
                    
                    HStack {
                        Text("Age")
                        Spacer()
                        Text("\(Int(userAge))")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $userAge, in: 13...100, step: 1)
                    
                    Picker("Gender", selection: $userGender) {
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                        Text("Other").tag("other")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: RuckSession.self, inMemory: true)
}