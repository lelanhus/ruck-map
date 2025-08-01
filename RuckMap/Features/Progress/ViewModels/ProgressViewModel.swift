//
//  ProgressViewModel.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

@MainActor
class ProgressViewModel: ObservableObject {
  @Published var personalRecords: [PersonalRecord] = []
  @Published var achievements: [Achievement] = []
  
  init() {
    loadMockData()
  }
  
  func summaryStats(for timeRange: TimeRange) -> SummaryStats {
    // Mock data based on time range
    switch timeRange {
    case .week:
      return SummaryStats(
        totalDistance: 24.5,
        totalCalories: 3850,
        totalDuration: 12600, // 3.5 hours
        sessionCount: 4,
        averageDistance: 6.125,
        averagePace: 18.5,
        longestSession: 8.2,
        bestPace: 16.8
      )
    case .month:
      return SummaryStats(
        totalDistance: 98.7,
        totalCalories: 15400,
        totalDuration: 50400, // 14 hours
        sessionCount: 16,
        averageDistance: 6.17,
        averagePace: 18.3,
        longestSession: 12.5,
        bestPace: 15.2
      )
    case .year:
      return SummaryStats(
        totalDistance: 1250.3,
        totalCalories: 195000,
        totalDuration: 648000, // 180 hours
        sessionCount: 203,
        averageDistance: 6.16,
        averagePace: 17.9,
        longestSession: 15.0,
        bestPace: 14.8
      )
    case .all:
      return SummaryStats(
        totalDistance: 2845.8,
        totalCalories: 444000,
        totalDuration: 1468800, // 408 hours
        sessionCount: 462,
        averageDistance: 6.16,
        averagePace: 17.5,
        longestSession: 18.2,
        bestPace: 14.5
      )
    }
  }
  
  func chartData(for timeRange: TimeRange) -> [ChartDataPoint] {
    // Mock chart data
    let calendar = Calendar.current
    let today = Date()
    var data: [ChartDataPoint] = []
    
    switch timeRange {
    case .week:
      for i in 0..<7 {
        let date = calendar.date(byAdding: .day, value: -i, to: today)!
        let value = Double.random(in: 0...10)
        let label = formatDayLabel(date)
        data.append(ChartDataPoint(date: date, value: value, label: label))
      }
    case .month:
      for i in stride(from: 0, to: 30, by: 3) {
        let date = calendar.date(byAdding: .day, value: -i, to: today)!
        let value = Double.random(in: 15...35)
        let label = formatDateLabel(date)
        data.append(ChartDataPoint(date: date, value: value, label: label))
      }
    case .year:
      for i in 0..<12 {
        let date = calendar.date(byAdding: .month, value: -i, to: today)!
        let value = Double.random(in: 80...150)
        let label = formatMonthLabel(date)
        data.append(ChartDataPoint(date: date, value: value, label: label))
      }
    case .all:
      for i in 0..<5 {
        let date = calendar.date(byAdding: .year, value: -i, to: today)!
        let value = Double.random(in: 800...1500)
        let label = formatYearLabel(date)
        data.append(ChartDataPoint(date: date, value: value, label: label))
      }
    }
    
    return data.reversed()
  }
  
  private func loadMockData() {
    personalRecords = [
      PersonalRecord(
        title: "Longest Ruck",
        value: "18.2",
        unit: "miles",
        date: Date().addingTimeInterval(-2592000), // 30 days ago
        improvement: 12
      ),
      PersonalRecord(
        title: "Fastest Pace",
        value: "14:30",
        unit: "min/mi",
        date: Date().addingTimeInterval(-864000), // 10 days ago
        improvement: 8
      ),
      PersonalRecord(
        title: "Most Calories",
        value: "2,450",
        unit: nil,
        date: Date().addingTimeInterval(-1728000), // 20 days ago
        improvement: 15
      ),
      PersonalRecord(
        title: "Heaviest Pack",
        value: "65",
        unit: "lbs",
        date: Date().addingTimeInterval(-432000), // 5 days ago
        improvement: 18
      )
    ]
    
    achievements = [
      Achievement(
        title: "Century Club",
        description: "Complete 100 miles total",
        progress: 0.85,
        goal: "85/100 miles",
        icon: "flag.checkered",
        isCompleted: false
      ),
      Achievement(
        title: "Week Warrior",
        description: "Ruck 5 days in one week",
        progress: 0.6,
        goal: "3/5 days",
        icon: "calendar",
        isCompleted: false
      ),
      Achievement(
        title: "Early Bird",
        description: "Complete 10 morning rucks",
        progress: 1.0,
        goal: "Completed!",
        icon: "sunrise",
        isCompleted: true
      ),
      Achievement(
        title: "Heavy Hauler",
        description: "Ruck with 50+ lbs",
        progress: 1.0,
        goal: "Completed!",
        icon: "backpack",
        isCompleted: true
      )
    ]
  }
  
  // MARK: - Date Formatting
  
  private func formatDayLabel(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "E"
    return formatter.string(from: date)
  }
  
  private func formatDateLabel(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
  }
  
  private func formatMonthLabel(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM"
    return formatter.string(from: date)
  }
  
  private func formatYearLabel(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy"
    return formatter.string(from: date)
  }
}