import XCTest
import SwiftData
import CoreLocation
@testable import RuckMap

/// Integration tests for analytics data models and calculations
final class AnalyticsIntegrationTests: XCTestCase {
  
  private var modelContainer: ModelContainer!
  private var analyticsRepository: AnalyticsRepository!
  private var analyticsViewModel: AnalyticsViewModel!
  
  override func setUp() async throws {
    try await super.setUp()
    
    // Create in-memory model container for testing
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    modelContainer = try ModelContainer(
      for: RuckSession.self, LocationPoint.self, TerrainSegment.self, WeatherConditions.self,
      configurations: configuration
    )
    
    analyticsRepository = AnalyticsRepository(modelContainer: modelContainer)
    analyticsViewModel = AnalyticsViewModel(modelContainer: modelContainer)
  }
  
  override func tearDown() async throws {
    analyticsRepository = nil
    analyticsViewModel = nil
    modelContainer = nil
    try await super.tearDown()
  }
  
  // MARK: - Analytics Data Model Tests
  
  func testAnalyticsDataCalculation() async throws {
    // Create test sessions
    let sessions = try await createTestSessions()
    
    // Calculate analytics data
    let analyticsData = AnalyticsData(
      sessions: sessions,
      timePeriod: .monthly
    )
    
    // Verify basic metrics
    XCTAssertEqual(analyticsData.totalSessions, sessions.count)
    XCTAssertGreaterThan(analyticsData.totalDistance, 0)
    XCTAssertGreaterThan(analyticsData.totalCalories, 0)
    XCTAssertGreaterThan(analyticsData.totalWeightMoved, 0)
    
    // Verify averages
    if sessions.count > 0 {
      XCTAssertGreaterThan(analyticsData.averageDistance, 0)
      XCTAssertGreaterThan(analyticsData.averageCalories, 0)
      XCTAssertGreaterThan(analyticsData.averageLoadWeight, 0)
    }
    
    // Verify personal records
    XCTAssertGreaterThan(analyticsData.longestDistance, 0)
    XCTAssertGreaterThan(analyticsData.heaviestLoad, 0)
    XCTAssertGreaterThan(analyticsData.highestCalorieBurn, 0)
  }
  
  func testPersonalRecordsCalculation() async throws {
    let sessions = try await createTestSessions()
    let personalRecords = PersonalRecords(sessions: sessions)
    
    // Verify records are valid
    XCTAssertTrue(personalRecords.longestDistance.isValid)
    XCTAssertTrue(personalRecords.heaviestLoad.isValid)
    XCTAssertTrue(personalRecords.highestCalorieBurn.isValid)
    XCTAssertTrue(personalRecords.longestDuration.isValid)
    
    // Verify longest distance record
    let expectedLongestDistance = sessions.map(\.totalDistance).max() ?? 0
    XCTAssertEqual(personalRecords.longestDistance.value, expectedLongestDistance, accuracy: 0.01)
    
    // Verify heaviest load record
    let expectedHeaviestLoad = sessions.map(\.loadWeight).max() ?? 0
    XCTAssertEqual(personalRecords.heaviestLoad.value, expectedHeaviestLoad, accuracy: 0.01)
  }
  
  func testWeeklyAnalyticsDataCalculation() async throws {
    let sessions = try await createTestSessionsSpreadOverWeeks()
    let weeklyData = WeeklyAnalyticsData(sessions: sessions, numberOfWeeks: 4)
    
    // Verify weekly data structure
    XCTAssertEqual(weeklyData.weeks.count, 4)
    XCTAssertGreaterThan(weeklyData.averageSessionsPerWeek, 0)
    XCTAssertGreaterThan(weeklyData.averageDistancePerWeek, 0)
    
    // Verify individual week data
    for week in weeklyData.weeks {
      XCTAssertNotNil(week.weekStart)
      XCTAssertNotNil(week.weekEnd)
      XCTAssertGreaterThanOrEqual(week.sessionCount, 0)
    }
  }
  
  func testTrainingStreakCalculation() async throws {
    // Create sessions with 2+ rucks per week for 3 consecutive weeks
    let sessions = try await createConsecutiveWeekSessions()
    
    let analyticsData = AnalyticsData(
      sessions: sessions,
      timePeriod: .lastMonth
    )
    
    // Should have a training streak of at least 3 weeks
    XCTAssertGreaterThanOrEqual(analyticsData.trainingStreak, 3)
    XCTAssertGreaterThan(analyticsData.averageSessionsPerWeek, 2.0)
  }
  
  func testTrendCalculation() async throws {
    let currentSessions = try await createTestSessions()
    let previousSessions = try await createPreviousPeriodSessions()
    
    let analyticsData = AnalyticsData(
      sessions: currentSessions,
      timePeriod: .monthly,
      previousPeriodSessions: previousSessions
    )
    
    // Verify trend data exists
    XCTAssertNotNil(analyticsData.distanceTrend)
    XCTAssertNotNil(analyticsData.calorieTrend)
    XCTAssertNotNil(analyticsData.sessionCountTrend)
    
    // Verify trend calculations
    if let distanceTrend = analyticsData.distanceTrend {
      XCTAssertEqual(distanceTrend.current, analyticsData.totalDistance, accuracy: 0.01)
      XCTAssertGreaterThanOrEqual(distanceTrend.previous, 0)
    }
  }
  
  // MARK: - Analytics Repository Tests
  
  func testAnalyticsRepositoryCaching() async throws {
    // Add test data to the model container
    let context = ModelContext(modelContainer)
    let sessions = try await createTestSessions()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // First fetch should compute fresh data
    let firstFetch = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    
    // Second fetch should return cached data (should be faster)
    let startTime = CFAbsoluteTimeGetCurrent()
    let secondFetch = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    let fetchTime = CFAbsoluteTimeGetCurrent() - startTime
    
    // Verify data consistency
    XCTAssertEqual(firstFetch.totalSessions, secondFetch.totalSessions)
    XCTAssertEqual(firstFetch.totalDistance, secondFetch.totalDistance, accuracy: 0.01)
    
    // Cache should make second fetch faster (though this might not always be true in tests)
    XCTAssertLessThan(fetchTime, 1.0) // Should complete within 1 second
  }
  
  func testAnalyticsRepositoryTimePeriodFiltering() async throws {
    // Create sessions spread across different time periods
    let context = ModelContext(modelContainer)
    let sessions = try await createSessionsAcrossTimeRanges()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // Test different time period filters
    let weeklyData = try await analyticsRepository.fetchAnalyticsData(for: .weekly)
    let monthlyData = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    let allTimeData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    // Weekly should have fewer sessions than monthly
    XCTAssertLessThanOrEqual(weeklyData.totalSessions, monthlyData.totalSessions)
    
    // Monthly should have fewer sessions than all-time
    XCTAssertLessThanOrEqual(monthlyData.totalSessions, allTimeData.totalSessions)
    
    // All-time should include all sessions
    XCTAssertEqual(allTimeData.totalSessions, sessions.count)
  }
  
  func testPersonalRecordsFetching() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createVariedTestSessions()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    let personalRecords = try await analyticsRepository.fetchPersonalRecords()
    
    // Verify personal records match expected values
    XCTAssertTrue(personalRecords.longestDistance.isValid)
    XCTAssertTrue(personalRecords.fastestPace.isValid)
    XCTAssertTrue(personalRecords.heaviestLoad.isValid)
    
    // Find expected records manually
    let expectedLongestDistance = sessions.map(\.totalDistance).max() ?? 0
    let expectedHeaviestLoad = sessions.map(\.loadWeight).max() ?? 0
    
    XCTAssertEqual(personalRecords.longestDistance.value, expectedLongestDistance, accuracy: 0.01)
    XCTAssertEqual(personalRecords.heaviestLoad.value, expectedHeaviestLoad, accuracy: 0.01)
  }
  
  // MARK: - Analytics View Model Tests
  
  @MainActor
  func testAnalyticsViewModelDataLoading() async throws {
    // Add test data
    let context = ModelContext(modelContainer)
    let sessions = try await createTestSessions()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // Load analytics data
    await analyticsViewModel.loadAllAnalyticsData()
    
    // Verify data was loaded
    XCTAssertNotNil(analyticsViewModel.analyticsData)
    XCTAssertNotNil(analyticsViewModel.personalRecords)
    XCTAssertNotNil(analyticsViewModel.weeklyAnalyticsData)
    
    // Verify computed properties
    XCTAssertTrue(analyticsViewModel.hasAnalyticsData)
    XCTAssertTrue(analyticsViewModel.hasPersonalRecords)
    XCTAssertTrue(analyticsViewModel.hasWeeklyData)
    
    XCTAssertEqual(analyticsViewModel.totalSessions, sessions.count)
    XCTAssertGreaterThan(analyticsViewModel.totalDistanceKm, 0)
    XCTAssertGreaterThan(analyticsViewModel.totalCalories, 0)
  }
  
  @MainActor
  func testAnalyticsViewModelTimePeriodChanges() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createSessionsAcrossTimeRanges()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // Test changing time periods
    await analyticsViewModel.changeTimePeriod(to: .weekly)
    await analyticsViewModel.loadAnalyticsData()
    let weeklySessionCount = analyticsViewModel.totalSessions
    
    await analyticsViewModel.changeTimePeriod(to: .monthly)
    await analyticsViewModel.loadAnalyticsData()
    let monthlySessionCount = analyticsViewModel.totalSessions
    
    // Monthly should have more or equal sessions than weekly
    XCTAssertGreaterThanOrEqual(monthlySessionCount, weeklySessionCount)
  }
  
  @MainActor
  func testAnalyticsViewModelFormatting() {
    // Test distance formatting
    let distanceFormatted = analyticsViewModel.formatDistance(5000) // 5km
    XCTAssertTrue(distanceFormatted.contains("5.00") || distanceFormatted.contains("5"))
    XCTAssertTrue(distanceFormatted.contains("km"))
    
    // Test pace formatting
    let paceFormatted = analyticsViewModel.formatPace(5.5) // 5:30/km
    XCTAssertTrue(paceFormatted.contains("5:30") || paceFormatted.contains("5:"))
    
    // Test duration formatting
    let durationFormatted = analyticsViewModel.formatDuration(3661) // 1h 1m 1s
    XCTAssertTrue(durationFormatted.contains("1h"))
    
    // Test calories formatting
    let caloriesFormatted = analyticsViewModel.formatCalories(1234)
    XCTAssertTrue(caloriesFormatted.contains("1234") || caloriesFormatted.contains("1.2k"))
  }
  
  // MARK: - Detailed Metrics Tests
  
  func testDetailedMetricsCalculation() async throws {
    let sessions = try await createVariedTestSessions()
    let detailedMetrics = DetailedMetrics(sessions: sessions, timePeriod: .monthly)
    
    // Verify pace buckets
    XCTAssertGreaterThan(detailedMetrics.paceBuckets.count, 0)
    
    // Verify distance buckets
    XCTAssertGreaterThan(detailedMetrics.distanceBuckets.count, 0)
    
    // Verify load distribution
    XCTAssertGreaterThan(detailedMetrics.loadWeightDistribution.count, 0)
    
    // Verify terrain distribution
    XCTAssertGreaterThan(detailedMetrics.terrainDistribution.count, 0)
    
    // Verify weather impact analysis
    XCTAssertNotNil(detailedMetrics.weatherImpactAnalysis)
  }
  
  // MARK: - Performance Tests
  
  func testAnalyticsPerformanceWithLargeDataset() async throws {
    // Create a large dataset
    let context = ModelContext(modelContainer)
    let largeSessions = try await createLargeTestDataset(sessionCount: 100)
    
    for session in largeSessions {
      context.insert(session)
    }
    try context.save()
    
    // Measure analytics calculation performance
    let startTime = CFAbsoluteTimeGetCurrent()
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    let calculationTime = CFAbsoluteTimeGetCurrent() - startTime
    
    // Should complete within reasonable time (adjust threshold as needed)
    XCTAssertLessThan(calculationTime, 5.0) // 5 seconds for 100 sessions
    
    // Verify data integrity with large dataset
    XCTAssertEqual(analyticsData.totalSessions, 100)
    XCTAssertGreaterThan(analyticsData.totalDistance, 0)
    XCTAssertGreaterThan(analyticsData.totalCalories, 0)
  }
  
  // MARK: - Helper Methods
  
  private func createTestSessions() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<5 {
      let session = try RuckSession(loadWeight: Double(20 + i * 5))
      session.startDate = Calendar.current.date(byAdding: .day, value: -i * 2, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600) // 1 hour
      session.totalDistance = Double(5000 + i * 1000) // 5-9 km
      session.totalCalories = Double(400 + i * 50)
      session.averagePace = Double(5.0 + Double(i) * 0.2) // 5.0-6.0 min/km
      session.totalDuration = 3600 // 1 hour
      session.elevationGain = Double(100 + i * 20)
      session.elevationLoss = Double(90 + i * 18)
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createTestSessionsSpreadOverWeeks() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    for week in 0..<4 {
      for session in 0..<3 { // 3 sessions per week
        let session = try RuckSession(loadWeight: 25.0)
        let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()) ?? Date()
        session.startDate = calendar.date(byAdding: .day, value: session, to: weekStart) ?? Date()
        session.endDate = session.startDate.addingTimeInterval(3600)
        session.totalDistance = 6000 // 6 km
        session.totalCalories = 450
        session.averagePace = 5.5
        session.totalDuration = 3600
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  private func createConsecutiveWeekSessions() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    // Create 3 consecutive weeks with 3 sessions each
    for week in 0..<3 {
      for sessionIndex in 0..<3 {
        let session = try RuckSession(loadWeight: 30.0)
        let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()) ?? Date()
        session.startDate = calendar.date(byAdding: .day, value: sessionIndex * 2, to: weekStart) ?? Date()
        session.endDate = session.startDate.addingTimeInterval(3600)
        session.totalDistance = 7000
        session.totalCalories = 500
        session.averagePace = 5.2
        session.totalDuration = 3600
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  private func createPreviousPeriodSessions() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<3 {
      let session = try RuckSession(loadWeight: 20.0)
      session.startDate = Calendar.current.date(byAdding: .day, value: -60 - i, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      session.totalDistance = Double(4000 + i * 500) // Slightly less than current
      session.totalCalories = Double(350 + i * 30)
      session.averagePace = Double(5.8 + Double(i) * 0.1)
      session.totalDuration = 3600
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createSessionsAcrossTimeRanges() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    let now = Date()
    
    // Sessions in different time periods
    let timeOffsets = [-3, -10, -40, -100, -200] // Days ago
    
    for (index, offset) in timeOffsets.enumerated() {
      let session = try RuckSession(loadWeight: Double(25 + index * 5))
      session.startDate = calendar.date(byAdding: .day, value: offset, to: now) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      session.totalDistance = Double(5000 + index * 1000)
      session.totalCalories = Double(400 + index * 50)
      session.averagePace = 5.5
      session.totalDuration = 3600
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createVariedTestSessions() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    // Create sessions with varying characteristics
    let configs = [
      (weight: 15.0, distance: 3000.0, pace: 4.5, calories: 300.0),
      (weight: 25.0, distance: 8000.0, pace: 5.2, calories: 550.0),
      (weight: 35.0, distance: 12000.0, pace: 6.0, calories: 800.0),
      (weight: 45.0, distance: 6000.0, pace: 5.8, calories: 650.0),
      (weight: 20.0, distance: 15000.0, pace: 5.0, calories: 900.0) // Longest distance
    ]
    
    for (index, config) in configs.enumerated() {
      let session = try RuckSession(loadWeight: config.weight)
      session.startDate = Calendar.current.date(byAdding: .day, value: -index * 3, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(TimeInterval(config.distance / 1000 * config.pace * 60))
      session.totalDistance = config.distance
      session.totalCalories = config.calories
      session.averagePace = config.pace
      session.totalDuration = TimeInterval(config.distance / 1000 * config.pace * 60)
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createLargeTestDataset(sessionCount: Int) async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<sessionCount {
      let session = try RuckSession(loadWeight: Double.random(in: 15...50))
      session.startDate = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(TimeInterval.random(in: 1800...7200)) // 30min-2hrs
      session.totalDistance = Double.random(in: 2000...20000) // 2-20km
      session.totalCalories = Double.random(in: 200...1200)
      session.averagePace = Double.random(in: 4.0...8.0)
      session.totalDuration = session.endDate?.timeIntervalSince(session.startDate) ?? 3600
      session.elevationGain = Double.random(in: 0...500)
      session.elevationLoss = Double.random(in: 0...500)
      
      sessions.append(session)
    }
    
    return sessions
  }
}