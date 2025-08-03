import Testing
import SwiftData
import Foundation
@testable import RuckMap

/// Comprehensive tests for Analytics Data Models using Swift Testing framework
@Suite("Analytics Data Models Tests")
struct AnalyticsDataModelsTests {
  
  // MARK: - AnalyticsData Tests
  
  @Test("AnalyticsData initialization with empty sessions")
  func analyticsDataInitializationEmptySessions() throws {
    let analyticsData = AnalyticsData(
      sessions: [],
      timePeriod: .monthly
    )
    
    #expect(analyticsData.totalSessions == 0)
    #expect(analyticsData.totalDistance == 0)
    #expect(analyticsData.totalCalories == 0)
    #expect(analyticsData.totalWeightMoved == 0)
    #expect(analyticsData.averageDistance == 0)
    #expect(analyticsData.averageCalories == 0)
    #expect(analyticsData.averageLoadWeight == 0)
    #expect(analyticsData.averagePace == 0)
    #expect(analyticsData.trainingStreak == 0)
    #expect(analyticsData.averageSessionsPerWeek == 0)
  }
  
  @Test("AnalyticsData calculations with single session")
  func analyticsDataCalculationsSingleSession() throws {
    let session = try createTestSession(
      loadWeight: 25.0,
      distance: 5000.0,
      calories: 400.0,
      pace: 5.0,
      duration: 3000
    )
    
    let analyticsData = AnalyticsData(
      sessions: [session],
      timePeriod: .monthly
    )
    
    #expect(analyticsData.totalSessions == 1)
    #expect(analyticsData.totalDistance == 5000.0)
    #expect(analyticsData.totalCalories == 400.0)
    #expect(analyticsData.totalWeightMoved == 125.0) // 25kg × 5km
    #expect(analyticsData.averageDistance == 5000.0)
    #expect(analyticsData.averageCalories == 400.0)
    #expect(analyticsData.averageLoadWeight == 25.0)
    #expect(analyticsData.averagePace == 5.0)
    
    // Personal records should match single session
    #expect(analyticsData.longestDistance == 5000.0)
    #expect(analyticsData.fastestPace == 5.0)
    #expect(analyticsData.heaviestLoad == 25.0)
    #expect(analyticsData.highestCalorieBurn == 400.0)
  }
  
  @Test("AnalyticsData calculations with multiple sessions",
        arguments: [
          (sessionCount: 3, expectedSessions: 3),
          (sessionCount: 10, expectedSessions: 10),
          (sessionCount: 25, expectedSessions: 25)
        ])
  func analyticsDataCalculationsMultipleSessions(
    sessionCount: Int,
    expectedSessions: Int
  ) throws {
    let sessions = try createMultipleTestSessions(count: sessionCount)
    
    let analyticsData = AnalyticsData(
      sessions: sessions,
      timePeriod: .monthly
    )
    
    #expect(analyticsData.totalSessions == expectedSessions)
    #expect(analyticsData.totalDistance > 0)
    #expect(analyticsData.totalCalories > 0)
    #expect(analyticsData.totalWeightMoved > 0)
    
    // Averages should be calculated correctly
    let expectedTotalDistance = sessions.reduce(0) { $0 + $1.totalDistance }
    let expectedTotalCalories = sessions.reduce(0) { $0 + $1.totalCalories }
    
    #expect(analyticsData.totalDistance == expectedTotalDistance)
    #expect(analyticsData.totalCalories == expectedTotalCalories)
    #expect(analyticsData.averageDistance == expectedTotalDistance / Double(sessionCount))
    #expect(analyticsData.averageCalories == expectedTotalCalories / Double(sessionCount))
  }
  
  @Test("AnalyticsData trend calculations")
  func analyticsDataTrendCalculations() throws {
    let currentSessions = try createTestSessionsWithValues(
      sessions: [
        (weight: 25.0, distance: 6000.0, calories: 500.0),
        (weight: 30.0, distance: 7000.0, calories: 600.0)
      ]
    )
    
    let previousSessions = try createTestSessionsWithValues(
      sessions: [
        (weight: 20.0, distance: 5000.0, calories: 400.0)
      ]
    )
    
    let analyticsData = AnalyticsData(
      sessions: currentSessions,
      timePeriod: .monthly,
      previousPeriodSessions: previousSessions
    )
    
    // Verify trend data exists
    #expect(analyticsData.distanceTrend != nil)
    #expect(analyticsData.calorieTrend != nil)
    #expect(analyticsData.sessionCountTrend != nil)
    
    // Verify trend calculations
    if let distanceTrend = analyticsData.distanceTrend {
      #expect(distanceTrend.current == 13000.0) // 6000 + 7000
      #expect(distanceTrend.previous == 5000.0)
      #expect(distanceTrend.direction == .improving) // Distance increased
    }
    
    if let sessionTrend = analyticsData.sessionCountTrend {
      #expect(sessionTrend.current == 2.0)
      #expect(sessionTrend.previous == 1.0)
      #expect(sessionTrend.direction == .improving) // More sessions
    }
  }
  
  @Test("AnalyticsData training streak calculation")
  func analyticsDataTrainingStreakCalculation() throws {
    // Create sessions with consistent 2+ sessions per week
    let sessions = try createConsecutiveWeekSessions(weeks: 4, sessionsPerWeek: 3)
    
    let analyticsData = AnalyticsData(
      sessions: sessions,
      timePeriod: .lastMonth
    )
    
    // Should have a training streak of 4 weeks
    #expect(analyticsData.trainingStreak >= 4)
    #expect(analyticsData.averageSessionsPerWeek >= 2.0)
    #expect(analyticsData.totalActiveWeeks >= 4)
  }
  
  @Test("AnalyticsData weight moved calculation accuracy")
  func analyticsDataWeightMovedCalculationAccuracy() throws {
    let sessions = try createTestSessionsWithValues(
      sessions: [
        (weight: 20.0, distance: 5000.0, calories: 400.0), // 20kg × 5km = 100 kg×km
        (weight: 30.0, distance: 8000.0, calories: 600.0), // 30kg × 8km = 240 kg×km
        (weight: 25.0, distance: 6000.0, calories: 500.0)  // 25kg × 6km = 150 kg×km
      ]
    )
    
    let analyticsData = AnalyticsData(
      sessions: sessions,
      timePeriod: .monthly
    )
    
    let expectedWeightMoved = 100.0 + 240.0 + 150.0 // 490 kg×km
    #expect(analyticsData.totalWeightMoved == expectedWeightMoved)
  }
  
  // MARK: - PersonalRecords Tests
  
  @Test("PersonalRecords initialization with varied sessions")
  func personalRecordsInitializationVariedSessions() throws {
    let sessions = try createVariedTestSessions()
    let personalRecords = PersonalRecords(sessions: sessions)
    
    // All records should be valid
    #expect(personalRecords.longestDistance.isValid)
    #expect(personalRecords.fastestPace.isValid)
    #expect(personalRecords.heaviestLoad.isValid)
    #expect(personalRecords.highestCalorieBurn.isValid)
    #expect(personalRecords.longestDuration.isValid)
    #expect(personalRecords.mostWeightMoved.isValid)
    
    // Verify record values match expected maximums/minimums
    let expectedLongestDistance = sessions.map(\.totalDistance).max() ?? 0
    let expectedHeaviestLoad = sessions.map(\.loadWeight).max() ?? 0
    let expectedFastestPace = sessions.compactMap { $0.averagePace > 0 ? $0.averagePace : nil }.min() ?? 0
    let expectedHighestCalories = sessions.map(\.totalCalories).max() ?? 0
    
    #expect(personalRecords.longestDistance.value == expectedLongestDistance)
    #expect(personalRecords.heaviestLoad.value == expectedHeaviestLoad)
    #expect(personalRecords.fastestPace.value == expectedFastestPace)
    #expect(personalRecords.highestCalorieBurn.value == expectedHighestCalories)
  }
  
  @Test("PersonalRecords with empty sessions")
  func personalRecordsEmptySessions() throws {
    let personalRecords = PersonalRecords(sessions: [])
    
    // All records should have zero values but UUIDs should still be set
    #expect(personalRecords.longestDistance.value == 0)
    #expect(personalRecords.fastestPace.value == 0)
    #expect(personalRecords.heaviestLoad.value == 0)
    #expect(personalRecords.highestCalorieBurn.value == 0)
    #expect(personalRecords.longestDuration.value == 0)
    #expect(personalRecords.mostWeightMoved.value == 0)
    
    // Records should not be considered valid
    #expect(!personalRecords.longestDistance.isValid)
    #expect(!personalRecords.fastestPace.isValid)
    #expect(!personalRecords.heaviestLoad.isValid)
  }
  
  @Test("PersonalRecord validity checks",
        arguments: [
          (value: 0.0, isValid: false),
          (value: -1.0, isValid: false),
          (value: 1.0, isValid: true),
          (value: 100.0, isValid: true)
        ])
  func personalRecordValidityChecks(value: Double, isValid: Bool) throws {
    let record = PersonalRecord(value: value, sessionId: UUID(), date: Date())
    #expect(record.isValid == isValid)
  }
  
  // MARK: - WeeklyAnalyticsData Tests
  
  @Test("WeeklyAnalyticsData initialization and calculations",
        arguments: [4, 8, 12, 26])
  func weeklyAnalyticsDataInitializationAndCalculations(numberOfWeeks: Int) throws {
    let sessions = try createSessionsSpreadOverWeeks(weeks: numberOfWeeks)
    let weeklyData = WeeklyAnalyticsData(sessions: sessions, numberOfWeeks: numberOfWeeks)
    
    #expect(weeklyData.weeks.count == numberOfWeeks)
    #expect(weeklyData.totalWeeks == numberOfWeeks)
    #expect(weeklyData.averageSessionsPerWeek >= 0)
    #expect(weeklyData.averageDistancePerWeek >= 0)
    #expect(weeklyData.averageCaloriesPerWeek >= 0)
    
    // Verify weeks are in chronological order (oldest to newest)
    for i in 1..<weeklyData.weeks.count {
      #expect(weeklyData.weeks[i-1].weekStart <= weeklyData.weeks[i].weekStart)
    }
  }
  
  @Test("WeekData calculations and properties")
  func weekDataCalculationsAndProperties() throws {
    let sessions = try createTestSessionsWithValues(
      sessions: [
        (weight: 25.0, distance: 5000.0, calories: 400.0),
        (weight: 30.0, distance: 6000.0, calories: 500.0)
      ]
    )
    
    let weekStart = Date()
    let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
    
    let weekData = WeekData(
      weekStart: weekStart,
      weekEnd: weekEnd,
      sessions: sessions
    )
    
    #expect(weekData.sessionCount == 2)
    #expect(weekData.totalDistance == 11000.0) // 5000 + 6000
    #expect(weekData.totalCalories == 900.0) // 400 + 500
    #expect(weekData.meetsTrainingGoal) // 2+ sessions
    
    // Test formatted week range
    #expect(!weekData.formattedWeekRange.isEmpty)
    
    // Test week number
    #expect(weekData.weekNumber > 0)
    #expect(weekData.weekNumber <= 53)
  }
  
  // MARK: - TrendData Tests
  
  @Test("TrendData calculations for different metrics",
        arguments: [
          (current: 100.0, previous: 80.0, metricType: MetricType.distance, expectedDirection: TrendDirection.improving),
          (current: 80.0, previous: 100.0, metricType: MetricType.distance, expectedDirection: TrendDirection.declining),
          (current: 5.0, previous: 6.0, metricType: MetricType.pace, expectedDirection: TrendDirection.improving), // Lower pace is better
          (current: 6.0, previous: 5.0, metricType: MetricType.pace, expectedDirection: TrendDirection.declining),
          (current: 100.0, previous: 100.0, metricType: MetricType.calories, expectedDirection: TrendDirection.stable)
        ])
  func trendDataCalculationsForDifferentMetrics(
    current: Double,
    previous: Double,
    metricType: MetricType,
    expectedDirection: TrendDirection
  ) throws {
    let trendData = TrendData(
      current: current,
      previous: previous,
      metricType: metricType
    )
    
    #expect(trendData.current == current)
    #expect(trendData.previous == previous)
    #expect(trendData.metricType == metricType)
    #expect(trendData.direction == expectedDirection)
    
    // Test percentage change calculation
    if previous > 0 {
      let expectedPercentage = ((current - previous) / previous) * 100
      #expect(abs(trendData.percentageChange - expectedPercentage) < 0.01)
    }
  }
  
  @Test("TrendData percentage formatting")
  func trendDataPercentageFormatting() throws {
    let trendData = TrendData(
      current: 120.0,
      previous: 100.0,
      metricType: .distance
    )
    
    let formatted = trendData.formattedPercentageChange
    #expect(formatted.contains("20.0%"))
  }
  
  @Test("TrendData edge cases",
        arguments: [
          (current: 100.0, previous: 0.0), // Division by zero
          (current: 0.0, previous: 100.0), // Zero current value
          (current: 0.0, previous: 0.0)    // Both zero
        ])
  func trendDataEdgeCases(current: Double, previous: Double) throws {
    let trendData = TrendData(
      current: current,
      previous: previous,
      metricType: .distance
    )
    
    // Should not crash and should have reasonable values
    #expect(trendData.current == current)
    #expect(trendData.previous == previous)
    #expect(trendData.percentageChange.isFinite)
  }
  
  // MARK: - AnalyticsTimePeriod Tests
  
  @Test("AnalyticsTimePeriod date range calculations",
        arguments: AnalyticsTimePeriod.allCases)
  func analyticsTimePeriodDateRangeCalculations(timePeriod: AnalyticsTimePeriod) throws {
    let referenceDate = Date()
    let dateRange = timePeriod.dateRange(relativeTo: referenceDate)
    
    // Start should be before or equal to end
    #expect(dateRange.start <= dateRange.end)
    
    // End should be the reference date (or before for historical periods)
    if timePeriod != .allTime {
      #expect(dateRange.end <= referenceDate.addingTimeInterval(86400)) // Allow for some tolerance
    }
    
    // Verify specific period logic
    switch timePeriod {
    case .allTime:
      #expect(dateRange.start == Date.distantPast)
    case .weekly, .monthly:
      #expect(dateRange.end == referenceDate)
    default:
      #expect(dateRange.end <= referenceDate)
    }
  }
  
  @Test("AnalyticsTimePeriod display properties")
  func analyticsTimePeriodDisplayProperties() throws {
    for timePeriod in AnalyticsTimePeriod.allCases {
      #expect(!timePeriod.displayName.isEmpty)
      #expect(!timePeriod.systemImage.isEmpty)
      #expect(!timePeriod.rawValue.isEmpty)
    }
  }
  
  // MARK: - Edge Cases and Error Conditions
  
  @Test("Analytics models handle invalid data gracefully")
  func analyticsModelsHandleInvalidDataGracefully() throws {
    // Session with negative values
    let invalidSession = try RuckSession(loadWeight: -10.0)
    invalidSession.totalDistance = -1000.0
    invalidSession.totalCalories = -500.0
    invalidSession.averagePace = -5.0
    invalidSession.startDate = Date()
    invalidSession.endDate = Date()
    
    let analyticsData = AnalyticsData(
      sessions: [invalidSession],
      timePeriod: .monthly
    )
    
    // Should not crash and should handle negative values
    #expect(analyticsData.totalSessions == 1)
    // Negative values should be included in calculations as-is
    #expect(analyticsData.totalDistance == -1000.0)
    #expect(analyticsData.totalCalories == -500.0)
  }
  
  @Test("WeeklyAnalyticsData handles zero weeks")
  func weeklyAnalyticsDataHandlesZeroWeeks() throws {
    let sessions = try createTestSessionsWithValues(
      sessions: [(weight: 25.0, distance: 5000.0, calories: 400.0)]
    )
    
    let weeklyData = WeeklyAnalyticsData(sessions: sessions, numberOfWeeks: 0)
    
    #expect(weeklyData.weeks.isEmpty)
    #expect(weeklyData.totalWeeks == 0)
    #expect(weeklyData.averageSessionsPerWeek.isNaN || weeklyData.averageSessionsPerWeek == 0)
  }
  
  @Test("PersonalRecords handles sessions with zero pace")
  func personalRecordsHandlesSessionsWithZeroPace() throws {
    let sessions = [
      try createTestSessionWithPace(pace: 0.0, distance: 5000.0),
      try createTestSessionWithPace(pace: 5.0, distance: 6000.0),
      try createTestSessionWithPace(pace: 0.0, distance: 7000.0)
    ]
    
    let personalRecords = PersonalRecords(sessions: sessions)
    
    // Should find the fastest valid pace (5.0), ignoring zero values
    #expect(personalRecords.fastestPace.value == 5.0)
    #expect(personalRecords.fastestPace.isValid)
  }
  
  // MARK: - Helper Methods
  
  private func createTestSession(
    loadWeight: Double,
    distance: Double = 5000.0,
    calories: Double = 400.0,
    pace: Double = 5.0,
    duration: TimeInterval = 3600
  ) throws -> RuckSession {
    let session = try RuckSession(loadWeight: loadWeight)
    session.startDate = Date()
    session.endDate = session.startDate.addingTimeInterval(duration)
    session.totalDistance = distance
    session.totalCalories = calories
    session.averagePace = pace
    session.totalDuration = duration
    session.elevationGain = 100.0
    session.elevationLoss = 90.0
    return session
  }
  
  private func createTestSessionWithPace(pace: Double, distance: Double) throws -> RuckSession {
    let session = try RuckSession(loadWeight: 25.0)
    session.startDate = Date()
    session.endDate = session.startDate.addingTimeInterval(3600)
    session.totalDistance = distance
    session.totalCalories = 400.0
    session.averagePace = pace
    session.totalDuration = 3600
    return session
  }
  
  private func createMultipleTestSessions(count: Int) throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<count {
      let session = try createTestSession(
        loadWeight: Double(20 + i % 30),
        distance: Double(3000 + i * 500),
        calories: Double(300 + i * 25),
        pace: Double(4.5 + Double(i % 10) * 0.2)
      )
      session.startDate = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createTestSessionsWithValues(
    sessions: [(weight: Double, distance: Double, calories: Double)]
  ) throws -> [RuckSession] {
    var result: [RuckSession] = []
    
    for (index, config) in sessions.enumerated() {
      let session = try createTestSession(
        loadWeight: config.weight,
        distance: config.distance,
        calories: config.calories
      )
      session.startDate = Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      result.append(session)
    }
    
    return result
  }
  
  private func createVariedTestSessions() throws -> [RuckSession] {
    let configurations = [
      (weight: 15.0, distance: 3000.0, pace: 4.5, calories: 300.0),
      (weight: 25.0, distance: 8000.0, pace: 5.2, calories: 550.0),
      (weight: 35.0, distance: 12000.0, pace: 6.0, calories: 800.0),
      (weight: 45.0, distance: 6000.0, pace: 5.8, calories: 650.0),
      (weight: 20.0, distance: 15000.0, pace: 5.0, calories: 900.0)
    ]
    
    var sessions: [RuckSession] = []
    
    for (index, config) in configurations.enumerated() {
      let session = try createTestSession(
        loadWeight: config.weight,
        distance: config.distance,
        calories: config.calories,
        pace: config.pace
      )
      session.startDate = Calendar.current.date(byAdding: .day, value: -index * 3, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(TimeInterval(config.distance / 1000 * config.pace * 60))
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createSessionsSpreadOverWeeks(weeks: Int) throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    for week in 0..<weeks {
      let sessionsPerWeek = Int.random(in: 1...4)
      
      for sessionIndex in 0..<sessionsPerWeek {
        let session = try createTestSession(
          loadWeight: Double.random(in: 20...40),
          distance: Double.random(in: 3000...12000)
        )
        
        if let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()),
           let sessionDate = calendar.date(byAdding: .day, value: sessionIndex, to: weekStart) {
          session.startDate = sessionDate
          session.endDate = sessionDate.addingTimeInterval(3600)
        }
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  private func createConsecutiveWeekSessions(weeks: Int, sessionsPerWeek: Int) throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    for week in 0..<weeks {
      for sessionIndex in 0..<sessionsPerWeek {
        let session = try createTestSession(
          loadWeight: 30.0,
          distance: 7000.0
        )
        
        if let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()),
           let sessionDate = calendar.date(byAdding: .day, value: sessionIndex * 2, to: weekStart) {
          session.startDate = sessionDate
          session.endDate = sessionDate.addingTimeInterval(3600)
        }
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
}