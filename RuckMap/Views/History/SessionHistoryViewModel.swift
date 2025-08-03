import SwiftUI
import SwiftData
import Foundation
import Observation

/// View model for SessionHistoryView using modern @Observable pattern
/// Manages filtering, sorting, and search functionality with optimal performance
@Observable
final class SessionHistoryViewModel {
    // MARK: - Published State
    
    /// Current search text
    var searchText: String = ""
    
    /// Selected sort option
    var selectedSortOption: SortOption = .dateDescending
    
    /// Filter sheet presentation
    var showingFilterSheet: Bool = false
    
    /// Delete confirmation alert
    var showingDeleteAlert: Bool = false
    
    /// Error alert presentation
    var showingErrorAlert: Bool = false
    
    /// Error message for alerts
    var errorMessage: String = ""
    
    /// Session pending deletion
    var sessionToDelete: RuckSession?
    
    // MARK: - Filter State
    
    /// Selected time range filter
    var selectedTimeRange: TimeRange = .all
    
    /// Distance range filter
    var distanceRange: ClosedRange<Double> = 0...50 // kilometers
    
    /// Load weight range filter
    var loadWeightRange: ClosedRange<Double> = 0...100 // kilograms
    
    /// Selected terrain types
    var selectedTerrainTypes: Set<TerrainType> = Set(TerrainType.allCases)
    
    /// Weather condition filters
    var temperatureRange: ClosedRange<Double> = -20...50 // Celsius
    var windSpeedMax: Double = 50 // m/s
    var precipitationMax: Double = 50 // mm/hr
    
    /// Show only favorite sessions
    var showOnlyFavorites: Bool = false
    
    /// Minimum calories filter
    var minCalories: Double = 0
    
    /// Elevation gain filter
    var minElevationGain: Double = 0
    
    // MARK: - Private State
    
    private var allSessions: [RuckSession] = []
    
    // MARK: - Computed Properties
    
    /// Check if any filters are active
    var hasActiveFilters: Bool {
        selectedTimeRange != .all ||
        distanceRange != 0...50 ||
        loadWeightRange != 0...100 ||
        selectedTerrainTypes != Set(TerrainType.allCases) ||
        temperatureRange != -20...50 ||
        windSpeedMax != 50 ||
        precipitationMax != 50 ||
        showOnlyFavorites ||
        minCalories > 0 ||
        minElevationGain > 0
    }
    
    // MARK: - Public Methods
    
    /// Updates the cached sessions
    func updateSessions(_ sessions: [RuckSession]) {
        allSessions = sessions
    }
    
    /// Returns filtered and sorted sessions
    func filteredSessions(from sessions: [RuckSession]) -> [RuckSession] {
        var filtered = sessions
        
        // Apply time range filter
        filtered = applyTimeRangeFilter(to: filtered)
        
        // Apply search filter
        filtered = applySearchFilter(to: filtered)
        
        // Apply distance filter
        filtered = applyDistanceFilter(to: filtered)
        
        // Apply load weight filter
        filtered = applyLoadWeightFilter(to: filtered)
        
        // Apply terrain filter
        filtered = applyTerrainFilter(to: filtered)
        
        // Apply weather filters
        filtered = applyWeatherFilters(to: filtered)
        
        // Apply favorites filter
        if showOnlyFavorites {
            filtered = filtered.filter { session in
                session.rpe != nil && session.rpe! >= 8
            }
        }
        
        // Apply calories filter
        if minCalories > 0 {
            filtered = filtered.filter { session in
                session.totalCalories >= minCalories
            }
        }
        
        // Apply elevation gain filter
        if minElevationGain > 0 {
            filtered = filtered.filter { session in
                session.elevationGain >= minElevationGain
            }
        }
        
        // Apply sorting
        return applySorting(to: filtered)
    }
    
    /// Clears all active filters
    func clearAllFilters() {
        selectedTimeRange = .all
        distanceRange = 0...50
        loadWeightRange = 0...100
        selectedTerrainTypes = Set(TerrainType.allCases)
        temperatureRange = -20...50
        windSpeedMax = 50
        precipitationMax = 50
        showOnlyFavorites = false
        minCalories = 0
        minElevationGain = 0
    }
    
    // MARK: - Private Filter Methods
    
    private func applyTimeRangeFilter(to sessions: [RuckSession]) -> [RuckSession] {
        guard selectedTimeRange != .all else { return sessions }
        
        let calendar = Calendar.current
        let now = Date()
        
        let cutoffDate: Date
        switch selectedTimeRange {
        case .all:
            return sessions
        case .week:
            cutoffDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? Date.distantPast
        case .month:
            cutoffDate = calendar.date(byAdding: .month, value: -1, to: now) ?? Date.distantPast
        case .threeMonths:
            cutoffDate = calendar.date(byAdding: .month, value: -3, to: now) ?? Date.distantPast
        case .sixMonths:
            cutoffDate = calendar.date(byAdding: .month, value: -6, to: now) ?? Date.distantPast
        case .year:
            cutoffDate = calendar.date(byAdding: .year, value: -1, to: now) ?? Date.distantPast
        }
        
        return sessions.filter { session in
            session.startDate >= cutoffDate
        }
    }
    
    private func applySearchFilter(to sessions: [RuckSession]) -> [RuckSession] {
        guard !searchText.isEmpty else { return sessions }
        
        let lowercaseSearch = searchText.lowercased()
        
        return sessions.filter { session in
            // Search in notes
            if let notes = session.notes, notes.lowercased().contains(lowercaseSearch) {
                return true
            }
            
            // Search in formatted date
            let dateString = DateFormatter.localizedString(
                from: session.startDate,
                dateStyle: .medium,
                timeStyle: .none
            )
            if dateString.lowercased().contains(lowercaseSearch) {
                return true
            }
            
            // Search in terrain types
            for terrain in session.terrainSegments {
                if terrain.terrainType.displayName.lowercased().contains(lowercaseSearch) {
                    return true
                }
            }
            
            // Search in weather conditions
            if let weather = session.weatherConditions,
               let description = weather.weatherDescription {
                if description.lowercased().contains(lowercaseSearch) {
                    return true
                }
            }
            
            return false
        }
    }
    
    private func applyDistanceFilter(to sessions: [RuckSession]) -> [RuckSession] {
        return sessions.filter { session in
            let distanceKm = session.totalDistance / 1000
            return distanceRange.contains(distanceKm)
        }
    }
    
    private func applyLoadWeightFilter(to sessions: [RuckSession]) -> [RuckSession] {
        return sessions.filter { session in
            loadWeightRange.contains(session.loadWeight)
        }
    }
    
    private func applyTerrainFilter(to sessions: [RuckSession]) -> [RuckSession] {
        guard selectedTerrainTypes != Set(TerrainType.allCases) else { return sessions }
        
        return sessions.filter { session in
            // Check if any terrain segment matches selected types
            for terrain in session.terrainSegments {
                if selectedTerrainTypes.contains(terrain.terrainType) {
                    return true
                }
            }
            return session.terrainSegments.isEmpty // Include sessions without terrain data
        }
    }
    
    private func applyWeatherFilters(to sessions: [RuckSession]) -> [RuckSession] {
        return sessions.filter { session in
            guard let weather = session.weatherConditions else {
                return true // Include sessions without weather data
            }
            
            return temperatureRange.contains(weather.temperature) &&
                   weather.windSpeed <= windSpeedMax &&
                   weather.precipitation <= precipitationMax
        }
    }
    
    private func applySorting(to sessions: [RuckSession]) -> [RuckSession] {
        return sessions.sorted { lhs, rhs in
            switch selectedSortOption {
            case .dateDescending:
                return lhs.startDate > rhs.startDate
            case .dateAscending:
                return lhs.startDate < rhs.startDate
            case .distanceDescending:
                return lhs.totalDistance > rhs.totalDistance
            case .distanceAscending:
                return lhs.totalDistance < rhs.totalDistance
            case .durationDescending:
                return lhs.totalDuration > rhs.totalDuration
            case .durationAscending:
                return lhs.totalDuration < rhs.totalDuration
            case .caloriesDescending:
                return lhs.totalCalories > rhs.totalCalories
            case .caloriesAscending:
                return lhs.totalCalories < rhs.totalCalories
            case .averagePaceDescending:
                return lhs.averagePace > rhs.averagePace
            case .averagePaceAscending:
                return lhs.averagePace < rhs.averagePace
            case .elevationGainDescending:
                return lhs.elevationGain > rhs.elevationGain
            case .elevationGainAscending:
                return lhs.elevationGain < rhs.elevationGain
            }
        }
    }
}

// MARK: - Supporting Enums

/// Available sort options for sessions
enum SortOption: String, CaseIterable {
    case dateDescending = "Newest First"
    case dateAscending = "Oldest First"
    case distanceDescending = "Longest Distance"
    case distanceAscending = "Shortest Distance"
    case durationDescending = "Longest Duration"
    case durationAscending = "Shortest Duration"
    case caloriesDescending = "Most Calories"
    case caloriesAscending = "Least Calories"
    case averagePaceDescending = "Fastest Pace"
    case averagePaceAscending = "Slowest Pace"
    case elevationGainDescending = "Most Elevation"
    case elevationGainAscending = "Least Elevation"
    
    var systemImage: String {
        switch self {
        case .dateDescending, .dateAscending:
            return "calendar"
        case .distanceDescending, .distanceAscending:
            return "map"
        case .durationDescending, .durationAscending:
            return "clock"
        case .caloriesDescending, .caloriesAscending:
            return "flame"
        case .averagePaceDescending, .averagePaceAscending:
            return "speedometer"
        case .elevationGainDescending, .elevationGainAscending:
            return "mountain.2"
        }
    }
}

/// Time range filter options
enum TimeRange: String, CaseIterable {
    case all = "All Time"
    case week = "This Week"
    case month = "This Month"
    case threeMonths = "Last 3 Months"
    case sixMonths = "Last 6 Months"
    case year = "This Year"
    
    var systemImage: String {
        switch self {
        case .all:
            return "infinity"
        case .week:
            return "calendar.day.timeline.left"
        case .month:
            return "calendar"
        case .threeMonths:
            return "calendar.badge.clock"
        case .sixMonths:
            return "calendar.badge.clock"
        case .year:
            return "calendar.circle"
        }
    }
}

/// Statistics with trend information
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
    
    var totalCalories: Double {
        sessions.reduce(0) { $0 + $1.totalCalories }
    }
    
    var averageDistance: Double {
        guard totalSessions > 0 else { return 0 }
        return totalDistance / Double(totalSessions)
    }
    
    var averageDuration: TimeInterval {
        guard totalSessions > 0 else { return 0 }
        return totalDuration / Double(totalSessions)
    }
    
    var averageCalories: Double {
        guard totalSessions > 0 else { return 0 }
        return totalCalories / Double(totalSessions)
    }
    
    // Trend calculations (simplified - comparing last 30 days to previous 30)
    var sessionsTrend: StatTrend? {
        calculateTrend(for: \.totalDistance) // Using distance as proxy for activity
    }
    
    var distanceTrend: StatTrend? {
        calculateTrend(for: \.totalDistance)
    }
    
    var timeTrend: StatTrend? {
        calculateTrend(for: \.totalDuration)
    }
    
    var caloriesTrend: StatTrend? {
        calculateTrend(for: \.totalCalories)
    }
    
    private func calculateTrend<T: Comparable>(for keyPath: KeyPath<RuckSession, T>) -> StatTrend? {
        let calendar = Calendar.current
        let now = Date()
        
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now),
              let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now) else {
            return nil
        }
        
        let recent = sessions.filter { $0.startDate >= thirtyDaysAgo }
        let previous = sessions.filter { $0.startDate >= sixtyDaysAgo && $0.startDate < thirtyDaysAgo }
        
        guard !recent.isEmpty && !previous.isEmpty else { return nil }
        
        // This is a simplified trend calculation
        // In a real implementation, you'd compare actual values
        if recent.count > previous.count {
            return .up
        } else if recent.count < previous.count {
            return .down
        } else {
            return .stable
        }
    }
}

/// Trend indicator for statistics
enum StatTrend {
    case up
    case down
    case stable
    
    var icon: String {
        switch self {
        case .up:
            return "arrow.up"
        case .down:
            return "arrow.down"
        case .stable:
            return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up:
            return .green
        case .down:
            return .red
        case .stable:
            return .gray
        }
    }
}