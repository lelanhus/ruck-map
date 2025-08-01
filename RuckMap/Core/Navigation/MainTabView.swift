//
//  MainTabView.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct MainTabView: View {
  @StateObject private var navigationState = NavigationState()
  @Environment(\.colorScheme) private var colorScheme
  
  var body: some View {
    TabView(selection: $navigationState.selectedTab) {
      ForEach(Tab.allCases, id: \.self) { tab in
        NavigationStack(path: navigationState.navigationPath(for: tab)) {
          contentView(for: tab)
            .navigationTitle(tab.title)
            .navigationBarTitleDisplayMode(.large)
        }
        .tabItem {
          Label(tab.title, systemImage: tab.systemImage)
        }
        .tag(tab)
      }
    }
    .tint(.armyGreenPrimary)
    .onAppear {
      configureTabBarAppearance()
    }
    .environmentObject(navigationState)
  }
  
  @ViewBuilder
  private func contentView(for tab: Tab) -> some View {
    switch tab {
    case .activity:
      ActivityView()
    case .progress:
      ProgressView()
    case .routes:
      RoutesView()
    case .community:
      CommunityView()
    case .profile:
      ProfileView()
    }
  }
  
  private func configureTabBarAppearance() {
    let appearance = UITabBarAppearance()
    appearance.configureWithDefaultBackground()
    
    // Background colors
    appearance.backgroundColor = UIColor(Color.armyBackgroundPrimary)
    
    // Normal state
    appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.armyGreenLight)
    appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
      .foregroundColor: UIColor(Color.armyGreenLight),
      .font: UIFont.systemFont(ofSize: 10, weight: .medium)
    ]
    
    // Selected state
    appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.armyGreenPrimary)
    appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
      .foregroundColor: UIColor(Color.armyGreenPrimary),
      .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
    ]
    
    // Apply appearance
    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
  }
}

// MARK: - Preview

#Preview {
  MainTabView()
}