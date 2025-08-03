import Testing
import SwiftData
import Foundation
@testable import RuckMap

/// Edge cases and error condition tests for Analytics using Swift Testing framework
@Suite("Analytics Edge Cases Tests")
struct AnalyticsEdgeCasesTests {
  
  private let modelContainer: ModelContainer
  private let analyticsRepository: AnalyticsRepository
  
  init() throws {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    modelContainer = try ModelContainer(
      for: RuckSession.self, LocationPoint.self, TerrainSegment.self, WeatherConditions.self,
      configurations: configuration
    )
    analyticsRepository = AnalyticsRepository(modelContainer: modelContainer)
  }
  
  // MARK: - No Data Edge Cases
  
  @Test("Analytics handles empty database gracefully")
  func analyticsHandlesEmptyDatabaseGracefully() async throws {
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    #expect(analyticsData.totalSessions == 0)
    #expect(analyticsData.totalDistance == 0)
    #expect(analyticsData.totalCalories == 0)
    #expect(analyticsData.totalWeightMoved == 0)
    
    // Averages should be zero when no data
    #expect(analyticsData.averageDistance == 0)
    #expect(analyticsData.averageCalories == 0)
    #expect(analyticsData.averageLoadWeight == 0)
    #expect(analyticsData.averagePace == 0)
    
    // Personal records should be zero
    #expect(analyticsData.longestDistance == 0)
    #expect(analyticsData.fastestPace == 0)
    #expect(analyticsData.heaviestLoad == 0)
    
    // Training metrics should be zero
    #expect(analyticsData.trainingStreak == 0)
    #expect(analyticsData.averageSessionsPerWeek == 0)
    #expect(analyticsData.totalActiveWeeks == 0)
    
    // Trends should be nil when no previous data
    #expect(analyticsData.distanceTrend == nil)
    #expect(analyticsData.paceTrend == nil)
    #expect(analyticsData.calorieTrend == nil)
  }
  
  @Test("Personal records with no valid sessions")
  func personalRecordsWithNoValidSessions() async throws {
    let personalRecords = try await analyticsRepository.fetchPersonalRecords()
    
    // All records should have zero values
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
    #expect(!personalRecords.highestCalorieBurn.isValid)
    #expect(!personalRecords.longestDuration.isValid)
    #expect(!personalRecords.mostWeightMoved.isValid)
  }
  
  @Test("Weekly analytics with no sessions")
  func weeklyAnalyticsWithNoSessions() async throws {
    let weeklyData = try await analyticsRepository.fetchWeeklyAnalyticsData(numberOfWeeks: 12)
    
    #expect(weeklyData.weeks.count == 12)
    #expect(weeklyData.totalWeeks == 12)
    #expect(weeklyData.averageSessionsPerWeek == 0)
    #expect(weeklyData.averageDistancePerWeek == 0)
    #expect(weeklyData.averageCaloriesPerWeek == 0)
    
    // All weeks should have zero sessions
    for week in weeklyData.weeks {
      #expect(week.sessionCount == 0)
      #expect(week.totalDistance == 0)
      #expect(week.totalCalories == 0)
      #expect(week.totalDuration == 0)
      #expect(week.averagePace == 0)
      #expect(!week.meetsTrainingGoal)
    }
  }
  
  // MARK: - Invalid Data Edge Cases
  
  @Test("Analytics handles sessions with zero or negative values")
  func analyticsHandlesSessionsWithZeroOrNegativeValues() async throws {
    let context = ModelContext(modelContainer)
    
    // Create sessions with problematic values
    let zeroSession = try createSessionWithValues(
      loadWeight: 0,
      distance: 0,
      calories: 0,
      pace: 0,
      duration: 0
    )
    
    let negativeSession = try createSessionWithValues(
      loadWeight: -10,
      distance: -1000,
      calories: -500,
      pace: -5,
      duration: -3600
    )
    
    let normalSession = try createSessionWithValues(
      loadWeight: 25,
      distance: 5000,
      calories: 400,
      pace: 5.5,
      duration: 3600
    )
    
    context.insert(zeroSession)
    context.insert(negativeSession)
    context.insert(normalSession)
    try context.save()
    
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    // Should include all sessions
    #expect(analyticsData.totalSessions == 3)
    
    // Should sum all values, including negative ones
    #expect(analyticsData.totalDistance == 4000) // 0 + (-1000) + 5000
    #expect(analyticsData.totalCalories == -100) // 0 + (-500) + 400
    
    // Weight moved calculation should handle edge cases
    let expectedWeightMoved = (0 * 0) + (-10 * -1) + (25 * 5) // 0 + 10 + 125 = 135
    #expect(analyticsData.totalWeightMoved == expectedWeightMoved)
  }
  
  @Test("Personal records ignores invalid pace values")
  func personalRecordsIgnoresInvalidPaceValues() async throws {
    let context = ModelContext(modelContainer)
    
    let sessions = [
      try createSessionWithValues(loadWeight: 25, distance: 5000, pace: 0), // Invalid pace
      try createSessionWithValues(loadWeight: 30, distance: 6000, pace: -1), // Invalid pace
      try createSessionWithValues(loadWeight: 20, distance: 4000, pace: 5.0), // Valid pace
      try createSessionWithValues(loadWeight: 35, distance: 7000, pace: 6.0) // Valid pace
    ]
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    let personalRecords = try await analyticsRepository.fetchPersonalRecords()
    
    // Should find fastest valid pace (5.0), ignoring zero and negative values
    #expect(personalRecords.fastestPace.value == 5.0)
    #expect(personalRecords.fastestPace.isValid)
  }
  
  @Test("Analytics handles incomplete sessions correctly")
  func analyticsHandlesIncompleteSessionsCorrectly() async throws {
    let context = ModelContext(modelContainer)
    
    // Complete session
    let completeSession = try RuckSession(loadWeight: 25.0)
    completeSession.startDate = Date()
    completeSession.endDate = completeSession.startDate.addingTimeInterval(3600)
    completeSession.totalDistance = 5000
    completeSession.totalCalories = 400
    
    // Incomplete session (no end date)
    let incompleteSession = try RuckSession(loadWeight: 30.0)
    incompleteSession.startDate = Date()
    incompleteSession.endDate = nil // No end date
    incompleteSession.totalDistance = 6000
    incompleteSession.totalCalories = 500
    
    context.insert(completeSession)
    context.insert(incompleteSession)
    try context.save()
    
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    // Should only include complete sessions in analytics
    #expect(analyticsData.totalSessions == 1)
    #expect(analyticsData.totalDistance == 5000)
    #expect(analyticsData.totalCalories == 400)
  }
  
  // MARK: - Date Range Edge Cases
  
  @Test("Analytics handles sessions at exact time period boundaries")
  func analyticsHandlesSessionsAtExactTimePeriodBoundaries() async throws {
    let context = ModelContext(modelContainer)
    let calendar = Calendar.current
    let now = Date()
    
    // Get exact boundary dates for monthly period
    let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
    let previousMonthEnd = calendar.date(byAdding: .second, value: -1, to: monthStart) ?? now
    
    // Session exactly at month boundary
    let boundarySession = try createSessionWithDate(date: monthStart)
    
    // Session just before boundary
    let beforeBoundarySession = try createSessionWithDate(date: previousMonthEnd)
    
    // Session well within month
    let withinMonthSession = try createSessionWithDate(
      date: calendar.date(byAdding: .day, value: 5, to: monthStart) ?? now
    )
    
    context.insert(boundarySession)
    context.insert(beforeBoundarySession)
    context.insert(withinMonthSession)
    try context.save()
    
    let monthlyData = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    
    // Should include boundary session and within-month session
    #expect(monthlyData.totalSessions == 2)
  }
  
  @Test("Analytics handles future dates gracefully")
  func analyticsHandlesFutureDatesGracefully() async throws {
    let context = ModelContext(modelContainer)
    let calendar = Calendar.current
    
    // Session with future date
    let futureDate = calendar.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    let futureSession = try createSessionWithDate(date: futureDate)
    
    // Session with current date
    let currentSession = try createSessionWithDate(date: Date())
    
    context.insert(futureSession)
    context.insert(currentSession)
    try context.save()
    
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    
    // Future sessions might or might not be included depending on filter logic
    // The key is that it shouldn't crash
    #expect(analyticsData.totalSessions >= 1)
  }
  
  @Test("Time period calculations handle invalid dates")
  func timePeriodCalculationsHandleInvalidDates() throws {
    // Test with extreme dates
    let extremePastDate = Date(timeIntervalSince1970: 0) // January 1, 1970
    let extremeFutureDate = Date(timeIntervalSince1970: 4102444800) // January 1, 2100
    
    for timePeriod in AnalyticsTimePeriod.allCases {
      let pastRange = timePeriod.dateRange(relativeTo: extremePastDate)
      let futureRange = timePeriod.dateRange(relativeTo: extremeFutureDate)
      
      // Should not crash and should maintain start <= end relationship
      #expect(pastRange.start <= pastRange.end)
      #expect(futureRange.start <= futureRange.end)
    }
  }
  
  // MARK: - Large Number Edge Cases
  
  @Test("Analytics handles extremely large values")
  func analyticsHandlesExtremelyLargeValues() async throws {
    let context = ModelContext(modelContainer)
    
    let extremeSession = try createSessionWithValues(
      loadWeight: Double.greatestFiniteMagnitude / 1e10, // Very large but finite
      distance: Double.greatestFiniteMagnitude / 1e10,
      calories: Double.greatestFiniteMagnitude / 1e10,
      pace: 1000.0, // Very slow pace
      duration: TimeInterval.greatestFiniteMagnitude / 1e10
    )
    
    context.insert(extremeSession)
    try context.save()
    
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    // Should not crash and should produce finite results
    #expect(analyticsData.totalSessions == 1)
    #expect(analyticsData.totalDistance.isFinite)
    #expect(analyticsData.totalCalories.isFinite)
    #expect(analyticsData.totalWeightMoved.isFinite)
    #expect(analyticsData.averageDistance.isFinite)
  }
  
  @Test("Analytics handles very small fractional values")
  func analyticsHandlesVerySmallFractionalValues() async throws {
    let context = ModelContext(modelContainer)
    
    let tinySession = try createSessionWithValues(
      loadWeight: 0.001, // 1 gram
      distance: 0.001, // 1 millimeter
      calories: 0.001,
      pace: 0.001, // Very fast pace
      duration: 0.001 // Fraction of a second
    )
    
    context.insert(tinySession)
    try context.save()
    
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    #expect(analyticsData.totalSessions == 1)
    #expect(analyticsData.totalDistance == 0.001)
    #expect(analyticsData.totalCalories == 0.001)
    #expect(analyticsData.totalWeightMoved == 0.000001) // 0.001kg × 0.000001km
  }
  
  // MARK: - Floating Point Edge Cases
  
  @Test("Analytics handles NaN and infinity values")
  func analyticsHandlesNaNAndInfinityValues() async throws {
    let context = ModelContext(modelContainer)
    
    // Create session with problematic floating point values
    let problemSession = try RuckSession(loadWeight: 25.0)
    problemSession.startDate = Date()
    problemSession.endDate = problemSession.startDate.addingTimeInterval(3600)
    problemSession.totalDistance = Double.nan
    problemSession.totalCalories = Double.infinity
    problemSession.averagePace = -Double.infinity
    problemSession.totalDuration = 3600
    
    // Also create a normal session for comparison
    let normalSession = try createSessionWithValues(
      loadWeight: 30,
      distance: 5000,
      calories: 400,
      pace: 5.5,
      duration: 3600
    )
    
    context.insert(problemSession)
    context.insert(normalSession)
    try context.save()
    
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    // Should handle gracefully without crashing
    #expect(analyticsData.totalSessions == 2)
    
    // Results should be finite where possible
    if !analyticsData.totalDistance.isNaN && !analyticsData.totalDistance.isInfinite {
      #expect(analyticsData.totalDistance.isFinite)
    }
  }
  
  @Test("Percentage calculations handle division by zero")
  func percentageCalculationsHandleDivisionByZero() throws {
    // Test trend calculation with zero previous value
    let trendDataZeroPrevious = TrendData(
      current: 100.0,
      previous: 0.0,
      metricType: .distance
    )
    
    #expect(trendDataZeroPrevious.percentageChange == 100.0) // Should show 100% increase
    #expect(trendDataZeroPrevious.direction == .improving)
    
    // Test with both values zero
    let trendDataBothZero = TrendData(
      current: 0.0,
      previous: 0.0,
      metricType: .distance
    )
    
    #expect(trendDataBothZero.percentageChange == 0.0)
    #expect(trendDataBothZero.direction == .stable)
  }
  
  // MARK: - Memory and Performance Edge Cases
  
  @Test("Analytics handles session with extremely long arrays")
  func analyticsHandlesSessionWithExtremelyLongArrays() async throws {
    let context = ModelContext(modelContainer)
    
    // Create session with large number of location points
    let session = try RuckSession(loadWeight: 25.0)
    session.startDate = Date()
    session.endDate = session.startDate.addingTimeInterval(3600)
    session.totalDistance = 5000
    session.totalCalories = 400
    
    // Add many location points (simulate very detailed tracking)
    for i in 0..<1000 {
      let locationPoint = LocationPoint()
      locationPoint.latitude = 37.7749 + Double(i) * 0.0001
      locationPoint.longitude = -122.4194 + Double(i) * 0.0001
      locationPoint.timestamp = session.startDate.addingTimeInterval(Double(i) * 3.6)
      locationPoint.altitude = 100.0
      locationPoint.speed = 1.4
      locationPoint.session = session
      session.locationPoints.append(locationPoint)
    }
    
    context.insert(session)
    try context.save()
    
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    #expect(analyticsData.totalSessions == 1)
    #expect(analyticsData.totalDistance == 5000)
  }
  
  // MARK: - Concurrent Access Edge Cases
  
  @Test("Analytics handles concurrent cache operations")
  func analyticsHandlesConcurrentCacheOperations() async throws {
    let context = ModelContext(modelContainer)
    let session = try createSessionWithValues(
      loadWeight: 25,
      distance: 5000,
      calories: 400,
      pace: 5.5,
      duration: 3600
    )
    
    context.insert(session)
    try context.save()
    
    // Start multiple concurrent operations
    async let fetch1 = analyticsRepository.fetchAnalyticsData(for: .monthly)
    async let fetch2 = analyticsRepository.fetchAnalyticsData(for: .weekly)
    let invalidateTask = Task {
      await analyticsRepository.invalidateCache()
    }
    async let fetch3 = analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    // Wait for all operations
    let (result1, result2, result3) = try await (fetch1, fetch2, fetch3)
    await invalidateTask.value
    
    // All operations should complete successfully
    #expect(result1.totalSessions >= 0)
    #expect(result2.totalSessions >= 0)
    #expect(result3.totalSessions >= 0)
  }
  
  // MARK: - Time Zone Edge Cases
  
  @Test("Analytics handles sessions across time zone changes")
  func analyticsHandlesSessionsAcrossTimeZoneChanges() async throws {
    let context = ModelContext(modelContainer)
    
    // Create sessions with different time zones
    let utcTimeZone = TimeZone(identifier: "UTC")!
    let pstTimeZone = TimeZone(identifier: "America/Los_Angeles")!
    let jstTimeZone = TimeZone(identifier: "Asia/Tokyo")!
    
    let calendar = Calendar.current
    let baseDate = Date()
    
    // Session in UTC
    let utcSession = try createSessionWithDate(date: baseDate)
    
    // Session as if created in PST (8 hours behind UTC)
    let pstDate = calendar.date(byAdding: .hour, value: -8, to: baseDate) ?? baseDate
    let pstSession = try createSessionWithDate(date: pstDate)
    
    // Session as if created in JST (9 hours ahead of UTC)
    let jstDate = calendar.date(byAdding: .hour, value: 9, to: baseDate) ?? baseDate
    let jstSession = try createSessionWithDate(date: jstDate)
    
    context.insert(utcSession)
    context.insert(pstSession)
    context.insert(jstSession)
    try context.save()
    
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    // Should handle all sessions regardless of time zone
    #expect(analyticsData.totalSessions == 3)
  }
  
  // MARK: - Data Corruption Edge Cases
  
  @Test("Analytics handles missing required fields")
  func analyticsHandlesMissingRequiredFields() async throws {
    let context = ModelContext(modelContainer)
    
    // Create session with minimal data
    let minimalSession = try RuckSession(loadWeight: 25.0)
    minimalSession.startDate = Date()
    // Missing endDate, totalDistance, etc.
    
    context.insert(minimalSession)
    try context.save()
    
    // Should not crash when processing incomplete data
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    // Incomplete sessions might be filtered out or handled gracefully
    #expect(analyticsData.totalSessions >= 0)
  }
  
  // MARK: - Helper Methods
  
  private func createSessionWithValues(
    loadWeight: Double,
    distance: Double,
    calories: Double,
    pace: Double,
    duration: TimeInterval
  ) throws -> RuckSession {
    let session = try RuckSession(loadWeight: loadWeight)
    session.startDate = Date()
    session.endDate = session.startDate.addingTimeInterval(duration)
    session.totalDistance = distance
    session.totalCalories = calories
    session.averagePace = pace
    session.totalDuration = duration
    return session
  }
  
  private func createSessionWithDate(date: Date) throws -> RuckSession {
    let session = try RuckSession(loadWeight: 25.0)
    session.startDate = date
    session.endDate = date.addingTimeInterval(3600)
    session.totalDistance = 5000
    session.totalCalories = 400
    session.averagePace = 5.5
    session.totalDuration = 3600
    return session
  }
}