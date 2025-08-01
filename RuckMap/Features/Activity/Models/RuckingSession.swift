//
//  RuckingSession.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import Foundation

struct RuckingSession: Identifiable {
  let id = UUID()
  let startTime: Date
  var endTime: Date?
  var distance: Double // in miles
  var calories: Double
  var averageSpeed: Double // mph
  var packWeight: Double // in pounds
  var userWeight: Double // in pounds
  var isPaused: Bool = false
  
  var duration: TimeInterval {
    let end = endTime ?? Date()
    return end.timeIntervalSince(startTime)
  }
  
  var isActive: Bool {
    endTime == nil
  }
}

// MARK: - Quick Stats

struct QuickStats {
  let weeklyDistance: Double
  let weeklyCalories: Double
  let weeklyDuration: TimeInterval
  let weeklySessionCount: Int
  let monthlyProgress: Double // 0.0 to 1.0
}

// MARK: - Recent Activity

struct RecentActivity: Identifiable {
  let id = UUID()
  let date: Date
  let distance: Double
  let duration: TimeInterval
  let calories: Double
  let route: String?
}