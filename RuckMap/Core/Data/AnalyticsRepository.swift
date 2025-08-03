import Foundation
import SwiftData
import OSLog

/// Repository for analytics data with efficient querying and caching
@ModelActor
actor AnalyticsRepository {
  private let logger = Logger(subsystem: "com.ruckmap.app", category: "AnalyticsRepository")
  
  // MARK: - Cache Management
  
  private var analyticsCache: [String: CachedAnalytics] = [:]
  private var personalRecordsCache: CachedPersonalRecords?
  private var weeklyAnalyticsCache: [String: CachedWeeklyAnalytics] = [:]
  private static let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
  
  /// Cached analytics data with timestamp
  private struct CachedAnalytics {
    let data: AnalyticsData
    let timestamp: Date
    
    var isExpired: Bool {
      Date().timeIntervalSince(timestamp) > AnalyticsRepository.cacheExpirationInterval
    }
  }
  
  /// Cached personal records with timestamp
  private struct CachedPersonalRecords {
    let records: PersonalRecords
    let timestamp: Date
    
    var isExpired: Bool {
      Date().timeIntervalSince(timestamp) > AnalyticsRepository.cacheExpirationInterval
    }
  }
  
  /// Cached weekly analytics with timestamp
  private struct CachedWeeklyAnalytics {
    let data: WeeklyAnalyticsData
    let timestamp: Date
    
    var isExpired: Bool {
      Date().timeIntervalSince(timestamp) > AnalyticsRepository.cacheExpirationInterval
    }
  }
  
  // MARK: - Public Methods
  
  /// Fetches analytics data for a specific time period with caching
  func fetchAnalyticsData(for timePeriod: AnalyticsTimePeriod) async throws -> AnalyticsData {
    let cacheKey = "analytics_\(timePeriod.rawValue)"
    
    // Check cache first
    if let cached = analyticsCache[cacheKey], !cached.isExpired {
      logger.debug("Returning cached analytics data for \(timePeriod.rawValue)")
      return cached.data
    }
    
    logger.info("Computing fresh analytics data for \(timePeriod.rawValue)")
    
    // Fetch sessions for the time period
    let dateRange = timePeriod.dateRange()
    let sessions = try await fetchSessions(from: dateRange.start, to: dateRange.end)
    
    // Fetch previous period sessions for trend calculation
    let previousPeriodSessions = try await fetchPreviousPeriodSessions(for: timePeriod)
    
    // Create analytics data
    let analyticsData = AnalyticsData(
      sessions: sessions,
      timePeriod: timePeriod,
      previousPeriodSessions: previousPeriodSessions
    )
    
    // Cache the result
    analyticsCache[cacheKey] = CachedAnalytics(
      data: analyticsData,
      timestamp: Date()
    )
    
    return analyticsData
  }
  
  /// Fetches personal records across all sessions
  func fetchPersonalRecords() async throws -> PersonalRecords {
    // Check if we have cached personal records
    if let cached = personalRecordsCache, !cached.isExpired {
      logger.debug("Returning cached personal records")
      return cached.records
    }
    
    logger.info("Computing fresh personal records")
    
    // Fetch all completed sessions
    let allSessions = try await fetchAllCompletedSessions()
    let personalRecords = PersonalRecords(sessions: allSessions)
    
    // Cache the result
    personalRecordsCache = CachedPersonalRecords(
      records: personalRecords,
      timestamp: Date()
    )
    
    return personalRecords
  }
  
  /// Fetches weekly analytics data for trend visualization
  func fetchWeeklyAnalyticsData(numberOfWeeks: Int = 12) async throws -> WeeklyAnalyticsData {
    let cacheKey = "weekly_analytics_\(numberOfWeeks)"
    
    if let cached = weeklyAnalyticsCache[cacheKey], !cached.isExpired {
      logger.debug("Returning cached weekly analytics data")
      return cached.data
    }
    
    logger.info("Computing fresh weekly analytics data")
    
    // Fetch sessions from the last N weeks
    let calendar = Calendar.current
    let endDate = Date()
    
    guard let startDate = calendar.date(byAdding: .weekOfYear, value: -numberOfWeeks, to: endDate) else {
      throw AnalyticsError.invalidDateRange
    }
    
    let sessions = try await fetchSessions(from: startDate, to: endDate)
    let weeklyData = WeeklyAnalyticsData(sessions: sessions, numberOfWeeks: numberOfWeeks)
    
    // Cache the result
    weeklyAnalyticsCache[cacheKey] = CachedWeeklyAnalytics(
      data: weeklyData,
      timestamp: Date()
    )
    
    return weeklyData
  }
  
  /// Fetches analytics data for comparison between two time periods
  func fetchComparativeAnalytics(
    currentPeriod: AnalyticsTimePeriod,
    comparisonPeriod: AnalyticsTimePeriod
  ) async throws -> (current: AnalyticsData, comparison: AnalyticsData) {
    
    async let currentData = fetchAnalyticsData(for: currentPeriod)
    async let comparisonData = fetchAnalyticsData(for: comparisonPeriod)
    
    return try await (currentData, comparisonData)
  }
  
  /// Fetches detailed session metrics for a specific time period
  func fetchDetailedMetrics(for timePeriod: AnalyticsTimePeriod) async throws -> DetailedMetrics {
    let dateRange = timePeriod.dateRange()
    let sessions = try await fetchSessions(from: dateRange.start, to: dateRange.end)
    
    return DetailedMetrics(sessions: sessions, timePeriod: timePeriod)
  }
  
  /// Invalidates analytics cache (call when new sessions are added/modified)
  func invalidateCache() {
    analyticsCache.removeAll()
    logger.info("Analytics cache invalidated")
  }
  
  /// Invalidates specific cache entries
  func invalidateCache(for timePeriods: [AnalyticsTimePeriod]) {
    for period in timePeriods {
      let cacheKey = "analytics_\(period.rawValue)"
      analyticsCache.removeValue(forKey: cacheKey)
    }
    logger.info("Invalidated cache for \(timePeriods.count) time periods")
  }
  
  // MARK: - Private Query Methods
  
  /// Fetches sessions within a date range with optimized query
  private func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [RuckSession] {
    let descriptor = FetchDescriptor<RuckSession>(
      predicate: #Predicate<RuckSession> { session in
        session.startDate >= startDate &&
        session.startDate <= endDate &&
        session.endDate != nil // Only completed sessions
      },
      sortBy: [SortDescriptor(\.startDate, order: .forward)]
    )
    
    // Optimize by only fetching needed properties for analytics
    descriptor.propertiesToFetch = [
      \.id,
      \.startDate,
      \.endDate,
      \.totalDistance,
      \.totalDuration,
      \.totalCalories,
      \.loadWeight,
      \.averagePace,
      \.elevationGain,
      \.elevationLoss
    ]
    
    // Add fetch limit for memory efficiency with large datasets
    descriptor.fetchLimit = 10000 // Prevent excessive memory usage
    
    return try modelContext.fetch(descriptor)
  }
  
  /// Fetches all completed sessions (for personal records) with batching
  private func fetchAllCompletedSessions() async throws -> [RuckSession] {
    let descriptor = FetchDescriptor<RuckSession>(
      predicate: #Predicate<RuckSession> { session in
        session.endDate != nil
      },
      sortBy: [SortDescriptor(\.startDate, order: .reverse)] // Most recent first for early optimization
    )
    
    // Limit to essential properties for performance
    descriptor.propertiesToFetch = [
      \.id,
      \.startDate,
      \.totalDistance,
      \.totalDuration,
      \.totalCalories,
      \.loadWeight,
      \.averagePace
    ]
    
    // Add fetch limit to prevent memory issues
    // Process in batches if needed for very large datasets
    descriptor.fetchLimit = 1000 // More conservative limit for better performance
    
    return try modelContext.fetch(descriptor)
  }
  
  /// Fetches sessions for the previous period to calculate trends
  private func fetchPreviousPeriodSessions(for timePeriod: AnalyticsTimePeriod) async throws -> [RuckSession] {
    let currentRange = timePeriod.dateRange()
    let periodDuration = currentRange.end.timeIntervalSince(currentRange.start)
    
    let previousStart = currentRange.start.addingTimeInterval(-periodDuration)
    let previousEnd = currentRange.start
    
    return try await fetchSessions(from: previousStart, to: previousEnd)
  }
  
  /// Fetches session count by week for streak calculation
  private func fetchWeeklySessionCounts(from startDate: Date, to endDate: Date) async throws -> [Date: Int] {
    let sessions = try await fetchSessions(from: startDate, to: endDate)
    let calendar = Calendar.current
    
    var weeklyCount: [Date: Int] = [:]
    
    for session in sessions {
      if let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.startDate)?.start {
        weeklyCount[weekStart, default: 0] += 1
      }
    }
    
    return weeklyCount
  }
  
  // MARK: - Batch Operations
  
  /// Precomputes and caches analytics for common time periods with priority ordering
  func precomputeAnalytics() async throws {
    logger.info("Starting analytics precomputation")
    
    // Prioritize most commonly used periods first
    let prioritizedPeriods: [AnalyticsTimePeriod] = [
      .monthly,
      .weekly,
      .last3Months,
      .last6Months,
      .lastYear,
      .allTime
    ]
    
    // Use TaskGroup with limited concurrency to prevent overwhelming the system
    try await withThrowingTaskGroup(of: Void.self) { group in
      var activeTasks = 0
      let maxConcurrentTasks = 3 // Limit concurrent tasks to prevent resource exhaustion
      
      for period in prioritizedPeriods {
        if activeTasks < maxConcurrentTasks {
          group.addTask {
            _ = try await self.fetchAnalyticsData(for: period)
          }
          activeTasks += 1
        } else {
          // Wait for a task to complete before starting the next
          _ = try await group.next()
          activeTasks -= 1
          
          group.addTask {
            _ = try await self.fetchAnalyticsData(for: period)
          }
          activeTasks += 1
        }
      }
      
      // Wait for remaining tasks to complete
      while activeTasks > 0 {
        _ = try await group.next()
        activeTasks -= 1
      }
    }
    
    logger.info("Analytics precomputation completed")
  }
  
  /// Handles memory pressure by clearing non-essential cache
  func handleMemoryPressure() {
    logger.warning("Handling memory pressure - clearing analytics cache")
    
    // Keep only the most recently used cache entries
    let sortedEntries = analyticsCache.sorted { $0.value.timestamp > $1.value.timestamp }
    let entriesToKeep = Array(sortedEntries.prefix(5)) // Keep only 5 most recent
    
    analyticsCache.removeAll()
    
    for (key, value) in entriesToKeep {
      analyticsCache[key] = value
    }
    
    logger.info("Reduced analytics cache to \(analyticsCache.count) entries")
  }
  
  /// Fetches analytics data in the background with cancellation support
  func fetchAnalyticsDataInBackground(
    for timePeriod: AnalyticsTimePeriod,
    priority: TaskPriority = .background
  ) -> Task<AnalyticsData, Error> {
    
    return Task(priority: priority) {
      try await fetchAnalyticsData(for: timePeriod)
    }
  }
  
  /// Performs analytics cache maintenance with memory pressure handling
  func performCacheMaintenance() {
    let expiredKeys = analyticsCache.compactMap { key, cached in
      cached.isExpired ? key : nil
    }
    
    for key in expiredKeys {
      analyticsCache.removeValue(forKey: key)
    }
    
    if !expiredKeys.isEmpty {
      logger.info("Removed \(expiredKeys.count) expired cache entries")
    }
    
    // Proactive memory management - limit cache size
    if analyticsCache.count > 20 {
      let sortedEntries = analyticsCache.sorted { $0.value.timestamp < $1.value.timestamp }
      let entriesToRemove = sortedEntries.prefix(analyticsCache.count - 15)
      
      for (key, _) in entriesToRemove {
        analyticsCache.removeValue(forKey: key)
      }
      
      logger.info("Removed \(entriesToRemove.count) old cache entries for memory management")
    }
  }
}

// MARK: - Detailed Metrics Model

/// Detailed metrics for advanced analytics
struct DetailedMetrics: Sendable {
  let timePeriod: AnalyticsTimePeriod
  let sessions: [RuckSession]
  
  // Pace analysis
  let paceBuckets: [PaceBucket]
  let paceConsistency: Double // coefficient of variation
  
  // Distance analysis  
  let distanceBuckets: [DistanceBucket]
  let preferredDistanceRange: ClosedRange<Double>
  
  // Load analysis
  let loadWeightDistribution: [LoadBucket]
  let averageLoadProgression: [Date: Double]
  
  // Terrain analysis
  let terrainDistribution: [TerrainType: Double] // percentage of total distance
  
  // Weather impact
  let weatherImpactAnalysis: WeatherImpactData
  
  init(sessions: [RuckSession], timePeriod: AnalyticsTimePeriod) {
    self.timePeriod = timePeriod
    self.sessions = sessions
    
    // Calculate pace buckets
    self.paceBuckets = Self.calculatePaceBuckets(sessions: sessions)
    self.paceConsistency = Self.calculatePaceConsistency(sessions: sessions)
    
    // Calculate distance buckets
    self.distanceBuckets = Self.calculateDistanceBuckets(sessions: sessions)
    self.preferredDistanceRange = Self.calculatePreferredDistanceRange(sessions: sessions)
    
    // Calculate load distribution
    self.loadWeightDistribution = Self.calculateLoadBuckets(sessions: sessions)
    self.averageLoadProgression = Self.calculateLoadProgression(sessions: sessions)
    
    // Calculate terrain distribution
    self.terrainDistribution = Self.calculateTerrainDistribution(sessions: sessions)
    
    // Calculate weather impact
    self.weatherImpactAnalysis = WeatherImpactData(sessions: sessions)
  }
  
  // MARK: - Static Analysis Methods
  
  private static func calculatePaceBuckets(sessions: [RuckSession]) -> [PaceBucket] {
    let validSessions = sessions.filter { $0.averagePace > 0 }
    guard !validSessions.isEmpty else { return [] }
    
    let paces = validSessions.map(\.averagePace)
    let minPace = paces.min() ?? 0
    let maxPace = paces.max() ?? 0
    
    let bucketSize = (maxPace - minPace) / 5
    var buckets: [PaceBucket] = []
    
    for i in 0..<5 {
      let bucketMin = minPace + (Double(i) * bucketSize)
      let bucketMax = bucketMin + bucketSize
      
      let sessionsInBucket = validSessions.filter { session in
        session.averagePace >= bucketMin && session.averagePace < bucketMax
      }
      
      buckets.append(PaceBucket(
        range: bucketMin...bucketMax,
        sessionCount: sessionsInBucket.count,
        percentage: Double(sessionsInBucket.count) / Double(validSessions.count) * 100
      ))
    }
    
    return buckets
  }
  
  private static func calculatePaceConsistency(sessions: [RuckSession]) -> Double {
    let paces = sessions.compactMap { $0.averagePace > 0 ? $0.averagePace : nil }
    guard paces.count > 1 else { return 0 }
    
    let mean = paces.reduce(0, +) / Double(paces.count)
    let variance = paces.map { pow($0 - mean, 2) }.reduce(0, +) / Double(paces.count)
    let standardDeviation = sqrt(variance)
    
    return mean > 0 ? (standardDeviation / mean) : 0
  }
  
  private static func calculateDistanceBuckets(sessions: [RuckSession]) -> [DistanceBucket] {
    guard !sessions.isEmpty else { return [] }
    
    let distances = sessions.map { $0.totalDistance / 1000.0 } // Convert to km
    let bucketRanges: [ClosedRange<Double>] = [
      0...3,
      3...8,
      8...15,
      15...25,
      25...Double.infinity
    ]
    
    return bucketRanges.compactMap { range in
      let sessionsInRange = sessions.filter { session in
        let distanceKm = session.totalDistance / 1000.0
        return range.contains(distanceKm)
      }
      
      guard !sessionsInRange.isEmpty else { return nil }
      
      return DistanceBucket(
        range: range,
        sessionCount: sessionsInRange.count,
        percentage: Double(sessionsInRange.count) / Double(sessions.count) * 100
      )
    }
  }
  
  private static func calculatePreferredDistanceRange(sessions: [RuckSession]) -> ClosedRange<Double> {
    guard !sessions.isEmpty else { return 0...10 }
    
    let distances = sessions.map { $0.totalDistance / 1000.0 }
    let sortedDistances = distances.sorted()
    
    // Calculate interquartile range
    let q1Index = sortedDistances.count / 4
    let q3Index = (sortedDistances.count * 3) / 4
    
    let q1 = sortedDistances[q1Index]
    let q3 = sortedDistances[q3Index]
    
    return q1...q3
  }
  
  private static func calculateLoadBuckets(sessions: [RuckSession]) -> [LoadBucket] {
    guard !sessions.isEmpty else { return [] }
    
    let bucketRanges: [ClosedRange<Double>] = [
      0...15,
      15...25,
      25...35,
      35...50,
      50...Double.infinity
    ]
    
    return bucketRanges.compactMap { range in
      let sessionsInRange = sessions.filter { range.contains($0.loadWeight) }
      guard !sessionsInRange.isEmpty else { return nil }
      
      return LoadBucket(
        range: range,
        sessionCount: sessionsInRange.count,
        percentage: Double(sessionsInRange.count) / Double(sessions.count) * 100
      )
    }
  }
  
  private static func calculateLoadProgression(sessions: [RuckSession]) -> [Date: Double] {
    let sortedSessions = sessions.sorted { $0.startDate < $1.startDate }
    let calendar = Calendar.current
    
    var monthlyAverages: [Date: (total: Double, count: Int)] = [:]
    
    for session in sortedSessions {
      let monthStart = calendar.dateInterval(of: .month, for: session.startDate)?.start ?? session.startDate
      
      if let existing = monthlyAverages[monthStart] {
        monthlyAverages[monthStart] = (existing.total + session.loadWeight, existing.count + 1)
      } else {
        monthlyAverages[monthStart] = (session.loadWeight, 1)
      }
    }
    
    return monthlyAverages.mapValues { $0.total / Double($0.count) }
  }
  
  private static func calculateTerrainDistribution(sessions: [RuckSession]) -> [TerrainType: Double] {
    let totalDistance = sessions.reduce(0) { $0 + $1.totalDistance }
    guard totalDistance > 0 else { return [:] }
    
    var terrainDistances: [TerrainType: Double] = [:]
    
    for session in sessions {
      // If session has terrain segments, use them
      if !session.terrainSegments.isEmpty {
        for segment in session.terrainSegments {
          let segmentDistance = segment.duration * (session.totalDistance / session.totalDuration)
          terrainDistances[segment.terrainType, default: 0] += segmentDistance
        }
      } else {
        // Default to pavedRoad if no terrain data
        terrainDistances[.pavedRoad, default: 0] += session.totalDistance
      }
    }
    
    // Convert to percentages
    return terrainDistances.mapValues { ($0 / totalDistance) * 100 }
  }
}

// MARK: - Supporting Analysis Models

struct PaceBucket: Sendable, Identifiable {
  let id = UUID()
  let range: ClosedRange<Double>
  let sessionCount: Int
  let percentage: Double
}

struct DistanceBucket: Sendable, Identifiable {
  let id = UUID()
  let range: ClosedRange<Double>
  let sessionCount: Int
  let percentage: Double
}

struct LoadBucket: Sendable, Identifiable {
  let id = UUID()
  let range: ClosedRange<Double>
  let sessionCount: Int
  let percentage: Double
}

struct WeatherImpactData: Sendable {
  let averagePaceByTemperature: [TemperatureRange: Double]
  let calorieAdjustmentByConditions: [WeatherCondition: Double]
  let performanceInHarshConditions: Double // pace penalty percentage
  
  init(sessions: [RuckSession]) {
    // Calculate average pace by temperature ranges
    var tempRangePaces: [TemperatureRange: [Double]] = [:]
    
    for session in sessions {
      guard let weather = session.weatherConditions, session.averagePace > 0 else { continue }
      
      let tempRange = TemperatureRange.from(temperature: weather.temperature)
      tempRangePaces[tempRange, default: []].append(session.averagePace)
    }
    
    self.averagePaceByTemperature = tempRangePaces.mapValues { paces in
      paces.reduce(0, +) / Double(paces.count)
    }
    
    // Calculate calorie adjustments
    var conditionCalories: [WeatherCondition: [Double]] = [:]
    
    for session in sessions {
      guard let weather = session.weatherConditions else { continue }
      
      let condition = WeatherCondition.from(weather: weather)
      conditionCalories[condition, default: []].append(session.totalCalories)
    }
    
    self.calorieAdjustmentByConditions = conditionCalories.mapValues { calories in
      calories.reduce(0, +) / Double(calories.count)
    }
    
    // Calculate performance penalty in harsh conditions
    let normalSessions = sessions.filter { session in
      guard let weather = session.weatherConditions else { return false }
      return !weather.isHarshConditions && session.averagePace > 0
    }
    
    let harshSessions = sessions.filter { session in
      guard let weather = session.weatherConditions else { return false }
      return weather.isHarshConditions && session.averagePace > 0
    }
    
    if !normalSessions.isEmpty && !harshSessions.isEmpty {
      let normalAvgPace = normalSessions.map(\.averagePace).reduce(0, +) / Double(normalSessions.count)
      let harshAvgPace = harshSessions.map(\.averagePace).reduce(0, +) / Double(harshSessions.count)
      
      self.performanceInHarshConditions = ((harshAvgPace - normalAvgPace) / normalAvgPace) * 100
    } else {
      self.performanceInHarshConditions = 0
    }
  }
}

enum TemperatureRange: CaseIterable, Sendable {
  case freezing    // < 0°C
  case cold        // 0-10°C
  case cool        // 10-20°C
  case moderate    // 20-30°C
  case hot         // > 30°C
  
  static func from(temperature: Double) -> TemperatureRange {
    switch temperature {
    case ..<0: return .freezing
    case 0..<10: return .cold
    case 10..<20: return .cool
    case 20..<30: return .moderate
    default: return .hot
    }
  }
  
  var displayName: String {
    switch self {
    case .freezing: return "Freezing (<0°C)"
    case .cold: return "Cold (0-10°C)"
    case .cool: return "Cool (10-20°C)"
    case .moderate: return "Moderate (20-30°C)"
    case .hot: return "Hot (>30°C)"
    }
  }
}

enum WeatherCondition: CaseIterable, Sendable {
  case clear
  case rainy
  case windy
  case harsh
  
  static func from(weather: WeatherConditions) -> WeatherCondition {
    if weather.isHarshConditions {
      return .harsh
    } else if weather.precipitation > 5 {
      return .rainy
    } else if weather.windSpeed > 10 {
      return .windy
    } else {
      return .clear
    }
  }
}

// MARK: - Error Types

enum AnalyticsError: LocalizedError {
  case invalidDateRange
  case noDataAvailable
  case cacheCorrupted
  
  var errorDescription: String? {
    switch self {
    case .invalidDateRange:
      return "Invalid date range for analytics calculation"
    case .noDataAvailable:
      return "No session data available for analytics"
    case .cacheCorrupted:
      return "Analytics cache is corrupted and needs to be rebuilt"
    }
  }
}