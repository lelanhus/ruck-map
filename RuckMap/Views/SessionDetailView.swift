import SwiftUI
import SwiftData

struct SessionDetailView: View {
    let session: RuckSession
    @EnvironmentObject private var dataCoordinator: DataCoordinator
    @State private var showingExportSheet = false
    @State private var showingShareSheet = false
    @State private var exportFormat: ExportManager.ExportFormat = .gpx
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var exportError: Error?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Session Header
                sessionHeader
                
                // Metrics Cards
                metricsSection
                
                // Elevation Profile
                if !session.locationPoints.isEmpty {
                    ElevationProfileView(
                        locationPoints: session.locationPoints,
                        session: session
                    )
                    .frame(height: 200)
                    .padding(.horizontal)
                }
                
                // Compression Info
                if hasCompressedData {
                    compressionInfoCard
                }
                
                // Export Actions
                exportActionsSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExportSheet) {
            exportSheet
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Export Error", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError?.localizedDescription ?? "Unknown error")
        }
    }
    
    // MARK: - Subviews
    
    private var sessionHeader: some View {
        VStack(spacing: 8) {
            Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
            
            if session.endDate != nil {
                Text("Duration: \(formatDuration(session.duration))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                Label("\(String(format: "%.1f", session.loadWeight)) kg", systemImage: "backpack")
                Label("\(String(format: "%.2f", session.totalDistance / 1000)) km", systemImage: "location")
                Label("\(Int(session.totalCalories)) cal", systemImage: "flame")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var metricsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SessionMetricCard(
                    title: "Avg Pace",
                    value: formatPace(session.averagePace),
                    icon: "speedometer",
                    color: .blue
                )
                
                SessionMetricCard(
                    title: "Elevation Gain",
                    value: "\(Int(session.elevationGain))m",
                    icon: "arrow.up.forward",
                    color: .green
                )
            }
            
            HStack(spacing: 12) {
                SessionMetricCard(
                    title: "Avg Grade",
                    value: String(format: "%.1f%%", session.averageGrade),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                )
                
                SessionMetricCard(
                    title: "Points",
                    value: "\(session.locationPoints.count)",
                    icon: "mappin.and.ellipse",
                    color: .purple
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var compressionInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Compression Info", systemImage: "rectangle.compress.vertical")
                .font(.headline)
            
            HStack {
                Text("Compressed Points:")
                Spacer()
                Text("\(compressedPointsCount) of \(totalPointsCount)")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            
            HStack {
                Text("Compression Ratio:")
                Spacer()
                Text(String(format: "%.1f%%", compressionRatio * 100))
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var exportActionsSection: some View {
        VStack(spacing: 12) {
            Text("Export & Share")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button(action: { showingExportSheet = true }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: shareSession) {
                    Label("Share", systemImage: "square.and.arrow.up.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
    }
    
    private var exportSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Export Format")
                    .font(.headline)
                
                ForEach(ExportManager.ExportFormat.allCases, id: \.self) { format in
                    Button(action: { exportSession(format: format) }) {
                        HStack {
                            Image(systemName: format.icon)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(format.title)
                                    .font(.headline)
                                Text(format.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isExporting && exportFormat == format {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(isExporting)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingExportSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var hasCompressedData: Bool {
        session.locationPoints.contains { $0.wasCompressed() }
    }
    
    private var compressedPointsCount: Int {
        session.locationPoints.filter { $0.wasCompressed() }.count
    }
    
    private var totalPointsCount: Int {
        if let maxIndex = session.locationPoints.compactMap({ $0.compressionIndex }).max() {
            return maxIndex + 1
        }
        return session.locationPoints.count
    }
    
    private var compressionRatio: Double {
        guard totalPointsCount > 0 else { return 1.0 }
        return Double(session.locationPoints.count) / Double(totalPointsCount)
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
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func exportSession(format: ExportManager.ExportFormat) {
        exportFormat = format
        isExporting = true
        showingExportSheet = false
        
        Task {
            do {
                let sessionId = session.id
                let url = try await dataCoordinator.exportSession(sessionId: sessionId, format: format)
                exportURL = url
                showingShareSheet = true
            } catch {
                exportError = error
            }
            
            isExporting = false
        }
    }
    
    private func shareSession() {
        Task {
            let shareManager = ShareManager()
            await shareManager.shareSession(sessionId: session.id, format: .gpx, dataCoordinator: dataCoordinator)
        }
    }
}

// MARK: - Supporting Views

private struct SessionMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ExportFormat Extensions

extension ExportManager.ExportFormat {
    var icon: String {
        switch self {
        case .gpx: return "map"
        case .csv: return "tablecells"
        case .json: return "curlybraces"
        }
    }
    
    var title: String {
        switch self {
        case .gpx: return "GPX File"
        case .csv: return "CSV Spreadsheet"
        case .json: return "JSON Data"
        }
    }
    
    var description: String {
        switch self {
        case .gpx: return "For use with mapping apps"
        case .csv: return "For analysis in Excel"
        case .json: return "For developers and APIs"
        }
    }
}