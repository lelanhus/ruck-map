import SwiftUI

/// Example view demonstrating export and share functionality integration
struct SessionExportView: View {
    let session: RuckSession
    @EnvironmentObject private var dataCoordinator: DataCoordinator
    @StateObject private var shareManager = ShareManager()
    @State private var selectedFormat: ExportManager.ExportFormat = .gpx
    @State private var isExporting = false
    @State private var exportError: Error?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Session Summary
                SessionSummaryCard(session: session)
                
                // Export Format Selection
                ExportFormatPicker(selectedFormat: $selectedFormat)
                
                // Export Actions
                ExportActionsSection(
                    session: session,
                    selectedFormat: selectedFormat,
                    isExporting: $isExporting,
                    onExport: { format in
                        await exportSession(format: format)
                    },
                    onShare: { format in
                        await shareSession(format: format)
                    }
                )
                
                // Recent Export Results
                if let result = shareManager.lastShareResult {
                    ShareResultView(result: result)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Session")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isExporting)
            .overlay {
                if isExporting {
                    ProgressOverlay()
                }
            }
        }
        .shareSheet(
            isPresented: $shareManager.isPresenting,
            items: shareManager.shareItems
        ) { result in
            shareManager.lastShareResult = result
        }
        .alert("Export Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(exportError?.localizedDescription ?? "Unknown error")
        }
    }
    
    private func exportSession(format: ExportManager.ExportFormat) async {
        isExporting = true
        defer { isExporting = false }
        
        do {
            let url = try await dataCoordinator.exportSession(session, format: format)
            print("Session exported to: \(url.path)")
        } catch {
            exportError = error
            showingError = true
        }
    }
    
    private func shareSession(format: ExportManager.ExportFormat) async {
        isExporting = true
        defer { isExporting = false }
        
        await shareManager.shareSession(session, format: format, dataCoordinator: dataCoordinator)
    }
}

// MARK: - Supporting Views

struct SessionSummaryCard: View {
    let session: RuckSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session Summary")
                    .font(.headline)
                Spacer()
                Text(session.startDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                MetricView(title: "Distance", value: "\(String(format: "%.2f", session.totalDistance / 1000)) km")
                MetricView(title: "Duration", value: formatDuration(session.duration))
                MetricView(title: "Load Weight", value: "\(String(format: "%.1f", session.loadWeight)) kg")
                MetricView(title: "Elevation Gain", value: "\(String(format: "%.0f", session.elevationGain)) m")
                MetricView(title: "GPS Points", value: "\(session.locationPoints.count)")
                MetricView(title: "Calories", value: "\(Int(session.totalCalories))")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct MetricView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ExportFormatPicker: View {
    @Binding var selectedFormat: ExportManager.ExportFormat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Format")
                .font(.headline)
            
            Picker("Format", selection: $selectedFormat) {
                HStack {
                    Image(systemName: "location")
                    Text("GPX")
                    Text("(GPS Exchange)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .tag(ExportManager.ExportFormat.gpx)
                
                HStack {
                    Image(systemName: "tablecells")
                    Text("CSV")
                    Text("(Data Analysis)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .tag(ExportManager.ExportFormat.csv)
                
                HStack {
                    Image(systemName: "doc.text")
                    Text("JSON")
                    Text("(Raw Data)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .tag(ExportManager.ExportFormat.json)
            }
            .pickerStyle(.segmented)
            
            // Format description
            Text(formatDescription(for: selectedFormat))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    private func formatDescription(for format: ExportManager.ExportFormat) -> String {
        switch format {
        case .gpx:
            return "Compatible with most GPS applications and fitness platforms. Includes elevation data and metadata."
        case .csv:
            return "Spreadsheet format for data analysis. Includes all metrics and location points with timestamps."
        case .json:
            return "Structured data format for developers and advanced analysis tools."
        }
    }
}

struct ExportActionsSection: View {
    let session: RuckSession
    let selectedFormat: ExportManager.ExportFormat
    @Binding var isExporting: Bool
    let onExport: (ExportManager.ExportFormat) async -> Void
    let onShare: (ExportManager.ExportFormat) async -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        await onExport(selectedFormat)
                    }
                }) {
                    Label("Export", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isExporting)
                
                Button(action: {
                    Task {
                        await onShare(selectedFormat)
                    }
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
            }
            
            // Quick share options
            HStack(spacing: 8) {
                Button("Share as Activity") {
                    Task {
                        await ShareManager().shareSessionAsActivity(
                            session,
                            dataCoordinator: DataCoordinator()
                        )
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                
                Button("Share for Analysis") {
                    Task {
                        await ShareManager().shareSessionForAnalysis(
                            session,
                            dataCoordinator: DataCoordinator()
                        )
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            .disabled(isExporting)
        }
    }
}

struct ShareResultView: View {
    let result: ShareManager.ShareResult
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
            
            Text(message)
                .font(.caption)
                .foregroundColor(textColor)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .cornerRadius(8)
    }
    
    private var iconName: String {
        switch result {
        case .success:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var iconColor: Color {
        switch result {
        case .success:
            return .green
        case .cancelled:
            return .orange
        case .failed:
            return .red
        }
    }
    
    private var message: String {
        switch result {
        case .success(let activity):
            return "Shared via \(activity)"
        case .cancelled:
            return "Share cancelled"
        case .failed(let error):
            return "Share failed: \(error.localizedDescription)"
        }
    }
    
    private var textColor: Color {
        switch result {
        case .success:
            return .green
        case .cancelled:
            return .orange
        case .failed:
            return .red
        }
    }
    
    private var backgroundColor: Color {
        switch result {
        case .success:
            return .green.opacity(0.1)
        case .cancelled:
            return .orange.opacity(0.1)
        case .failed:
            return .red.opacity(0.1)
        }
    }
}

struct ProgressOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Exporting...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        }
    }
}

#Preview {
    let session = try! RuckSession(loadWeight: 35.0)
    session.totalDistance = 5000
    session.elevationGain = 250
    session.totalCalories = 750
    
    // Add some sample location points
    for i in 0..<10 {
        let point = LocationPoint(
            timestamp: Date(),
            latitude: 40.7128 + Double(i) * 0.001,
            longitude: -74.0060,
            altitude: 10.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            speed: 1.5,
            course: 0.0
        )
        session.locationPoints.append(point)
    }
    
    return SessionExportView(session: session)
        .environmentObject(try! DataCoordinator())
}