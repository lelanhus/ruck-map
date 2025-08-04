import SwiftUI
import SwiftData

/// History view showing past ruck sessions
struct HistoryView: View {
    @EnvironmentObject private var dataCoordinator: DataCoordinator
    @Query(sort: \RuckSession.startDate, order: .reverse) private var sessions: [RuckSession]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
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
                                Label("\(FormatUtilities.formatDistance(session.distance))", systemImage: "figure.walk")
                                    .font(.subheadline)
                                
                                Label("\(FormatUtilities.formatDuration(session.duration))", systemImage: "clock")
                                    .font(.subheadline)
                                
                                Label("\(Int(session.totalCalories)) kcal", systemImage: "flame")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { offsets in
                    Task {
                        await deleteSessions(at: offsets)
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView("No Sessions Yet", systemImage: "figure.walk", description: Text("Your completed ruck sessions will appear here"))
                }
            }
        }
    }
    
    private func deleteSessions(at offsets: IndexSet) async {
        for index in offsets {
            let session = sessions[index]
            try? await dataCoordinator.deleteSession(sessionId: session.id)
        }
    }
}

// MARK: - Preview Helpers

private func createPreviewDataCoordinator() -> DataCoordinator {
    do {
        return try DataCoordinator()
    } catch {
        fatalError("Failed to create preview DataCoordinator: \(error)")
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: RuckSession.self, inMemory: true)
        .environmentObject(createPreviewDataCoordinator())
}