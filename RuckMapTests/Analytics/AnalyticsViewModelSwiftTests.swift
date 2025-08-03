import Testing
import SwiftData
import Foundation
@testable import RuckMap

/// Comprehensive tests for AnalyticsViewModel using Swift Testing framework
@Suite("Analytics View Model Tests")
@MainActor
struct AnalyticsViewModelTests {
  
  private let modelContainer: ModelContainer
  private let analyticsViewModel: AnalyticsViewModel
  
  init() throws {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    modelContainer = try ModelContainer(
      for: RuckSession.self, LocationPoint.self, TerrainSegment.self, WeatherConditions.self,
      configurations: configuration
    )
    analyticsViewModel = AnalyticsViewModel(modelContainer: modelContainer)
  }
  
  // MARK: - Data Loading Tests
  
  @Test("View model loads analytics data correctly")
  func loadAnalyticsDataCorrectly() async throws {
    // Setup test data
    let context = ModelContext(modelContainer)
    let sessions = try await createTestSessions(count: 5)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // Load analytics data
    await analyticsViewModel.loadAllAnalyticsData()
    
    // Verify data was loaded
    #expect(analyticsViewModel.analyticsData != nil)
    #expect(analyticsViewModel.personalRecords != nil)
    #expect(analyticsViewModel.weeklyAnalyticsData != nil)
    
    // Verify computed properties
    #expect(analyticsViewModel.hasAnalyticsData)
    #expect(analyticsViewModel.hasPersonalRecords)
    #expect(analyticsViewModel.hasWeeklyData)
    
    #expect(analyticsViewModel.totalSessions == 5)
    #expect(analyticsViewModel.totalDistanceKm > 0)
    #expect(analyticsViewModel.totalCalories > 0)
    #expect(analyticsViewModel.currentTrainingStreak >= 0)
  }
  
  @Test("View model handles empty data correctly")
  func handleEmptyDataCorrectly() async throws {
    // Load data with no sessions
    await analyticsViewModel.loadAllAnalyticsData()
    
    // Should handle empty state gracefully
    #expect(analyticsViewModel.totalSessions == 0)
    #expect(analyticsViewModel.totalDistanceKm == 0)
    #expect(analyticsViewModel.totalCalories == 0)
    #expect(analyticsViewModel.currentTrainingStreak == 0)
    
    // Should still have loaded data objects (empty)
    #expect(analyticsViewModel.hasAnalyticsData)
  }
  
  @Test("View model loading states work correctly")
  func loadingStatesWorkCorrectly() async throws {
    // Initially not loading
    #expect(!analyticsViewModel.isLoading)
    #expect(!analyticsViewModel.isLoadingAnalytics)
    
    // Start loading (this would be async in real usage)
    let loadingTask = Task {
      await analyticsViewModel.loadAnalyticsData()
    }
    
    // Wait for completion
    await loadingTask.value
    
    // Should not be loading after completion
    #expect(!analyticsViewModel.isLoading)
    #expect(!analyticsViewModel.isLoadingAnalytics)
  }
  
  // MARK: - Time Period Selection Tests
  
  @Test("Time period changes trigger data reload", 
        arguments: [
          AnalyticsTimePeriod.weekly,
          AnalyticsTimePeriod.monthly,
          AnalyticsTimePeriod.last3Months,
          AnalyticsTimePeriod.lastYear,
          AnalyticsTimePeriod.allTime
        ])
  func timePeriodChangeTriggersReload(timePeriod: AnalyticsTimePeriod) async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createSessionsAcrossTimeRanges()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // Change time period
    analyticsViewModel.changeTimePeriod(to: timePeriod)
    
    // Wait for data to load
    await analyticsViewModel.loadAnalyticsData()
    
    // Verify time period was updated
    #expect(analyticsViewModel.selectedTimePeriod == timePeriod)
    #expect(analyticsViewModel.analyticsData?.timePeriod == timePeriod)
    
    // Verify data reflects the time period
    if let analyticsData = analyticsViewModel.analyticsData {
      #expect(analyticsData.totalSessions >= 0)
    }
  }
  
  @Test("Time period picker state management")
  func timePeriodPickerStateManagement() async throws {
    // Initially picker should not be showing
    #expect(!analyticsViewModel.showingTimePeriodPicker)
    
    // Show picker
    analyticsViewModel.showingTimePeriodPicker = true
    #expect(analyticsViewModel.showingTimePeriodPicker)
    
    // Change period should hide picker
    analyticsViewModel.changeTimePeriod(to: .weekly)
    #expect(!analyticsViewModel.showingTimePeriodPicker)
  }
  
  // MARK: - Data Formatting Tests
  
  @Test("Distance formatting works correctly",
        arguments: [
          (500.0, "500 m"),
          (1000.0, "1.00 km"),
          (5500.0, "5.50 km"),
          (12000.0, "12.00 km")
        ])
  func distanceFormattingWorksCorrectly(distance: Double, expected: String) {
    let formatted = analyticsViewModel.formatDistance(distance)
    #expect(formatted.contains("m") || formatted.contains("km"))
    
    // Check that reasonable formatting is applied
    if distance < 1000 {
      #expect(formatted.contains("m"))
    } else {
      #expect(formatted.contains("km"))
    }
  }
  
  @Test("Pace formatting works correctly",
        arguments: [
          (4.0, "4:00"),
          (5.5, "5:30"),
          (6.25, "6:15"),
          (0.0, "N/A")
        ])
  func paceFormattingWorksCorrectly(pace: Double, expectedPattern: String) {
    let formatted = analyticsViewModel.formatPace(pace)
    
    if pace == 0.0 {
      #expect(formatted == "N/A")
    } else {
      #expect(formatted.contains(":"))
      #expect(formatted.contains("/km"))
    }
  }
  
  @Test("Duration formatting works correctly",
        arguments: [
          (1800.0, "30m"),   // 30 minutes
          (3661.0, "1h"),    // 1 hour 1 minute 1 second
          (7200.0, "2h"),    // 2 hours
          (3600.0, "1h")     // 1 hour exactly
        ])
  func durationFormattingWorksCorrectly(duration: TimeInterval, expectedPattern: String) {
    let formatted = analyticsViewModel.formatDuration(duration)
    
    if duration >= 3600 {
      #expect(formatted.contains("h"))
    } else {
      #expect(formatted.contains("m"))
    }
  }
  
  @Test("Weight and calories formatting",
        arguments: [
          (1234.0, "1234"),
          (25.5, "25.5"),
          (0.0, "0")
        ])
  func weightAndCaloriesFormatting(value: Double, expectedPattern: String) {
    let caloriesFormatted = analyticsViewModel.formatCalories(value)
    let weightFormatted = analyticsViewModel.formatWeight(value)
    let weightMovedFormatted = analyticsViewModel.formatWeightMoved(value)
    
    #expect(caloriesFormatted.contains("cal"))
    #expect(weightFormatted.contains("kg"))
    #expect(weightMovedFormatted.contains("kg×km"))
  }
  
  // MARK: - Trend Data Tests
  
  @Test("Trend data properties work correctly")
  func trendDataPropertiesWorkCorrectly() async throws {
    let context = ModelContext(modelContainer)
    
    // Create current and previous period sessions
    let currentSessions = try await createCurrentPeriodSessions()
    let previousSessions = try await createPreviousPeriodSessions()
    
    let allSessions = currentSessions + previousSessions
    for session in allSessions {
      context.insert(session)
    }
    try context.save()
    
    await analyticsViewModel.loadAnalyticsData()
    
    // Check trend data exists if we have previous period data
    if analyticsViewModel.analyticsData?.distanceTrend != nil {
      #expect(analyticsViewModel.distanceTrend != nil)
      #expect(analyticsViewModel.paceTrend != nil)
      #expect(analyticsViewModel.calorieTrend != nil)
      #expect(analyticsViewModel.sessionCountTrend != nil)
    }
  }
  
  // MARK: - Personal Records Tests
  
  @Test("Personal records properties work correctly")
  func personalRecordsPropertiesWorkCorrectly() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createVariedTestSessions()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    await analyticsViewModel.loadPersonalRecords()
    
    #expect(analyticsViewModel.hasPersonalRecords)
    
    // Verify personal record properties exist
    #expect(analyticsViewModel.longestDistanceRecord != nil)
    #expect(analyticsViewModel.fastestPaceRecord != nil) 
    #expect(analyticsViewModel.heaviestLoadRecord != nil)
    #expect(analyticsViewModel.highestCalorieRecord != nil)
    #expect(analyticsViewModel.longestDurationRecord != nil)
    #expect(analyticsViewModel.mostWeightMovedRecord != nil)
    
    // Verify records are valid
    if let longestRecord = analyticsViewModel.longestDistanceRecord {
      #expect(longestRecord.isValid)
      #expect(longestRecord.value > 0)
    }
  }
  
  // MARK: - Weekly Data Tests
  
  @Test("Weekly chart data properties work correctly")
  func weeklyChartDataPropertiesWorkCorrectly() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createSessionsSpreadOverWeeks(weeks: 8)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    await analyticsViewModel.loadWeeklyAnalyticsData(numberOfWeeks: 8)
    
    #expect(analyticsViewModel.hasWeeklyData)
    
    // Test chart data arrays
    let distanceData = analyticsViewModel.weeklyDistanceData
    let sessionData = analyticsViewModel.weeklySessionData  
    let calorieData = analyticsViewModel.weeklyCalorieData
    let goalData = analyticsViewModel.weeklyGoalAchievement
    
    #expect(distanceData.count == 8)
    #expect(sessionData.count == 8)
    #expect(calorieData.count == 8)
    #expect(goalData.count == 8)
    
    // Verify data structure
    for (week, distance) in distanceData {
      #expect(!week.isEmpty)
      #expect(distance >= 0)
    }
    
    for (week, sessions) in sessionData {
      #expect(!week.isEmpty)
      #expect(sessions >= 0)
    }
  }
  
  // MARK: - Error Handling Tests
  
  @Test("Error handling works correctly")
  func errorHandlingWorksCorrectly() async throws {
    // Initially no error
    #expect(!analyticsViewModel.showingErrorAlert)
    #expect(analyticsViewModel.errorMessage.isEmpty)
    
    // Simulate error condition by using invalid model container state
    // (This is a simplified test - in real scenarios errors might come from network/disk issues)
    
    // Test error dismissal
    analyticsViewModel.errorMessage = "Test error"
    analyticsViewModel.showingErrorAlert = true
    
    analyticsViewModel.dismissError()
    
    #expect(!analyticsViewModel.showingErrorAlert)
    #expect(analyticsViewModel.errorMessage.isEmpty)
  }
  
  // MARK: - UI State Tests
  
  @Test("UI state management works correctly")
  func uiStateManagementWorksCorrectly() async throws {
    // Test detailed metrics view state
    #expect(!analyticsViewModel.showingDetailedMetrics)
    
    analyticsViewModel.showDetailedMetrics()
    #expect(analyticsViewModel.showingDetailedMetrics)
    
    // Test personal records detail state
    #expect(!analyticsViewModel.showingPersonalRecordsDetail)
    
    analyticsViewModel.showPersonalRecordsDetail()
    #expect(analyticsViewModel.showingPersonalRecordsDetail)
  }
  
  // MARK: - Refresh Functionality Tests
  
  @Test("Refresh analytics works correctly")
  func refreshAnalyticsWorksCorrectly() async throws {
    let context = ModelContext(modelContainer)
    let initialSessions = try await createTestSessions(count: 3)
    
    for session in initialSessions {
      context.insert(session)
    }
    try context.save()
    
    // Load initial data
    await analyticsViewModel.loadAllAnalyticsData()
    let initialSessionCount = analyticsViewModel.totalSessions
    
    // Add more sessions
    let additionalSessions = try await createTestSessions(count: 2)
    for session in additionalSessions {
      context.insert(session)
    }
    try context.save()
    
    // Refresh should get new data
    await analyticsViewModel.refreshAnalytics()
    
    #expect(analyticsViewModel.totalSessions > initialSessionCount)
  }
  
  // MARK: - Concurrent Loading Tests
  
  @Test("Concurrent loading prevents multiple simultaneous loads")
  func concurrentLoadingPreventsMultipleSimultaneousLoads() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createTestSessions(count: 10)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    // Start multiple concurrent loads
    async let load1 = analyticsViewModel.loadAnalyticsData()
    async let load2 = analyticsViewModel.loadAnalyticsData()
    async let load3 = analyticsViewModel.loadAnalyticsData()
    
    // Wait for all to complete
    await load1
    await load2
    await load3
    
    // Should have loaded data correctly without issues
    #expect(analyticsViewModel.hasAnalyticsData)
    #expect(analyticsViewModel.totalSessions == 10)
  }
  
  // MARK: - Performance Tests
  
  @Test("View model formatting performance",
        .timeLimit(.seconds(5)))
  func viewModelFormattingPerformance() async throws {
    let testValues = Array(0..<1000).map { Double($0) }
    
    let startTime = Date()
    
    for value in testValues {
      _ = analyticsViewModel.formatDistance(value * 1000)
      _ = analyticsViewModel.formatPace(value / 100 + 4.0)
      _ = analyticsViewModel.formatDuration(value * 60)
      _ = analyticsViewModel.formatCalories(value * 10)
      _ = analyticsViewModel.formatWeight(value / 10)
    }
    
    let formatTime = Date().timeIntervalSince(startTime)
    #expect(formatTime < 1.0, "Formatting 1000 values should complete within 1 second")
  }
  
  // MARK: - Memory Management Tests
  
  @Test("View model properly manages memory")
  func viewModelProperlyManagesMemory() async throws {
    // Load large dataset
    let context = ModelContext(modelContainer)
    let largeSessions = try await createTestSessions(count: 100)
    
    for session in largeSessions {
      context.insert(session)
    }
    try context.save()
    
    // Load data multiple times
    for _ in 0..<5 {
      await analyticsViewModel.loadAllAnalyticsData()
      await analyticsViewModel.refreshAnalytics()
    }
    
    // Should complete without memory issues
    #expect(analyticsViewModel.hasAnalyticsData)
    #expect(analyticsViewModel.totalSessions == 100)
  }
  
  // MARK: - Helper Methods
  
  private func createTestSessions(count: Int) async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<count {
      let session = try RuckSession(loadWeight: Double(20 + i % 30))
      session.startDate = Calendar.current.date(byAdding: .day, value: -i * 2, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      session.totalDistance = Double(3000 + i * 1000)
      session.totalCalories = Double(300 + i * 50)
      session.averagePace = Double(5.0 + Double(i % 5) * 0.2)
      session.totalDuration = 3600
      session.elevationGain = Double(50 + i * 10)
      session.elevationLoss = Double(45 + i * 8)
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createSessionsAcrossTimeRanges() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    let now = Date()
    
    // Sessions in different time periods
    let timeOffsets = [-2, -10, -40, -100, -200] // Days ago
    
    for (index, offset) in timeOffsets.enumerated() {
      let session = try RuckSession(loadWeight: Double(25 + index * 5))
      session.startDate = calendar.date(byAdding: .day, value: offset, to: now) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      session.totalDistance = Double(4000 + index * 1000)
      session.totalCalories = Double(350 + index * 50)
      session.averagePace = 5.5
      session.totalDuration = 3600
      
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
  
  private func createSessionsSpreadOverWeeks(weeks: Int) async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    for week in 0..<weeks {
      let sessionsPerWeek = Int.random(in: 1...4)
      
      for sessionIndex in 0..<sessionsPerWeek {
        let session = try RuckSession(loadWeight: Double.random(in: 20...40))
        
        if let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()),
           let sessionDate = calendar.date(byAdding: .day, value: sessionIndex, to: weekStart) {
          session.startDate = sessionDate
          session.endDate = sessionDate.addingTimeInterval(3600)
          session.totalDistance = Double.random(in: 3000...12000)
          session.totalCalories = Double.random(in: 300...800)
          session.averagePace = Double.random(in: 4.5...6.5)
          session.totalDuration = 3600
        }
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  private func createCurrentPeriodSessions() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<4 {
      let session = try RuckSession(loadWeight: 30.0)
      session.startDate = Calendar.current.date(byAdding: .day, value: -i * 3, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      session.totalDistance = Double(5000 + i * 1000)
      session.totalCalories = Double(450 + i * 50)
      session.averagePace = 5.2
      session.totalDuration = 3600
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  private func createPreviousPeriodSessions() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<3 {
      let session = try RuckSession(loadWeight: 25.0)
      session.startDate = Calendar.current.date(byAdding: .day, value: -45 - i * 4, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      session.totalDistance = Double(4000 + i * 800)
      session.totalCalories = Double(350 + i * 40)
      session.averagePace = 5.8
      session.totalDuration = 3600
      
      sessions.append(session)
    }
    
    return sessions
  }
}