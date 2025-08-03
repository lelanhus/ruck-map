import Testing
import SwiftData
import Foundation
@testable import RuckMap

/// Comprehensive tests for AnalyticsRepository using Swift Testing framework
@Suite("Analytics Repository Tests")
struct AnalyticsRepositoryTests {
  
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
  
  // MARK: - Basic Analytics Fetching Tests
  
  @Test("Fetch analytics data with no sessions returns empty data")
  func fetchAnalyticsDataEmptyDatabase() async throws {
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    
    #expect(analyticsData.totalSessions == 0)
    #expect(analyticsData.totalDistance == 0)
    #expect(analyticsData.totalCalories == 0)
    #expect(analyticsData.totalWeightMoved == 0)
  }
  
  @Test("Fetch analytics data with single session calculates correctly")
  func fetchAnalyticsDataSingleSession() async throws {
    let context = ModelContext(modelContainer)
    let session = try createTestSession(
      loadWeight: 25.0,
      distance: 5000.0,
      calories: 400.0,
      pace: 5.0,
      duration: 3000
    )
    
    context.insert(session)
    try context.save()
    
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    #expect(analyticsData.totalSessions == 1)
    #expect(analyticsData.totalDistance == 5000.0)
    #expect(analyticsData.totalCalories == 400.0)
    #expect(analyticsData.averageDistance == 5000.0)
    #expect(analyticsData.averageCalories == 400.0)
    #expect(analyticsData.averageLoadWeight == 25.0)
    #expect(analyticsData.totalWeightMoved == 125.0) // 25kg × 5km
  }
  
  // MARK: - Parameterized Time Period Tests
  
  @Test("Analytics data filters by time period correctly", 
        arguments: [
          (AnalyticsTimePeriod.weekly, -3),
          (AnalyticsTimePeriod.monthly, -15),
          (AnalyticsTimePeriod.last3Months, -60),
          (AnalyticsTimePeriod.lastYear, -200)
        ])
  func fetchAnalyticsDataTimePeriodFiltering(
    timePeriod: AnalyticsTimePeriod,
    daysOld: Int
  ) async throws {
    let context = ModelContext(modelContainer)
    
    // Create session within time period
    let recentSession = try createTestSession(loadWeight: 25.0, distance: 5000.0)
    recentSession.startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    recentSession.endDate = recentSession.startDate.addingTimeInterval(3600)
    
    // Create session outside time period
    let oldSession = try createTestSession(loadWeight: 30.0, distance: 6000.0)
    oldSession.startDate = Calendar.current.date(byAdding: .day, value: daysOld, to: Date()) ?? Date()
    oldSession.endDate = oldSession.startDate.addingTimeInterval(3600)
    
    context.insert(recentSession)
    context.insert(oldSession)
    try context.save()
    
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: timePeriod)
    
    // Should only include recent session for specific time periods
    if timePeriod != .allTime {
      #expect(analyticsData.totalSessions == 1)
      #expect(analyticsData.totalDistance == 5000.0)
    } else {
      #expect(analyticsData.totalSessions == 2)
    }
  }
  
  // MARK: - Cache Behavior Tests
  
  @Test("Analytics repository caches data correctly")
  func cacheDataCorrectly() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createMultipleTestSessions(count: 5)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // First fetch - should compute fresh data
    let startTime = Date()
    let firstFetch = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    let firstFetchDuration = Date().timeIntervalSince(startTime)
    
    // Second fetch - should return cached data
    let secondStartTime = Date()
    let secondFetch = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    let secondFetchDuration = Date().timeIntervalSince(secondStartTime)
    
    // Verify data consistency
    #expect(firstFetch.totalSessions == secondFetch.totalSessions)
    #expect(firstFetch.totalDistance == secondFetch.totalDistance)
    #expect(firstFetch.totalCalories == secondFetch.totalCalories)
    
    // Second fetch should be faster (cached)
    #expect(secondFetchDuration < firstFetchDuration)
  }
  
  @Test("Cache invalidation works correctly")
  func cacheInvalidationWorks() async throws {
    let context = ModelContext(modelContainer)
    let session = try createTestSession(loadWeight: 25.0, distance: 5000.0)
    context.insert(session)
    try context.save()
    
    // Fetch data to populate cache
    let firstFetch = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    #expect(firstFetch.totalSessions == 1)
    
    // Add another session
    let newSession = try createTestSession(loadWeight: 30.0, distance: 6000.0)
    context.insert(newSession)
    try context.save()
    
    // Invalidate cache
    await analyticsRepository.invalidateCache()
    
    // Fetch again - should include new session
    let secondFetch = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    #expect(secondFetch.totalSessions == 2)
  }
  
  // MARK: - Personal Records Tests
  
  @Test("Personal records calculation finds correct records")
  func personalRecordsCalculation() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createVariedTestSessions()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    let personalRecords = try await analyticsRepository.fetchPersonalRecords()
    
    // Verify records are valid
    #expect(personalRecords.longestDistance.isValid)
    #expect(personalRecords.fastestPace.isValid)
    #expect(personalRecords.heaviestLoad.isValid)
    #expect(personalRecords.highestCalorieBurn.isValid)
    #expect(personalRecords.longestDuration.isValid)
    #expect(personalRecords.mostWeightMoved.isValid)
    
    // Verify actual record values
    let expectedLongestDistance = sessions.map(\.totalDistance).max() ?? 0
    let expectedHeaviestLoad = sessions.map(\.loadWeight).max() ?? 0
    let expectedFastestPace = sessions.compactMap { $0.averagePace > 0 ? $0.averagePace : nil }.min() ?? 0
    
    #expect(personalRecords.longestDistance.value == expectedLongestDistance)
    #expect(personalRecords.heaviestLoad.value == expectedHeaviestLoad) 
    #expect(personalRecords.fastestPace.value == expectedFastestPace)
  }
  
  // MARK: - Weekly Analytics Tests
  
  @Test("Weekly analytics data calculation works correctly", 
        arguments: [4, 8, 12, 26])
  func weeklyAnalyticsDataCalculation(numberOfWeeks: Int) async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createSessionsSpreadOverWeeks(weeks: numberOfWeeks)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    let weeklyData = try await analyticsRepository.fetchWeeklyAnalyticsData(numberOfWeeks: numberOfWeeks)
    
    #expect(weeklyData.weeks.count == numberOfWeeks)
    #expect(weeklyData.totalWeeks == numberOfWeeks)
    #expect(weeklyData.averageSessionsPerWeek >= 0)
    #expect(weeklyData.averageDistancePerWeek >= 0)
    #expect(weeklyData.averageCaloriesPerWeek >= 0)
    
    // Verify individual week data structure
    for week in weeklyData.weeks {
      #expect(week.sessionCount >= 0)
      #expect(week.totalDistance >= 0)
      #expect(week.totalCalories >= 0)
      #expect(week.weekStart <= week.weekEnd)
    }
  }
  
  // MARK: - Comparative Analytics Tests
  
  @Test("Comparative analytics returns data for both periods")
  func comparativeAnalytics() async throws {
    let context = ModelContext(modelContainer)
    
    // Create current period sessions
    let currentSessions = try await createCurrentPeriodSessions()
    
    // Create previous period sessions  
    let previousSessions = try await createPreviousPeriodSessions()
    
    let allSessions = currentSessions + previousSessions
    for session in allSessions {
      context.insert(session)
    }
    try context.save()
    
    let (current, comparison) = try await analyticsRepository.fetchComparativeAnalytics(
      currentPeriod: .monthly,
      comparisonPeriod: .lastMonth
    )
    
    #expect(current.totalSessions >= 0)
    #expect(comparison.totalSessions >= 0)
    #expect(current.timePeriod == .monthly)
    #expect(comparison.timePeriod == .lastMonth)
  }
  
  // MARK: - Performance Tests
  
  @Test("Analytics calculation performance with large dataset",
        .timeLimit(.minutes(1)))
  func analyticsPerformanceWithLargeDataset() async throws {
    let context = ModelContext(modelContainer)
    let largeSessionSet = try await createLargeTestDataset(sessionCount: 1000)
    
    // Insert sessions in batches for better performance
    for sessionBatch in largeSessionSet.chunked(into: 100) {
      for session in sessionBatch {
        context.insert(session)
      }
      try context.save()
    }
    
    let startTime = Date()
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    let calculationTime = Date().timeIntervalSince(startTime)
    
    // Should complete within reasonable time
    #expect(calculationTime < 10.0, "Analytics calculation should complete within 10 seconds for 1000 sessions")
    
    // Verify data integrity
    #expect(analyticsData.totalSessions == 1000)
    #expect(analyticsData.totalDistance > 0)
    #expect(analyticsData.totalCalories > 0)
    #expect(analyticsData.averageDistance > 0)
  }
  
  @Test("Precompute analytics performance",
        .timeLimit(.minutes(2)))
  func precomputeAnalyticsPerformance() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createMultipleTestSessions(count: 50)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    let startTime = Date()
    try await analyticsRepository.precomputeAnalytics()
    let precomputeTime = Date().timeIntervalSince(startTime)
    
    #expect(precomputeTime < 30.0, "Precomputation should complete within 30 seconds")
    
    // Verify all common periods are cached
    for period in [AnalyticsTimePeriod.weekly, .monthly, .lastYear] {
      let data = try await analyticsRepository.fetchAnalyticsData(for: period)
      #expect(data.totalSessions >= 0)
    }
  }
  
  // MARK: - Edge Case Tests
  
  @Test("Analytics handles incomplete sessions correctly")
  func analyticsHandlesIncompleteSessions() async throws {
    let context = ModelContext(modelContainer)
    
    // Create complete session
    let completeSession = try createTestSession(loadWeight: 25.0, distance: 5000.0)
    completeSession.endDate = completeSession.startDate.addingTimeInterval(3600)
    
    // Create incomplete session (no end date)
    let incompleteSession = try createTestSession(loadWeight: 30.0, distance: 0)
    incompleteSession.endDate = nil
    
    context.insert(completeSession)
    context.insert(incompleteSession)
    try context.save()
    
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    // Should only include complete sessions
    #expect(analyticsData.totalSessions == 1)
    #expect(analyticsData.totalDistance == 5000.0)
  }
  
  @Test("Analytics handles zero values correctly")
  func analyticsHandlesZeroValues() async throws {
    let context = ModelContext(modelContainer)
    
    // Create session with zero distance
    let zeroDistanceSession = try createTestSession(loadWeight: 25.0, distance: 0)
    zeroDistanceSession.endDate = zeroDistanceSession.startDate.addingTimeInterval(3600)
    zeroDistanceSession.totalCalories = 0
    zeroDistanceSession.averagePace = 0
    
    context.insert(zeroDistanceSession)
    try context.save()
    
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    #expect(analyticsData.totalSessions == 1)
    #expect(analyticsData.totalDistance == 0)
    #expect(analyticsData.averageDistance == 0)
    #expect(analyticsData.totalWeightMoved == 0)
  }
  
  @Test("Cache expiration works correctly")
  func cacheExpirationWorks() async throws {
    let context = ModelContext(modelContainer)
    let session = try createTestSession(loadWeight: 25.0, distance: 5000.0)
    context.insert(session)
    try context.save()
    
    // Fetch data to populate cache
    _ = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    
    // Perform cache maintenance
    await analyticsRepository.performCacheMaintenance()
    
    // Cache should still be valid (within 5 minute expiry)
    let cachedData = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    #expect(cachedData.totalSessions == 1)
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
  
  private func createMultipleTestSessions(count: Int) async throws -> [RuckSession] {
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
  
  private func createVariedTestSessions() async throws -> [RuckSession] {
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
  
  private func createSessionsSpreadOverWeeks(weeks: Int) async throws -> [RuckSession] {
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
  
  private func createCurrentPeriodSessions() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<3 {
      let session = try createTestSession(
        loadWeight: 25.0,
        distance: Double(5000 + i * 1000)
      )
      session.startDate = Calendar.current.date(byAdding: .day, value: -i * 3, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createPreviousPeriodSessions() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<2 {
      let session = try createTestSession(
        loadWeight: 20.0,
        distance: Double(4000 + i * 500)
      )
      session.startDate = Calendar.current.date(byAdding: .day, value: -45 - i * 5, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createLargeTestDataset(sessionCount: Int) async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<sessionCount {
      let session = try createTestSession(
        loadWeight: Double.random(in: 15...50),
        distance: Double.random(in: 2000...20000),
        calories: Double.random(in: 200...1200),
        pace: Double.random(in: 4.0...8.0)
      )
      session.startDate = Calendar.current.date(byAdding: .hour, value: -i * 2, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(TimeInterval.random(in: 1800...7200))
      sessions.append(session)
    }
    
    return sessions
  }
}

// MARK: - Array Extension for Chunking

private extension Array {
  func chunked(into size: Int) -> [[Element]] {
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0..<Swift.min($0 + size, count)])
    }
  }
}