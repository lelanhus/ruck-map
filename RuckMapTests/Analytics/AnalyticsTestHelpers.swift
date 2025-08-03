import Foundation
import SwiftData
@testable import RuckMap

/// Helper utilities for Analytics testing with Swift Testing framework
struct AnalyticsTestHelpers {
  
  // MARK: - Mock Data Generators
  
  /// Creates a comprehensive test session with realistic data
  static func createRealisticTestSession(
    loadWeight: Double = 25.0,
    distance: Double = 5000.0,
    pace: Double = 5.5,
    startDate: Date = Date(),
    includeWeather: Bool = false,
    includeTerrain: Bool = false,
    includeLocationPoints: Bool = false
  ) throws -> RuckSession {
    
    let session = try RuckSession(loadWeight: loadWeight)
    session.startDate = startDate
    session.totalDistance = distance
    session.averagePace = pace
    session.totalDuration = TimeInterval(distance / 1000.0 * pace * 60) // Convert to seconds
    session.endDate = startDate.addingTimeInterval(session.totalDuration)
    session.totalCalories = calculateRealisticCalories(
      distance: distance,
      weight: loadWeight,
      pace: pace
    )
    session.elevationGain = Double.random(in: 50...300)
    session.elevationLoss = session.elevationGain * Double.random(in: 0.8...1.2)
    
    // Add weather conditions if requested
    if includeWeather {
      let weather = WeatherConditions()
      weather.temperature = Double.random(in: -5...35)
      weather.humidity = Double.random(in: 30...90)
      weather.windSpeed = Double.random(in: 0...20)
      weather.precipitation = Double.random(in: 0...15)
      weather.session = session
      session.weatherConditions = weather
    }
    
    // Add terrain segments if requested
    if includeTerrain {
      let terrainTypes: [TerrainType] = [.pavedRoad, .trail, .sand, .grass, .gravel]
      let numSegments = Int.random(in: 1...3)
      
      for i in 0..<numSegments {
        let terrain = TerrainSegment()
        terrain.terrainType = terrainTypes.randomElement() ?? .pavedRoad
        terrain.duration = session.totalDuration / Double(numSegments)
        terrain.session = session
        session.terrainSegments.append(terrain)
      }
    }
    
    // Add location points if requested
    if includeLocationPoints {
      let numPoints = Int(session.totalDuration / 60) // One point per minute
      let startLat = 37.7749 + Double.random(in: -0.1...0.1)
      let startLon = -122.4194 + Double.random(in: -0.1...0.1)
      
      for i in 0..<numPoints {
        let locationPoint = LocationPoint()
        locationPoint.latitude = startLat + (Double(i) * 0.0001)
        locationPoint.longitude = startLon + (Double(i) * 0.0001)
        locationPoint.timestamp = startDate.addingTimeInterval(Double(i) * 60)
        locationPoint.altitude = Double.random(in: 0...500)
        locationPoint.speed = (distance / session.totalDuration) + Double.random(in: -0.5...0.5)
        locationPoint.session = session
        session.locationPoints.append(locationPoint)
      }
    }
    
    return session
  }
  
  /// Creates a batch of test sessions with progressive improvement
  static func createProgressiveTrainingData(
    weeks: Int = 12,
    sessionsPerWeek: Int = 3,
    startWeight: Double = 15.0,
    endWeight: Double = 35.0,
    startDistance: Double = 3000.0,
    endDistance: Double = 10000.0,
    startPace: Double = 6.5,
    endPace: Double = 4.8
  ) throws -> [RuckSession] {
    
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    for week in 0..<weeks {
      let weekProgress = Double(week) / Double(weeks - 1)
      
      // Progressive values
      let weekWeight = startWeight + (endWeight - startWeight) * weekProgress
      let weekDistance = startDistance + (endDistance - startDistance) * weekProgress
      let weekPace = startPace - (startPace - endPace) * weekProgress
      
      for sessionIndex in 0..<sessionsPerWeek {
        guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()),
              let sessionDate = calendar.date(byAdding: .day, value: sessionIndex * 2, to: weekStart) else {
          continue
        }
        
        let session = try createRealisticTestSession(
          loadWeight: weekWeight + Double.random(in: -2...2),
          distance: weekDistance + Double.random(in: -500...500),
          pace: weekPace + Double.random(in: -0.2...0.2),
          startDate: sessionDate,
          includeWeather: week % 2 == 0,
          includeTerrain: week % 3 == 0
        )
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  /// Creates sessions with specific patterns for testing streaks
  static func createTrainingStreakData(
    consecutiveWeeks: Int = 6,
    sessionsPerWeek: Int = 3,
    breakWeeks: [Int] = []
  ) throws -> [RuckSession] {
    
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    for week in 0..<consecutiveWeeks {
      // Skip weeks that should be breaks
      if breakWeeks.contains(week) {
        continue
      }
      
      for sessionIndex in 0..<sessionsPerWeek {
        guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()),
              let sessionDate = calendar.date(byAdding: .day, value: sessionIndex * 2, to: weekStart) else {
          continue
        }
        
        let session = try createRealisticTestSession(
          loadWeight: Double.random(in: 20...35),
          distance: Double.random(in: 4000...8000),
          pace: Double.random(in: 5.0...6.0),
          startDate: sessionDate
        )
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  /// Creates sessions for testing personal records
  static func createPersonalRecordTestData() throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    // Define record scenarios
    let recordConfigs = [
      // Longest distance record
      (weight: 25.0, distance: 15000.0, pace: 5.5, daysAgo: 30, isRecord: "distance"),
      
      // Fastest pace record
      (weight: 20.0, distance: 5000.0, pace: 4.2, daysAgo: 15, isRecord: "pace"),
      
      // Heaviest load record
      (weight: 50.0, distance: 6000.0, pace: 6.0, daysAgo: 45, isRecord: "weight"),
      
      // Highest calories record (heavy weight + long distance)
      (weight: 45.0, distance: 12000.0, pace: 5.8, daysAgo: 10, isRecord: "calories"),
      
      // Regular sessions for comparison
      (weight: 25.0, distance: 5000.0, pace: 5.5, daysAgo: 5, isRecord: "none"),
      (weight: 30.0, distance: 7000.0, pace: 5.2, daysAgo: 20, isRecord: "none"),
      (weight: 35.0, distance: 8000.0, pace: 5.0, daysAgo: 35, isRecord: "none")
    ]
    
    for config in recordConfigs {
      guard let sessionDate = calendar.date(byAdding: .day, value: -config.daysAgo, to: Date()) else {
        continue
      }
      
      let session = try createRealisticTestSession(
        loadWeight: config.weight,
        distance: config.distance,
        pace: config.pace,
        startDate: sessionDate,
        includeWeather: true,
        includeTerrain: true
      )
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  /// Creates large dataset for performance testing
  static func createLargePerformanceDataset(
    sessionCount: Int = 1000,
    timeSpanDays: Int = 365
  ) throws -> [RuckSession] {
    
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    for i in 0..<sessionCount {
      let daysAgo = Int.random(in: 0...timeSpanDays)
      guard let sessionDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else {
        continue
      }
      
      let session = try createRealisticTestSession(
        loadWeight: Double.random(in: 10...60),
        distance: Double.random(in: 1000...25000),
        pace: Double.random(in: 3.5...8.0),
        startDate: sessionDate,
        includeWeather: i % 4 == 0,
        includeTerrain: i % 3 == 0,
        includeLocationPoints: i % 10 == 0
      )
      
      sessions.append(session)
    }
    
    return sessions.sorted { $0.startDate < $1.startDate }
  }
  
  // MARK: - Data Validation Helpers
  
  /// Validates that analytics data is consistent with source sessions
  static func validateAnalyticsConsistency(
    analyticsData: AnalyticsData,
    sessions: [RuckSession],
    tolerance: Double = 0.01
  ) -> Bool {
    
    // Check session count
    guard analyticsData.totalSessions == sessions.count else {
      return false
    }
    
    // Check total distance
    let expectedDistance = sessions.reduce(0) { $0 + $1.totalDistance }
    guard abs(analyticsData.totalDistance - expectedDistance) < tolerance else {
      return false
    }
    
    // Check total calories
    let expectedCalories = sessions.reduce(0) { $0 + $1.totalCalories }
    guard abs(analyticsData.totalCalories - expectedCalories) < tolerance else {
      return false
    }
    
    // Check weight moved calculation
    let expectedWeightMoved = sessions.reduce(0) { sum, session in
      sum + (session.loadWeight * (session.totalDistance / 1000.0))
    }
    guard abs(analyticsData.totalWeightMoved - expectedWeightMoved) < tolerance else {
      return false
    }
    
    return true
  }
  
  /// Validates personal records against session data
  static func validatePersonalRecords(
    personalRecords: PersonalRecords,
    sessions: [RuckSession]
  ) -> Bool {
    
    guard !sessions.isEmpty else {
      return !personalRecords.longestDistance.isValid &&
             !personalRecords.fastestPace.isValid &&
             !personalRecords.heaviestLoad.isValid
    }
    
    // Check longest distance
    let expectedLongestDistance = sessions.map(\.totalDistance).max() ?? 0
    guard personalRecords.longestDistance.value == expectedLongestDistance else {
      return false
    }
    
    // Check heaviest load
    let expectedHeaviestLoad = sessions.map(\.loadWeight).max() ?? 0
    guard personalRecords.heaviestLoad.value == expectedHeaviestLoad else {
      return false
    }
    
    // Check fastest pace (minimum of valid paces)
    let validPaces = sessions.compactMap { $0.averagePace > 0 ? $0.averagePace : nil }
    if !validPaces.isEmpty {
      let expectedFastestPace = validPaces.min() ?? 0
      guard personalRecords.fastestPace.value == expectedFastestPace else {
        return false
      }
    }
    
    return true
  }
  
  // MARK: - Time Range Helpers
  
  /// Creates sessions distributed across specific time ranges
  static func createSessionsForTimeRangeTesting() throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    let now = Date()
    
    // Define specific time ranges with known session counts
    let timeRangeConfigs = [
      // This week: 2 sessions
      (daysAgo: 2, sessions: 1),
      (daysAgo: 5, sessions: 1),
      
      // This month (beyond this week): 3 sessions
      (daysAgo: 12, sessions: 1),
      (daysAgo: 18, sessions: 1),
      (daysAgo: 25, sessions: 1),
      
      // Last 3 months (beyond this month): 2 sessions
      (daysAgo: 45, sessions: 1),
      (daysAgo: 70, sessions: 1),
      
      // Last year (beyond 3 months): 1 session
      (daysAgo: 200, sessions: 1),
      
      // All time (beyond last year): 1 session
      (daysAgo: 400, sessions: 1)
    ]
    
    for config in timeRangeConfigs {
      for _ in 0..<config.sessions {
        guard let sessionDate = calendar.date(byAdding: .day, value: -config.daysAgo, to: now) else {
          continue
        }
        
        let session = try createRealisticTestSession(
          loadWeight: Double.random(in: 20...35),
          distance: Double.random(in: 4000...8000),
          pace: Double.random(in: 5.0...6.0),
          startDate: sessionDate
        )
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  // MARK: - Edge Case Data Generators
  
  /// Creates sessions with edge case values for robustness testing
  static func createEdgeCaseTestData() throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    // Edge case configurations
    let edgeCases = [
      // Zero values
      (weight: 0.0, distance: 0.0, pace: 0.0, calories: 0.0, description: "zero values"),
      
      // Very small values
      (weight: 0.001, distance: 0.001, pace: 0.001, calories: 0.001, description: "tiny values"),
      
      // Very large values
      (weight: 999.0, distance: 999999.0, pace: 99.0, calories: 99999.0, description: "large values"),
      
      // Negative values (invalid but should be handled)
      (weight: -10.0, distance: -1000.0, pace: -5.0, calories: -500.0, description: "negative values")
    ]
    
    for (index, edgeCase) in edgeCases.enumerated() {
      guard let sessionDate = calendar.date(byAdding: .day, value: -index, to: Date()) else {
        continue
      }
      
      let session = try RuckSession(loadWeight: edgeCase.weight)
      session.startDate = sessionDate
      session.endDate = sessionDate.addingTimeInterval(3600)
      session.totalDistance = edgeCase.distance
      session.totalCalories = edgeCase.calories
      session.averagePace = edgeCase.pace
      session.totalDuration = 3600
      
      sessions.append(session)
    }
    
    return sessions
  }
  
  // MARK: - Calculation Helpers
  
  /// Calculates realistic calories based on distance, weight, and pace
  static func calculateRealisticCalories(
    distance: Double,
    weight: Double,
    pace: Double
  ) -> Double {
    // Base calorie calculation: ~0.75 calories per kg per km
    let baseCalories = (distance / 1000.0) * weight * 0.75
    
    // Pace adjustment: faster pace burns more calories
    let paceMultiplier = max(0.8, 2.0 - (pace / 8.0))
    
    // Load adjustment: heavier loads burn more calories
    let loadMultiplier = 1.0 + (weight / 100.0)
    
    return baseCalories * paceMultiplier * loadMultiplier
  }
  
  /// Generates realistic elevation data
  static func generateRealisticElevation() -> (gain: Double, loss: Double) {
    let gain = Double.random(in: 10...500)
    let loss = gain * Double.random(in: 0.7...1.3) // Loss usually similar to gain
    return (gain, loss)
  }
  
  /// Generates weather conditions based on temperature
  static func generateRealisticWeather(temperature: Double? = nil) -> WeatherConditions {
    let weather = WeatherConditions()
    
    weather.temperature = temperature ?? Double.random(in: -10...40)
    
    // Humidity tends to be higher at moderate temperatures
    if weather.temperature > 20 && weather.temperature < 30 {
      weather.humidity = Double.random(in: 50...85)
    } else {
      weather.humidity = Double.random(in: 30...70)
    }
    
    weather.windSpeed = Double.random(in: 0...25)
    
    // Precipitation more likely at certain temperatures
    if weather.temperature > 0 && weather.temperature < 25 {
      weather.precipitation = Double.random(in: 0...15)
    } else {
      weather.precipitation = Double.random(in: 0...5)
    }
    
    return weather
  }
  
  // MARK: - Accessibility Testing Helpers
  
  /// Generates test data suitable for accessibility testing
  static func createAccessibilityTestData() throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    let calendar = Calendar.current
    
    // Create data with clear trends for audio graph testing
    let trendConfigs = [
      // Increasing distance trend
      (week: 0, distance: 3000.0, pace: 6.0),
      (week: 1, distance: 4000.0, pace: 5.8),
      (week: 2, distance: 5000.0, pace: 5.6),
      (week: 3, distance: 6000.0, pace: 5.4),
      (week: 4, distance: 7000.0, pace: 5.2),
      (week: 5, distance: 8000.0, pace: 5.0)
    ]
    
    for config in trendConfigs {
      guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -config.week, to: Date()) else {
        continue
      }
      
      // Create 2 sessions per week for consistent training
      for sessionInWeek in 0..<2 {
        guard let sessionDate = calendar.date(byAdding: .day, value: sessionInWeek * 3, to: weekStart) else {
          continue
        }
        
        let session = try createRealisticTestSession(
          loadWeight: 25.0,
          distance: config.distance,
          pace: config.pace,
          startDate: sessionDate
        )
        
        sessions.append(session)
      }
    }
    
    return sessions
  }
  
  // MARK: - Performance Measurement Helpers
  
  /// Measures execution time of a block
  static func measureExecutionTime<T>(
    operation: () async throws -> T
  ) async rethrows -> (result: T, executionTime: TimeInterval) {
    let startTime = Date()
    let result = try await operation()
    let executionTime = Date().timeIntervalSince(startTime)
    return (result, executionTime)
  }
  
  /// Creates benchmark session data of specified size
  static func createBenchmarkData(sessionCount: Int) throws -> [RuckSession] {
    var sessions: [RuckSession] = []
    
    for i in 0..<sessionCount {
      let session = try createRealisticTestSession(
        loadWeight: Double.random(in: 15...50),
        distance: Double.random(in: 2000...20000),
        pace: Double.random(in: 4.0...8.0),
        startDate: Calendar.current.date(byAdding: .hour, value: -i * 2, to: Date()) ?? Date(),
        includeWeather: i % 5 == 0,
        includeTerrain: i % 3 == 0,
        includeLocationPoints: i % 20 == 0
      )
      
      sessions.append(session)
    }
    
    return sessions
  }
}