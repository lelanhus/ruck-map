//
//  NavigationState.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

// MARK: - Tab Enumeration

enum Tab: String, CaseIterable {
  case activity
  case progress
  case routes
  case community
  case profile
  
  var title: String {
    switch self {
    case .activity: return "Activity"
    case .progress: return "Progress"
    case .routes: return "Routes"
    case .community: return "Community"
    case .profile: return "Profile"
    }
  }
  
  var systemImage: String {
    switch self {
    case .activity: return "figure.walk"
    case .progress: return "chart.line.uptrend.xyaxis"
    case .routes: return "map"
    case .community: return "person.3"
    case .profile: return "person.circle"
    }
  }
}

// MARK: - Navigation State

@MainActor
class NavigationState: ObservableObject {
  @Published var selectedTab: Tab = .activity
  @Published var activityPath = NavigationPath()
  @Published var progressPath = NavigationPath()
  @Published var routesPath = NavigationPath()
  @Published var communityPath = NavigationPath()
  @Published var profilePath = NavigationPath()
  
  func navigationPath(for tab: Tab) -> Binding<NavigationPath> {
    switch tab {
    case .activity: 
      return Binding(
        get: { self.activityPath },
        set: { self.activityPath = $0 }
      )
    case .progress:
      return Binding(
        get: { self.progressPath },
        set: { self.progressPath = $0 }
      )
    case .routes:
      return Binding(
        get: { self.routesPath },
        set: { self.routesPath = $0 }
      )
    case .community:
      return Binding(
        get: { self.communityPath },
        set: { self.communityPath = $0 }
      )
    case .profile:
      return Binding(
        get: { self.profilePath },
        set: { self.profilePath = $0 }
      )
    }
  }
  
  func resetPath(for tab: Tab) {
    switch tab {
    case .activity: activityPath = NavigationPath()
    case .progress: progressPath = NavigationPath()
    case .routes: routesPath = NavigationPath()
    case .community: communityPath = NavigationPath()
    case .profile: profilePath = NavigationPath()
    }
  }
  
  func popToRoot(for tab: Tab) {
    resetPath(for: tab)
  }
}