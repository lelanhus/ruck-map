import SwiftUI
import SwiftData

// MARK: - SessionSummaryIntegration
// Integration example showing how to navigate to SessionSummaryView after session completion

extension ActiveTrackingView {
    
    /// Example integration: Navigate to SessionSummaryView after session completion
    /// This demonstrates how to modify the existing "End Ruck" flow to show the summary view
    
    /*
    // INTEGRATION EXAMPLE:
    // Replace the existing "End" button action in ActiveTrackingView with:
    
    Button("End", role: .destructive) {
        locationManager.stopTracking()
        do {
            try modelContext.save()
            
            // Navigate to SessionSummaryView instead of just dismissing
            if let completedSession = locationManager.currentSession {
                showSessionSummary = true
                self.completedSession = completedSession
            }
        } catch {
            showSaveError = true
        }
    }
    
    // Add these state variables to ActiveTrackingView:
    @State private var showSessionSummary = false
    @State private var completedSession: RuckSession?
    
    // Add this modifier to the ActiveTrackingView body:
    .fullScreenCover(isPresented: $showSessionSummary) {
        if let session = completedSession {
            SessionSummaryView(session: session)
        }
    }
    */
}

// MARK: - Integration Examples

/// Example 1: Direct Navigation from ActiveTrackingView
struct ActiveTrackingWithSummaryIntegration: View {
    @State var locationManager: LocationTrackingManager
    @Environment(\.modelContext) private var modelContext
    @State private var showSessionSummary = false
    @State private var completedSession: RuckSession?
    @State private var showEndConfirmation = false
    
    var body: some View {
        VStack {
            // ... existing ActiveTrackingView content
            
            Button("End Ruck") {
                showEndConfirmation = true
            }
        }
        .alert("End Ruck?", isPresented: $showEndConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("End", role: .destructive) {
                endRuckWithSummary()
            }
        }
        .fullScreenCover(isPresented: $showSessionSummary) {
            if let session = completedSession {
                SessionSummaryView(session: session)
            }
        }
    }
    
    private func endRuckWithSummary() {
        locationManager.stopTracking()
        
        do {
            try modelContext.save()
            
            // Navigate to SessionSummaryView
            if let session = locationManager.currentSession {
                completedSession = session
                showSessionSummary = true
            }
        } catch {
            // Handle error appropriately
            print("Failed to save session: \(error)")
        }
    }
}

/// Example 2: Navigation from History View
struct HistoryViewWithSummaryIntegration: View {
    let sessions: [RuckSession]
    @State private var selectedSession: RuckSession?
    @State private var showSessionSummary = false
    
    var body: some View {
        List {
            ForEach(sessions, id: \.id) { session in
                HStack {
                    VStack(alignment: .leading) {
                        Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                        Text("\(FormatUtilities.formatDistancePrecise(session.totalDistance)) • \(FormatUtilities.formatDurationWithSeconds(session.duration))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Add a summary button for completed sessions without RPE
                    if session.endDate != nil && session.rpe == nil {
                        Button("Add Summary") {
                            selectedSession = session
                            showSessionSummary = true
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showSessionSummary) {
            if let session = selectedSession {
                SessionSummaryView(session: session)
            }
        }
    }
}

/// Example 3: Programmatic Session Completion
struct ProgrammaticSessionSummary {
    
    /// Complete a session and show summary programmatically
    static func completeSessionWithSummary(
        session: RuckSession,
        modelContext: ModelContext,
        presentingSummary: @escaping (RuckSession) -> Void
    ) async throws {
        
        // Ensure session is ended
        if session.endDate == nil {
            session.endDate = Date()
        }
        
        // Update session metrics
        await session.updateElevationMetrics()
        session.updateModificationDate()
        
        // Save to context
        try modelContext.save()
        
        // Present summary view
        presentingSummary(session)
    }
}

// MARK: - Usage Examples

#Preview("Integration Example 1") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: RuckSession.self, configurations: config)
    
    return ActiveTrackingWithSummaryIntegration(
        locationManager: LocationTrackingManager()
    )
    .modelContainer(container)
}

#Preview("Integration Example 2") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: RuckSession.self, configurations: config)
    
    // Create sample sessions
    let session1 = RuckSession()
    session1.totalDistance = 5000
    session1.totalDuration = 3600
    session1.endDate = Date()
    
    let session2 = RuckSession()
    session2.totalDistance = 3000
    session2.totalDuration = 2400
    session2.endDate = Date()
    session2.rpe = 6 // Already has summary
    
    container.mainContext.insert(session1)
    container.mainContext.insert(session2)
    
    return HistoryViewWithSummaryIntegration(sessions: [session1, session2])
        .modelContainer(container)
}

// MARK: - Navigation Patterns

/*
INTEGRATION PATTERNS:

1. **Post-Session Flow** (Recommended)
   - User completes a ruck in ActiveTrackingView
   - Instead of returning to home, show SessionSummaryView
   - User adds RPE and notes
   - Session is saved with summary data
   - User can then share or return to home

2. **Retrospective Summary**
   - User browses history in HistoryView
   - Sessions without RPE show "Add Summary" button
   - User can add summary data to past sessions
   - Useful for users who forgot to add notes initially

3. **Quick Review**
   - Show SessionSummaryView as a sheet/modal
   - Allow quick RPE entry without full session review
   - Useful for power users who want minimal friction

4. **Auto-Summary**
   - Automatically show summary for sessions over certain duration/distance
   - Optional for shorter/casual rucks
   - Smart prompting based on session importance

NAVIGATION MODIFIERS:
- .fullScreenCover: Full immersive experience (recommended for post-session)
- .sheet: Modal overlay (good for retrospective summaries)
- NavigationLink: In-flow navigation (good for history browsing)
- .alert: Quick RPE-only input (minimal friction option)

ACCESSIBILITY CONSIDERATIONS:
- Always provide alternative navigation paths
- Support VoiceOver navigation between sections
- Ensure RPE scale is fully accessible
- Provide text alternatives for visual elements
- Support Dynamic Type throughout
*/