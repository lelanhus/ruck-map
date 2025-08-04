import SwiftUI
import SwiftData

/// History tab view - displays completed ruck sessions
struct HistoryTabView: View {
    @Query private var sessions: [RuckSession]
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedSortOption: SortOption = .dateDescending
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @AppStorage("preferredUnits") private var preferredUnits = "imperial"

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
            VStack(spacing: 4) {
                Image(systemName: "list.bullet.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("\(filteredSessions.count)")
                    .font(.headline)
                Text("Sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Image(systemName: "map.circle")
                    .font(.title2)
                    .foregroundColor(.green)
                Text(FormatUtilities.formatDistance(filteredSessions.reduce(0) { $0 + $1.totalDistance }, units: preferredUnits))
                    .font(.headline)
                Text("Distance")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Image(systemName: "clock.circle")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text(FormatUtilities.formatTotalDuration(filteredSessions.reduce(0) { $0 + $1.totalDuration }))
                    .font(.headline)
                Text("Time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
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
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)
                            Spacer()
                            if let rpe = session.rpe {
                                Text("RPE: \(rpe)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Label(FormatUtilities.formatDistance(session.totalDistance, units: preferredUnits), systemImage: "figure.walk")
                                .font(.subheadline)
                            
                            Label(FormatUtilities.formatDuration(session.totalDuration), systemImage: "clock")
                                .font(.subheadline)
                            
                            Label("\(Int(session.totalCalories)) kcal", systemImage: "flame")
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
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