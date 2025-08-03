import SwiftUI
import SwiftData

/// Enhanced session history list view with comprehensive filtering, sorting, and search capabilities
/// Implements modern SwiftUI patterns with @Observable for optimal performance
/// Prepared for iOS 26 Liquid Glass design system
struct SessionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSessions: [RuckSession]
    @State private var viewModel = SessionHistoryViewModel()
    @AppStorage("preferredUnits") private var preferredUnits = "imperial"
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Statistics header
                if !viewModel.filteredSessions(from: completedSessions).isEmpty {
                    statisticsHeader
                        .padding()
                        .background(
                            // iOS 26 Liquid Glass preparation
                            if #available(iOS 26.0, *) {
                                AnyView(Color.liquidGlassCard.ignoresSafeArea(.container, edges: .horizontal))
                            } else {
                                AnyView(Color.ruckMapSecondaryBackground.ignoresSafeArea(.container, edges: .horizontal))
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Main content
                Group {
                    if viewModel.filteredSessions(from: completedSessions).isEmpty {
                        emptyStateView
                    } else {
                        sessionsList
                    }
                }
                .refreshable {
                    await refreshData()
                }
            }
            .navigationTitle("History")
            .searchable(
                text: $viewModel.searchText,
                prompt: "Search by location, notes, or date"
            )
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    filterButton
                    sortButton
                }
            }
            .sheet(isPresented: $viewModel.showingFilterSheet) {
                filterSheet
            }
            .alert("Delete Session", isPresented: $viewModel.showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteSessionFromAlert()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this session? This action cannot be undone.")
            }
            .alert("Error", isPresented: $viewModel.showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .onAppear {
            viewModel.updateSessions(completedSessions)
        }
        .onChange(of: allSessions) { _, newSessions in
            viewModel.updateSessions(newSessions.filter { $0.endDate != nil })
        }
    }
    
    // MARK: - Computed Properties
    
    private var completedSessions: [RuckSession] {
        allSessions.filter { $0.endDate != nil }
    }
    
    private var historyStats: HistoryStatistics {
        HistoryStatistics(sessions: viewModel.filteredSessions(from: completedSessions))
    }
    
    // MARK: - View Components
    
    private var statisticsHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
            StatisticCard(
                title: "Sessions",
                value: "\(historyStats.totalSessions)",
                icon: "list.bullet.circle.fill",
                color: .blue,
                trend: historyStats.sessionsTrend
            )
            
            StatisticCard(
                title: "Distance",
                value: FormatUtilities.formatDistance(historyStats.totalDistance, units: preferredUnits),
                icon: "map.circle.fill",
                color: .green,
                trend: historyStats.distanceTrend
            )
            
            StatisticCard(
                title: "Time",
                value: FormatUtilities.formatTotalDuration(historyStats.totalDuration),
                icon: "clock.circle.fill",
                color: .orange,
                trend: historyStats.timeTrend
            )
            
            StatisticCard(
                title: "Calories",
                value: "\(Int(historyStats.totalCalories))",
                icon: "flame.circle.fill",
                color: .red,
                trend: historyStats.caloriesTrend
            )
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: historyStats.totalSessions)
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Sessions Found", systemImage: "clock.badge.xmark")
        } description: {
            if !viewModel.searchText.isEmpty || viewModel.hasActiveFilters {
                Text("Try adjusting your search terms or filters to find more sessions.")
            } else {
                Text("Start your first ruck session to see it here.")
            }
        } actions: {
            if !viewModel.searchText.isEmpty || viewModel.hasActiveFilters {
                HStack {
                    if !viewModel.searchText.isEmpty {
                        Button("Clear Search") {
                            viewModel.searchText = ""
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if viewModel.hasActiveFilters {
                        Button("Clear Filters") {
                            viewModel.clearAllFilters()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
    
    private var sessionsList: some View {
        List {
            ForEach(viewModel.filteredSessions(from: completedSessions), id: \.id) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    SessionListCard(session: session, preferredUnits: preferredUnits)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        shareSession(session)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                    
                    Button {
                        toggleFavorite(session)
                    } label: {
                        Label(
                            session.rpe != nil && session.rpe! >= 8 ? "Unfavorite" : "Favorite",
                            systemImage: session.rpe != nil && session.rpe! >= 8 ? "heart.fill" : "heart"
                        )
                    }
                    .tint(.pink)
                    
                    Button {
                        requestDeleteSession(session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .accessibilityLabel(sessionAccessibilityLabel(for: session))
            }
        }
        .listStyle(.plain)
        .animation(.default, value: viewModel.filteredSessions(from: completedSessions))
    }
    
    private var filterButton: some View {
        Button {
            viewModel.showingFilterSheet = true
        } label: {
            Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .foregroundColor(viewModel.hasActiveFilters ? .blue : .primary)
        }
        .accessibilityLabel("Filter sessions")
    }
    
    private var sortButton: some View {
        Menu {
            sortMenu
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
        .accessibilityLabel("Sort sessions")
    }
    
    private var sortMenu: some View {
        ForEach(SortOption.allCases, id: \.self) { option in
            Button {
                viewModel.selectedSortOption = option
            } label: {
                HStack {
                    Label(option.rawValue, systemImage: option.systemImage)
                    if viewModel.selectedSortOption == option {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
    
    private var filterSheet: some View {
        FilterSheetView(viewModel: viewModel, preferredUnits: preferredUnits)
    }
    
    // MARK: - Actions
    
    private func refreshData() async {
        // Simulate network refresh delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        viewModel.updateSessions(completedSessions)
    }
    
    private func shareSession(_ session: RuckSession) {
        // Implementation for sharing sessions
        // This would typically use ShareManager or similar
        print("Sharing session: \(session.id)")
    }
    
    private func toggleFavorite(_ session: RuckSession) {
        // Toggle favorite status (using RPE as favorite indicator for now)
        session.rpe = (session.rpe != nil && session.rpe! >= 8) ? nil : 10
        try? modelContext.save()
        viewModel.updateSessions(completedSessions)
    }
    
    private func requestDeleteSession(_ session: RuckSession) {
        viewModel.sessionToDelete = session
        viewModel.showingDeleteAlert = true
    }
    
    private func deleteSessionFromAlert() {
        guard let session = viewModel.sessionToDelete else { return }
        
        withAnimation {
            modelContext.delete(session)
            
            do {
                try modelContext.save()
                viewModel.updateSessions(completedSessions)
            } catch {
                viewModel.errorMessage = "Unable to delete the session. Please check your device storage and try again."
                viewModel.showingErrorAlert = true
            }
        }
        
        viewModel.sessionToDelete = nil
    }
    
    private func sessionAccessibilityLabel(for session: RuckSession) -> String {
        let distance = FormatUtilities.formatDistance(session.totalDistance, units: preferredUnits)
        let duration = FormatUtilities.formatDuration(session.totalDuration)
        let date = FormatUtilities.formatSessionDate(session.startDate)
        let weight = FormatUtilities.formatWeight(session.loadWeight, units: preferredUnits)
        
        var label = "Ruck session: \(distance), \(duration), \(weight) load, on \(date)"
        
        if let rpe = session.rpe {
            label += ", difficulty \(rpe) out of 10"
        }
        
        if let weather = session.weatherConditions {
            label += ", \(Int(weather.temperature))°C"
        }
        
        return label
    }
}

// MARK: - Supporting Views

/// Individual session card with enhanced visual design
struct SessionListCard: View {
    let session: RuckSession
    let preferredUnits: String
    
    private var dominantTerrain: TerrainType? {
        session.terrainSegments
            .max(by: { $0.duration < $1.duration })?
            .terrainType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with date and favorite indicator
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(FormatUtilities.formatSessionDate(session.startDate))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let weather = session.weatherConditions {
                        HStack(spacing: 4) {
                            Image(systemName: weatherIcon(for: weather))
                                .font(.caption)
                                .foregroundColor(weatherColor(for: weather))
                            Text("\(Int(weather.temperature))°C")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let rpe = session.rpe, rpe >= 8 {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                            .font(.caption)
                    }
                    
                    if let terrain = dominantTerrain {
                        TerrainBadge(terrain: terrain)
                    }
                }
            }
            
            // Metrics row
            HStack(spacing: 16) {
                MetricPill(
                    icon: "map",
                    value: FormatUtilities.formatDistancePrecise(session.totalDistance, units: preferredUnits),
                    color: .blue
                )
                
                MetricPill(
                    icon: "clock",
                    value: FormatUtilities.formatDuration(session.totalDuration),
                    color: .green
                )
                
                MetricPill(
                    icon: "backpack",
                    value: FormatUtilities.formatWeight(session.loadWeight, units: preferredUnits),
                    color: .orange
                )
                
                if session.totalCalories > 0 {
                    MetricPill(
                        icon: "flame",
                        value: "\(Int(session.totalCalories))",
                        color: .red
                    )
                }
            }
            
            // Elevation info if available
            if session.elevationGain > 0 {
                HStack(spacing: 12) {
                    ElevationMetric(
                        icon: "arrow.up",
                        value: "\(Int(session.elevationGain))m",
                        color: .green
                    )
                    
                    if session.elevationLoss > 0 {
                        ElevationMetric(
                            icon: "arrow.down",
                            value: "\(Int(session.elevationLoss))m",
                            color: .red
                        )
                    }
                    
                    Spacer()
                    
                    if let rpe = session.rpe {
                        RPEBadge(rpe: rpe)
                    }
                }
            } else if let rpe = session.rpe {
                HStack {
                    Spacer()
                    RPEBadge(rpe: rpe)
                }
            }
            
            // Notes preview
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.ruckMapSecondaryBackground)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .contentShape(Rectangle())
    }
    
    private func weatherIcon(for weather: WeatherConditions) -> String {
        if weather.precipitation > 0 {
            return "cloud.rain"
        } else if weather.temperature < 0 {
            return "thermometer.snowflake"
        } else if weather.temperature > 30 {
            return "thermometer.sun"
        } else {
            return "sun.max"
        }
    }
    
    private func weatherColor(for weather: WeatherConditions) -> Color {
        Color.temperatureColor(for: weather.temperature)
    }
}

/// Terrain type badge
struct TerrainBadge: View {
    let terrain: TerrainType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: terrain.icon)
                .font(.caption2)
            Text(terrain.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.ruckMapAccent.opacity(0.2))
        .foregroundColor(.ruckMapPrimary)
        .cornerRadius(8)
    }
}

/// Small elevation metric display
struct ElevationMetric: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
}

/// Enhanced statistic card with trend indicators
struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: StatTrend?
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                if let trend = trend {
                    Image(systemName: trend.icon)
                        .font(.caption2)
                        .foregroundColor(trend.color)
                }
            }
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// RPE (Rating of Perceived Exertion) badge
struct RPEBadge: View {
    let rpe: Int
    
    private var color: Color {
        switch rpe {
        case 1...3:
            return .green
        case 4...6:
            return .yellow
        case 7...8:
            return .orange
        case 9...10:
            return .red
        default:
            return .gray
        }
    }
    
    var body: some View {
        Text("RPE \(rpe)")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

/// Small metric pill display
struct MetricPill: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    SessionHistoryView()
        .modelContainer(for: RuckSession.self, inMemory: true)
}