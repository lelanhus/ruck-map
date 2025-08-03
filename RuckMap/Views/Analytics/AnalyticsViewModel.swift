import SwiftUI
import SwiftData
import Foundation
import Observation
import OSLog

/// Main view model for analytics dashboard using @Observable pattern
/// Manages analytics data fetching, caching, and UI state
@Observable
final class AnalyticsViewModel {
  
  // MARK: - Published State
  
  /// Current analytics data for selected time period
  var analyticsData: AnalyticsData?
  
  /// Personal records across all sessions
  var personalRecords: PersonalRecords?
  
  /// Weekly analytics data for chart visualization
  var weeklyAnalyticsData: WeeklyAnalyticsData?
  
  /// Detailed metrics for advanced analytics
  var detailedMetrics: DetailedMetrics?
  
  /// Currently selected analytics time period
  var selectedTimePeriod: AnalyticsTimePeriod = .monthly {
    didSet {
      if selectedTimePeriod != oldValue {
        Task {
          await loadAnalyticsData()
        }
      }
    }
  }
  
  /// Loading states
  var isLoadingAnalytics: Bool = false
  var isLoadingPersonalRecords: Bool = false
  var isLoadingWeeklyData: Bool = false
  var isLoadingDetailedMetrics: Bool = false
  
  /// Error states
  var showingErrorAlert: Bool = false
  var errorMessage: String = ""
  
  /// UI States
  var showingTimePeriodPicker: Bool = false
  var showingDetailedMetrics: Bool = false
  var showingPersonalRecordsDetail: Bool = false
  
  // MARK: - Private Properties
  
  private let analyticsRepository: AnalyticsRepository
  private let logger = Logger(subsystem: "com.ruckmap.app", category: "AnalyticsViewModel")
  private var refreshTask: Task<Void, Never>?
  private var backgroundTasks: [String: Task<Void, Never>] = [:]
  private let memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .warning, queue: .global(qos: .utility))
  
  // MARK: - Initialization
  
  init(modelContainer: ModelContainer) {
    self.analyticsRepository = AnalyticsRepository(modelContainer: modelContainer)
    setupMemoryPressureHandling()
  }
  
  // MARK: - Public Methods
  
  /// Loads all analytics data for the current time period
  @MainActor
  func loadAllAnalyticsData() async {
    guard !isLoadingAnalytics else { return }
    
    refreshTask?.cancel()
    refreshTask = Task {
      await loadAnalyticsData()
      await loadPersonalRecords()
      await loadWeeklyAnalyticsData()
    }
  }
  
  /// Loads analytics data for the selected time period
  @MainActor
  func loadAnalyticsData() async {
    guard !isLoadingAnalytics else { return }
    
    isLoadingAnalytics = true
    errorMessage = ""
    
    do {
      let data = try await analyticsRepository.fetchAnalyticsData(for: selectedTimePeriod)
      analyticsData = data
      logger.info("Successfully loaded analytics data for \(selectedTimePeriod.rawValue)")
    } catch {
      await handleError(error, context: "loading analytics data")
    }
    
    isLoadingAnalytics = false
  }
  
  /// Loads personal records
  @MainActor
  func loadPersonalRecords() async {
    guard !isLoadingPersonalRecords else { return }
    
    isLoadingPersonalRecords = true
    
    do {
      let records = try await analyticsRepository.fetchPersonalRecords()
      personalRecords = records
      logger.info("Successfully loaded personal records")
    } catch {
      await handleError(error, context: "loading personal records")
    }
    
    isLoadingPersonalRecords = false
  }
  
  /// Loads weekly analytics data for charts
  @MainActor
  func loadWeeklyAnalyticsData(numberOfWeeks: Int = 12) async {
    guard !isLoadingWeeklyData else { return }
    
    isLoadingWeeklyData = true
    
    do {
      let data = try await analyticsRepository.fetchWeeklyAnalyticsData(numberOfWeeks: numberOfWeeks)
      weeklyAnalyticsData = data
      logger.info("Successfully loaded weekly analytics data for \(numberOfWeeks) weeks")
    } catch {
      await handleError(error, context: "loading weekly analytics data")
    }
    
    isLoadingWeeklyData = false
  }
  
  /// Loads detailed metrics for advanced analytics
  @MainActor
  func loadDetailedMetrics() async {
    guard !isLoadingDetailedMetrics else { return }
    
    isLoadingDetailedMetrics = true
    
    do {
      let metrics = try await analyticsRepository.fetchDetailedMetrics(for: selectedTimePeriod)
      detailedMetrics = metrics
      logger.info("Successfully loaded detailed metrics for \(selectedTimePeriod.rawValue)")
    } catch {
      await handleError(error, context: "loading detailed metrics")
    }
    
    isLoadingDetailedMetrics = false
  }
  
  /// Refreshes all analytics data
  @MainActor
  func refreshAnalytics() async {
    // Invalidate cache to force fresh data
    await analyticsRepository.invalidateCache()
    await loadAllAnalyticsData()
  }
  
  /// Changes the selected time period and refreshes data
  @MainActor
  func changeTimePeriod(to newPeriod: AnalyticsTimePeriod) {
    selectedTimePeriod = newPeriod
    showingTimePeriodPicker = false
  }
  
  /// Shows detailed metrics view
  @MainActor
  func showDetailedMetrics() {
    showingDetailedMetrics = true
    Task {
      await loadDetailedMetrics()
    }
  }
  
  /// Shows personal records detail view
  @MainActor
  func showPersonalRecordsDetail() {
    showingPersonalRecordsDetail = true
  }
  
  /// Dismisses error alert
  @MainActor
  func dismissError() {
    showingErrorAlert = false
    errorMessage = ""
  }
  
  // MARK: - Computed Properties
  
  /// Indicates if any data is currently loading
  var isLoading: Bool {
    isLoadingAnalytics || isLoadingPersonalRecords || isLoadingWeeklyData || isLoadingDetailedMetrics
  }
  
  /// Indicates if analytics data is available
  var hasAnalyticsData: Bool {
    analyticsData != nil
  }
  
  /// Indicates if personal records are available
  var hasPersonalRecords: Bool {
    personalRecords != nil
  }
  
  /// Indicates if weekly data is available
  var hasWeeklyData: Bool {
    weeklyAnalyticsData != nil
  }
  
  /// Gets the current training streak
  var currentTrainingStreak: Int {
    analyticsData?.trainingStreak ?? 0
  }
  
  /// Gets the total sessions for current period
  var totalSessions: Int {
    analyticsData?.totalSessions ?? 0
  }
  
  /// Gets the total distance for current period (in kilometers)
  var totalDistanceKm: Double {
    guard let data = analyticsData else { return 0 }
    return data.totalDistance / 1000.0
  }
  
  /// Gets the average pace for current period
  var averagePace: Double {
    analyticsData?.averagePace ?? 0
  }
  
  /// Gets the total calories for current period
  var totalCalories: Double {
    analyticsData?.totalCalories ?? 0
  }
  
  /// Gets the total weight moved for current period
  var totalWeightMoved: Double {
    analyticsData?.totalWeightMoved ?? 0
  }
  
  // MARK: - Trend Helpers
  
  /// Gets distance trend information
  var distanceTrend: TrendData? {
    analyticsData?.distanceTrend
  }
  
  /// Gets pace trend information
  var paceTrend: TrendData? {
    analyticsData?.paceTrend
  }
  
  /// Gets calorie trend information
  var calorieTrend: TrendData? {
    analyticsData?.calorieTrend
  }
  
  /// Gets session count trend information
  var sessionCountTrend: TrendData? {
    analyticsData?.sessionCountTrend
  }
  
  // MARK: - Personal Records Helpers
  
  /// Gets the longest distance personal record
  var longestDistanceRecord: PersonalRecord<Double>? {
    personalRecords?.longestDistance
  }
  
  /// Gets the fastest pace personal record
  var fastestPaceRecord: PersonalRecord<Double>? {
    personalRecords?.fastestPace
  }
  
  /// Gets the heaviest load personal record
  var heaviestLoadRecord: PersonalRecord<Double>? {
    personalRecords?.heaviestLoad
  }
  
  /// Gets the highest calorie burn personal record
  var highestCalorieRecord: PersonalRecord<Double>? {
    personalRecords?.highestCalorieBurn
  }
  
  /// Gets the longest duration personal record
  var longestDurationRecord: PersonalRecord<TimeInterval>? {
    personalRecords?.longestDuration
  }
  
  /// Gets the most weight moved personal record
  var mostWeightMovedRecord: PersonalRecord<Double>? {
    personalRecords?.mostWeightMoved
  }
  
  // MARK: - Weekly Data Helpers
  
  /// Gets weekly distance data for charts
  var weeklyDistanceData: [(week: String, distance: Double)] {
    guard let weeklyData = weeklyAnalyticsData else { return [] }
    
    return weeklyData.weeks.map { week in
      (week.formattedWeekRange, week.totalDistance / 1000.0) // Convert to km
    }
  }
  
  /// Gets weekly session count data for charts
  var weeklySessionData: [(week: String, sessions: Int)] {
    guard let weeklyData = weeklyAnalyticsData else { return [] }
    
    return weeklyData.weeks.map { week in
      (week.formattedWeekRange, week.sessionCount)
    }
  }
  
  /// Gets weekly calorie data for charts
  var weeklyCalorieData: [(week: String, calories: Double)] {
    guard let weeklyData = weeklyAnalyticsData else { return [] }
    
    return weeklyData.weeks.map { week in
      (week.formattedWeekRange, week.totalCalories)
    }
  }
  
  /// Gets training goal achievement data
  var weeklyGoalAchievement: [(week: String, achieved: Bool)] {
    guard let weeklyData = weeklyAnalyticsData else { return [] }
    
    return weeklyData.weeks.map { week in
      (week.formattedWeekRange, week.meetsTrainingGoal)
    }
  }
  
  // MARK: - Formatting Helpers
  
  /// Formats distance in appropriate units
  func formatDistance(_ distance: Double) -> String {
    let km = distance / 1000.0
    if km < 1.0 {
      return String(format: "%.0f m", distance)
    } else {
      return String(format: "%.2f km", km)
    }
  }
  
  /// Formats pace in min/km
  func formatPace(_ pace: Double) -> String {
    guard pace > 0 else { return "N/A" }
    
    let minutes = Int(pace)
    let seconds = Int((pace - Double(minutes)) * 60)
    return String(format: "%d:%02d/km", minutes, seconds)
  }
  
  /// Formats duration in hours and minutes
  func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = Int(duration) % 3600 / 60
    
    if hours > 0 {
      return String(format: "%dh %dm", hours, minutes)
    } else {
      return String(format: "%dm", minutes)
    }
  }
  
  /// Formats calories with appropriate precision
  func formatCalories(_ calories: Double) -> String {
    return String(format: "%.0f cal", calories)
  }
  
  /// Formats weight with appropriate unit
  func formatWeight(_ weight: Double) -> String {
    return String(format: "%.1f kg", weight)
  }
  
  /// Formats weight moved (kg×km)
  func formatWeightMoved(_ weightMoved: Double) -> String {
    return String(format: "%.1f kg×km", weightMoved)
  }
  
  // MARK: - Private Methods
  
  /// Handles errors consistently across all operations
  @MainActor
  private func handleError(_ error: Error, context: String) async {
    logger.error("Error \(context): \(error.localizedDescription)")
    errorMessage = "Failed \(context): \(error.localizedDescription)"
    showingErrorAlert = true
  }
  
  /// Precomputes analytics data in the background
  private func precomputeAnalytics() {
    Task {
      do {
        try await analyticsRepository.precomputeAnalytics()
        logger.info("Analytics precomputation completed")
      } catch {
        logger.error("Analytics precomputation failed: \(error.localizedDescription)")
      }
    }
  }
  
  // MARK: - Background Processing
  
  /// Sets up memory pressure handling
  private func setupMemoryPressureHandling() {
    memoryPressureSource.setEventHandler { [weak self] in
      Task { @MainActor in
        await self?.handleMemoryPressure()
      }
    }
    memoryPressureSource.resume()
  }
  
  /// Handles memory pressure by clearing non-essential data
  @MainActor
  private func handleMemoryPressure() async {
    logger.warning("Handling memory pressure in AnalyticsViewModel")
    
    // Cancel background tasks
    backgroundTasks.values.forEach { $0.cancel() }
    backgroundTasks.removeAll()
    
    // Clear detailed metrics if not currently shown
    if !showingDetailedMetrics {
      detailedMetrics = nil
    }
    
    // Clear weekly data if not actively being used
    if selectedTimePeriod != .weekly {
      weeklyAnalyticsData = nil
    }
    
    // Ask repository to handle memory pressure
    await analyticsRepository.handleMemoryPressure()
  }
  
  /// Loads analytics data in background with priority
  private func loadAnalyticsDataInBackground(priority: TaskPriority = .background) {
    let taskKey = "analytics_\(selectedTimePeriod.rawValue)"
    
    // Cancel existing background task for this period
    backgroundTasks[taskKey]?.cancel()
    
    backgroundTasks[taskKey] = Task(priority: priority) {
      do {
        let data = try await analyticsRepository.fetchAnalyticsData(for: selectedTimePeriod)
        
        await MainActor.run {
          guard !Task.isCancelled else { return }
          self.analyticsData = data
          self.isLoadingAnalytics = false
        }
      } catch {
        await MainActor.run {
          guard !Task.isCancelled else { return }
          self.handleError(error, context: "loading analytics data in background")
          self.isLoadingAnalytics = false
        }
      }
    }
  }
  
  /// Preloads commonly used analytics data
  func preloadCommonAnalytics() {
    let commonPeriods: [AnalyticsTimePeriod] = [.weekly, .monthly, .last3Months]
    
    for period in commonPeriods {
      let taskKey = "preload_\(period.rawValue)"
      backgroundTasks[taskKey] = Task(priority: .utility) {
        _ = try? await analyticsRepository.fetchAnalyticsData(for: period)
      }
    }
  }
  
  // MARK: - Lifecycle
  
  deinit {
    refreshTask?.cancel()
    backgroundTasks.values.forEach { $0.cancel() }
    memoryPressureSource.cancel()
  }
}

// MARK: - Analytics Dashboard State

/// Represents the current state of the analytics dashboard
enum AnalyticsDashboardState {
  case loading
  case loaded
  case error(String)
  case empty
  
  var isLoading: Bool {
    if case .loading = self { return true }
    return false
  }
  
  var isError: Bool {
    if case .error = self { return true }
    return false
  }
  
  var isEmpty: Bool {
    if case .empty = self { return true }
    return false
  }
  
  var errorMessage: String? {
    if case .error(let message) = self { return message }
    return nil
  }
}

// MARK: - Comparison View Model

/// View model for comparative analytics between time periods
@Observable
final class ComparativeAnalyticsViewModel {
  
  // MARK: - Published State
  
  var currentPeriodData: AnalyticsData?
  var comparisonPeriodData: AnalyticsData?
  
  var selectedCurrentPeriod: AnalyticsTimePeriod = .monthly
  var selectedComparisonPeriod: AnalyticsTimePeriod = .lastMonth
  
  var isLoading: Bool = false
  var errorMessage: String = ""
  var showingErrorAlert: Bool = false
  
  // MARK: - Private Properties
  
  private let analyticsRepository: AnalyticsRepository
  private let logger = Logger(subsystem: "com.ruckmap.app", category: "ComparativeAnalyticsViewModel")
  
  // MARK: - Initialization
  
  init(modelContainer: ModelContainer) {
    self.analyticsRepository = AnalyticsRepository(modelContainer: modelContainer)
  }
  
  // MARK: - Public Methods
  
  /// Loads comparative analytics data
  @MainActor
  func loadComparativeData() async {
    guard !isLoading else { return }
    
    isLoading = true
    errorMessage = ""
    
    do {
      let (current, comparison) = try await analyticsRepository.fetchComparativeAnalytics(
        currentPeriod: selectedCurrentPeriod,
        comparisonPeriod: selectedComparisonPeriod
      )
      
      currentPeriodData = current
      comparisonPeriodData = comparison
      
      logger.info("Successfully loaded comparative analytics data")
    } catch {
      logger.error("Error loading comparative analytics: \(error.localizedDescription)")
      errorMessage = "Failed to load comparative data: \(error.localizedDescription)"
      showingErrorAlert = true
    }
    
    isLoading = false
  }
  
  /// Updates the current period selection
  @MainActor
  func updateCurrentPeriod(_ period: AnalyticsTimePeriod) {
    selectedCurrentPeriod = period
    Task {
      await loadComparativeData()
    }
  }
  
  /// Updates the comparison period selection
  @MainActor
  func updateComparisonPeriod(_ period: AnalyticsTimePeriod) {
    selectedComparisonPeriod = period
    Task {
      await loadComparativeData()
    }
  }
  
  // MARK: - Computed Properties
  
  /// Distance comparison data
  var distanceComparison: (current: Double, comparison: Double, change: Double)? {
    guard let current = currentPeriodData,
          let comparison = comparisonPeriodData else { return nil }
    
    let change = comparison.totalDistance > 0 ?
      ((current.totalDistance - comparison.totalDistance) / comparison.totalDistance) * 100 : 0
    
    return (current.totalDistance, comparison.totalDistance, change)
  }
  
  /// Session count comparison data
  var sessionComparison: (current: Int, comparison: Int, change: Double)? {
    guard let current = currentPeriodData,
          let comparison = comparisonPeriodData else { return nil }
    
    let change = comparison.totalSessions > 0 ?
      Double(current.totalSessions - comparison.totalSessions) / Double(comparison.totalSessions) * 100 : 0
    
    return (current.totalSessions, comparison.totalSessions, change)
  }
  
  /// Calories comparison data
  var caloriesComparison: (current: Double, comparison: Double, change: Double)? {
    guard let current = currentPeriodData,
          let comparison = comparisonPeriodData else { return nil }
    
    let change = comparison.totalCalories > 0 ?
      ((current.totalCalories - comparison.totalCalories) / comparison.totalCalories) * 100 : 0
    
    return (current.totalCalories, comparison.totalCalories, change)
  }
}