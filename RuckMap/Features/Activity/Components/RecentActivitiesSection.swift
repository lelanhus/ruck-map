//
//  RecentActivitiesSection.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct RecentActivitiesSection: View {
  let activities: [RecentActivity]
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Recent Activities")
          .armyTextStyle(.headline)
        
        Spacer()
        
        Button(action: {}) {
          Text("See All")
            .armyTextStyle(.callout)
            .foregroundStyle(Color.armyGreenPrimary)
        }
      }
      
      if activities.isEmpty {
        EmptyActivitiesView()
      } else {
        VStack(spacing: 8) {
          ForEach(activities) { activity in
            ActivityListItem(activity: activity)
          }
        }
      }
    }
  }
}

// MARK: - Activity List Item

struct ActivityListItem: View {
  let activity: RecentActivity
  
  var body: some View {
    ArmyListItemCard(
      title: activity.route ?? formatDate(activity.date),
      subtitle: formatStats(activity),
      trailing: formatRelativeDate(activity.date),
      action: {
        // Navigate to activity detail
      }
    )
  }
  
  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMM d"
    return formatter.string(from: date)
  }
  
  private func formatRelativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }
  
  private func formatStats(_ activity: RecentActivity) -> String {
    let distance = String(format: "%.1f mi", activity.distance)
    let duration = formatDuration(activity.duration)
    let calories = "\(Int(activity.calories)) cal"
    return "\(distance) • \(duration) • \(calories)"
  }
  
  private func formatDuration(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds) / 3600
    let minutes = Int(seconds) % 3600 / 60
    
    if hours > 0 {
      return "\(hours)h \(minutes)m"
    } else {
      return "\(minutes) min"
    }
  }
}

// MARK: - Empty State

struct EmptyActivitiesView: View {
  var body: some View {
    ArmyCard {
      VStack(spacing: 12) {
        Image(systemName: "figure.walk.circle")
          .font(.system(size: 48))
          .foregroundStyle(Color.armyGreenLight)
        
        Text("No activities yet")
          .armyTextStyle(.headline)
        
        Text("Start your first ruck to see your progress here")
          .armyTextStyle(.caption)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 20)
    }
  }
}