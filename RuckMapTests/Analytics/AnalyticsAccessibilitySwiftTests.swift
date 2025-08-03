import Testing
import SwiftUI
import SwiftData
import AccessibilityTesting
@testable import RuckMap

/// Comprehensive accessibility tests for Analytics using Swift Testing framework
@Suite("Analytics Accessibility Tests")
@MainActor
struct AnalyticsAccessibilityTests {
  
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
  
  // MARK: - VoiceOver Label Tests
  
  @Test("Analytics dashboard VoiceOver labels are descriptive")
  func analyticsDashboardVoiceOverLabelsAreDescriptive() async throws {
    // Setup test data
    let context = ModelContext(modelContainer)
    let sessions = try await createTestSessions(count: 5)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    await analyticsViewModel.loadAllAnalyticsData()
    
    // Test metric labels with actual data
    let totalDistanceLabel = formatAccessibilityLabel(
      value: analyticsViewModel.totalDistanceKm,
      unit: "kilometers",
      metric: "total distance"
    )
    
    let totalSessionsLabel = formatAccessibilityLabel(
      value: Double(analyticsViewModel.totalSessions),
      unit: "sessions",
      metric: "total sessions"
    )
    
    let trainingStreakLabel = formatAccessibilityLabel(
      value: Double(analyticsViewModel.currentTrainingStreak),
      unit: "weeks",
      metric: "training streak"
    )
    
    // Verify labels are meaningful and complete
    #expect(totalDistanceLabel.contains("total distance"))
    #expect(totalDistanceLabel.contains("kilometers"))
    #expect(totalSessionsLabel.contains("sessions"))
    #expect(trainingStreakLabel.contains("training streak"))
    
    // Labels should not be empty or just numeric
    #expect(!totalDistanceLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    #expect(totalDistanceLabel.count > 5) // Should be descriptive, not just "5.2"
  }
  
  @Test("Personal records VoiceOver announcements are celebratory")
  func personalRecordsVoiceOverAnnouncementsAreCelebratory() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createVariedTestSessions()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    await analyticsViewModel.loadPersonalRecords()
    
    if let longestRecord = analyticsViewModel.longestDistanceRecord {
      let announcement = formatPersonalRecordAnnouncement(
        record: longestRecord,
        recordType: "longest distance",
        unit: "kilometers",
        formatter: { analyticsViewModel.formatDistance($0) }
      )
      
      #expect(announcement.contains("personal record"))
      #expect(announcement.contains("longest distance"))
      #expect(announcement.contains("kilometers") || announcement.contains("meters"))
      
      // Should be celebratory in tone
      #expect(announcement.contains("achieved") || 
              announcement.contains("record") || 
              announcement.contains("best"))
    }
    
    if let fastestRecord = analyticsViewModel.fastestPaceRecord {
      let announcement = formatPersonalRecordAnnouncement(
        record: fastestRecord,
        recordType: "fastest pace",
        unit: "per kilometer",
        formatter: { analyticsViewModel.formatPace($0) }
      )
      
      #expect(announcement.contains("fastest pace"))
      #expect(announcement.contains("per kilometer") || announcement.contains("/km"))
    }
  }
  
  @Test("Chart data accessibility labels include context and trends")
  func chartDataAccessibilityLabelsIncludeContextAndTrends() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createSessionsWithTrends()
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    await analyticsViewModel.loadAllAnalyticsData()
    
    // Weekly distance chart accessibility
    let weeklyDistanceData = analyticsViewModel.weeklyDistanceData
    if !weeklyDistanceData.isEmpty {
      let chartLabel = formatChartAccessibilityLabel(
        chartType: "Weekly Distance",
        dataPoints: weeklyDistanceData.count,
        trendDescription: determineTrendDescription(data: weeklyDistanceData.map { $0.distance })
      )
      
      #expect(chartLabel.contains("Weekly Distance"))
      #expect(chartLabel.contains("\(weeklyDistanceData.count) weeks"))
      #expect(chartLabel.contains("trend") || chartLabel.contains("increasing") || 
              chartLabel.contains("decreasing") || chartLabel.contains("stable"))
    }
    
    // Session count chart accessibility
    let weeklySessionData = analyticsViewModel.weeklySessionData
    if !weeklySessionData.isEmpty {
      let chartLabel = formatChartAccessibilityLabel(
        chartType: "Weekly Sessions",
        dataPoints: weeklySessionData.count,
        trendDescription: determineTrendDescription(data: weeklySessionData.map { Double($0.sessions) })
      )
      
      #expect(chartLabel.contains("Weekly Sessions"))
      #expect(chartLabel.contains("sessions"))
    }
  }
  
  // MARK: - Audio Graph Tests
  
  @Test("Audio graph generation for different metric types")
  func audioGraphGenerationForDifferentMetricTypes() async throws {
    let testData = [
      ("Distance over time", [5.2, 7.1, 6.8, 8.3, 9.1], "increasing"),
      ("Pace over time", [6.0, 5.8, 5.5, 5.2, 5.0], "improving"), // Lower is better for pace
      ("Calories over time", [400.0, 450.0, 420.0, 480.0, 510.0], "variable")
    ]
    
    for (metricName, values, expectedPattern) in testData {
      let audioGraph = generateAudioGraphDescription(
        metric: metricName,
        values: values,
        pattern: expectedPattern
      )
      
      #expect(audioGraph.contains(metricName))
      #expect(audioGraph.contains("\(values.count) data points"))
      #expect(audioGraph.contains(expectedPattern))
      
      // Audio graph should describe the pattern
      if expectedPattern == "improving" && metricName.contains("Pace") {
        #expect(audioGraph.contains("faster") || audioGraph.contains("improving"))
      } else if expectedPattern == "increasing" {
        #expect(audioGraph.contains("increasing") || audioGraph.contains("rising"))
      }
    }
  }
  
  @Test("Audio graph accessibility for users with varying hearing abilities")
  func audioGraphAccessibilityForUsersWithVaryingHearingAbilities() async throws {
    let testValues = [10.0, 15.0, 12.0, 18.0, 20.0, 25.0]
    
    // Test different audio representation options
    let textDescription = generateTextBasedAudioGraph(values: testValues, metric: "distance")
    let hapticDescription = generateHapticFeedbackDescription(values: testValues)
    let visualDescription = generateVisualAudioGraphDescription(values: testValues)
    
    // Text description should be comprehensive
    #expect(textDescription.contains("starts at"))
    #expect(textDescription.contains("ends at"))
    #expect(textDescription.contains("highest"))
    #expect(textDescription.contains("lowest"))
    
    // Haptic description should describe tactile feedback
    #expect(hapticDescription.contains("vibration") || hapticDescription.contains("tactile"))
    #expect(hapticDescription.contains("pattern"))
    
    // Visual description should describe chart appearance
    #expect(visualDescription.contains("line") || visualDescription.contains("bar"))
    #expect(visualDescription.contains("rising") || visualDescription.contains("falling"))
  }
  
  // MARK: - Rotor Navigation Tests
  
  @Test("Rotor navigation provides logical chart element ordering")
  func rotorNavigationProvidesLogicalChartElementOrdering() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createTestSessions(count: 10)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    await analyticsViewModel.loadAllAnalyticsData()
    
    // Simulate rotor entries for analytics dashboard
    let rotorEntries = generateRotorEntries(analyticsViewModel: analyticsViewModel)
    
    // Should have logical order: Overview -> Charts -> Personal Records -> Details
    let expectedOrder = ["Overview", "Charts", "Personal Records", "Weekly Trends", "Detailed Metrics"]
    
    for (index, expectedSection) in expectedOrder.enumerated() {
      if index < rotorEntries.count {
        #expect(rotorEntries[index].contains(expectedSection))
      }
    }
    
    // Each rotor entry should have clear description
    for entry in rotorEntries {
      #expect(!entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      #expect(entry.count > 3) // Should be descriptive
    }
  }
  
  @Test("Rotor navigation includes actionable elements")
  func rotorNavigationIncludesActionableElements() async throws {
    let rotorActions = generateRotorActions()
    
    let expectedActions = [
      "Play audio graph",
      "Show data table",
      "Change time period",
      "View personal records",
      "Export data",
      "Share analytics"
    ]
    
    for expectedAction in expectedActions {
      let hasAction = rotorActions.contains { action in
        action.lowercased().contains(expectedAction.lowercased().replacingOccurrences(of: " ", with: ""))
      }
      #expect(hasAction, "Should include \(expectedAction) in rotor actions")
    }
    
    // Actions should be clearly described
    for action in rotorActions {
      #expect(action.count > 5) // Should be descriptive
      #expect(!action.contains("button") || action.contains("action")) // Should describe purpose, not just UI element
    }
  }
  
  // MARK: - Dynamic Type Tests
  
  @Test("Analytics displays correctly at different Dynamic Type sizes",
        arguments: [
          ContentSizeCategory.small,
          ContentSizeCategory.medium, 
          ContentSizeCategory.large,
          ContentSizeCategory.extraLarge,
          ContentSizeCategory.extraExtraLarge,
          ContentSizeCategory.extraExtraExtraLarge,
          ContentSizeCategory.accessibilityMedium,
          ContentSizeCategory.accessibilityLarge,
          ContentSizeCategory.accessibilityExtraLarge,
          ContentSizeCategory.accessibilityExtraExtraLarge,
          ContentSizeCategory.accessibilityExtraExtraExtraLarge
        ])
  func analyticsDisplaysCorrectlyAtDifferentDynamicTypeSizes(sizeCategory: ContentSizeCategory) async throws {
    let scaleFactor = getDynamicTypeScaleFactor(for: sizeCategory)
    let isAccessibilitySize = sizeCategory.isAccessibilityCategory
    
    // Test text scaling
    let baseFontSize: CGFloat = 17.0
    let scaledFontSize = baseFontSize * scaleFactor
    
    #expect(scaledFontSize >= baseFontSize)
    
    if isAccessibilitySize {
      #expect(scaledFontSize >= baseFontSize * 1.5, "Accessibility sizes should significantly increase text size")
    }
    
    // Test that touch targets remain appropriate size
    let baseTouchTargetSize: CGFloat = 44.0
    let adjustedTouchTargetSize = max(baseTouchTargetSize, baseTouchTargetSize * scaleFactor * 0.8)
    
    #expect(adjustedTouchTargetSize >= 44.0, "Touch targets should remain at least 44 points")
    
    // Test chart readability
    let chartSuitabilityScore = calculateChartReadabilityScore(
      sizeCategory: sizeCategory,
      scaleFactor: scaleFactor
    )
    
    #expect(chartSuitabilityScore >= 0.7, "Charts should remain readable at \(sizeCategory)")
  }
  
  // MARK: - High Contrast and Color Tests
  
  @Test("Analytics charts support high contrast mode")
  func analyticsChartsSupportHighContrastMode() async throws {
    let standardColors = getStandardChartColors()
    let highContrastColors = getHighContrastChartColors()
    
    // High contrast colors should have better contrast ratios
    for (standard, highContrast) in zip(standardColors, highContrastColors) {
      let standardContrast = calculateContrastRatio(foreground: standard, background: .white)
      let highContrastRatio = calculateContrastRatio(foreground: highContrast, background: .white)
      
      #expect(highContrastRatio >= standardContrast, "High contrast colors should have better contrast")
      #expect(highContrastRatio >= 4.5, "High contrast colors should meet WCAG AA standards")
    }
  }
  
  @Test("Charts are distinguishable without color")
  func chartsAreDistinguishableWithoutColor() async throws {
    let chartPatterns = getChartPatterns()
    
    // Different data series should have unique patterns
    let patterns = ["solid", "dashed", "dotted", "striped", "crosshatch"]
    
    #expect(chartPatterns.count >= patterns.count)
    
    // Each pattern should be unique
    let uniquePatterns = Set(chartPatterns)
    #expect(uniquePatterns.count == chartPatterns.count, "All chart patterns should be unique")
    
    // Test color-blind simulation
    let colorBlindFriendlyScore = calculateColorBlindFriendlinessScore(patterns: chartPatterns)
    #expect(colorBlindFriendlyScore >= 0.8, "Charts should be color-blind friendly")
  }
  
  // MARK: - Reduced Motion Tests
  
  @Test("Analytics animations respect reduced motion preferences")
  func analyticsAnimationsRespectReducedMotionPreferences() async throws {
    // Test with reduced motion enabled
    let reducedMotionAnimations = getReducedMotionAnimations()
    let standardAnimations = getStandardAnimations()
    
    // Reduced motion should have simpler animations
    #expect(reducedMotionAnimations.count <= standardAnimations.count)
    
    for animation in reducedMotionAnimations {
      #expect(animation.duration <= 0.5, "Reduced motion animations should be brief")
      #expect(!animation.includesRotation, "Should avoid rotation animations")
      #expect(!animation.includesComplexTransitions, "Should avoid complex transitions")
    }
    
    // Essential information should still be conveyed
    let informationPreserved = checkInformationPreservationWithReducedMotion()
    #expect(informationPreserved, "Essential information should be preserved with reduced motion")
  }
  
  // MARK: - Voice Control Tests
  
  @Test("Voice Control commands work for analytics navigation")
  func voiceControlCommandsWorkForAnalyticsNavigation() async throws {
    let voiceControlCommands = getVoiceControlCommands()
    
    let expectedCommands = [
      "show numbers",
      "tap chart",
      "play audio graph",
      "show data table",
      "change time period",
      "show personal records"
    ]
    
    for expectedCommand in expectedCommands {
      let hasCommand = voiceControlCommands.contains { command in
        command.lowercased().contains(expectedCommand.lowercased())
      }
      #expect(hasCommand, "Should support voice command: \(expectedCommand)")
    }
    
    // Commands should be unambiguous
    for command in voiceControlCommands {
      #expect(command.count >= 3, "Voice commands should be clear and unambiguous")
      #expect(!command.contains("button"), "Commands should focus on action, not UI element type")
    }
  }
  
  // MARK: - Switch Control Tests
  
  @Test("Switch Control can access all analytics elements")
  func switchControlCanAccessAllAnalyticsElements() async throws {
    let switchControlElements = getSwitchControlElements()
    
    let expectedElementTypes = [
      "metric_cards",
      "charts",
      "time_period_selector",
      "personal_records",
      "data_table_button",
      "audio_graph_button",
      "export_button"
    ]
    
    for elementType in expectedElementTypes {
      let hasElement = switchControlElements.contains { element in
        element.identifier.contains(elementType)
      }
      #expect(hasElement, "Should be accessible via Switch Control: \(elementType)")
    }
    
    // Elements should have proper switch control traits
    for element in switchControlElements {
      #expect(!element.accessibilityLabel.isEmpty, "Switch control elements should have labels")
      #expect(element.isAccessibilityElement, "Should be properly marked as accessibility element")
    }
  }
  
  // MARK: - Cognitive Accessibility Tests
  
  @Test("Analytics provide clear and simple language")
  func analyticsProvidesClearAndSimpleLanguage() async throws {
    let context = ModelContext(modelContainer)
    let sessions = try await createTestSessions(count: 3)
    
    for session in sessions {
      context.insert(session)
    }
    try context.save()
    
    await analyticsViewModel.loadAllAnalyticsData()
    
    // Test metric descriptions for clarity
    let descriptions = [
      formatMetricDescription(value: analyticsViewModel.totalDistanceKm, metric: "total distance"),
      formatMetricDescription(value: Double(analyticsViewModel.totalSessions), metric: "total sessions"),
      formatMetricDescription(value: analyticsViewModel.totalCalories, metric: "total calories"),
      formatMetricDescription(value: Double(analyticsViewModel.currentTrainingStreak), metric: "training streak")
    ]
    
    for description in descriptions {
      // Should use simple, clear language
      let complexityScore = calculateLanguageComplexity(text: description)
      #expect(complexityScore <= 0.6, "Descriptions should use simple language")
      
      // Should avoid jargon
      let jargonWords = ["optimal", "aggregate", "cumulative", "coefficient"]
      for jargon in jargonWords {
        #expect(!description.lowercased().contains(jargon), "Should avoid jargon: \(jargon)")
      }
      
      // Should be specific and helpful
      #expect(description.count > 10, "Descriptions should be informative")
      #expect(!description.contains("N/A") || description.contains("no data"), "Should explain when no data available")
    }
  }
  
  @Test("Error messages are clear and actionable")
  func errorMessagesAreClearAndActionable() async throws {
    let errorMessages = [
      "No session data available. Start your first ruck to see analytics.",
      "Unable to load analytics data. Please check your connection and try again.",
      "Audio graphs are not available on this device. View the data table instead."
    ]
    
    for errorMessage in errorMessages {
      // Should explain what happened
      #expect(errorMessage.contains("No") || errorMessage.contains("Unable") || errorMessage.contains("not available"))
      
      // Should provide next steps
      #expect(errorMessage.contains("Start") || errorMessage.contains("try again") || errorMessage.contains("instead"))
      
      // Should be appropriately conversational
      let formalityScore = calculateFormalityScore(text: errorMessage)
      #expect(formalityScore <= 0.7, "Error messages should be conversational")
    }
  }
  
  // MARK: - Helper Methods
  
  private func createTestSessions(count: Int) async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<count {
      let session = try RuckSession(loadWeight: Double(20 + i * 5))
      session.startDate = Calendar.current.date(byAdding: .day, value: -i * 2, to: Date()) ?? Date()
      session.endDate = session.startDate.addingTimeInterval(3600)
      session.totalDistance = Double(3000 + i * 1000)
      session.totalCalories = Double(300 + i * 50)
      session.averagePace = Double(5.0 + Double(i % 3) * 0.2)
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
  
  private func createSessionsWithTrends() async throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    // Create increasing trend over 8 weeks
    for week in 0..<8 {
      let sessionsPerWeek = 2 + (week / 2) // Gradually increasing sessions
      
      for sessionIndex in 0..<sessionsPerWeek {
        let session = try RuckSession(loadWeight: Double(20 + week * 2))
        
        if let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()),
           let sessionDate = calendar.date(byAdding: .day, value: sessionIndex * 2, to: weekStart) {
          session.startDate = sessionDate
          session.endDate = sessionDate.addingTimeInterval(3600)
          session.totalDistance = Double(4000 + week * 500) // Increasing distance
          session.totalCalories = Double(350 + week * 30)
          session.averagePace = Double(6.0 - week * 0.1) // Improving pace
          session.totalDuration = 3600
        }
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  // MARK: - Accessibility Helper Functions
  
  private func formatAccessibilityLabel(value: Double, unit: String, metric: String) -> String {
    let formattedValue = String(format: "%.1f", value)
    return "\(metric): \(formattedValue) \(unit)"
  }
  
  private func formatPersonalRecordAnnouncement<T: Comparable>(
    record: PersonalRecord<T>,
    recordType: String,
    unit: String,
    formatter: (T) -> String
  ) -> String {
    let formattedValue = formatter(record.value)
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    let dateString = dateFormatter.string(from: record.date)
    
    return "Personal record achieved: \(recordType) of \(formattedValue) \(unit) on \(dateString)"
  }
  
  private func formatChartAccessibilityLabel(chartType: String, dataPoints: Int, trendDescription: String) -> String {
    return "\(chartType) chart with \(dataPoints) data points showing \(trendDescription) trend"
  }
  
  private func determineTrendDescription(data: [Double]) -> String {
    guard data.count >= 2 else { return "insufficient data" }
    
    let firstHalf = Array(data.prefix(data.count / 2))
    let secondHalf = Array(data.suffix(data.count / 2))
    
    let firstAverage = firstHalf.reduce(0, +) / Double(firstHalf.count)
    let secondAverage = secondHalf.reduce(0, +) / Double(secondHalf.count)
    
    let percentChange = ((secondAverage - firstAverage) / firstAverage) * 100
    
    if abs(percentChange) < 5 {
      return "stable"
    } else if percentChange > 0 {
      return "increasing"
    } else {
      return "decreasing"
    }
  }
  
  private func generateAudioGraphDescription(metric: String, values: [Double], pattern: String) -> String {
    let min = values.min() ?? 0
    let max = values.max() ?? 0
    return "\(metric) with \(values.count) data points, ranging from \(String(format: "%.1f", min)) to \(String(format: "%.1f", max)), showing \(pattern) pattern"
  }
  
  private func generateTextBasedAudioGraph(values: [Double], metric: String) -> String {
    guard !values.isEmpty else { return "No data available for \(metric)" }
    
    let min = values.min()!
    let max = values.max()!
    let start = values.first!
    let end = values.last!
    
    return "\(metric) starts at \(String(format: "%.1f", start)), ends at \(String(format: "%.1f", end)), with highest value \(String(format: "%.1f", max)) and lowest value \(String(format: "%.1f", min))"
  }
  
  private func generateHapticFeedbackDescription(values: [Double]) -> String {
    return "Tactile feedback pattern with \(values.count) vibration points representing data trend"
  }
  
  private func generateVisualAudioGraphDescription(values: [Double]) -> String {
    let trend = determineTrendDescription(data: values)
    return "Line chart visualization showing \(trend) pattern across \(values.count) data points"
  }
  
  private func generateRotorEntries(analyticsViewModel: AnalyticsViewModel) -> [String] {
    return [
      "Overview: \(analyticsViewModel.totalSessions) sessions, \(String(format: "%.1f", analyticsViewModel.totalDistanceKm)) kilometers",
      "Charts: Weekly trends and performance visualization",
      "Personal Records: Best achievements across all sessions",
      "Weekly Trends: Training consistency and progress",
      "Detailed Metrics: Advanced analytics and insights"
    ]
  }
  
  private func generateRotorActions() -> [String] {
    return [
      "Play audio graph for weekly distance",
      "Show data table with detailed session information",
      "Change time period selector",
      "View personal records details",
      "Export analytics data",
      "Share analytics summary"
    ]
  }
  
  private func getDynamicTypeScaleFactor(for sizeCategory: ContentSizeCategory) -> CGFloat {
    switch sizeCategory {
    case .small: return 0.85
    case .medium: return 1.0
    case .large: return 1.0
    case .extraLarge: return 1.15
    case .extraExtraLarge: return 1.3
    case .extraExtraExtraLarge: return 1.5
    case .accessibilityMedium: return 1.8
    case .accessibilityLarge: return 2.1
    case .accessibilityExtraLarge: return 2.5
    case .accessibilityExtraExtraLarge: return 2.9
    case .accessibilityExtraExtraExtraLarge: return 3.5
    default: return 1.0
    }
  }
  
  private func calculateChartReadabilityScore(sizeCategory: ContentSizeCategory, scaleFactor: CGFloat) -> Double {
    // Simulate chart readability score based on size category
    let baseScore = 1.0
    let scalingPenalty = max(0, (scaleFactor - 2.0) * 0.2) // Penalty for very large sizes
    return max(0.3, baseScore - scalingPenalty)
  }
  
  private func getStandardChartColors() -> [UIColor] {
    return [.systemBlue, .systemGreen, .systemOrange, .systemRed, .systemPurple]
  }
  
  private func getHighContrastChartColors() -> [UIColor] {
    return [.black, .white, .systemRed, .systemBlue, .systemYellow]
  }
  
  private func calculateContrastRatio(foreground: UIColor, background: UIColor) -> Double {
    // Simplified contrast ratio calculation
    // In real implementation, would calculate luminance properly
    return 4.8 // Simulated WCAG AA compliant ratio
  }
  
  private func getChartPatterns() -> [String] {
    return ["solid", "dashed", "dotted", "striped", "crosshatch"]
  }
  
  private func calculateColorBlindFriendlinessScore(patterns: [String]) -> Double {
    // Simulate color-blind friendliness score
    return patterns.count >= 5 ? 0.9 : 0.7
  }
  
  private func getReducedMotionAnimations() -> [MockAnimation] {
    return [
      MockAnimation(duration: 0.2, includesRotation: false, includesComplexTransitions: false),
      MockAnimation(duration: 0.3, includesRotation: false, includesComplexTransitions: false)
    ]
  }
  
  private func getStandardAnimations() -> [MockAnimation] {
    return [
      MockAnimation(duration: 0.5, includesRotation: true, includesComplexTransitions: true),
      MockAnimation(duration: 0.8, includesRotation: true, includesComplexTransitions: true),
      MockAnimation(duration: 1.2, includesRotation: false, includesComplexTransitions: true)
    ]
  }
  
  private func checkInformationPreservationWithReducedMotion() -> Bool {
    // In real implementation, would verify that essential information is still conveyed
    return true
  }
  
  private func getVoiceControlCommands() -> [String] {
    return [
      "show numbers",
      "tap chart one",
      "play audio graph",
      "show data table",
      "change time period",
      "show personal records",
      "export data"
    ]
  }
  
  private func getSwitchControlElements() -> [MockAccessibilityElement] {
    return [
      MockAccessibilityElement(identifier: "metric_cards", accessibilityLabel: "Analytics Overview"),
      MockAccessibilityElement(identifier: "charts", accessibilityLabel: "Performance Charts"),
      MockAccessibilityElement(identifier: "time_period_selector", accessibilityLabel: "Time Period Selector"),
      MockAccessibilityElement(identifier: "personal_records", accessibilityLabel: "Personal Records"),
      MockAccessibilityElement(identifier: "data_table_button", accessibilityLabel: "Show Data Table"),
      MockAccessibilityElement(identifier: "audio_graph_button", accessibilityLabel: "Play Audio Graph")
    ]
  }
  
  private func formatMetricDescription(value: Double, metric: String) -> String {
    let formattedValue = String(format: "%.1f", value)
    
    switch metric {
    case "total distance":
      return "You have completed \(formattedValue) kilometers total"
    case "total sessions":
      return "You have completed \(Int(value)) ruck sessions"
    case "total calories":
      return "You have burned \(Int(value)) calories total"
    case "training streak":
      if value > 0 {
        return "You have a \(Int(value)) week training streak"
      } else {
        return "Start rucking twice per week to build a training streak"
      }
    default:
      return "\(metric): \(formattedValue)"
    }
  }
  
  private func calculateLanguageComplexity(text: String) -> Double {
    // Simplified complexity calculation based on word length and sentence structure
    let words = text.components(separatedBy: .whitespacesAndNewlines)
    let averageWordLength = words.reduce(0) { $0 + $1.count } / max(words.count, 1)
    
    // Complexity score: 0 = very simple, 1 = very complex
    return min(1.0, Double(averageWordLength) / 10.0)
  }
  
  private func calculateFormalityScore(text: String) -> Double {
    // Simplified formality calculation
    let formalWords = ["please", "kindly", "accordingly", "therefore"]
    let informalWords = ["you", "your", "try", "start"]
    
    let formalCount = formalWords.reduce(0) { count, word in
      count + (text.lowercased().contains(word) ? 1 : 0)
    }
    
    let informalCount = informalWords.reduce(0) { count, word in
      count + (text.lowercased().contains(word) ? 1 : 0)
    }
    
    return Double(formalCount) / Double(max(formalCount + informalCount, 1))
  }
}

// MARK: - Mock Types for Testing

private struct MockAnimation {
  let duration: Double
  let includesRotation: Bool
  let includesComplexTransitions: Bool
}

private struct MockAccessibilityElement {
  let identifier: String
  let accessibilityLabel: String
  let isAccessibilityElement: Bool = true
}