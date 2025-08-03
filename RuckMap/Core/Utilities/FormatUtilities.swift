import Foundation

/// Utility functions for consistent formatting across the app
enum FormatUtilities {
    
    // MARK: - Constants
    
    /// Conversion constants to avoid magic numbers
    enum ConversionConstants {
        /// Pounds to kilograms conversion factor
        static let poundsToKilograms = 0.453592
        
        /// Kilograms to pounds conversion factor
        static let kilogramsToPounds = 2.20462
        
        /// Meters to miles conversion factor
        static let metersToMiles = 1609.34
        
        /// Meters to kilometers conversion factor
        static let metersToKilometers = 1000.0
    }
    
    // MARK: - Distance Formatting
    
    /// Formats distance based on user's preferred units
    /// - Parameters:
    ///   - meters: Distance in meters
    ///   - units: Preferred units ("imperial" or "metric")
    /// - Returns: Formatted distance string
    static func formatDistance(_ meters: Double, units: String = "imperial") -> String {
        if units == "imperial" {
            let miles = meters / ConversionConstants.metersToMiles
            return String(format: "%.1f mi", miles)
        } else {
            let kilometers = meters / ConversionConstants.metersToKilometers
            return String(format: "%.1f km", kilometers)
        }
    }
    
    /// Formats distance with higher precision
    /// - Parameters:
    ///   - meters: Distance in meters
    ///   - units: Preferred units ("imperial" or "metric")
    /// - Returns: Formatted distance string with 2 decimal places
    static func formatDistancePrecise(_ meters: Double, units: String = "imperial") -> String {
        if units == "imperial" {
            let miles = meters / ConversionConstants.metersToMiles
            return String(format: "%.2f mi", miles)
        } else {
            let kilometers = meters / ConversionConstants.metersToKilometers
            return String(format: "%.2f km", kilometers)
        }
    }
    
    // MARK: - Duration Formatting
    
    /// Formats duration for display
    /// - Parameter seconds: Duration in seconds
    /// - Returns: Formatted duration string (e.g., "1:23:45" or "45 min")
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        
        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        } else {
            return String(format: "%d min", minutes)
        }
    }
    
    /// Formats total duration in hours
    /// - Parameter seconds: Duration in seconds
    /// - Returns: Formatted duration string in hours (e.g., "123h")
    static func formatTotalDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        return "\(hours)h"
    }
    
    /// Formats duration with seconds for active tracking
    /// - Parameter seconds: Duration in seconds
    /// - Returns: Formatted duration string (e.g., "1:23:45")
    static func formatDurationWithSeconds(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    // MARK: - Weight Formatting
    
    /// Converts pounds to kilograms
    /// - Parameter pounds: Weight in pounds
    /// - Returns: Weight in kilograms
    static func poundsToKilograms(_ pounds: Double) -> Double {
        pounds * ConversionConstants.poundsToKilograms
    }
    
    /// Converts kilograms to pounds
    /// - Parameter kilograms: Weight in kilograms
    /// - Returns: Weight in pounds
    static func kilogramsToPounds(_ kilograms: Double) -> Double {
        kilograms * ConversionConstants.kilogramsToPounds
    }
    
    /// Formats weight based on user's preferred units
    /// - Parameters:
    ///   - kilograms: Weight in kilograms
    ///   - units: Preferred units ("imperial" or "metric")
    /// - Returns: Formatted weight string
    static func formatWeight(_ kilograms: Double, units: String = "imperial") -> String {
        if units == "imperial" {
            let pounds = kilogramsToPounds(kilograms)
            return String(format: "%.0f lbs", pounds)
        } else {
            return String(format: "%.0f kg", kilograms)
        }
    }
    
    // MARK: - Date Formatting
    
    /// Formats member since date
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string (e.g., "January 2024")
    static func formatMemberSince(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    /// Formats session date
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string in medium style
    static func formatSessionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - Other Formatting
    
    /// Formats calories for display
    /// - Parameter calories: Calorie value
    /// - Returns: Formatted calorie string
    static func formatCalories(_ calories: Double) -> String {
        return "\(Int(calories)) kcal"
    }
    
    /// Formats elevation based on user's preferred units
    /// - Parameters:
    ///   - meters: Elevation in meters
    ///   - units: Preferred units ("imperial" or "metric")
    /// - Returns: Formatted elevation string
    static func formatElevation(_ meters: Double, units: String = "imperial") -> String {
        if units == "imperial" {
            let feet = meters * 3.28084
            return "\(Int(feet)) ft"
        }
        return "\(Int(meters)) m"
    }
    
    /// Formats pace in minutes per mile/km
    /// - Parameter pace: Pace in minutes per mile/km
    /// - Returns: Formatted pace string (e.g., "9:30")
    static func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}