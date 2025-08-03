import Testing
import SwiftData
import SwiftUI
import Foundation
@testable import RuckMap

/// Performance tests for optimized analytics dashboard
@Suite("Optimized Analytics Performance Tests")
struct AnalyticsOptimizedPerformanceTests {
  
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
  
  // MARK: - Memory Pressure Tests
  
  @Test("Memory pressure handling with large datasets",
        .timeLimit(.minutes(2)))
  func memoryPressureHandlingWithLargeDatasets() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createLargeTestDataset(sessionCount: 2000)
    
    // Insert sessions in batches
    for sessionBatch in sessions.chunked(into: 200) {
      for session in sessionBatch {
        context.insert(session)
      }
      try context.save()
    }
    
    // Fill cache with multiple time periods
    let timePeriods: [AnalyticsTimePeriod] = [.weekly, .monthly, .last3Months, .last6Months, .lastYear, .allTime]
    for period in timePeriods {
      _ = try await analyticsRepository.fetchAnalyticsData(for: period)
    }
    
    // Simulate memory pressure
    let startTime = Date()
    await analyticsRepository.handleMemoryPressure()
    let handlingTime = Date().timeIntervalSince(startTime)
    
    #expect(handlingTime < 1.0, "Memory pressure handling should complete quickly")
    
    // Verify that data can still be fetched after memory pressure
    let data = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    #expect(data.totalSessions > 0)
  }
  
  @Test("Chart data optimization performance",
        .timeLimit(.seconds(30)))
  func chartDataOptimizationPerformance() async throws {
    // Create large dataset for chart optimization testing
    let weeklyData = createLargeWeeklyDataset(weekCount: 500)
    let optimizedChartData = OptimizedChartData<WeekData>(maxDisplayPoints: 100, strategy: .adaptive)
    
    let startTime = Date()
    await optimizedChartData.updateData(weeklyData)
    let optimizationTime = Date().timeIntervalSince(startTime)
    
    #expect(optimizationTime < 5.0, "Chart data optimization should complete within 5 seconds")
    #expect(optimizedChartData.displayData.count <= 100, "Optimized data should respect max points limit")
    #expect(!optimizedChartData.displayData.isEmpty, "Optimized data should not be empty")
  }
  
  @Test("Douglas-Peucker sampling performance",
        .timeLimit(.seconds(10)))
  func douglasPeuckerSamplingPerformance() async throws {
    let largeDataset = createLargeWeeklyDataset(weekCount: 1000)
    
    let startTime = Date()
    let sampledData = ChartDataSampler.sampleLineData(largeDataset, maxPoints: 100)
    let samplingTime = Date().timeIntervalSince(startTime)
    
    #expect(samplingTime < 2.0, "Douglas-Peucker sampling should complete within 2 seconds")
    #expect(sampledData.count <= 100, "Sampled data should respect max points limit")
    #expect(sampledData.count >= 2, "Sampled data should have at least start and end points")
  }
  
  @Test("Peak detection sampling performance",
        .timeLimit(.seconds(10)))
  func peakDetectionSamplingPerformance() async throws {
    let largeDataset = createVariedWeeklyDataset(weekCount: 1000)
    
    let startTime = Date()
    let sampledData = ChartDataSampler.sampleWithPeakDetection(largeDataset, maxPoints: 100)
    let samplingTime = Date().timeIntervalSince(startTime)
    
    #expect(samplingTime < 2.0, "Peak detection sampling should complete within 2 seconds")
    #expect(sampledData.count <= 100, "Sampled data should respect max points limit")
    #expect(sampledData.count >= 2, "Sampled data should have at least start and end points")
  }
  
  // MARK: - Background Processing Tests
  
  @Test("Background analytics loading performance",
        .timeLimit(.seconds(45)))
  func backgroundAnalyticsLoadingPerformance() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createLargeTestDataset(sessionCount: 1000)
    
    for sessionBatch in sessions.chunked(into: 100) {
      for session in sessionBatch {
        context.insert(session)
      }
      try context.save()
    }
    
    let startTime = Date()
    
    // Start multiple background tasks
    let backgroundTask1 = analyticsRepository.fetchAnalyticsDataInBackground(for: .monthly, priority: .background)
    let backgroundTask2 = analyticsRepository.fetchAnalyticsDataInBackground(for: .weekly, priority: .background)
    let backgroundTask3 = analyticsRepository.fetchAnalyticsDataInBackground(for: .last3Months, priority: .background)
    
    let results = try await [backgroundTask1.value, backgroundTask2.value, backgroundTask3.value]
    let totalTime = Date().timeIntervalSince(startTime)
    
    #expect(totalTime < 30.0, "Background loading should complete within 30 seconds")
    #expect(results.count == 3, "All background tasks should complete successfully")
    
    for result in results {
      #expect(result.totalSessions > 0, "Background loaded data should be valid")
    }
  }
  
  @Test("Concurrent chart optimization performance",
        .timeLimit(.seconds(20)))
  func concurrentChartOptimizationPerformance() async throws {
    let datasets = [
      createLargeWeeklyDataset(weekCount: 300),
      createLargeWeeklyDataset(weekCount: 400),
      createLargeWeeklyDataset(weekCount: 500)
    ]
    
    let startTime = Date()
    
    await withTaskGroup(of: Void.self) { group in
      for (index, dataset) in datasets.enumerated() {
        group.addTask {
          let optimizedData = OptimizedChartData<WeekData>(strategy: .adaptive)
          await optimizedData.updateData(dataset)
        }
      }
    }
    
    let totalTime = Date().timeIntervalSince(startTime)
    #expect(totalTime < 15.0, "Concurrent chart optimization should complete within 15 seconds")
  }
  
  // MARK: - Cache Performance Tests
  
  @Test("Optimized cache performance with priority ordering",
        .timeLimit(.seconds(30)))
  func optimizedCachePerformanceWithPriorityOrdering() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createLargeTestDataset(sessionCount: 1000)
    
    for sessionBatch in sessions.chunked(into: 100) {
      for session in sessionBatch {
        context.insert(session)
      }
      try context.save()
    }
    
    // Test prioritized precomputation
    let startTime = Date()
    try await analyticsRepository.precomputeAnalytics()
    let precomputeTime = Date().timeIntervalSince(startTime)
    
    #expect(precomputeTime < 45.0, "Prioritized precomputation should complete within 45 seconds")
    
    // Verify cache hits are fast
    let cacheTestStart = Date()
    _ = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    _ = try await analyticsRepository.fetchAnalyticsData(for: .weekly)
    _ = try await analyticsRepository.fetchAnalyticsData(for: .last3Months)
    let cacheTime = Date().timeIntervalSince(cacheTestStart)
    
    #expect(cacheTime < 1.0, "Cached data access should be very fast")
  }
  
  @Test("Cache maintenance performance under load",
        .timeLimit(.seconds(15)))
  func cacheMaintenancePerformanceUnderLoad() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createLargeTestDataset(sessionCount: 500)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // Fill cache with many entries
    let allPeriods = AnalyticsTimePeriod.allCases
    for period in allPeriods {
      _ = try await analyticsRepository.fetchAnalyticsData(for: period)
    }
    
    // Perform cache maintenance multiple times
    let startTime = Date()
    for _ in 0..<10 {
      await analyticsRepository.performCacheMaintenance()
    }
    let maintenanceTime = Date().timeIntervalSince(startTime)
    
    #expect(maintenanceTime < 5.0, "Cache maintenance should be efficient even under load")
  }
  
  // MARK: - Real-world Simulation Tests
  
  @Test("Dashboard loading simulation with mixed operations",
        .timeLimit(.minutes(1)))
  func dashboardLoadingSimulationWithMixedOperations() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createRealisticTestDataset()
    
    for sessionBatch in sessions.chunked(into: 50) {
      for session in sessionBatch {
        context.insert(session)
      }
      try context.save()
    }
    
    let startTime = Date()
    
    // Simulate real dashboard loading pattern
    async let analyticsData = analyticsRepository.fetchAnalyticsData(for: .monthly)
    async let personalRecords = analyticsRepository.fetchPersonalRecords()
    async let weeklyData = analyticsRepository.fetchWeeklyAnalyticsData(numberOfWeeks: 12)
    async let detailedMetrics = analyticsRepository.fetchDetailedMetrics(for: .monthly)
    
    let results = try await (analyticsData, personalRecords, weeklyData, detailedMetrics)
    let totalTime = Date().timeIntervalSince(startTime)
    
    #expect(totalTime < 30.0, "Dashboard loading simulation should complete within 30 seconds")
    
    // Verify data quality
    #expect(results.0.totalSessions > 0)
    #expect(results.1.longestDistance.isValid)
    #expect(results.2.weeks.count == 12)
    #expect(results.3.sessions.count > 0)
  }
  
  @Test("High-frequency dashboard updates performance",
        .timeLimit(.seconds(30)))
  func highFrequencyDashboardUpdatesPerformance() async throws {
    let context = ModelContext(modelContainer)
    let initialSessions = try await createLargeTestDataset(sessionCount: 100)
    
    for session in initialSessions {
      context.insert(session)
    }
    try context.save()
    
    let startTime = Date()
    
    // Simulate high-frequency updates (like during active session)
    for i in 0..<20 {
      let newSession = try createTestSession(
        loadWeight: 25.0,
        distance: 5000.0 + Double(i * 100),
        sessionIndex: 100 + i
      )
      context.insert(newSession)
      try context.save()
      
      // Invalidate cache and fetch fresh data
      await analyticsRepository.invalidateCache()
      _ = try await analyticsRepository.fetchAnalyticsData(for: .weekly)
    }
    
    let totalTime = Date().timeIntervalSince(startTime)
    #expect(totalTime < 25.0, "High-frequency updates should maintain good performance")
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
  
  private func createLargeWeeklyDataset(weekCount: Int) -> [WeekData] {
    var weekData: [WeekData] = []
    let calendar = Calendar.current
    
    for i in 0..<weekCount {
      let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: Date()) ?? Date()
      let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
      
      // Create random sessions for this week
      var sessions: [RuckSession] = []
      let sessionCount = Int.random(in: 0...5)
      
      for j in 0..<sessionCount {
        do {
          let session = try RuckSession(loadWeight: Double.random(in: 15...50))
          session.startDate = calendar.date(byAdding: .day, value: j, to: weekStart) ?? weekStart
          session.endDate = session.startDate.addingTimeInterval(3600)
          session.totalDistance = Double.random(in: 2000...15000)
          session.totalCalories = Double.random(in: 200...800)
          session.averagePace = Double.random(in: 5.0...8.0)
          session.totalDuration = 3600
          sessions.append(session)
        } catch {
          // Skip if session creation fails
          continue
        }
      }
      
      let weekDataItem = WeekData(
        weekStart: weekStart,
        weekEnd: weekEnd,
        sessions: sessions
      )
      weekData.append(weekDataItem)
    }
    
    return weekData.reversed() // Oldest to newest
  }
  
  private func createVariedWeeklyDataset(weekCount: Int) -> [WeekData] {
    var weekData = createLargeWeeklyDataset(weekCount: weekCount)
    
    // Add artificial peaks and valleys for peak detection testing
    for i in stride(from: 0, to: weekData.count, by: 20) {
      if i < weekData.count {
        // Create artificial peak
        var sessions = weekData[i].sessions
        do {
          let peakSession = try RuckSession(loadWeight: 45.0)
          peakSession.startDate = weekData[i].weekStart
          peakSession.endDate = peakSession.startDate.addingTimeInterval(3600)
          peakSession.totalDistance = 25000 // High distance for peak
          peakSession.totalCalories = 1200
          peakSession.averagePace = 4.5
          peakSession.totalDuration = 3600
          sessions.append(peakSession)
          
          weekData[i] = WeekData(
            weekStart: weekData[i].weekStart,
            weekEnd: weekData[i].weekEnd,
            sessions: sessions
          )
        } catch {
          // Skip if session creation fails
          continue
        }
      }
    }
    
    return weekData
  }
  
  private func createRealisticTestDataset(weeks: Int = 52) async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    for week in 0..<weeks {
      let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()) ?? Date()
      
      // Realistic pattern: 2-3 sessions per week on average
      let sessionCount = Int.random(in: 1...4)
      
      for sessionIndex in 0..<sessionCount {
        let session = try RuckSession(loadWeight: Double.random(in: 20...40))
        session.startDate = calendar.date(byAdding: .day, value: sessionIndex * 2, to: weekStart) ?? weekStart
        session.endDate = session.startDate.addingTimeInterval(TimeInterval.random(in: 2700...5400)) // 45-90 minutes
        session.totalDistance = Double.random(in: 3000...12000) // 3-12km realistic range
        session.totalCalories = Double.random(in: 300...900)
        session.averagePace = Double.random(in: 5.5...7.5) // Realistic ruck pace
        session.totalDuration = session.endDate?.timeIntervalSince(session.startDate) ?? 3600
        session.elevationGain = Double.random(in: 50...300)
        session.elevationLoss = Double.random(in: 50...300)
        
        sessions.append(session)
      }
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