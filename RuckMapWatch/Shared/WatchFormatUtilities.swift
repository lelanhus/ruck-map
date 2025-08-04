import Foundation

/// Formatting utilities optimized for Apple Watch displays
struct WatchFormatUtilities {
    
    // MARK: - Distance Formatting
    
    /// Format distance with appropriate units for Watch display
    static func formatDistance(_ distance: Double, style: DistanceStyle = .auto) -> String {
        switch style {
        case .auto:
            if distance < 1000 {
                return "\(Int(distance))m"
            } else {
                return String(format: "%.2fkm", distance / 1000)
            }
        case .meters:
            return "\(Int(distance))m"
        case .kilometers:
            return String(format: "%.2fkm", distance / 1000)
        case .precise:
            if distance < 100 {
                return String(format: "%.1fm", distance)
            } else if distance < 1000 {
                return "\(Int(distance))m"
            } else {
                return String(format: "%.2fkm", distance / 1000)
            }
        }
    }
    
    // MARK: - Pace Formatting
    
    /// Format pace for Watch display (mm:ss format)
    static func formatPace(_ pace: Double, unit: PaceUnit = .perKilometer) -> String {
        guard pace > 0 && pace.isFinite else { return "--:--" }
        
        let adjustedPace = unit == .perMile ? pace * 1.60934 : pace
        let minutes = Int(adjustedPace)
        let seconds = Int((adjustedPace - Double(minutes)) * 60)
        
        let unitSuffix = unit == .perMile ? "/mi" : "/km"
        return String(format: "%d:%02d%@", minutes, seconds, unitSuffix)
    }
    
    /// Format current speed as pace
    static func formatCurrentPace(from speed: Double, unit: PaceUnit = .perKilometer) -> String {
        guard speed > 0 else { return "--:--" }
        
        let metersPerMinute = speed * 60 // m/s to m/min
        let paceMinutesPerKm = 1000.0 / metersPerMinute
        
        return formatPace(paceMinutesPerKm, unit: unit)
    }
    
    // MARK: - Duration Formatting
    
    /// Format duration for Watch display
    static func formatDuration(_ duration: TimeInterval, style: DurationStyle = .compact) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        switch style {
        case .compact:
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%d:%02d", minutes, seconds)
            }
        case .verbose:
            if hours > 0 {
                return String(format: "%dh %dm %ds", hours, minutes, seconds)
            } else if minutes > 0 {
                return String(format: "%dm %ds", minutes, seconds)
            } else {
                return String(format: "%ds", seconds)
            }
        case .hoursMinutes:
            if hours > 0 {
                return String(format: "%d:%02d", hours, minutes)
            } else {
                return String(format: "%dm", minutes)
            }
        }
    }
    
    // MARK: - Elevation Formatting
    
    /// Format elevation for Watch display
    static func formatElevation(_ elevation: Double, showSign: Bool = false) -> String {
        let roundedElevation = Int(elevation.rounded())
        
        if showSign && elevation >= 0 {
            return "+\(roundedElevation)m"
        } else {
            return "\(roundedElevation)m"
        }
    }
    
    /// Format elevation gain/loss
    static func formatElevationChange(_ change: Double) -> String {
        let absChange = abs(change)
        let sign = change >= 0 ? "+" : "-"
        return "\(sign)\(Int(absChange))m"
    }
    
    // MARK: - Grade Formatting
    
    /// Format grade percentage for Watch display
    static func formatGrade(_ grade: Double) -> String {
        if abs(grade) < 0.1 {
            return "0.0%"
        } else {
            return String(format: "%.1f%%", grade)
        }
    }
    
    // MARK: - Calorie Formatting
    
    /// Format calories for Watch display
    static func formatCalories(_ calories: Double, style: CalorieStyle = .whole) -> String {
        switch style {
        case .whole:
            return "\(Int(calories.rounded()))"
        case .precise:
            if calories < 10 {
                return String(format: "%.1f", calories)
            } else {
                return "\(Int(calories.rounded()))"
            }
        case .withUnit:
            return "\(Int(calories.rounded())) cal"
        }
    }
    
    /// Format calorie burn rate
    static func formatCalorieBurnRate(_ rate: Double) -> String {
        return String(format: "%.1f cal/min", rate)
    }
    
    // MARK: - Heart Rate Formatting
    
    /// Format heart rate for Watch display
    static func formatHeartRate(_ heartRate: Double) -> String {
        return "\(Int(heartRate.rounded())) BPM"
    }
    
    // MARK: - Weight Formatting
    
    /// Format weight for Watch display
    static func formatWeight(_ weight: Double, unit: WeightUnit = .kilograms) -> String {
        switch unit {
        case .kilograms:
            if weight < 1 {
                return String(format: "%.0fg", weight * 1000)
            } else {
                return String(format: "%.1fkg", weight)
            }
        case .pounds:
            let pounds = weight * 2.20462
            return String(format: "%.1flb", pounds)
        }
    }
    
    // MARK: - Date/Time Formatting
    
    /// Format date for Watch display
    static func formatDate(_ date: Date, style: DateStyle = .short) -> String {
        let formatter = DateFormatter()
        
        switch style {
        case .short:
            formatter.dateStyle = .short
        case .medium:
            formatter.dateStyle = .medium
        case .timeOnly:
            formatter.timeStyle = .short
            formatter.dateStyle = .none
        case .relative:
            return formatRelativeDate(date)
        }
        
        return formatter.string(from: date)
    }
    
    /// Format relative date (e.g., "2 hours ago")
    private static func formatRelativeDate(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    // MARK: - Numeric Formatting
    
    /// Format large numbers with appropriate abbreviations
    static func formatLargeNumber(_ number: Double) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", number / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", number / 1_000)
        } else {
            return String(format: "%.0f", number)
        }
    }
}

// MARK: - Supporting Enums

enum DistanceStyle {
    case auto
    case meters
    case kilometers
    case precise
}

enum PaceUnit {
    case perKilometer
    case perMile
}

enum DurationStyle {
    case compact
    case verbose
    case hoursMinutes
}

enum CalorieStyle {
    case whole
    case precise
    case withUnit
}

enum WeightUnit {
    case kilograms
    case pounds
}

enum DateStyle {
    case short
    case medium
    case timeOnly
    case relative
}