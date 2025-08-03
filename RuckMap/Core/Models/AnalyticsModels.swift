import Foundation
import SwiftData

// MARK: - Time Period Definitions

/// Time periods for analytics calculations
enum AnalyticsTimePeriod: String, CaseIterable, Sendable {
  case weekly = "weekly"
  case monthly = "monthly" 
  case allTime = "all_time"
  case lastWeek = "last_week"
  case lastMonth = "last_month"
  case last3Months = "last_3_months"
  case last6Months = "last_6_months"
  case lastYear = "last_year"
  
  var displayName: String {
    switch self {
    case .weekly:
      return "This Week"
    case .monthly:
      return "This Month"
    case .allTime:
      return "All Time"
    case .lastWeek:
      return "Last Week"
    case .lastMonth:
      return "Last Month"
    case .last3Months:
      return "Last 3 Months"
    case .last6Months:
      return "Last 6 Months"
    case .lastYear:
      return "Last Year"
    }
  }
  
  var systemImage: String {
    switch self {
    case .weekly, .lastWeek:
      return "calendar.day.timeline.left"
    case .monthly, .lastMonth:
      return "calendar"
    case .allTime:
      return "infinity"
    case .last3Months, .last6Months:
      return "calendar.badge.clock"
    case .lastYear:
      return "calendar.circle"
    }
  }
  
  /// Returns the date range for this time period
  func dateRange(relativeTo referenceDate: Date = Date()) -> (start: Date, end: Date) {
    let calendar = Calendar.current
    
    switch self {
    case .weekly:
      let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate
      return (startOfWeek, referenceDate)
      
    case .monthly:
      let startOfMonth = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
      return (startOfMonth, referenceDate)
      
    case .allTime:
      return (Date.distantPast, referenceDate)
      
    case .lastWeek:
      let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate
      let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? Date.distantPast
      return (lastWeekStart, thisWeekStart)
      
    case .lastMonth:
      let thisMonthStart = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
      let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? Date.distantPast
      return (lastMonthStart, thisMonthStart)
      
    case .last3Months:
      let startDate = calendar.date(byAdding: .month, value: -3, to: referenceDate) ?? Date.distantPast
      return (startDate, referenceDate)
      
    case .last6Months:
      let startDate = calendar.date(byAdding: .month, value: -6, to: referenceDate) ?? Date.distantPast
      return (startDate, referenceDate)
      
    case .lastYear:
      let startDate = calendar.date(byAdding: .year, value: -1, to: referenceDate) ?? Date.distantPast
      return (startDate, referenceDate)
    }
  }
}

// MARK: - Analytics Data Models

/// Comprehensive analytics data for a specific time period
struct AnalyticsData: Sendable {
  let timePeriod: AnalyticsTimePeriod
  let dateRange: (start: Date, end: Date)
  let sessions: [RuckSession]
  
  // Basic metrics
  let totalSessions: Int
  let totalDistance: Double // meters
  let totalDuration: TimeInterval // seconds
  let totalCalories: Double
  let totalWeightMoved: Double // kg × km
  
  // Averages
  let averageDistance: Double // meters
  let averageDuration: TimeInterval // seconds
  let averagePace: Double // min/km
  let averageCalories: Double
  let averageLoadWeight: Double // kg
  
  // Personal records
  let longestDistance: Double // meters
  let fastestPace: Double // min/km (lowest value)
  let heaviestLoad: Double // kg
  let highestCalorieBurn: Double
  let longestDuration: TimeInterval // seconds
  
  // Training consistency
  let trainingStreak: Int // consecutive weeks with 2+ rucks
  let averageSessionsPerWeek: Double
  let totalActiveWeeks: Int
  
  // Trend data (vs previous period)
  let distanceTrend: TrendData?
  let paceTrend: TrendData?
  let calorieTrend: TrendData?
  let sessionCountTrend: TrendData?
  
  init(sessions: [RuckSession], timePeriod: AnalyticsTimePeriod, previousPeriodSessions: [RuckSession]? = nil) {
    self.timePeriod = timePeriod
    self.dateRange = timePeriod.dateRange()
    self.sessions = sessions
    
    // Calculate basic metrics
    self.totalSessions = sessions.count
    self.totalDistance = sessions.reduce(0) { $0 + $1.totalDistance }
    self.totalDuration = sessions.reduce(0) { $0 + $1.totalDuration }
    self.totalCalories = sessions.reduce(0) { $0 + $1.totalCalories }
    
    // Calculate weight moved (load × distance)
    self.totalWeightMoved = sessions.reduce(0) { sum, session in
      let distanceKm = session.totalDistance / 1000.0
      return sum + (session.loadWeight * distanceKm)
    }
    
    // Calculate averages
    if totalSessions > 0 {
      self.averageDistance = totalDistance / Double(totalSessions)
      self.averageDuration = totalDuration / Double(totalSessions)
      self.averageCalories = totalCalories / Double(totalSessions)
      self.averageLoadWeight = sessions.reduce(0) { $0 + $1.loadWeight } / Double(totalSessions)
      
      // Calculate average pace (weighted by distance)
      let totalPaceDistance = sessions.reduce(0.0) { sum, session in
        return sum + (session.averagePace * session.totalDistance)
      }
      self.averagePace = totalDistance > 0 ? totalPaceDistance / totalDistance : 0
    } else {
      self.averageDistance = 0
      self.averageDuration = 0
      self.averageCalories = 0
      self.averageLoadWeight = 0
      self.averagePace = 0
    }
    
    // Calculate personal records
    self.longestDistance = sessions.map(\.totalDistance).max() ?? 0
    self.fastestPace = sessions.compactMap { $0.averagePace > 0 ? $0.averagePace : nil }.min() ?? 0
    self.heaviestLoad = sessions.map(\.loadWeight).max() ?? 0
    self.highestCalorieBurn = sessions.map(\.totalCalories).max() ?? 0
    self.longestDuration = sessions.map(\.totalDuration).max() ?? 0
    
    // Calculate training consistency
    let (streak, weeksWithRucks, activeWeeks) = Self.calculateTrainingConsistency(sessions: sessions)
    self.trainingStreak = streak
    self.totalActiveWeeks = activeWeeks
    self.averageSessionsPerWeek = activeWeeks > 0 ? Double(totalSessions) / Double(activeWeeks) : 0
    
    // Calculate trends
    if let previousSessions = previousPeriodSessions {
      let previousData = AnalyticsData(sessions: previousSessions, timePeriod: timePeriod)
      
      self.distanceTrend = TrendData(
        current: totalDistance,
        previous: previousData.totalDistance,
        metricType: .distance
      )
      
      self.paceTrend = TrendData(
        current: averagePace,
        previous: previousData.averagePace,
        metricType: .pace
      )
      
      self.calorieTrend = TrendData(
        current: totalCalories,
        previous: previousData.totalCalories,
        metricType: .calories
      )
      
      self.sessionCountTrend = TrendData(
        current: Double(totalSessions),
        previous: Double(previousData.totalSessions),
        metricType: .sessionCount
      )
    } else {
      self.distanceTrend = nil
      self.paceTrend = nil
      self.calorieTrend = nil
      self.sessionCountTrend = nil
    }
  }
  
  /// Calculates training streak and consistency metrics
  private static func calculateTrainingConsistency(sessions: [RuckSession]) -> (streak: Int, weeksWithRucks: Int, activeWeeks: Int) {
    guard !sessions.isEmpty else { return (0, 0, 0) }
    
    let calendar = Calendar.current
    let sortedSessions = sessions.sorted { $0.startDate < $1.startDate }
    
    // Group sessions by week
    var weeklySessionCounts: [Date: Int] = [:]
    
    for session in sortedSessions {
      let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.startDate)?.start ?? session.startDate
      weeklySessionCounts[weekStart, default: 0] += 1
    }
    
    // Count weeks with 2+ rucks
    let weeksWithMinimumRucks = weeklySessionCounts.values.filter { $0 >= 2 }.count
    
    // Calculate current streak (consecutive weeks with 2+ rucks from most recent)
    let allWeeks = weeklySessionCounts.keys.sorted(by: >)
    var currentStreak = 0
    
    for week in allWeeks {
      if weeklySessionCounts[week, default: 0] >= 2 {
        currentStreak += 1
      } else {
        break
      }
    }
    
    return (currentStreak, weeksWithMinimumRucks, weeklySessionCounts.count)
  }
}

/// Trend data for comparing metrics between periods
struct TrendData: Sendable {
  let current: Double
  let previous: Double
  let percentageChange: Double
  let direction: TrendDirection
  let metricType: MetricType
  
  init(current: Double, previous: Double, metricType: MetricType) {
    self.current = current
    self.previous = previous
    self.metricType = metricType
    
    if previous > 0 {
      self.percentageChange = ((current - previous) / previous) * 100
    } else if current > 0 {
      self.percentageChange = 100 // Show as 100% increase if going from 0 to any value
    } else {
      self.percentageChange = 0
    }
    
    // For pace, lower is better (faster pace)
    if metricType == .pace {
      if current < previous {
        self.direction = .improving
      } else if current > previous {
        self.direction = .declining
      } else {
        self.direction = .stable
      }
    } else {
      // For other metrics, higher is generally better
      if current > previous {
        self.direction = .improving
      } else if current < previous {
        self.direction = .declining
      } else {
        self.direction = .stable
      }
    }
  }
  
  var formattedPercentageChange: String {
    let absValue = abs(percentageChange)
    return String(format: "%.1f%%", absValue)
  }
}

enum TrendDirection: Sendable {
  case improving
  case declining
  case stable
  
  var systemImage: String {
    switch self {
    case .improving:
      return "arrow.up"
    case .declining:
      return "arrow.down"
    case .stable:
      return "minus"
    }
  }
  
  var color: String {
    switch self {
    case .improving:
      return "green"
    case .declining:
      return "red"
    case .stable:
      return "gray"
    }
  }
}

enum MetricType: Sendable {
  case distance
  case pace
  case calories
  case sessionCount
  case weightMoved
}

// MARK: - Personal Records Model

/// Tracks personal records across all sessions
struct PersonalRecords: Sendable {
  let longestDistance: PersonalRecord<Double>?
  let fastestPace: PersonalRecord<Double>?
  let heaviestLoad: PersonalRecord<Double>?
  let highestCalorieBurn: PersonalRecord<Double>?
  let longestDuration: PersonalRecord<TimeInterval>?
  let mostWeightMoved: PersonalRecord<Double>?
  
  init(sessions: [RuckSession]) {
    // Longest distance
    if let maxDistanceSession = sessions.max(by: { $0.totalDistance < $1.totalDistance }),
       maxDistanceSession.totalDistance > 0 {
      self.longestDistance = PersonalRecord(
        value: maxDistanceSession.totalDistance,
        sessionId: maxDistanceSession.id,
        date: maxDistanceSession.startDate
      )
    } else {
      self.longestDistance = nil
    }
    
    // Fastest pace (lowest value is best)
    if let fastestSession = sessions.filter({ $0.averagePace > 0 }).min(by: { $0.averagePace < $1.averagePace }) {
      self.fastestPace = PersonalRecord(
        value: fastestSession.averagePace,
        sessionId: fastestSession.id,
        date: fastestSession.startDate
      )
    } else {
      self.fastestPace = nil
    }
    
    // Heaviest load
    if let heaviestSession = sessions.max(by: { $0.loadWeight < $1.loadWeight }),
       heaviestSession.loadWeight > 0 {
      self.heaviestLoad = PersonalRecord(
        value: heaviestSession.loadWeight,
        sessionId: heaviestSession.id,
        date: heaviestSession.startDate
      )
    } else {
      self.heaviestLoad = nil
    }
    
    // Highest calorie burn
    if let highestCalorieSession = sessions.max(by: { $0.totalCalories < $1.totalCalories }),
       highestCalorieSession.totalCalories > 0 {
      self.highestCalorieBurn = PersonalRecord(
        value: highestCalorieSession.totalCalories,
        sessionId: highestCalorieSession.id,
        date: highestCalorieSession.startDate
      )
    } else {
      self.highestCalorieBurn = nil
    }
    
    // Longest duration
    if let longestSession = sessions.max(by: { $0.totalDuration < $1.totalDuration }),
       longestSession.totalDuration > 0 {
      self.longestDuration = PersonalRecord(
        value: longestSession.totalDuration,
        sessionId: longestSession.id,
        date: longestSession.startDate
      )
    } else {
      self.longestDuration = nil
    }
    
    // Most weight moved
    let sessionWithMostWeightMoved = sessions.max { session1, session2 in
      let weightMoved1 = session1.loadWeight * (session1.totalDistance / 1000.0)
      let weightMoved2 = session2.loadWeight * (session2.totalDistance / 1000.0)
      return weightMoved1 < weightMoved2
    }
    
    if let bestSession = sessionWithMostWeightMoved {
      let weightMoved = bestSession.loadWeight * (bestSession.totalDistance / 1000.0)
      if weightMoved > 0 {
        self.mostWeightMoved = PersonalRecord(
          value: weightMoved,
          sessionId: bestSession.id,
          date: bestSession.startDate
        )
      } else {
        self.mostWeightMoved = nil
      }
    } else {
      self.mostWeightMoved = nil
    }
  }
}

/// Individual personal record
struct PersonalRecord<T: Comparable & Sendable>: Sendable {
  let value: T
  let sessionId: UUID
  let date: Date
  
  var isValid: Bool {
    switch value {
    case let doubleValue as Double:
      return doubleValue > 0
    case let timeInterval as TimeInterval:
      return timeInterval > 0
    default:
      return true
    }
  }
}

// MARK: - Weekly Analytics Data Model

/// Analytics data optimized for weekly views and trends
struct WeeklyAnalyticsData: Sendable {
  let weeks: [WeekData]
  let totalWeeks: Int
  let averageSessionsPerWeek: Double
  let averageDistancePerWeek: Double
  let averageCaloriesPerWeek: Double
  
  init(sessions: [RuckSession], numberOfWeeks: Int = 12) {
    let calendar = Calendar.current
    let endDate = Date()
    
    var weeklyData: [WeekData] = []
    
    for weekOffset in 0..<numberOfWeeks {
      guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: endDate),
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else {
        continue
      }
      
      let weekSessions = sessions.filter { session in
        weekInterval.contains(session.startDate)
      }
      
      let weekData = WeekData(
        weekStart: weekInterval.start,
        weekEnd: weekInterval.end,
        sessions: weekSessions
      )
      
      weeklyData.append(weekData)
    }
    
    self.weeks = weeklyData.reversed() // Show oldest to newest
    self.totalWeeks = numberOfWeeks
    
    let totalSessions = weeks.reduce(0) { $0 + $1.sessionCount }
    let totalDistance = weeks.reduce(0) { $0 + $1.totalDistance }
    let totalCalories = weeks.reduce(0) { $0 + $1.totalCalories }
    
    self.averageSessionsPerWeek = Double(totalSessions) / Double(numberOfWeeks)
    self.averageDistancePerWeek = totalDistance / Double(numberOfWeeks)
    self.averageCaloriesPerWeek = totalCalories / Double(numberOfWeeks)
  }
}

/// Data for a single week
struct WeekData: Sendable, Identifiable {
  let id = UUID()
  let weekStart: Date
  let weekEnd: Date
  let sessions: [RuckSession]
  
  var sessionCount: Int {
    sessions.count
  }
  
  var totalDistance: Double {
    sessions.reduce(0) { $0 + $1.totalDistance }
  }
  
  var totalCalories: Double {
    sessions.reduce(0) { $0 + $1.totalCalories }
  }
  
  var totalDuration: TimeInterval {
    sessions.reduce(0) { $0 + $1.totalDuration }
  }
  
  var averagePace: Double {
    guard !sessions.isEmpty else { return 0 }
    let totalPaceDistance = sessions.reduce(0.0) { sum, session in
      return sum + (session.averagePace * session.totalDistance)
    }
    return totalDistance > 0 ? totalPaceDistance / totalDistance : 0
  }
  
  var meetsTrainingGoal: Bool {
    sessionCount >= 2
  }
  
  var weekNumber: Int {
    Calendar.current.component(.weekOfYear, from: weekStart)
  }
  
  var formattedWeekRange: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    
    let startString = formatter.string(from: weekStart)
    let endString = formatter.string(from: weekEnd)
    
    return "\(startString) - \(endString)"
  }
}