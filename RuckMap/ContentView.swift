import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [RuckSession]
    @State private var locationManager = LocationTrackingManager()
    @State private var selectedTab: Tab = .home
    @State private var currentWeight: Double = 35.0

    /// Navigation tabs available in the app
    enum Tab: String, CaseIterable {
        case home = "Home"
        case history = "History"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .home:
                "house.fill"
            case .history:
                "clock.fill"
            case .profile:
                "person.circle.fill"
            }
        }

        var iconUnselected: String {
            switch self {
            case .home:
                "house"
            case .history:
                "clock"
            case .profile:
                "person.circle"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationStack {
                HomeTabContent(
                    locationManager: locationManager,
                    currentWeight: $currentWeight,
                    sessions: sessions,
                    modelContext: modelContext,
                    selectedTab: $selectedTab
                )
            }
            .tabItem {
                Label(
                    Tab.home.rawValue,
                    systemImage: selectedTab == .home ? Tab.home.icon : Tab.home.iconUnselected
                )
            }
            .tag(Tab.home)

            // History Tab
            NavigationStack {
                HistoryTabContent(sessions: sessions, modelContext: modelContext)
            }
            .tabItem {
                Label(
                    Tab.history.rawValue,
                    systemImage: selectedTab == .history ? Tab.history.icon : Tab.history
                        .iconUnselected
                )
            }
            .tag(Tab.history)

            // Profile Tab
            NavigationStack {
                ProfileTabContent(sessions: sessions)
            }
            .tabItem {
                Label(
                    Tab.profile.rawValue,
                    systemImage: selectedTab == .profile ? Tab.profile.icon : Tab.profile
                        .iconUnselected
                )
            }
            .tag(Tab.profile)
        }
        .tint(Color.armyGreenPrimary)
        .onAppear {
            locationManager.setModelContext(modelContext)
            locationManager.requestLocationPermission()
        }
    }
}

// MARK: - Tab Content Views

/// Home tab content - handles ruck starting and active tracking
struct HomeTabContent: View {
    @State var locationManager: LocationTrackingManager
    @Binding var currentWeight: Double
    let sessions: [RuckSession]
    let modelContext: ModelContext
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
            errorMessage = "Unable to start your ruck session. Please check your device storage and try again. If the problem persists, restart the app."
            showingErrorAlert = true
        }
    }
}

/// History tab content - displays past sessions
struct HistoryTabContent: View {
    let sessions: [RuckSession]
    let modelContext: ModelContext
    @State private var searchText = ""
    @State private var selectedSortOption: SortOption = .dateDescending
    @AppStorage("preferredUnits") private var preferredUnits = "imperial"
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    enum SortOption: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case distanceDescending = "Longest Distance"
        case durationDescending = "Longest Duration"

        var systemImage: String {
            switch self {
            case .dateDescending, .dateAscending:
                "calendar"
            case .distanceDescending:
                "map"
            case .durationDescending:
                "clock"
            }
        }
    }

    private var completedSessions: [RuckSession] {
        sessions.filter { $0.endDate != nil }
    }

    private var filteredSessions: [RuckSession] {
        var sessions = completedSessions

        // Apply search filter
        if !searchText.isEmpty {
            sessions = sessions.filter { session in
                let dateString = DateFormatter.localizedString(
                    from: session.startDate,
                    dateStyle: .medium,
                    timeStyle: .none
                )
                return session.notes?.localizedCaseInsensitiveContains(searchText) == true ||
                    dateString.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply sorting
        return sessions.sorted { lhs, rhs in
            switch selectedSortOption {
            case .dateDescending:
                lhs.startDate > rhs.startDate
            case .dateAscending:
                lhs.startDate < rhs.startDate
            case .distanceDescending:
                lhs.totalDistance > rhs.totalDistance
            case .durationDescending:
                lhs.totalDuration > rhs.totalDuration
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Statistics header
            if !filteredSessions.isEmpty {
                statisticsHeader
                    .padding()
                    .background(Color.ruckMapSecondaryBackground)
            }

            // Sessions list
            if filteredSessions.isEmpty {
                emptyStateView
            } else {
                sessionsList
            }
        }
        .navigationTitle("History")
        .searchable(text: $searchText, prompt: "Search sessions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    sortMenu
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Sort options")
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private var statisticsHeader: some View {
        HStack(spacing: 16) {
            StatisticItem(
                title: "Sessions",
                value: "\(filteredSessions.count)",
                icon: "list.bullet.circle",
                color: .blue
            )

            StatisticItem(
                title: "Distance",
                value: FormatUtilities.formatDistance(filteredSessions.reduce(0) { $0 + $1.totalDistance }, units: preferredUnits),
                icon: "map.circle",
                color: .green
            )

            StatisticItem(
                title: "Time",
                value: FormatUtilities.formatTotalDuration(filteredSessions.reduce(0) { $0 + $1.totalDuration }),
                icon: "clock.circle",
                color: .orange
            )
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Sessions Found", systemImage: "clock.badge.xmark")
        } description: {
            if searchText.isEmpty {
                Text("Start your first ruck session to see it here.")
            } else {
                Text("Try adjusting your search.")
            }
        } actions: {
            if !searchText.isEmpty {
                Button("Clear Search") {
                    searchText = ""
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var sessionsList: some View {
        List {
            ForEach(filteredSessions, id: \.id) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    SessionListRow(session: session)
                }
            }
            .onDelete(perform: deleteSessions)
        }
        .listStyle(.insetGrouped)
    }

    private var sortMenu: some View {
        ForEach(SortOption.allCases, id: \.self) { option in
            Button {
                selectedSortOption = option
            } label: {
                Label(option.rawValue, systemImage: option.systemImage)
                if selectedSortOption == option {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private func deleteSessions(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let session = filteredSessions[index]
                modelContext.delete(session)
            }

            do {
                try modelContext.save()
            } catch {
                errorMessage = "Failed to delete sessions: \(error.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }
    
}

/// Profile tab content - user stats and settings
struct ProfileTabContent: View {
    let sessions: [RuckSession]
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

// Note: Supporting view components have been moved to their respective view files to avoid duplicates

#Preview {
    ContentView()
        .modelContainer(for: RuckSession.self, inMemory: true)
}
