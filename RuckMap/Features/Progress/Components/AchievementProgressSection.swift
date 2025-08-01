//
//  AchievementProgressSection.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct AchievementProgressSection: View {
  let achievements: [Achievement]
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Achievements")
          .armyTextStyle(.headline)
        
        Spacer()
        
        Text("\(completedCount)/\(achievements.count)")
          .armyTextStyle(.caption)
      }
      
      VStack(spacing: 8) {
        ForEach(achievements) { achievement in
          AchievementCard(achievement: achievement)
        }
      }
    }
  }
  
  private var completedCount: Int {
    achievements.filter { $0.isCompleted }.count
  }
}

// MARK: - Achievement Card

struct AchievementCard: View {
  let achievement: Achievement
  
  var body: some View {
    ArmyCard(padding: 12) {
      HStack(spacing: 12) {
        // Icon
        ZStack {
          Circle()
            .fill(achievement.isCompleted ? Color.armyGreenSuccess.opacity(0.2) : Color.armyBackgroundTertiary)
            .frame(width: 44, height: 44)
          
          Image(systemName: achievement.icon)
            .font(.system(size: 20))
            .foregroundStyle(achievement.isCompleted ? Color.armyGreenSuccess : Color.armyGreenLight)
        }
        
        // Content
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(achievement.title)
              .armyTextStyle(.body)
            
            if achievement.isCompleted {
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.armyGreenSuccess)
            }
          }
          
          Text(achievement.description)
            .armyTextStyle(.caption)
          
          if !achievement.isCompleted {
            HStack(spacing: 8) {
              ArmyProgressView(
                progress: achievement.progress,
                total: 1.0,
                label: nil,
                showPercentage: false
              )
              
              Text(achievement.goal)
                .armyTextStyle(.caption2)
            }
          }
        }
        
        Spacer()
      }
    }
  }
}