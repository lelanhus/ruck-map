import Foundation
import SwiftUI
import UIKit
import OSLog

/// Manages share sheet functionality for RuckMap exports
@MainActor
class ShareManager: ObservableObject {
    private let logger = Logger(subsystem: "com.ruckmap.app", category: "ShareManager")
    
    @Published var isPresenting = false
    @Published var shareItems: [Any] = []
    @Published var lastShareResult: ShareResult?
    
    enum ShareResult {
        case success(String)
        case cancelled
        case failed(Error)
    }
    
    enum ShareError: LocalizedError {
        case noItemsToShare
        case exportFailed(Error)
        case unsupportedFormat
        
        var errorDescription: String? {
            switch self {
            case .noItemsToShare:
                return "No items to share"
            case .exportFailed(let error):
                return "Export failed: \(error.localizedDescription)"
            case .unsupportedFormat:
                return "Unsupported file format for sharing"
            }
        }
    }
    
    /// Shares a single session with format selection
    func shareSession(
        _ session: RuckSession,
        format: ExportManager.ExportFormat,
        dataCoordinator: DataCoordinator
    ) async {
        do {
            logger.info("Starting share for session \(session.id) in \(format.rawValue) format")
            
            let url = try await dataCoordinator.exportSession(session, format: format)
            
            // Create share items
            var items: [Any] = [url]
            
            // Add session summary as text
            let summary = createSessionSummary(session)
            items.append(summary)
            
            // Add metadata for the file
            if let metadata = createFileMetadata(url: url, session: session) {
                items.append(metadata)
            }
            
            await presentShareSheet(items: items)
            lastShareResult = .success("Session shared successfully")
            
        } catch {
            logger.error("Failed to share session: \(error.localizedDescription)")
            lastShareResult = .failed(error)
        }
    }
    
    /// Shares multiple sessions
    func shareSessions(
        _ sessions: [RuckSession],
        format: ExportManager.ExportFormat,
        dataCoordinator: DataCoordinator
    ) async {
        do {
            logger.info("Starting batch share for \(sessions.count) sessions in \(format.rawValue) format")
            
            let urls = try await dataCoordinator.exportSessions(sessions, format: format)
            
            guard !urls.isEmpty else {
                throw ShareError.noItemsToShare
            }
            
            var items: [Any] = urls
            
            // Add batch summary
            let batchSummary = createBatchSummary(sessions: sessions)
            items.append(batchSummary)
            
            await presentShareSheet(items: items)
            lastShareResult = .success("\(sessions.count) sessions shared successfully")
            
        } catch {
            logger.error("Failed to share sessions: \(error.localizedDescription)")
            lastShareResult = .failed(error)
        }
    }
    
    /// Shares session as GPX with activity metadata
    func shareSessionAsActivity(
        _ session: RuckSession,
        dataCoordinator: DataCoordinator,
        includePhotos: Bool = false
    ) async {
        do {
            let gpxURL = try await dataCoordinator.exportSessionToGPX(session)
            
            var items: [Any] = [gpxURL]
            
            // Add rich activity description
            let activityDescription = createActivityDescription(session)
            items.append(activityDescription)
            
            // Add session statistics as formatted text
            let statistics = createDetailedStatistics(session)
            items.append(statistics)
            
            // TODO: Add photos if requested (future feature)
            if includePhotos {
                // Add session photos when photo feature is implemented
            }
            
            await presentShareSheet(items: items)
            lastShareResult = .success("Activity shared successfully")
            
        } catch {
            logger.error("Failed to share activity: \(error.localizedDescription)")
            lastShareResult = .failed(error)
        }
    }
    
    /// Shares session data for analysis (CSV format with metadata)
    func shareSessionForAnalysis(
        _ session: RuckSession,
        dataCoordinator: DataCoordinator
    ) async {
        do {
            let csvURL = try await dataCoordinator.exportSessionToCSV(session)
            
            var items: [Any] = [csvURL]
            
            // Add analysis summary
            let analysisSummary = createAnalysisSummary(session)
            items.append(analysisSummary)
            
            // Add technical details
            let technicalDetails = createTechnicalDetails(session)
            items.append(technicalDetails)
            
            await presentShareSheet(items: items)
            lastShareResult = .success("Session data shared for analysis")
            
        } catch {
            logger.error("Failed to share session for analysis: \(error.localizedDescription)")
            lastShareResult = .failed(error)
        }
    }
    
    /// Shares custom text content
    func shareText(_ text: String, subject: String? = nil) async {
        var items: [Any] = [text]
        
        if let subject = subject {
            items.append(subject)
        }
        
        await presentShareSheet(items: items)
        lastShareResult = .success("Text shared successfully")
    }
    
    /// Shares custom URL content
    func shareURL(_ url: URL, description: String? = nil) async {
        var items: [Any] = [url]
        
        if let description = description {
            items.append(description)
        }
        
        await presentShareSheet(items: items)
        lastShareResult = .success("URL shared successfully")
    }
    
    // MARK: - Private Methods
    
    private func presentShareSheet(items: [Any]) async {
        shareItems = items
        isPresenting = true
    }
    
    private func createSessionSummary(_ session: RuckSession) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let distance = String(format: "%.2f", session.totalDistance / 1000)
        let duration = formatDuration(session.duration)
        let weight = String(format: "%.1f", session.loadWeight)
        
        return """
        🎒 Ruck March Summary
        📅 Date: \(formatter.string(from: session.startDate))
        📏 Distance: \(distance) km
        ⏱️ Duration: \(duration)
        🎒 Load Weight: \(weight) kg
        🔥 Calories: \(Int(session.totalCalories))
        ⛰️ Elevation Gain: \(String(format: "%.0f", session.elevationGain)) m
        
        Shared from RuckMap 📍
        """
    }
    
    private func createBatchSummary(sessions: [RuckSession]) -> String {
        let totalDistance = sessions.reduce(0) { $0 + $1.totalDistance }
        let totalDuration = sessions.reduce(0) { $0 + $1.duration }
        let totalCalories = sessions.reduce(0) { $0 + $1.totalCalories }
        let totalElevationGain = sessions.reduce(0) { $0 + $1.elevationGain }
        
        let distance = String(format: "%.2f", totalDistance / 1000)
        let duration = formatDuration(totalDuration)
        
        return """
        🎒 Ruck March Collection
        📊 Sessions: \(sessions.count)
        📏 Total Distance: \(distance) km
        ⏱️ Total Duration: \(duration)
        🔥 Total Calories: \(Int(totalCalories))
        ⛰️ Total Elevation: \(String(format: "%.0f", totalElevationGain)) m
        
        Shared from RuckMap 📍
        """
    }
    
    private func createActivityDescription(_ session: RuckSession) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        
        let distance = String(format: "%.2f", session.totalDistance / 1000)
        let avgPace = formatPace(session.averagePace)
        let weight = String(format: "%.1f", session.loadWeight)
        
        return """
        🎒 Ruck March Activity
        
        Completed a challenging ruck march carrying \(weight) kg over \(distance) km.
        
        📅 \(formatter.string(from: session.startDate))
        ⏱️ Duration: \(formatDuration(session.duration))
        🏃‍♂️ Average Pace: \(avgPace)
        🔥 Calories Burned: \(Int(session.totalCalories))
        ⛰️ Elevation Gain: \(String(format: "%.0f", session.elevationGain)) m
        📊 Average Grade: \(String(format: "%.1f", session.averageGrade))%
        
        #RuckMarch #Fitness #Endurance #Military #Training
        """
    }
    
    private func createDetailedStatistics(_ session: RuckSession) -> String {
        return """
        📊 Detailed Statistics
        
        Distance Metrics:
        • Total Distance: \(String(format: "%.3f", session.totalDistance / 1000)) km
        • GPS Points: \(session.locationPoints.count)
        
        Elevation Profile:
        • Gain: \(String(format: "%.1f", session.elevationGain)) m
        • Loss: \(String(format: "%.1f", session.elevationLoss)) m
        • Max: \(String(format: "%.1f", session.maxElevation)) m
        • Min: \(String(format: "%.1f", session.minElevation)) m
        • Range: \(String(format: "%.1f", session.elevationRange)) m
        
        Grade Analysis:
        • Average: \(String(format: "%.2f", session.averageGrade))%
        • Maximum: \(String(format: "%.2f", session.maxGrade))%
        • Minimum: \(String(format: "%.2f", session.minGrade))%
        
        Performance:
        • Average Pace: \(formatPace(session.averagePace))
        • Calories: \(Int(session.totalCalories))
        • Load Weight: \(String(format: "%.1f", session.loadWeight)) kg
        """
    }
    
    private func createAnalysisSummary(_ session: RuckSession) -> String {
        return """
        🔬 Analysis Summary for Session \(session.id.uuidString.prefix(8))
        
        Data Quality:
        • Location Points: \(session.locationPoints.count)
        • Elevation Accuracy: \(String(format: "%.1f", session.elevationAccuracy)) m
        • Barometer Data: \(session.barometerDataPoints) points
        • High Quality Data: \(session.hasHighQualityElevationData ? "Yes" : "No")
        
        Export Information:
        • Format: CSV (Comma-Separated Values)
        • Fields: Timestamp, Coordinates, Elevation, Speed, Accuracy, Heart Rate, Grade
        • Compatible with: Excel, R, Python, MATLAB, GPS software
        
        Recommended Analysis:
        • Elevation profile visualization
        • Speed/pace analysis
        • Grade distribution
        • Heart rate correlation (if available)
        • GPS accuracy assessment
        """
    }
    
    private func createTechnicalDetails(_ session: RuckSession) -> String {
        return """
        🔧 Technical Details
        
        Session Metadata:
        • ID: \(session.id.uuidString)
        • Version: \(session.version)
        • Created: \(DateFormatter.iso8601.string(from: session.createdAt))
        • Modified: \(DateFormatter.iso8601.string(from: session.modifiedAt))
        
        Data Processing:
        • Elevation Fusion: Enhanced GPS + Barometer
        • Grade Calculation: Moving average with outlier detection
        • Accuracy Filtering: Horizontal < 10m, Vertical confidence-based
        
        Export Format:
        • Encoding: UTF-8
        • Decimal Places: 6 (coordinates), 3 (elevation), 1 (speed)
        • Timestamp: ISO 8601 format
        """
    }
    
    private func createFileMetadata(url: URL, session: RuckSession) -> [String: Any]? {
        // Create metadata dictionary for the file
        return [
            "title": "Ruck Session - \(DateFormatter.shortDate.string(from: session.startDate))",
            "description": "GPS track and elevation data from ruck march",
            "distance": session.totalDistance,
            "duration": session.duration,
            "elevationGain": session.elevationGain,
            "loadWeight": session.loadWeight,
            "fileFormat": url.pathExtension.uppercased(),
            "app": "RuckMap"
        ]
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatPace(_ paceInSeconds: Double) -> String {
        guard paceInSeconds > 0 else { return "N/A" }
        
        let minutes = Int(paceInSeconds) / 60
        let seconds = Int(paceInSeconds) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

// MARK: - SwiftUI Integration

/// SwiftUI view modifier for presenting share sheets
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: (ShareManager.ShareResult) -> Void
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        controller.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if let error = error {
                onComplete(.failed(error))
            } else if completed {
                let activityName = activityType?.rawValue ?? "Unknown"
                onComplete(.success(activityName))
            } else {
                onComplete(.cancelled)
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - View Extension

extension View {
    /// Presents a share sheet with the given items
    func shareSheet(
        isPresented: Binding<Bool>,
        items: [Any],
        onComplete: @escaping (ShareManager.ShareResult) -> Void = { _ in }
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            ShareSheetView(items: items, onComplete: onComplete)
        }
    }
}

// MARK: - Date Formatter Extensions

private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()
}