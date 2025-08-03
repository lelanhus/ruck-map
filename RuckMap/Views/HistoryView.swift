import SwiftUI
import SwiftData

/// Temporary FormatUtilities - should be moved to separate file when project structure is fixed
private enum FormatUtilities {
    enum ConversionConstants {
        static let poundsToKilograms = 0.453592
        static let kilogramsToPounds = 2.20462
        static let metersToMiles = 1609.34
        static let metersToKilometers = 1000.0
    }
    
    static func formatDistance(_ meters: Double, units: String = "imperial") -> String {
        if units == "imperial" {
            let miles = meters / ConversionConstants.metersToMiles
            return String(format: "%.1f mi", miles)
        } else {
            let kilometers = meters / ConversionConstants.metersToKilometers
            return String(format: "%.1f km", kilometers)
        }
    }
    
    static func formatDistancePrecise(_ meters: Double, units: String = "imperial") -> String {
        if units == "imperial" {
            let miles = meters / ConversionConstants.metersToMiles
            return String(format: "%.2f mi", miles)
        } else {
            let kilometers = meters / ConversionConstants.metersToKilometers
            return String(format: "%.2f km", kilometers)
        }
    }
    
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        
        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        } else {
            return String(format: "%d min", minutes)
        }
    }
    
    static func formatTotalDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        return "\(hours)h"
    }
    
    static func formatWeight(_ kilograms: Double, units: String = "imperial") -> String {
        if units == "imperial" {
            let pounds = kilograms * ConversionConstants.kilogramsToPounds
            return String(format: "%.0f lbs", pounds)
        } else {
            return String(format: "%.0f kg", kilograms)
        }
    }
    
    static func formatSessionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

/// History view displaying past ruck sessions with filtering and sorting options
/// Provides detailed session management and statistics
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSessions: [RuckSession]
    @State private var searchText = ""
    @State private var selectedSortOption: SortOption = .dateDescending
    @State private var showingFilterSheet = false
    @State private var selectedTimeRange: TimeRange = .all
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
                return "calendar"
            case .distanceDescending:
                return "map"
            case .durationDescending:
                return "clock"
            }
        }
    }
    
    enum TimeRange: String, CaseIterable {
        case all = "All Time"
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
        
        var systemImage: String {
            switch self {
            case .all:
                return "infinity"
            case .week:
                return "calendar.day.timeline.left"
            case .month:
                return "calendar"
            case .year:
                return "calendar.badge.clock"
            }
        }
    }
    
    // Computed properties
    private var completedSessions: [RuckSession] {
        allSessions.filter { $0.endDate != nil }
    }
    
    private var filteredSessions: [RuckSession] {
        var sessions = completedSessions
        
        // Apply time range filter
        sessions = sessions.filter { session in
            switch selectedTimeRange {
            case .all:
                return true
            case .week:
                return session.startDate >= Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date.distantPast
            case .month:
                return session.startDate >= Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date.distantPast
            case .year:
                return session.startDate >= Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date.distantPast
            }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            sessions = sessions.filter { session in
                // Search in notes or formatted date
                let dateString = DateFormatter.localizedString(from: session.startDate, dateStyle: .medium, timeStyle: .none)
                return session.notes?.localizedCaseInsensitiveContains(searchText) == true ||
                       dateString.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        return sessions.sorted { lhs, rhs in
            switch selectedSortOption {
            case .dateDescending:
                return lhs.startDate > rhs.startDate
            case .dateAscending:
                return lhs.startDate < rhs.startDate
            case .distanceDescending:
                return lhs.totalDistance > rhs.totalDistance
            case .durationDescending:
                return lhs.totalDuration > rhs.totalDuration
            }
        }
    }
    
    private var historyStats: HistoryStatistics {
        HistoryStatistics(sessions: filteredSessions)
    }
    
    var body: some View {
        NavigationStack {
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
                        Divider()
                        filterMenu
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filter and sort options")
                }
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - View Components
    
    private var statisticsHeader: some View {
        HStack(spacing: 16) {
            StatisticItem(
                title: "Sessions",
                value: "\(historyStats.totalSessions)",
                icon: "list.bullet.circle",
                color: .blue
            )
            
            StatisticItem(
                title: "Distance",
                value: FormatUtilities.formatDistance(historyStats.totalDistance, units: preferredUnits),
                icon: "map.circle",
                color: .green
            )
            
            StatisticItem(
                title: "Time",
                value: FormatUtilities.formatTotalDuration(historyStats.totalDuration),
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
                Text("Try adjusting your search or filters.")
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
                .accessibilityLabel(sessionAccessibilityLabel(for: session))
            }
            .onDelete(perform: deleteSessions)
        }
        .listStyle(.insetGrouped)
    }
    
    private var sortMenu: some View {
        Menu("Sort By") {
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
    }
    
    private var filterMenu: some View {
        Menu("Time Range") {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    selectedTimeRange = range
                } label: {
                    Label(range.rawValue, systemImage: range.systemImage)
                    if selectedTimeRange == range {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    
    private func sessionAccessibilityLabel(for session: RuckSession) -> String {
        let distance = formatDistance(session.totalDistance)
        let duration = formatTotalDuration(session.totalDuration)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let date = formatter.string(from: session.startDate)
        return "Ruck session: \(distance), \(duration), on \(date)"
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
                errorMessage = "Unable to delete the selected sessions. Please check your device storage and try again. If the problem persists, restart the app."
                showingErrorAlert = true
            }
        }
    }
}

// MARK: - Supporting Types and Views

/// Statistics helper for history calculations
struct HistoryStatistics {
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
    
    var averageDuration: TimeInterval {
        guard totalSessions > 0 else { return 0 }
        return totalDuration / Double(totalSessions)
    }
}

/// Statistic display item
struct StatisticItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Session row in the list
struct SessionListRow: View {
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
    
    private var loadWeight: String {
        FormatUtilities.formatWeight(session.loadWeight, units: preferredUnits)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formattedDate)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let rpe = session.rpe {
                    RPEBadge(rpe: rpe)
                }
            }
            
            HStack(spacing: 16) {
                MetricPill(icon: "map", value: formattedDistance, color: .blue)
                MetricPill(icon: "clock", value: formattedDuration, color: .green)
                MetricPill(icon: "backpack", value: loadWeight, color: .orange)
            }
            
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
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
    HistoryView()
        .modelContainer(for: RuckSession.self, inMemory: true)
}