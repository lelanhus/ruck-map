//
//  QuickStatsSection.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct QuickStatsSection: View {
  let stats: QuickStats
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("This Week")
        .armyTextStyle(.headline)
      
      HStack(spacing: 12) {
        ArmyStatCard(
          label: "Distance",
          value: String(format: "%.1f", stats.weeklyDistance),
          unit: "mi",
          trend: .up(12)
        )
        
        ArmyStatCard(
          label: "Calories",
          value: formatNumber(stats.weeklyCalories),
          trend: .up(8)
        )
      }
      
      HStack(spacing: 12) {
        ArmyStatCard(
          label: "Duration",
          value: formatDuration(stats.weeklyDuration),
          trend: .neutral
        )
        
        ArmyStatCard(
          label: "Sessions",
          value: "\(stats.weeklySessionCount)",
          trend: .down(20)
        )
      }
      
      // Monthly Progress
      VStack(alignment: .leading, spacing: 8) {
        Text("Monthly Goal Progress")
          .armyTextStyle(.caption)
        
        ArmyProgressView(
          progress: stats.monthlyProgress * 100,
          total: 100,
          label: nil,
          showPercentage: true
        )
      }
      .padding(.top, 8)
    }
  }
  
  private func formatNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
  }
  
  private func formatDuration(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds) / 3600
    let minutes = Int(seconds) % 3600 / 60
    
    if hours > 0 {
      return "\(hours)h \(minutes)m"
    } else {
      return "\(minutes)m"
    }
  }
}