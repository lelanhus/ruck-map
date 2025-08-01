//
//  SummaryStatsGrid.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct SummaryStatsGrid: View {
  let stats: SummaryStats
  
  var body: some View {
    VStack(spacing: 12) {
      // Top row - main stats
      HStack(spacing: 12) {
        StatCard(
          title: "Total Distance",
          value: formatDistance(stats.totalDistance),
          unit: "miles"
        )
        
        StatCard(
          title: "Total Calories",
          value: formatNumber(stats.totalCalories),
          unit: nil
        )
      }
      
      // Middle row
      HStack(spacing: 12) {
        StatCard(
          title: "Sessions",
          value: "\(stats.sessionCount)",
          unit: nil
        )
        
        StatCard(
          title: "Total Time",
          value: formatDuration(stats.totalDuration),
          unit: nil
        )
      }
      
      // Bottom row - records
      HStack(spacing: 12) {
        StatCard(
          title: "Best Pace",
          value: formatPace(stats.bestPace),
          unit: "min/mi"
        )
        
        StatCard(
          title: "Longest",
          value: formatDistance(stats.longestSession),
          unit: "miles"
        )
      }
    }
  }
  
  private func formatDistance(_ distance: Double) -> String {
    String(format: "%.1f", distance)
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
  
  private func formatPace(_ pace: Double) -> String {
    let minutes = Int(pace)
    let seconds = Int((pace - Double(minutes)) * 60)
    return String(format: "%d:%02d", minutes, seconds)
  }
}

// MARK: - Stat Card

struct StatCard: View {
  let title: String
  let value: String
  let unit: String?
  
  var body: some View {
    ArmyCard(padding: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .armyTextStyle(.caption)
          .lineLimit(1)
        
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(value)
            .font(.armyNumberMedium)
            .foregroundStyle(Color.armyTextPrimary)
          
          if let unit = unit {
            Text(unit)
              .armyTextStyle(.caption2)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}