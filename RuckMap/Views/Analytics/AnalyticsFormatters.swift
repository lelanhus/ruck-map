import Foundation

/// Formatters and utilities for analytics data display
struct AnalyticsFormatters {
  
  // MARK: - Distance Formatters
  
  /// Formats distance with appropriate units and precision
  static func formatDistance(_ distance: Double, unit: DistanceUnit = .automatic) -> String {
    switch unit {
    case .automatic:
      let km = distance / 1000.0
      if km >= 1.0 {
        return String(format: "%.2f km", km)
      } else {
        return String(format: "%.0f m", distance)
      }
      
    case .kilometers:
      return String(format: "%.2f km", distance / 1000.0)
      
    case .meters:
      return String(format: "%.0f m", distance)
      
    case .miles:
      let miles = distance * 0.000621371
      return String(format: "%.2f mi", miles)
    }
  }
  
  /// Formats distance for compact display (shorter format)
  static func formatDistanceCompact(_ distance: Double) -> String {
    let km = distance / 1000.0
    if km >= 10.0 {
      return String(format: "%.0f km", km)
    } else if km >= 1.0 {
      return String(format: "%.1f km", km)
    } else {
      return String(format: "%.0f m", distance)
    }
  }
  
  // MARK: - Pace Formatters
  
  /// Formats pace in minutes:seconds per kilometer
  static func formatPace(_ pace: Double) -> String {
    guard pace > 0 && pace.isFinite else { return "N/A" }
    
    let minutes = Int(pace)
    let seconds = Int((pace - Double(minutes)) * 60)
    return String(format: "%d:%02d/km", minutes, seconds)
  }
  
  /// Formats pace for imperial units (minutes:seconds per mile)
  static func formatPaceImperial(_ pace: Double) -> String {
    guard pace > 0 && pace.isFinite else { return "N/A" }
    
    let pacePerMile = pace * 1.609344 // Convert km pace to mile pace
    let minutes = Int(pacePerMile)
    let seconds = Int((pacePerMile - Double(minutes)) * 60)
    return String(format: "%d:%02d/mi", minutes, seconds)
  }
  
  /// Formats pace with trend indicator
  static func formatPaceWithTrend(_ pace: Double, trend: TrendDirection?) -> String {
    let paceString = formatPace(pace)
    
    guard let trend = trend else { return paceString }
    
    let trendSymbol: String
    switch trend {
    case .improving:
      trendSymbol = " ↗" // Faster pace (lower number) is improving
    case .declining:
      trendSymbol = " ↘" // Slower pace (higher number) is declining
    case .stable:
      trendSymbol = " →"
    }
    
    return paceString + trendSymbol
  }
  
  // MARK: - Duration Formatters
  
  /// Formats duration in human-readable format
  static func formatDuration(_ duration: TimeInterval) -> String {
    guard duration > 0 && duration.isFinite else { return "0m" }
    
    let hours = Int(duration) / 3600
    let minutes = Int(duration) % 3600 / 60
    let seconds = Int(duration) % 60
    
    if hours > 0 {
      if minutes > 0 {
        return String(format: "%dh %dm", hours, minutes)
      } else {
        return String(format: "%dh", hours)
      }
    } else if minutes > 0 {
      if seconds > 0 && duration < 600 { // Show seconds only for durations < 10 minutes
        return String(format: "%dm %ds", minutes, seconds)
      } else {
        return String(format: "%dm", minutes)
      }
    } else {
      return String(format: "%ds", seconds)
    }
  }
  
  /// Formats duration in compact format for charts
  static func formatDurationCompact(_ duration: TimeInterval) -> String {
    guard duration > 0 && duration.isFinite else { return "0m" }
    
    let hours = Int(duration) / 3600
    let minutes = Int(duration) % 3600 / 60
    
    if hours > 0 {
      return String(format: "%dh", hours)
    } else {
      return String(format: "%dm", minutes)
    }
  }
  
  // MARK: - Calorie Formatters
  
  /// Formats calories with appropriate precision
  static func formatCalories(_ calories: Double) -> String {
    guard calories >= 0 && calories.isFinite else { return "0 cal" }
    
    if calories >= 1000 {
      return String(format: "%.1fk cal", calories / 1000.0)
    } else {
      return String(format: "%.0f cal", calories)
    }
  }
  
  /// Formats calorie burn rate (calories per minute)
  static func formatCalorieBurnRate(_ caloriesPerMinute: Double) -> String {
    guard caloriesPerMinute > 0 && caloriesPerMinute.isFinite else { return "0 cal/min" }
    
    return String(format: "%.1f cal/min", caloriesPerMinute)
  }
  
  // MARK: - Weight Formatters
  
  /// Formats weight with appropriate unit
  static func formatWeight(_ weight: Double, unit: WeightUnit = .kilograms) -> String {
    guard weight >= 0 && weight.isFinite else { return "0 kg" }
    
    switch unit {
    case .kilograms:
      return String(format: "%.1f kg", weight)
    case .pounds:
      let pounds = weight * 2.20462
      return String(format: "%.1f lbs", pounds)
    }
  }
  
  /// Formats weight moved (load × distance)
  static func formatWeightMoved(_ weightMoved: Double) -> String {
    guard weightMoved >= 0 && weightMoved.isFinite else { return "0 kg×km" }
    
    if weightMoved >= 1000 {
      return String(format: "%.1fk kg×km", weightMoved / 1000.0)
    } else {
      return String(format: "%.1f kg×km", weightMoved)
    }
  }
  
  // MARK: - Percentage and Trend Formatters
  
  /// Formats percentage change with appropriate sign and color context
  static func formatPercentageChange(_ percentage: Double, metricType: MetricType = .distance) -> String {
    guard percentage.isFinite else { return "0%" }
    
    let absPercentage = abs(percentage)
    let sign = percentage >= 0 ? "+" : "-"
    
    return String(format: "%@%.1f%%", sign, absPercentage)
  }
  
  /// Formats trend with descriptive text
  static func formatTrendDescription(_ trend: TrendData, metricType: MetricType) -> String {
    let changeText = formatPercentageChange(trend.percentageChange, metricType: metricType)
    
    switch trend.direction {
    case .improving:
      switch metricType {
      case .pace:
        return "Pace improved by \(changeText)"
      case .distance:
        return "Distance increased by \(changeText)"
      case .calories:
        return "Calories increased by \(changeText)"
      case .sessionCount:
        return "Sessions increased by \(changeText)"
      case .weightMoved:
        return "Weight moved increased by \(changeText)"
      }
      
    case .declining:
      switch metricType {
      case .pace:
        return "Pace slowed by \(changeText)"
      case .distance:
        return "Distance decreased by \(changeText)"
      case .calories:
        return "Calories decreased by \(changeText)"
      case .sessionCount:
        return "Sessions decreased by \(changeText)"
      case .weightMoved:
        return "Weight moved decreased by \(changeText)"
      }
      
    case .stable:
      return "No significant change"
    }
  }
  
  // MARK: - Personal Records Formatters
  
  /// Formats a personal record with context
  static func formatPersonalRecord<T: Comparable & Sendable>(
    _ record: PersonalRecord<T>,
    metricType: PersonalRecordType
  ) -> String {
    
    switch metricType {
    case .distance:
      if let distance = record.value as? Double {
        return formatDistance(distance)
      }
      
    case .pace:
      if let pace = record.value as? Double {
        return formatPace(pace)
      }
      
    case .weight:
      if let weight = record.value as? Double {
        return formatWeight(weight)
      }
      
    case .calories:
      if let calories = record.value as? Double {
        return formatCalories(calories)
      }
      
    case .duration:
      if let duration = record.value as? TimeInterval {
        return formatDuration(duration)
      }
      
    case .weightMoved:
      if let weightMoved = record.value as? Double {
        return formatWeightMoved(weightMoved)
      }
    }
    
    return "N/A"
  }
  
  /// Formats personal record date
  static func formatPersonalRecordDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }
  
  // MARK: - Chart Data Formatters
  
  /// Formats values for chart axes
  static func formatChartAxisValue(_ value: Double, metricType: ChartMetricType) -> String {
    switch metricType {
    case .distance:
      return formatDistanceCompact(value * 1000) // Assuming chart values are in km
    case .sessions:
      return String(format: "%.0f", value)
    case .calories:
      return formatCalories(value)
    case .pace:
      return formatPace(value)
    case .duration:
      return formatDurationCompact(value)
    }
  }
  
  // MARK: - Training Streak Formatters
  
  /// Formats training streak with context
  static func formatTrainingStreak(_ streak: Int) -> String {
    switch streak {
    case 0:
      return "No current streak"
    case 1:
      return "1 week streak"
    default:
      return "\(streak) week streak"
    }
  }
  
  /// Formats sessions per week average
  static func formatSessionsPerWeek(_ sessionsPerWeek: Double) -> String {
    return String(format: "%.1f sessions/week", sessionsPerWeek)
  }
  
  // MARK: - Date Range Formatters
  
  /// Formats date range for analytics periods
  static func formatDateRange(for timePeriod: AnalyticsTimePeriod) -> String {
    let dateRange = timePeriod.dateRange()
    let formatter = DateFormatter()
    
    switch timePeriod {
    case .weekly, .lastWeek:
      formatter.dateFormat = "MMM d"
      let start = formatter.string(from: dateRange.start)
      let end = formatter.string(from: dateRange.end)
      return "\(start) - \(end)"
      
    case .monthly, .lastMonth:
      formatter.dateFormat = "MMMM yyyy"
      return formatter.string(from: dateRange.start)
      
    case .last3Months, .last6Months:
      formatter.dateFormat = "MMM yyyy"
      let start = formatter.string(from: dateRange.start)
      let end = formatter.string(from: dateRange.end)
      return "\(start) - \(end)"
      
    case .lastYear:
      formatter.dateFormat = "yyyy"
      return formatter.string(from: dateRange.start)
      
    case .allTime:
      return "All Time"
    }
  }
}

// MARK: - Supporting Enums

enum DistanceUnit {
  case automatic
  case kilometers
  case meters
  case miles
}

enum WeightUnit {
  case kilograms
  case pounds
}

enum PersonalRecordType {
  case distance
  case pace
  case weight
  case calories
  case duration
  case weightMoved
}

enum ChartMetricType {
  case distance
  case sessions
  case calories
  case pace
  case duration
}

// MARK: - Number Formatters Extension

extension AnalyticsFormatters {
  
  /// Shared number formatter for consistent decimal places
  private static let numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 0
    return formatter
  }()
  
  /// Shared percentage formatter
  private static let percentageFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = 0
    return formatter
  }()
  
  /// Formats a double with consistent decimal places
  static func formatNumber(_ number: Double, decimalPlaces: Int = 1) -> String {
    numberFormatter.maximumFractionDigits = decimalPlaces
    numberFormatter.minimumFractionDigits = min(decimalPlaces, 0)
    return numberFormatter.string(from: NSNumber(value: number)) ?? "0"
  }
  
  /// Formats a percentage value
  static func formatPercentage(_ value: Double) -> String {
    let percentage = value / 100.0 // Convert from percentage to decimal
    return percentageFormatter.string(from: NSNumber(value: percentage)) ?? "0%"
  }
}

// MARK: - Validation Helpers

extension AnalyticsFormatters {
  
  /// Validates if a value is suitable for display
  static func isValidForDisplay<T: FloatingPoint>(_ value: T) -> Bool {
    return value.isFinite && !value.isNaN && value >= 0
  }
  
  /// Returns a safe display value, defaulting to 0 if invalid
  static func safeDisplayValue<T: FloatingPoint>(_ value: T) -> T {
    return isValidForDisplay(value) ? value : 0
  }
  
  /// Safely formats a potentially invalid floating point value
  static func safeFormatDistance(_ distance: Double) -> String {
    return formatDistance(safeDisplayValue(distance))
  }
  
  /// Safely formats a potentially invalid pace value
  static func safeFormatPace(_ pace: Double) -> String {
    return formatPace(safeDisplayValue(pace))
  }
  
  /// Safely formats a potentially invalid calorie value  
  static func safeFormatCalories(_ calories: Double) -> String {
    return formatCalories(safeDisplayValue(calories))
  }
}