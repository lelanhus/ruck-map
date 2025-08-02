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
        sessionId: UUID,
        format: ExportManager.ExportFormat,
        dataCoordinator: DataCoordinator
    ) async {
        do {
            logger.info("Starting share for session \(sessionId) in \(format.rawValue) format")
            
            let url = try await dataCoordinator.exportSession(sessionId: sessionId, format: format)
            
            // Get session data for summary
            guard let sessionData = try await dataCoordinator.getSessionExportData(id: sessionId) else {
                throw ShareError.exportFailed(ExportManager.ExportError.sessionNotFound)
            }
            
            // Create share items
            var items: [Any] = [url]
            
            // Add session summary as text
            let summary = createSessionSummary(sessionData)
            items.append(summary)
            
            // Add metadata for the file
            if let metadata = createFileMetadata(url: url, sessionData: sessionData) {
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
        sessionIds: [UUID],
        format: ExportManager.ExportFormat,
        dataCoordinator: DataCoordinator
    ) async {
        do {
            logger.info("Starting batch share for \(sessionIds.count) sessions in \(format.rawValue) format")
            
            let urls = try await dataCoordinator.exportSessions(sessionIds: sessionIds, format: format)
            
            guard !urls.isEmpty else {
                throw ShareError.noItemsToShare
            }
            
            var items: [Any] = urls
            
            // Get session data for summary
            var sessionDataList: [SessionExportData] = []
            for sessionId in sessionIds {
                if let data = try await dataCoordinator.getSessionExportData(id: sessionId) {
                    sessionDataList.append(data)
                }
            }
            
            // Add batch summary
            let batchSummary = createBatchSummary(sessions: sessionDataList)
            items.append(batchSummary)
            
            await presentShareSheet(items: items)
            lastShareResult = .success("\(sessionIds.count) sessions shared successfully")
            
        } catch {
            logger.error("Failed to share sessions: \(error.localizedDescription)")
            lastShareResult = .failed(error)
        }
    }
    
    /// Shares session as GPX with activity metadata
    func shareSessionAsActivity(
        sessionId: UUID,
        dataCoordinator: DataCoordinator,
        includePhotos: Bool = false
    ) async {
        do {
            let gpxURL = try await dataCoordinator.exportSessionToGPX(sessionId: sessionId)
            
            // Get session data for descriptions
            guard let sessionData = try await dataCoordinator.getSessionExportData(id: sessionId) else {
                throw ShareError.exportFailed(ExportManager.ExportError.sessionNotFound)
            }
            
            var items: [Any] = [gpxURL]
            
            // Add rich activity description
            let activityDescription = createActivityDescription(sessionData)
            items.append(activityDescription)
            
            // Add session statistics as formatted text
            let statistics = createDetailedStatistics(sessionData)
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
        sessionId: UUID,
        dataCoordinator: DataCoordinator
    ) async {
        do {
            let csvURL = try await dataCoordinator.exportSessionToCSV(sessionId: sessionId)
            
            // Get session data for analysis summary
            guard let sessionData = try await dataCoordinator.getSessionExportData(id: sessionId) else {
                throw ShareError.exportFailed(ExportManager.ExportError.sessionNotFound)
            }
            
            var items: [Any] = [csvURL]
            
            // Add analysis summary
            let analysisSummary = createAnalysisSummary(sessionData)
            items.append(analysisSummary)
            
            // Add technical details
            let technicalDetails = createTechnicalDetails(sessionData)
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
    
    private func createSessionSummary(_ sessionData: SessionExportData) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let distance = String(format: "%.2f", sessionData.totalDistance / 1000)
        let duration = sessionData.endDate != nil ? formatDuration(sessionData.endDate!.timeIntervalSince(sessionData.startDate)) : "In Progress"
        let weight = String(format: "%.1f", sessionData.loadWeight)
        
        return """
        🎒 Ruck March Summary
        📅 Date: \(formatter.string(from: sessionData.startDate))
        📏 Distance: \(distance) km
        ⏱️ Duration: \(duration)
        🎒 Load Weight: \(weight) kg
        🔥 Calories: \(Int(sessionData.totalCalories))
        ⛰️ Elevation Gain: \(String(format: "%.0f", sessionData.elevationGain)) m
        
        Shared from RuckMap 📍
        """
    }
    
    private func createBatchSummary(sessions: [SessionExportData]) -> String {
        let totalDistance = sessions.reduce(0) { $0 + $1.totalDistance }
        let totalDuration = sessions.reduce(0.0) { total, session in
            if let endDate = session.endDate {
                return total + endDate.timeIntervalSince(session.startDate)
            }
            return total
        }
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
    
    private func createActivityDescription(_ sessionData: SessionExportData) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        
        let distance = String(format: "%.2f", sessionData.totalDistance / 1000)
        let avgPace = formatPaceMinPerKm(sessionData.averagePace)
        let weight = String(format: "%.1f", sessionData.loadWeight)
        let duration = sessionData.endDate != nil ? formatDuration(sessionData.endDate!.timeIntervalSince(sessionData.startDate)) : "In Progress"
        
        return """
        🎒 Ruck March Activity
        
        Completed a challenging ruck march carrying \(weight) kg over \(distance) km.
        
        📅 \(formatter.string(from: sessionData.startDate))
        ⏱️ Duration: \(duration)
        🏃‍♂️ Average Pace: \(avgPace)
        🔥 Calories Burned: \(Int(sessionData.totalCalories))
        ⛰️ Elevation Gain: \(String(format: "%.0f", sessionData.elevationGain)) m
        
        #RuckMarch #Fitness #Endurance #Military #Training
        """
    }
    
    private func createDetailedStatistics(_ sessionData: SessionExportData) -> String {
        return """
        📊 Detailed Statistics
        
        Distance Metrics:
        • Total Distance: \(String(format: "%.3f", sessionData.totalDistance / 1000)) km
        • GPS Points: \(sessionData.locationPointsCount)
        
        Elevation Profile:
        • Gain: \(String(format: "%.1f", sessionData.elevationGain)) m
        • Loss: \(String(format: "%.1f", sessionData.elevationLoss)) m
        • Max: \(String(format: "%.1f", sessionData.maxElevation)) m
        • Min: \(String(format: "%.1f", sessionData.minElevation)) m
        • Range: \(String(format: "%.1f", sessionData.elevationRange)) m
        
        Grade Analysis:
        • Average: \(String(format: "%.2f", sessionData.averageGrade))%
        • Maximum: \(String(format: "%.2f", sessionData.maxGrade))%
        • Minimum: \(String(format: "%.2f", sessionData.minGrade))%
        
        Performance:
        • Average Pace: \(formatPaceMinPerKm(sessionData.averagePace))
        • Calories: \(Int(sessionData.totalCalories))
        • Load Weight: \(String(format: "%.1f", sessionData.loadWeight)) kg
        """
    }
    
    private func createAnalysisSummary(_ sessionData: SessionExportData) -> String {
        return """
        🔬 Analysis Summary for Session \(sessionData.id.uuidString.prefix(8))
        
        Data Quality:
        • Location Points: \(sessionData.locationPointsCount)
        • Elevation Accuracy: \(String(format: "%.1f", sessionData.elevationAccuracy)) m
        • Barometer Data: \(sessionData.barometerDataPoints) points
        • High Quality Data: \(sessionData.hasHighQualityElevationData ? "Yes" : "No")
        
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
    
    private func createTechnicalDetails(_ sessionData: SessionExportData) -> String {
        return """
        🔧 Technical Details
        
        Session Metadata:
        • ID: \(sessionData.id.uuidString)
        • Version: \(sessionData.version)
        • Created: \(DateFormatter.iso8601.string(from: sessionData.createdAt))
        • Modified: \(DateFormatter.iso8601.string(from: sessionData.modifiedAt))
        
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
    
    private func createFileMetadata(url: URL, sessionData: SessionExportData) -> [String: Any]? {
        // Create metadata dictionary for the file
        let duration = sessionData.endDate != nil ? sessionData.endDate!.timeIntervalSince(sessionData.startDate) : 0
        return [
            "title": "Ruck Session - \(DateFormatter.shortDate.string(from: sessionData.startDate))",
            "description": "GPS track and elevation data from ruck march",
            "distance": sessionData.totalDistance,
            "duration": duration,
            "elevationGain": sessionData.elevationGain,
            "loadWeight": sessionData.loadWeight,
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
    
    private func formatPaceMinPerKm(_ paceMinPerKm: Double) -> String {
        guard paceMinPerKm > 0 else { return "N/A" }
        
        let minutes = Int(paceMinPerKm)
        let seconds = Int((paceMinPerKm - Double(minutes)) * 60)
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