import Testing
import SwiftData
import Foundation
@testable import RuckMap

/// Performance and stress tests for Analytics using Swift Testing framework
@Suite("Analytics Performance Tests")
struct AnalyticsPerformanceTests {
  
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
  
  // MARK: - Large Dataset Performance Tests
  
  @Test("Analytics calculation with 1000 sessions",
        .timeLimit(.minutes(2)))
  func analyticsCalculationWith1000Sessions() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createLargeTestDataset(sessionCount: 1000)
    
    // Insert sessions in batches to avoid memory pressure
    for sessionBatch in sessions.chunked(into: 100) {
      for session in sessionBatch {
        context.insert(session)
      }
      try context.save()
    }
    
    let startTime = Date()
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    let calculationTime = Date().timeIntervalSince(startTime)
    
    // Performance assertions
    #expect(calculationTime < 15.0, "Analytics calculation should complete within 15 seconds for 1000 sessions")
    
    // Data integrity assertions
    #expect(analyticsData.totalSessions == 1000)
    #expect(analyticsData.totalDistance > 0)
    #expect(analyticsData.totalCalories > 0)
    #expect(analyticsData.averageDistance > 0)
    #expect(analyticsData.averageCalories > 0)
  }
  
  @Test("Personal records calculation with 5000 sessions",
        .timeLimit(.minutes(3)))
  func personalRecordsCalculationWith5000Sessions() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createLargeTestDataset(sessionCount: 5000)
    
    // Insert sessions in larger batches for performance
    for sessionBatch in sessions.chunked(into: 500) {
      for session in sessionBatch {
        context.insert(session)
      }
      try context.save()
    }
    
    let startTime = Date()
    let personalRecords = try await analyticsRepository.fetchPersonalRecords()
    let calculationTime = Date().timeIntervalSince(startTime)
    
    // Performance assertions
    #expect(calculationTime < 20.0, "Personal records calculation should complete within 20 seconds for 5000 sessions")
    
    // Data integrity assertions
    #expect(personalRecords.longestDistance.isValid)
    #expect(personalRecords.fastestPace.isValid)
    #expect(personalRecords.heaviestLoad.isValid)
    #expect(personalRecords.highestCalorieBurn.isValid)
  }
  
  @Test("Weekly analytics with large dataset",
        .timeLimit(.minutes(1)))
  func weeklyAnalyticsWithLargeDataset() async throws {
    let context = ModelContext(modelContainer)
    
    // Create 2 years worth of sessions (approximately 2000 sessions)
    let sessions = try await createSessionsOverTimeRange(
      startDate: Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date(),
      endDate: Date(),
      averageSessionsPerWeek: 20
    )
    
    for sessionBatch in sessions.chunked(into: 200) {
      for session in sessionBatch {
        context.insert(session)
      }
      try context.save()
    }
    
    let startTime = Date()
    let weeklyData = try await analyticsRepository.fetchWeeklyAnalyticsData(numberOfWeeks: 52)
    let calculationTime = Date().timeIntervalSince(startTime)
    
    // Performance assertions
    #expect(calculationTime < 10.0, "Weekly analytics calculation should complete within 10 seconds")
    
    // Data integrity assertions
    #expect(weeklyData.weeks.count == 52)
    #expect(weeklyData.averageSessionsPerWeek > 0)
    #expect(weeklyData.averageDistancePerWeek > 0)
  }
  
  // MARK: - Cache Performance Tests
  
  @Test("Cache performance with multiple time periods",
        .timeLimit(.seconds(30)))
  func cachePerformanceWithMultipleTimePeriods() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createLargeTestDataset(sessionCount: 500)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    let timePeriods: [AnalyticsTimePeriod] = [.weekly, .monthly, .last3Months, .lastYear, .allTime]
    
    // First fetch - should populate cache
    let firstFetchStart = Date()
    for period in timePeriods {
      _ = try await analyticsRepository.fetchAnalyticsData(for: period)
    }
    let firstFetchTime = Date().timeIntervalSince(firstFetchStart)
    
    // Second fetch - should use cache
    let secondFetchStart = Date()
    for period in timePeriods {
      _ = try await analyticsRepository.fetchAnalyticsData(for: period)
    }
    let secondFetchTime = Date().timeIntervalSince(secondFetchStart)
    
    // Cache should make subsequent fetches significantly faster
    #expect(secondFetchTime < firstFetchTime * 0.5, "Cached fetches should be at least 50% faster")
    #expect(secondFetchTime < 5.0, "Cached fetches should complete within 5 seconds")
  }
  
  @Test("Precompute analytics performance",
        .timeLimit(.minutes(2)))
  func precomputeAnalyticsPerformance() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createLargeTestDataset(sessionCount: 1000)
    
    for sessionBatch in sessions.chunked(into: 100) {
      for session in sessionBatch {  
        context.insert(session)
      }
      try context.save()
    }
    
    let startTime = Date()
    try await analyticsRepository.precomputeAnalytics()
    let precomputeTime = Date().timeIntervalSince(startTime)
    
    #expect(precomputeTime < 60.0, "Precompute analytics should complete within 1 minute for 1000 sessions")
    
    // Verify all periods are cached by checking fast subsequent access
    let verifyStart = Date()
    for period in [AnalyticsTimePeriod.weekly, .monthly, .lastYear, .allTime] {
      _ = try await analyticsRepository.fetchAnalyticsData(for: period)
    }
    let verifyTime = Date().timeIntervalSince(verifyStart)
    
    #expect(verifyTime < 2.0, "Accessing precomputed analytics should be very fast")
  }
  
  // MARK: - Memory Performance Tests
  
  @Test("Memory efficiency with large datasets",
        .timeLimit(.minutes(3)))
  func memoryEfficiencyWithLargeDatasets() async throws {
    let context = ModelContext(modelContainer)
    
    // Create and process multiple batches to test memory management
    let batchSize = 1000
    let numberOfBatches = 5
    
    for batchIndex in 0..<numberOfBatches {
      let sessions = try await createLargeTestDataset(sessionCount: batchSize)
      
      for session in sessions {
        context.insert(session)
      }
      try context.save()
      
      // Process analytics for each batch
      let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
      #expect(analyticsData.totalSessions == (batchIndex + 1) * batchSize)
      
      // Clear cache to test memory management
      await analyticsRepository.invalidateCache()
    }
    
    // Final verification
    let finalData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    #expect(finalData.totalSessions == numberOfBatches * batchSize)
  }
  
  @Test("Concurrent analytics requests performance",
        .timeLimit(.minutes(1)))
  func concurrentAnalyticsRequestsPerformance() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createLargeTestDataset(sessionCount: 500)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    let startTime = Date()
    
    // Start multiple concurrent analytics requests
    async let weekly = analyticsRepository.fetchAnalyticsData(for: .weekly)
    async let monthly = analyticsRepository.fetchAnalyticsData(for: .monthly)
    async let quarterly = analyticsRepository.fetchAnalyticsData(for: .last3Months)
    async let yearly = analyticsRepository.fetchAnalyticsData(for: .lastYear)
    async let allTime = analyticsRepository.fetchAnalyticsData(for: .allTime)
    async let personalRecords = analyticsRepository.fetchPersonalRecords()
    async let weeklyData = analyticsRepository.fetchWeeklyAnalyticsData(numberOfWeeks: 12)
    
    // Wait for all requests to complete
    let results = try await (weekly, monthly, quarterly, yearly, allTime, personalRecords, weeklyData)
    
    let totalTime = Date().timeIntervalSince(startTime)
    
    // Concurrent execution should be faster than sequential
    #expect(totalTime < 30.0, "Concurrent analytics requests should complete within 30 seconds")
    
    // Verify all results are valid
    #expect(results.0.totalSessions >= 0) // weekly
    #expect(results.1.totalSessions >= 0) // monthly
    #expect(results.2.totalSessions >= 0) // quarterly
    #expect(results.3.totalSessions >= 0) // yearly
    #expect(results.4.totalSessions == 500) // allTime
    #expect(results.5.longestDistance.value >= 0) // personalRecords
    #expect(results.6.weeks.count == 12) // weeklyData
  }
  
  // MARK: - Query Optimization Performance Tests
  
  @Test("SwiftData query performance with property filtering",
        .timeLimit(.seconds(30)))
  func swiftDataQueryPerformanceWithPropertyFiltering() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createLargeTestDataset(sessionCount: 2000)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // Test optimized property fetching vs full object fetching
    let startTimeOptimized = Date()
    
    // This should use the optimized query from AnalyticsRepository
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    let optimizedTime = Date().timeIntervalSince(startTimeOptimized)
    
    #expect(optimizedTime < 15.0, "Optimized query should complete within 15 seconds for 2000 sessions")
    #expect(analyticsData.totalSessions == 2000)
  }
  
  @Test("Time period filtering performance",
        .timeLimit(.seconds(20)))
  func timePeriodFilteringPerformance() async throws {
    let context = ModelContext(modelContainer)
    
    // Create sessions spread over 3 years
    let sessions = try await createSessionsOverTimeRange(
      startDate: Calendar.current.date(byAdding: .year, value: -3, to: Date()) ?? Date(),
      endDate: Date(),
      averageSessionsPerWeek: 10
    )
    
    for sessionBatch in sessions.chunked(into: 200) {
      for session in sessionBatch {
        context.insert(session)
      }
      try context.save()
    }
    
    // Test filtering performance for different time periods
    let timePeriods: [AnalyticsTimePeriod] = [.weekly, .monthly, .last3Months, .lastYear]
    
    for period in timePeriods {
      let startTime = Date()
      let data = try await analyticsRepository.fetchAnalyticsData(for: period)
      let filterTime = Date().timeIntervalSince(startTime)
      
      #expect(filterTime < 5.0, "Time period filtering for \(period.rawValue) should complete within 5 seconds")
      #expect(data.totalSessions >= 0)
    }
  }
  
  // MARK: - Stress Tests
  
  @Test("Rapid cache invalidation and rebuild stress test",
        .timeLimit(.minutes(2)))
  func rapidCacheInvalidationAndRebuildStressTest() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createLargeTestDataset(sessionCount: 200)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // Perform rapid cache invalidation and rebuild cycles
    let cycles = 10
    let startTime = Date()
    
    for cycle in 0..<cycles {
      // Load data to populate cache
      _ = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
      _ = try await analyticsRepository.fetchPersonalRecords()
      
      // Invalidate cache
      await analyticsRepository.invalidateCache()
      
      // Add a new session to force fresh calculations
      let newSession = try createTestSession(
        loadWeight: Double(25 + cycle),
        distance: Double(5000 + cycle * 100),
        sessionIndex: sessions.count + cycle
      )
      context.insert(newSession)
      try context.save()
    }
    
    let totalTime = Date().timeIntervalSince(startTime)
    #expect(totalTime < 60.0, "Rapid cache invalidation cycles should complete within 1 minute")
    
    // Verify final data integrity
    let finalData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    #expect(finalData.totalSessions == sessions.count + cycles)
  }
  
  @Test("High frequency analytics requests simulation",
        .timeLimit(.seconds(45)))
  func highFrequencyAnalyticsRequestsSimulation() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createLargeTestDataset(sessionCount: 100)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // Simulate high frequency requests like a real-time dashboard
    let requestCount = 50
    let timePeriods: [AnalyticsTimePeriod] = [.weekly, .monthly, .last3Months]
    
    let startTime = Date()
    
    // Use TaskGroup for concurrent high-frequency requests
    try await withThrowingTaskGroup(of: AnalyticsData.self) { group in
      for i in 0..<requestCount {
        let period = timePeriods[i % timePeriods.count]
        group.addTask {
          return try await self.analyticsRepository.fetchAnalyticsData(for: period)
        }
      }
      
      // Collect all results
      var results: [AnalyticsData] = []
      for try await result in group {
        results.append(result)
      }
      
      #expect(results.count == requestCount)
    }
    
    let totalTime = Date().timeIntervalSince(startTime)
    #expect(totalTime < 30.0, "High frequency requests should complete within 30 seconds")
  }
  
  // MARK: - Detailed Metrics Performance Tests
  
  @Test("Detailed metrics calculation performance",
        .timeLimit(.minutes(1)))
  func detailedMetricsCalculationPerformance() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createVariedTestSessionsForDetailedMetrics(count: 1000)
    
    for sessionBatch in sessions.chunked(into: 100) {
      for session in sessionBatch {
        context.insert(session)
      }
      try context.save()
    }
    
    let startTime = Date()
    let detailedMetrics = try await analyticsRepository.fetchDetailedMetrics(for: .allTime)
    let calculationTime = Date().timeIntervalSince(startTime)
    
    #expect(calculationTime < 30.0, "Detailed metrics calculation should complete within 30 seconds")
    
    // Verify detailed metrics completeness
    #expect(detailedMetrics.paceBuckets.count > 0)
    #expect(detailedMetrics.distanceBuckets.count > 0)
    #expect(detailedMetrics.loadWeightDistribution.count > 0)
    #expect(detailedMetrics.terrainDistribution.count > 0)
    #expect(detailedMetrics.paceConsistency >= 0)
  }
  
  // MARK: - Helper Methods
  
  private func createLargeTestDataset(sessionCount: Int) async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<sessionCount {
      let session = try createTestSession(
        loadWeight: Double.random(in: 15...50),
        distance: Double.random(in: 2000...20000),
        sessionIndex: i
      )
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createTestSession(
    loadWeight: Double,
    distance: Double,
    sessionIndex: Int
  ) throws -> RuckSession {
    let session = try RuckSession(loadWeight: loadWeight)
    session.startDate = Calendar.current.date(byAdding: .hour, value: -sessionIndex * 2, to: Date()) ?? Date()
    session.endDate = session.startDate.addingTimeInterval(TimeInterval.random(in: 1800...7200))
    session.totalDistance = distance
    session.totalCalories = Double.random(in: 200...1200)
    session.averagePace = Double.random(in: 4.0...8.0)
    session.totalDuration = session.endDate?.timeIntervalSince(session.startDate) ?? 3600
    session.elevationGain = Double.random(in: 0...500)
    session.elevationLoss = Double.random(in: 0...500)
    return session
  }
  
  private func createSessionsOverTimeRange(
    startDate: Date,
    endDate: Date,
    averageSessionsPerWeek: Int
  ) async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    var currentDate = startDate
    let daysBetween = Int(endDate.timeIntervalSince(startDate) / 86400)
    
    for dayOffset in 0..<daysBetween {
      currentDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
      
      // Randomly decide if there's a session on this day
      // Average sessions per week means probability = averageSessionsPerWeek / 7
      let probability = Double(averageSessionsPerWeek) / 7.0
      
      if Double.random(in: 0...1) < probability {
        let session = try RuckSession(loadWeight: Double.random(in: 15...50))
        session.startDate = currentDate
        session.endDate = currentDate.addingTimeInterval(TimeInterval.random(in: 1800...7200))
        session.totalDistance = Double.random(in: 2000...20000)
        session.totalCalories = Double.random(in: 200...1200)
        session.averagePace = Double.random(in: 4.0...8.0)
        session.totalDuration = session.endDate?.timeIntervalSince(session.startDate) ?? 3600
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  private func createVariedTestSessionsForDetailedMetrics(count: Int) async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    // Create sessions with varied characteristics for detailed metrics
    let terrainTypes: [TerrainType] = [.pavedRoad, .trail, .sand, .grass, .gravel]
    
    for i in 0..<count {
      let session = try RuckSession(loadWeight: Double.random(in: 15...50))
      session.startDate = Calendar.current.date(byAdding: .hour, value: -i * 2, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(TimeInterval.random(in: 1800...7200))
      session.totalDistance = Double.random(in: 2000...20000)
      session.totalCalories = Double.random(in: 200...1200)
      session.averagePace = Double.random(in: 4.0...8.0)
      session.totalDuration = session.endDate?.timeIntervalSince(session.startDate) ?? 3600
      
      // Add terrain segments for detailed analysis
      let terrainSegment = TerrainSegment()
      terrainSegment.terrainType = terrainTypes.randomElement() ?? .pavedRoad
      terrainSegment.duration = TimeInterval.random(in: 600...3600)
      terrainSegment.session = session
      session.terrainSegments.append(terrainSegment)
      
      // Add weather conditions for some sessions
      if i % 3 == 0 {
        let weather = WeatherConditions()
        weather.temperature = Double.random(in: -10...40)
        weather.humidity = Double.random(in: 20...90)
        weather.windSpeed = Double.random(in: 0...25)
        weather.precipitation = Double.random(in: 0...20)
        weather.session = session
        session.weatherConditions = weather
      }
      
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