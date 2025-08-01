//
//  ProgressModels.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import Foundation

// MARK: - Time Range

enum TimeRange: String, CaseIterable {
  case week = "Week"
  case month = "Month"
  case year = "Year"
  case all = "All Time"
}

// MARK: - Summary Stats

struct SummaryStats {
  let totalDistance: Double
  let totalCalories: Double
  let totalDuration: TimeInterval
  let sessionCount: Int
  let averageDistance: Double
  let averagePace: Double // minutes per mile
  let longestSession: Double // distance
  let bestPace: Double // minutes per mile
}

// MARK: - Chart Data

struct ChartDataPoint: Identifiable {
  let id = UUID()
  let date: Date
  let value: Double
  let label: String
}

// MARK: - Personal Record

struct PersonalRecord: Identifiable {
  let id = UUID()
  let title: String
  let value: String
  let unit: String?
  let date: Date
  let improvement: Double? // percentage improvement
}

// MARK: - Achievement

struct Achievement: Identifiable {
  let id = UUID()
  let title: String
  let description: String
  let progress: Double // 0.0 to 1.0
  let goal: String
  let icon: String
  let isCompleted: Bool
}