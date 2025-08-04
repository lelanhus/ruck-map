import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appCoordinator: WatchAppCoordinator
    @State private var showingSessionDetail: WatchRuckSession?
    
    private var dataManager: WatchDataManager? {
        appCoordinator.dataManager
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if let sessions = dataManager?.recentSessions, !sessions.isEmpty {
                    List {
                        ForEach(sessions, id: \.id) { session in
                            SessionRowView(session: session)
                                .onTapGesture {
                                    showingSessionDetail = session
                                }
                        }
                    }
                    .listStyle(.carousel)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $showingSessionDetail) { session in
            SessionDetailView(session: session)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Sessions Yet")
                .font(.headline)
            
            Text("Your recent ruck sessions will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

// MARK: - Session Row View

struct SessionRowView: View {
    let session: WatchRuckSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatDate(session.startDate))
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                if session.isActive {
                    Text("Active")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            HStack(spacing: 12) {
                MetricPill(
                    icon: "figure.walk",
                    value: formatDistance(session.totalDistance)
                )
                
                MetricPill(
                    icon: "clock",
                    value: formatDuration(session.duration)
                )
                
                if session.loadWeight > 0 {
                    MetricPill(
                        icon: "bag.fill",
                        value: "\(Int(session.loadWeight))kg"
                    )
                }
            }
            
            if session.totalCalories > 0 {
                HStack(spacing: 12) {
                    MetricPill(
                        icon: "flame.fill",
                        value: "\(Int(session.totalCalories)) cal"
                    )
                    
                    if session.averagePace > 0 {
                        MetricPill(
                            icon: "speedometer",
                            value: formatPace(session.averagePace)
                        )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Metric Pill View

struct MetricPill: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.blue)
            
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    let session: WatchRuckSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Ruck Session")
                            .font(.headline)
                        
                        Text(formatDateLong(session.startDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if session.isActive {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                
                                Text("Active Session")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Primary Metrics
                    VStack(spacing: 12) {
                        DetailMetricRow(
                            title: "Distance",
                            value: formatDistance(session.totalDistance),
                            icon: "figure.walk"
                        )
                        
                        DetailMetricRow(
                            title: "Duration",
                            value: formatDuration(session.duration),
                            icon: "clock"
                        )
                        
                        if session.loadWeight > 0 {
                            DetailMetricRow(
                                title: "Load Weight",
                                value: "\(Int(session.loadWeight)) kg",
                                icon: "bag.fill"
                            )
                        }
                        
                        if session.totalCalories > 0 {
                            DetailMetricRow(
                                title: "Calories",
                                value: "\(Int(session.totalCalories)) cal",
                                icon: "flame.fill"
                            )
                        }
                        
                        if session.averagePace > 0 {
                            DetailMetricRow(
                                title: "Average Pace",
                                value: formatPace(session.averagePace),
                                icon: "speedometer"
                            )
                        }
                    }
                    
                    // Elevation Metrics
                    if session.elevationGain > 0 || session.elevationLoss > 0 {
                        Divider()
                        
                        VStack(spacing: 12) {
                            Text("Elevation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            DetailMetricRow(
                                title: "Gain",
                                value: "\(Int(session.elevationGain)) m",
                                icon: "arrow.up"
                            )
                            
                            DetailMetricRow(
                                title: "Loss",
                                value: "\(Int(session.elevationLoss)) m",
                                icon: "arrow.down"
                            )
                            
                            DetailMetricRow(
                                title: "Net Change",
                                value: "\(Int(session.netElevationChange)) m",
                                icon: "mountain.2.fill"
                            )
                        }
                    }
                    
                    // Data Points
                    Divider()
                    
                    VStack(spacing: 8) {
                        Text("Tracking Data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(session.locationPoints.count) GPS points recorded")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Detail Metric Row

struct DetailMetricRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(width: 16)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Formatting Helpers

private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func formatDateLong(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func formatDistance(_ distance: Double) -> String {
    if distance < 1000 {
        return "\(Int(distance)) m"
    } else {
        return String(format: "%.2f km", distance / 1000)
    }
}

private func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    let seconds = Int(duration) % 60
    
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private func formatPace(_ pace: Double) -> String {
    guard pace > 0 && pace.isFinite else { return "--:--" }
    
    let minutes = Int(pace)
    let seconds = Int((pace - Double(minutes)) * 60)
    
    return String(format: "%d:%02d /km", minutes, seconds)
}

#Preview {
    HistoryView()
        .environmentObject(WatchAppCoordinator())
}