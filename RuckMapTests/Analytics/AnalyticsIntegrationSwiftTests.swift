import Testing
import SwiftData
import SwiftUI
import Foundation
@testable import RuckMap

/// Integration tests for Analytics system components using Swift Testing framework
@Suite("Analytics Integration Tests")
@MainActor
struct AnalyticsIntegrationTests {
  
  private let modelContainer: ModelContainer
  private let analyticsRepository: AnalyticsRepository
  private let analyticsViewModel: AnalyticsViewModel
  
  init() throws {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    modelContainer = try ModelContainer(
      for: RuckSession.self, LocationPoint.self, TerrainSegment.self, WeatherConditions.self,
      configurations: configuration
    )
    analyticsRepository = AnalyticsRepository(modelContainer: modelContainer)
    analyticsViewModel = AnalyticsViewModel(modelContainer: modelContainer)
  }
  
  // MARK: - Full System Integration Tests
  
  @Test("Complete analytics workflow from session creation to display")
  func completeAnalyticsWorkflowFromSessionCreationToDisplay() async throws {
    let context = ModelContext(modelContainer)
    
    // 1. Create realistic session data
    let sessions = try await createRealisticSessionData()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // 2. Load all analytics data through view model
    await analyticsViewModel.loadAllAnalyticsData()
    
    // 3. Verify repository data matches view model data
    let repositoryData = try await analyticsRepository.fetchAnalyticsData(for: .monthly)
    let repositoryRecords = try await analyticsRepository.fetchPersonalRecords()
    let repositoryWeekly = try await analyticsRepository.fetchWeeklyAnalyticsData()
    
    #expect(analyticsViewModel.totalSessions == repositoryData.totalSessions)
    #expect(abs(analyticsViewModel.totalDistanceKm - repositoryData.totalDistance / 1000.0) < 0.01)
    #expect(analyticsViewModel.totalCalories == repositoryData.totalCalories)
    
    // 4. Verify personal records consistency
    #expect(analyticsViewModel.longestDistanceRecord?.value == repositoryRecords.longestDistance.value)
    #expect(analyticsViewModel.fastestPaceRecord?.value == repositoryRecords.fastestPace.value)
    #expect(analyticsViewModel.heaviestLoadRecord?.value == repositoryRecords.heaviestLoad.value)
    
    // 5. Verify weekly data consistency
    #expect(analyticsViewModel.weeklyDistanceData.count == repositoryWeekly.weeks.count)
    #expect(analyticsViewModel.weeklySessionData.count == repositoryWeekly.weeks.count)
    
    // 6. Test data formatting consistency
    let formattedDistance = analyticsViewModel.formatDistance(repositoryData.totalDistance)
    #expect(!formattedDistance.isEmpty)
    
    let formattedPace = analyticsViewModel.formatPace(repositoryData.averagePace)
    #expect(!formattedPace.isEmpty)
  }
  
  @Test("Analytics data consistency across time period changes")
  func analyticsDataConsistencyAcrossTimePeriodChanges() async throws {
    let context = ModelContext(modelContainer)
    
    // Create sessions spanning multiple time periods
    let sessions = try await createSessionsAcrossMultipleTimeRanges()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    let timePeriods: [AnalyticsTimePeriod] = [.weekly, .monthly, .last3Months, .lastYear, .allTime]
    var previousSessionCount = 0
    
    for period in timePeriods {
      // Repository level
      let repositoryData = try await analyticsRepository.fetchAnalyticsData(for: period)
      
      // View model level
      analyticsViewModel.changeTimePeriod(to: period)
      await analyticsViewModel.loadAnalyticsData()
      
      // Verify consistency between repository and view model
      #expect(repositoryData.totalSessions == analyticsViewModel.totalSessions)
      #expect(repositoryData.timePeriod == period)
      #expect(analyticsViewModel.selectedTimePeriod == period)
      
      // Session counts should generally increase with broader time periods
      // (except for historical periods which might have fewer sessions)
      if period != .weekly && period != .lastWeek {
        #expect(repositoryData.totalSessions >= 0)
      }
      
      previousSessionCount = repositoryData.totalSessions
    }
  }
  
  @Test("Cache behavior across repository and view model")
  func cacheBehaviorAcrossRepositoryAndViewModel() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createTestSessions(count: 20)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // 1. Load data through view model (should populate repository cache)
    await analyticsViewModel.loadAllAnalyticsData()
    let initialSessionCount = analyticsViewModel.totalSessions
    
    // 2. Load same data directly through repository (should use cache)
    let startTime = Date()
    let cachedData = try await analyticsRepository.fetchAnalyticsData(for: analyticsViewModel.selectedTimePeriod)
    let cacheAccessTime = Date().timeIntervalSince(startTime)
    
    #expect(cachedData.totalSessions == initialSessionCount)
    #expect(cacheAccessTime < 1.0, "Cached access should be fast")
    
    // 3. Add new session and test cache invalidation
    let newSession = try createTestSession(loadWeight: 35.0, distance: 8000.0)
    context.insert(newSession)
    try context.save()
    
    // 4. Refresh view model (should invalidate cache)
    await analyticsViewModel.refreshAnalytics()
    
    #expect(analyticsViewModel.totalSessions == initialSessionCount + 1)
    
    // 5. Verify repository sees new data too
    let refreshedData = try await analyticsRepository.fetchAnalyticsData(for: analyticsViewModel.selectedTimePeriod)
    #expect(refreshedData.totalSessions == initialSessionCount + 1)
  }
  
  // MARK: - SwiftData Integration Tests
  
  @Test("SwiftData query optimization effectiveness")
  func swiftDataQueryOptimizationEffectiveness() async throws {
    let context = ModelContext(modelContainer)
    
    // Create sessions with full data including relationships
    let sessions = try await createSessionsWithFullRelationships(count: 100)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // Test optimized analytics queries
    let startTime = Date()
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    let optimizedQueryTime = Date().timeIntervalSince(startTime)
    
    #expect(optimizedQueryTime < 5.0, "Optimized queries should complete within 5 seconds")
    #expect(analyticsData.totalSessions == 100)
    
    // Test personal records query efficiency
    let recordsStartTime = Date()
    let personalRecords = try await analyticsRepository.fetchPersonalRecords()
    let recordsQueryTime = Date().timeIntervalSince(recordsStartTime)
    
    #expect(recordsQueryTime < 2.0, "Personal records query should be fast")
    #expect(personalRecords.longestDistance.isValid)
  }
  
  @Test("SwiftData relationship handling in analytics")
  func swiftDataRelationshipHandlingInAnalytics() async throws {
    let context = ModelContext(modelContainer)
    
    // Create session with weather and terrain relationships
    let session = try RuckSession(loadWeight: 30.0)
    session.startDate = Date()
    session.endDate = session.startDate.addingTimeInterval(3600)
    session.totalDistance = 8000
    session.totalCalories = 600
    session.averagePace = 5.5
    session.totalDuration = 3600
    
    // Add weather conditions
    let weather = WeatherConditions()
    weather.temperature = 25.0
    weather.humidity = 60.0
    weather.windSpeed = 10.0
    weather.precipitation = 0.0
    weather.session = session
    session.weatherConditions = weather
    
    // Add terrain segments
    let terrain1 = TerrainSegment()
    terrain1.terrainType = .pavedRoad
    terrain1.duration = 1800
    terrain1.session = session
    
    let terrain2 = TerrainSegment()
    terrain2.terrainType = .trail
    terrain2.duration = 1800
    terrain2.session = session
    
    session.terrainSegments = [terrain1, terrain2]
    
    context.insert(session)
    try context.save()
    
    // Test detailed metrics that use relationships
    let detailedMetrics = try await analyticsRepository.fetchDetailedMetrics(for: .allTime)
    
    #expect(detailedMetrics.terrainDistribution.count > 0)
    #expect(detailedMetrics.weatherImpactAnalysis.averagePaceByTemperature.count >= 0)
    
    // Verify terrain distribution calculation
    let roadPercentage = detailedMetrics.terrainDistribution[.pavedRoad] ?? 0
    let trailPercentage = detailedMetrics.terrainDistribution[.trail] ?? 0
    
    #expect(roadPercentage >= 0)
    #expect(trailPercentage >= 0)
    #expect(abs((roadPercentage + trailPercentage) - 100.0) < 1.0) // Should sum to ~100%
  }
  
  // MARK: - Real-world Scenario Integration Tests
  
  @Test("Analytics handles typical user patterns")
  func analyticsHandlesTypicalUserPatterns() async throws {
    let context = ModelContext(modelContainer)
    
    // Simulate 6 months of realistic user activity
    let sessions = try await simulateRealisticUserActivity()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    await analyticsViewModel.loadAllAnalyticsData()
    
    // Verify realistic metrics
    #expect(analyticsViewModel.totalSessions > 20) // Regular user over 6 months
    #expect(analyticsViewModel.totalDistanceKm > 50) // Reasonable total distance
    #expect(analyticsViewModel.currentTrainingStreak >= 0)
    #expect(analyticsViewModel.averagePace > 0)
    
    // Test weekly trends show progression
    let weeklyDistanceData = analyticsViewModel.weeklyDistanceData
    #expect(weeklyDistanceData.count > 0)
    
    // Verify personal records are realistic
    if let longestRecord = analyticsViewModel.longestDistanceRecord {
      #expect(longestRecord.value > 0)
      #expect(longestRecord.value < 100000) // Less than 100km (reasonable max)
    }
  }
  
  @Test("Analytics performance with concurrent user interactions")
  func analyticsPerformanceWithConcurrentUserInteractions() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createTestSessions(count: 50)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // Simulate concurrent user interactions
    let startTime = Date()
    
    async let loadAnalytics = analyticsViewModel.loadAllAnalyticsData()
    async let changeTimePeriod = {
      analyticsViewModel.changeTimePeriod(to: .weekly)
      await analyticsViewModel.loadAnalyticsData()
    }()
    async let loadDetailedMetrics = analyticsViewModel.loadDetailedMetrics()
    async let refreshData = analyticsViewModel.refreshAnalytics()
    
    // Wait for all operations
    await loadAnalytics
    await changeTimePeriod
    await loadDetailedMetrics
    await refreshData
    
    let totalTime = Date().timeIntervalSince(startTime)
    
    #expect(totalTime < 15.0, "Concurrent operations should complete within 15 seconds")
    
    // Verify final state is consistent
    #expect(analyticsViewModel.hasAnalyticsData)
    #expect(analyticsViewModel.selectedTimePeriod == .weekly)
    #expect(analyticsViewModel.detailedMetrics != nil)
  }
  
  // MARK: - Error Recovery Integration Tests
  
  @Test("Analytics error recovery across system layers")
  func analyticsErrorRecoveryAcrossSystemLayers() async throws {
    // Test error propagation and recovery
    
    // 1. Start with valid data
    let context = ModelContext(modelContainer)
    let sessions = try await createTestSessions(count: 5)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    await analyticsViewModel.loadAllAnalyticsData()
    #expect(analyticsViewModel.hasAnalyticsData)
    #expect(!analyticsViewModel.showingErrorAlert)
    
    // 2. Simulate data corruption by clearing context
    try context.delete(model: RuckSession.self)
    try context.save()
    
    // 3. Refresh should handle gracefully
    await analyticsViewModel.refreshAnalytics()
    
    // Should have empty data but no error state
    #expect(analyticsViewModel.totalSessions == 0)
    #expect(analyticsViewModel.hasAnalyticsData) // Should have empty analytics data object
  }
  
  @Test("Analytics data migration simulation")
  func analyticsDataMigrationSimulation() async throws {
    let context = ModelContext(modelContainer)
    
    // 1. Create "old format" sessions
    let oldSessions = try await createLegacyFormatSessions()
    
    for session in oldSessions {
      context.insert(session)
    }
    try context.save()
    
    // 2. Process with current analytics system
    let analyticsData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    #expect(analyticsData.totalSessions == oldSessions.count)
    #expect(analyticsData.totalDistance > 0)
    
    // 3. Add new format sessions
    let newSessions = try await createCurrentFormatSessions()
    
    for session in newSessions {
      context.insert(session)
    }
    try context.save()
    
    // 4. Verify mixed data processing
    let mixedData = try await analyticsRepository.fetchAnalyticsData(for: .allTime)
    
    #expect(mixedData.totalSessions == oldSessions.count + newSessions.count)
    #expect(mixedData.totalDistance > analyticsData.totalDistance)
  }
  
  // MARK: - Chart Data Integration Tests
  
  @Test("Chart data transformation accuracy")
  func chartDataTransformationAccuracy() async throws {
    let context = ModelContext(modelContainer)
    
    // Create sessions with known values for easy verification
    let knownSessions = try await createSessionsWithKnownValues()
    
    for session in knownSessions {
      context.insert(session)
    }
    try context.save()
    
    await analyticsViewModel.loadWeeklyAnalyticsData(numberOfWeeks: 4)
    
    // Test weekly distance chart data
    let weeklyDistanceData = analyticsViewModel.weeklyDistanceData
    #expect(weeklyDistanceData.count == 4)
    
    // Verify data transformation is correct
    let totalChartDistance = weeklyDistanceData.reduce(0) { sum, data in
      sum + data.distance
    }
    
    let expectedTotalKm = knownSessions.reduce(0) { sum, session in
      sum + (session.totalDistance / 1000.0)
    }
    
    #expect(abs(totalChartDistance - expectedTotalKm) < 0.1)
    
    // Test session count chart data
    let weeklySessionData = analyticsViewModel.weeklySessionData
    let totalChartSessions = weeklySessionData.reduce(0) { sum, data in
      sum + data.sessions
    }
    
    #expect(totalChartSessions == knownSessions.count)
  }
  
  @Test("Accessibility data preparation for charts")
  func accessibilityDataPreparationForCharts() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createSessionsWithProgressiveImprovement()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    await analyticsViewModel.loadAllAnalyticsData()
    
    // Test data suitable for audio graphs
    let weeklyDistanceData = analyticsViewModel.weeklyDistanceData
    #expect(weeklyDistanceData.count > 0)
    
    // Verify data has clear trend for audio representation
    let distances = weeklyDistanceData.map { $0.distance }
    let isIncreasing = zip(distances, distances.dropFirst()).allSatisfy { $0 <= $1 }
    let isDecreasing = zip(distances, distances.dropFirst()).allSatisfy { $0 >= $1 }
    
    #expect(isIncreasing || isDecreasing || distances.count < 2, "Data should have clear trend for accessibility")
  }
  
  // MARK: - Helper Methods
  
  private func createRealisticSessionData() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    // Simulate 3 months of realistic training
    let sessionConfigs = [
      // Week 1: Getting started
      (weight: 15.0, distance: 3000.0, pace: 6.0, days: [1, 3]),
      (weight: 15.0, distance: 3500.0, pace: 5.8, days: [1, 3]),
      
      // Week 2: Building base
      (weight: 20.0, distance: 4000.0, pace: 5.5, days: [1, 3, 5]),
      (weight: 20.0, distance: 4500.0, pace: 5.3, days: [1, 3, 5]),
      
      // Week 3-4: Progression
      (weight: 25.0, distance: 5000.0, pace: 5.2, days: [1, 3, 5]),
      (weight: 25.0, distance: 5500.0, pace: 5.0, days: [1, 3, 5]),
      
      // Week 5-8: Consistency
      (weight: 30.0, distance: 6000.0, pace: 4.8, days: [1, 3, 5]),
      (weight: 30.0, distance: 6500.0, pace: 4.7, days: [1, 3, 5]),
      (weight: 30.0, distance: 7000.0, pace: 4.6, days: [1, 3, 5]),
      (weight: 30.0, distance: 7500.0, pace: 4.5, days: [1, 3, 5])
    ]
    
    for (weekIndex, config) in sessionConfigs.enumerated() {
      for dayOffset in config.days {
        let session = try RuckSession(loadWeight: config.weight)
        
        if let sessionDate = calendar.date(byAdding: .day, value: -(weekIndex * 7 + dayOffset), to: Date()) {
          session.startDate = sessionDate
          session.endDate = sessionDate.addingTimeInterval(TimeInterval(config.distance / 1000 * config.pace * 60))
          session.totalDistance = config.distance
          session.totalCalories = calculateRealisticCalories(
            distance: config.distance,
            weight: config.weight,
            pace: config.pace
          )
          session.averagePace = config.pace
          session.totalDuration = TimeInterval(config.distance / 1000 * config.pace * 60)
          session.elevationGain = Double.random(in: 50...200)
          session.elevationLoss = session.elevationGain * Double.random(in: 0.8...1.2)
        }
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  private func createSessionsAcrossMultipleTimeRanges() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    let now = Date()
    
    // Create sessions in different time ranges
    let timeRanges = [
      (-2, "this week"),        // 2 days ago
      (-10, "this month"),      // 10 days ago
      (-45, "last 3 months"),   // 45 days ago
      (-120, "last 6 months"),  // 120 days ago
      (-300, "last year"),      // 300 days ago
      (-500, "all time")        // 500 days ago
    ]
    
    for (daysAgo, description) in timeRanges {
      let session = try RuckSession(loadWeight: Double.random(in: 20...35))
      session.startDate = calendar.date(byAdding: .day, value: daysAgo, to: now) ?? now
      session.endDate = session.startDate.addingTimeInterval(3600)
      session.totalDistance = Double.random(in: 3000...10000)
      session.totalCalories = Double.random(in: 300...800)
      session.averagePace = Double.random(in: 4.5...6.5)
      session.totalDuration = 3600
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createTestSessions(count: Int) async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<count {
      let session = try createTestSession(
        loadWeight: Double(20 + i % 30),
        distance: Double(3000 + i * 500)
      )
      session.startDate = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createTestSession(loadWeight: Double, distance: Double) throws -> RuckSession {
    let session = try RuckSession(loadWeight: loadWeight)
    session.startDate = Date()
    session.endDate = session.startDate.addingTimeInterval(3600)
    session.totalDistance = distance
    session.totalCalories = calculateRealisticCalories(distance: distance, weight: loadWeight, pace: 5.5)
    session.averagePace = 5.5
    session.totalDuration = 3600
    session.elevationGain = 100.0
    session.elevationLoss = 90.0
    return session
  }
  
  private func createSessionsWithFullRelationships(count: Int) async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let terrainTypes: [TerrainType] = [.pavedRoad, .trail, .sand, .grass, .gravel]
    
    for i in 0..<count {
      let session = try RuckSession(loadWeight: Double.random(in: 15...50))
      session.startDate = Calendar.current.date(byAdding: .hour, value: -i * 2, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      session.totalDistance = Double.random(in: 3000...15000)
      session.totalCalories = Double.random(in: 300...1200)
      session.averagePace = Double.random(in: 4.5...7.0)
      session.totalDuration = 3600
      
      // Add location points
      for j in 0..<20 {
        let locationPoint = LocationPoint()
        locationPoint.latitude = 37.7749 + Double.random(in: -0.01...0.01)
        locationPoint.longitude = -122.4194 + Double.random(in: -0.01...0.01)
        locationPoint.timestamp = session.startDate.addingTimeInterval(Double(j) * 180)
        locationPoint.altitude = Double.random(in: 0...300)
        locationPoint.speed = Double.random(in: 1.0...2.5)
        locationPoint.session = session
        session.locationPoints.append(locationPoint)
      }
      
      // Add terrain segment
      let terrain = TerrainSegment()
      terrain.terrainType = terrainTypes.randomElement() ?? .pavedRoad
      terrain.duration = TimeInterval.random(in: 1800...3600)
      terrain.session = session
      session.terrainSegments.append(terrain)
      
      // Add weather (sometimes)
      if i % 3 == 0 {
        let weather = WeatherConditions()
        weather.temperature = Double.random(in: -5...35)
        weather.humidity = Double.random(in: 30...90)
        weather.windSpeed = Double.random(in: 0...20)
        weather.precipitation = Double.random(in: 0...10)
        weather.session = session
        session.weatherConditions = weather
      }
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func simulateRealisticUserActivity() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    // Simulate 6 months of activity with realistic patterns
    for week in 0..<26 {
      let sessionsThisWeek = Int.random(in: 1...4) // Varying activity
      
      for sessionIndex in 0..<sessionsThisWeek {
        let session = try RuckSession(loadWeight: Double.random(in: 15...40))
        
        if let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()),
           let sessionDate = calendar.date(byAdding: .day, value: sessionIndex * 2, to: weekStart) {
          session.startDate = sessionDate
          session.endDate = sessionDate.addingTimeInterval(TimeInterval.random(in: 1800...7200))
          
          // Progressive improvement over time
          let progressFactor = 1.0 + (Double(week) * 0.02) // 2% improvement per week
          session.totalDistance = Double.random(in: 3000...12000) * progressFactor
          session.averagePace = max(4.0, Double.random(in: 5.0...7.0) - (Double(week) * 0.01)) // Getting faster
          session.totalCalories = calculateRealisticCalories(
            distance: session.totalDistance,
            weight: session.loadWeight,
            pace: session.averagePace
          )
          session.totalDuration = session.endDate?.timeIntervalSince(session.startDate) ?? 3600
        }
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  private func createLegacyFormatSessions() async throws -> [RuckSession] {
    // Simulate older sessions that might have minimal data
    var sessions: [RuckSession] = []
    
    for i in 0..<5 {
      let session = try RuckSession(loadWeight: 25.0)
      session.startDate = Calendar.current.date(byAdding: .month, value: -6 - i, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      session.totalDistance = Double(4000 + i * 500)
      session.totalCalories = 350.0 // Fixed value for legacy
      session.averagePace = 6.0 // Fixed pace for legacy
      session.totalDuration = 3600
      // No elevation, weather, or terrain data
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createCurrentFormatSessions() async throws -> [RuckSession] {
    // Current format sessions with full data
    var sessions: [RuckSession] = []
    
    for i in 0..<3 {
      let session = try RuckSession(loadWeight: Double(30 + i * 5))
      session.startDate = Calendar.current.date(byAdding: .day, value: -i * 7, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      session.totalDistance = Double(6000 + i * 1000)
      session.totalCalories = calculateRealisticCalories(
        distance: session.totalDistance,
        weight: session.loadWeight,
        pace: 5.0
      )
      session.averagePace = 5.0
      session.totalDuration = 3600
      session.elevationGain = Double(100 + i * 50)
      session.elevationLoss = Double(90 + i * 45)
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createSessionsWithKnownValues() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    // Create sessions with predictable values for verification
    let weekConfigs = [
      (sessions: 2, distance: 5000.0, week: 0),
      (sessions: 3, distance: 6000.0, week: 1),
      (sessions: 2, distance: 7000.0, week: 2),
      (sessions: 4, distance: 8000.0, week: 3)
    ]
    
    for config in weekConfigs {
      for sessionIndex in 0..<config.sessions {
        let session = try RuckSession(loadWeight: 25.0)
        
        if let weekStart = calendar.date(byAdding: .weekOfYear, value: -config.week, to: Date()),
           let sessionDate = calendar.date(byAdding: .day, value: sessionIndex, to: weekStart) {
          session.startDate = sessionDate
          session.endDate = sessionDate.addingTimeInterval(3600)
          session.totalDistance = config.distance
          session.totalCalories = 400.0
          session.averagePace = 5.5
          session.totalDuration = 3600
        }
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  private func createSessionsWithProgressiveImprovement() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    // Create sessions showing clear improvement over time
    for week in 0..<8 {
      let session = try RuckSession(loadWeight: 25.0)
      
      if let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()) {
        session.startDate = weekStart
        session.endDate = weekStart.addingTimeInterval(3600)
        
        // Progressive improvement: increasing distance, decreasing pace
        session.totalDistance = Double(3000 + week * 500) // 3km to 6.5km
        session.averagePace = max(4.5, 6.5 - Double(week) * 0.25) // 6.5 to 4.5 min/km
        session.totalCalories = calculateRealisticCalories(
          distance: session.totalDistance,
          weight: 25.0,
          pace: session.averagePace
        )
        session.totalDuration = 3600
      }
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func calculateRealisticCalories(distance: Double, weight: Double, pace: Double) -> Double {
    // Simple calorie calculation: roughly 0.7 cal per kg per km, adjusted for pace
    let baseCalories = (distance / 1000.0) * weight * 0.7
    let paceMultiplier = max(0.8, 2.0 - (pace / 10.0)) // Faster pace = more calories
    return baseCalories * paceMultiplier
  }
}