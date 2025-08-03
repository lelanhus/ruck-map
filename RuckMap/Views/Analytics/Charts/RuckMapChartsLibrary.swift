import SwiftUI
import Charts
import Foundation

// MARK: - RuckMap Charts Library
// Central library providing comprehensive Swift Charts implementations for RuckMap analytics

/// A collection of performance-optimized Swift Charts components specifically designed for fitness tracking and ruck march analytics.
/// All charts follow RuckMap's design system with army green color palette and support for dark mode.

// MARK: - Chart Component Exports

// From AnalyticsChartComponents.swift
public typealias WeeklyOverviewChart = WeeklyOverviewChart
public typealias PaceTrendChart = PaceTrendChart  
public typealias WeightMovedChart = WeightMovedChart

// From PersonalRecordsCharts.swift
public typealias PersonalRecordsChart = PersonalRecordsChart
public typealias PersonalRecordsProgressChart = PersonalRecordsProgressChart

// From StreakVisualizationCharts.swift
public typealias TrainingStreakChart = TrainingStreakChart

// From PeriodComparisonCharts.swift
public typealias PeriodComparisonChart = PeriodComparisonChart
public typealias WeeklyComparisonChart = WeeklyComparisonChart

// MARK: - Chart Design System

/// RuckMap chart color palette following army green design system
struct RuckMapChartColors {
    static let primaryGreen = Color(red: 0.18, green: 0.31, blue: 0.18) // Army green
    static let secondaryGreen = Color(red: 0.18, green: 0.31, blue: 0.18).opacity(0.6)
    static let accentOrange = Color.orange
    static let accentBlue = Color.blue
    static let accentRed = Color.red
    static let accentPurple = Color.purple
    static let accentTeal = Color.teal
    
    /// Returns appropriate color for metric type
    static func color(for metric: String) -> Color {
        switch metric.lowercased() {
        case "distance", "route": return primaryGreen
        case "pace", "speed": return accentBlue
        case "calories", "energy": return accentRed
        case "load", "weight": return accentOrange
        case "elevation", "altitude": return accentPurple
        case "heart rate", "hr": return accentRed
        default: return primaryGreen
        }
    }
}

// MARK: - Chart Performance Optimizations

/// Performance utilities for large dataset handling
struct ChartPerformanceUtils {
    
    /// Sample data points for efficient rendering of large datasets
    static func sampleData<T>(_ data: [T], maxPoints: Int = 100) -> [T] {
        guard data.count > maxPoints else { return data }
        
        let step = Double(data.count) / Double(maxPoints)
        var sampledData: [T] = []
        
        for i in 0..<maxPoints {
            let index = Int(Double(i) * step)
            if index < data.count {
                sampledData.append(data[index])
            }
        }
        
        return sampledData
    }
    
    /// Aggregate data points by time interval for better performance
    static func aggregateByTimeInterval<T>(
        _ data: [T],
        interval: TimeInterval,
        dateKeyPath: KeyPath<T, Date>,
        valueKeyPath: KeyPath<T, Double>
    ) -> [(date: Date, value: Double)] {
        
        let grouped = Dictionary(grouping: data) { item in
            let date = item[keyPath: dateKeyPath]
            return Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / interval) * interval)
        }
        
        return grouped.map { (date, items) in
            let averageValue = items.reduce(0.0) { $0 + $1[keyPath: valueKeyPath] } / Double(items.count)
            return (date: date, value: averageValue)
        }.sorted { $0.date < $1.date }
    }
}

// MARK: - Chart Accessibility

/// Accessibility utilities for inclusive chart design
struct ChartAccessibilityUtils {
    
    /// Generate accessibility description for chart data
    static func generateDescription(for chartType: String, dataPoints: Int, trend: String?) -> String {
        var description = "\(chartType) chart with \(dataPoints) data points"
        
        if let trend = trend {
            description += ". \(trend)"
        }
        
        return description
    }
    
    /// Create audio graph data for VoiceOver
    static func createAudioGraphData(from values: [Double]) -> [Double] {
        // Normalize values to 0-1 range for audio graph
        guard !values.isEmpty else { return [] }
        
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = maxValue - minValue
        
        if range == 0 { return Array(repeating: 0.5, count: values.count) }
        
        return values.map { ($0 - minValue) / range }
    }
}

// MARK: - Chart Animation Utilities

/// Animation utilities for smooth chart transitions
struct ChartAnimationUtils {
    
    /// Standard animation for chart data updates
    static let dataUpdate = Animation.easeInOut(duration: 0.3)
    
    /// Animation for chart selection changes
    static let selection = Animation.easeInOut(duration: 0.2)
    
    /// Animation for chart view mode changes
    static let viewModeChange = Animation.easeInOut(duration: 0.4)
    
    /// Create staggered animation for multiple chart elements
    static func staggeredAnimation(index: Int, total: Int, baseDuration: Double = 0.3) -> Animation {
        let delay = Double(index) / Double(total) * baseDuration
        return Animation.easeInOut(duration: baseDuration).delay(delay)
    }
}

// MARK: - Chart Data Models

/// Common data structures used across multiple chart components
extension RuckMapChartsLibrary {
    
    /// Generic data point for time-series charts
    struct TimeSeriesDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let category: String?
        
        init(date: Date, value: Double, category: String? = nil) {
            self.date = date
            self.value = value
            self.category = category
        }
    }
    
    /// Data point for comparison charts
    struct ComparisonDataPoint: Identifiable {
        let id = UUID()
        let label: String
        let currentValue: Double
        let previousValue: Double
        let unit: String
        
        var percentageChange: Double {
            guard previousValue > 0 else { return currentValue > 0 ? 100 : 0 }
            return ((currentValue - previousValue) / previousValue) * 100
        }
        
        var isImprovement: Bool {
            return currentValue > previousValue
        }
    }
    
    /// Data point for heatmap-style charts
    struct HeatmapDataPoint: Identifiable {
        let id = UUID()
        let x: Double
        let y: Double
        let intensity: Double
        let label: String?
        
        init(x: Double, y: Double, intensity: Double, label: String? = nil) {
            self.x = x
            self.y = y
            self.intensity = intensity
            self.label = label
        }
    }
}

// MARK: - Chart Formatting Utilities

/// Formatting utilities specific to chart display
struct ChartFormattingUtils {
    
    /// Format axis labels for different metric types
    static func formatAxisLabel(_ value: Double, metricType: String, compact: Bool = true) -> String {
        switch metricType.lowercased() {
        case "distance":
            let km = value / 1000.0
            return compact ? String(format: "%.0fkm", km) : String(format: "%.1f km", km)
            
        case "pace":
            let minutes = Int(value)
            let seconds = Int((value - Double(minutes)) * 60)
            return String(format: "%d:%02d", minutes, seconds) + (compact ? "" : "/km")
            
        case "calories":
            return compact ? String(format: "%.0f", value) : String(format: "%.0f cal", value)
            
        case "weight":
            return compact ? String(format: "%.0fkg", value) : String(format: "%.1f kg", value)
            
        case "elevation":
            return compact ? String(format: "%.0fm", value) : String(format: "%.0f m", value)
            
        default:
            return String(format: compact ? "%.0f" : "%.1f", value)
        }
    }
    
    /// Generate chart title with context
    static func generateChartTitle(
        for metricType: String,
        timePeriod: String,
        includeCount: Int? = nil
    ) -> String {
        var title = metricType.capitalized
        
        if let count = includeCount {
            title += " (\(count) data points)"
        }
        
        title += " - \(timePeriod)"
        return title
    }
}

// MARK: - Chart Gesture Handlers

/// Common gesture handling for chart interactions
struct ChartGestureHandlers {
    
    /// Generic tap handler for chart selection
    static func handleTapGesture<T: Identifiable>(
        at location: CGPoint,
        in geometry: GeometryProxy,
        with chartProxy: ChartProxy,
        data: [T],
        dateKeyPath: KeyPath<T, Date>,
        onSelection: @escaping (T?) -> Void
    ) {
        guard let plotFrame = chartProxy.plotAreaFrame else { return }
        
        let origin = geometry[plotFrame].origin
        let relativeXPosition = location.x - origin.x
        
        if let date = chartProxy.value(atX: relativeXPosition, as: Date.self) {
            let selectedItem = data.min(by: { item1, item2 in
                abs(item1[keyPath: dateKeyPath].timeIntervalSince(date)) <
                abs(item2[keyPath: dateKeyPath].timeIntervalSince(date))
            })
            onSelection(selectedItem)
        }
    }
    
    /// Generic drag handler for chart range selection
    static func handleDragGesture(
        startLocation: CGPoint,
        currentLocation: CGPoint,
        in geometry: GeometryProxy,
        with chartProxy: ChartProxy,
        onRangeSelection: @escaping (Date, Date) -> Void
    ) {
        guard let plotFrame = chartProxy.plotAreaFrame else { return }
        
        let origin = geometry[plotFrame].origin
        let startX = startLocation.x - origin.x
        let currentX = currentLocation.x - origin.x
        
        if let startDate = chartProxy.value(atX: min(startX, currentX), as: Date.self),
           let endDate = chartProxy.value(atX: max(startX, currentX), as: Date.self) {
            onRangeSelection(startDate, endDate)
        }
    }
}

// MARK: - Main Library Struct

/// Main RuckMap Charts Library container
struct RuckMapChartsLibrary {
    
    /// Library version
    static let version = "1.0.0"
    
    /// Supported iOS version
    static let minimumIOSVersion = "18.0"
    
    /// Chart components available in this library
    static let availableComponents = [
        "WeeklyOverviewChart",
        "PaceTrendChart", 
        "WeightMovedChart",
        "PersonalRecordsChart",
        "PersonalRecordsProgressChart",
        "TrainingStreakChart",
        "PeriodComparisonChart",
        "WeeklyComparisonChart"
    ]
    
    /// Performance recommendations for chart usage
    static let performanceRecommendations = [
        "Use data sampling for datasets > 1000 points",
        "Implement lazy loading for scrollable chart lists",
        "Cache computed chart data to avoid recalculation",
        "Use appropriate animation durations (0.2-0.4s)",
        "Test performance on older devices (iPhone 12 and below)"
    ]
    
    /// Accessibility features implemented
    static let accessibilityFeatures = [
        "VoiceOver support with descriptive labels",
        "Audio Graphs for data sonification", 
        "High contrast mode support",
        "Dynamic Type support for chart labels",
        "Reduced motion respect for animations"
    ]
}