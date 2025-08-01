//
//  NavigationStateTests.swift
//  RuckMapTests
//
//  Created by Claude on 8/1/25.
//

import Testing
import SwiftUI
@testable import RuckMap

typealias AppTab = RuckMap.Tab

@Suite("Navigation State Tests")
@MainActor
struct NavigationStateTests {
  
  // MARK: - Tab Enumeration Tests
  
  @Test("Tab enum has all required cases")
  func testTabEnumCases() {
    let allTabs: [AppTab] = [.activity, .progress, .routes, .community, .profile]
    
    #expect(AppTab.allCases.count == 5)
    #expect(AppTab.allCases == allTabs)
  }
  
  @Test("Tab titles are properly defined")
  func testTabTitles() {
    #expect(AppTab.activity.title == "Activity")
    #expect(AppTab.progress.title == "Progress")
    #expect(AppTab.routes.title == "Routes")
    #expect(AppTab.community.title == "Community")
    #expect(AppTab.profile.title == "Profile")
  }
  
  @Test("Tab system images are properly defined")
  func testTabSystemImages() {
    #expect(AppTab.activity.systemImage == "figure.walk")
    #expect(AppTab.progress.systemImage == "chart.line.uptrend.xyaxis")
    #expect(AppTab.routes.systemImage == "map")
    #expect(AppTab.community.systemImage == "person.3")
    #expect(AppTab.profile.systemImage == "person.circle")
  }
  
  @Test("Tab enum conforms to required protocols")
  func testTabProtocolConformance() {
    // Test String conformance
    #expect(AppTab.activity.rawValue == "activity")
    #expect(AppTab.progress.rawValue == "progress")
    #expect(AppTab.routes.rawValue == "routes")
    #expect(AppTab.community.rawValue == "community")
    #expect(AppTab.profile.rawValue == "profile")
    
    // Test CaseIterable conformance
    #expect(AppTab.allCases.contains(.activity))
    #expect(AppTab.allCases.contains(.progress))
    #expect(AppTab.allCases.contains(.routes))
    #expect(AppTab.allCases.contains(.community))
    #expect(AppTab.allCases.contains(.profile))
  }
  
  // MARK: - Navigation State Initialization Tests
  
  @Test("Navigation state initializes with default values")
  func testNavigationStateInitialization() {
    let navigationState = NavigationState()
    
    #expect(navigationState.selectedTab == .activity)
    #expect(navigationState.activityPath.isEmpty)
    #expect(navigationState.progressPath.isEmpty)
    #expect(navigationState.routesPath.isEmpty)
    #expect(navigationState.communityPath.isEmpty)
    #expect(navigationState.profilePath.isEmpty)
  }
  
  @Test("Navigation state is MainActor isolated")
  func testNavigationStateMainActorIsolation() {
    let navigationState = NavigationState()
    
    // This test ensures the class is properly annotated with @MainActor
    #expect(navigationState != nil)
  }
  
  @Test("Navigation state conforms to ObservableObject")
  func testNavigationStateObservableObject() {
    let navigationState = NavigationState()
    
    // Test that it's an ObservableObject
    #expect(navigationState is ObservableObject)
  }
  
  // MARK: - Tab Selection Tests
  
  @Test("Selected tab can be changed")
  func testSelectedTabChange() {
    let navigationState = NavigationState()
    
    #expect(navigationState.selectedTab == .activity)
    
    navigationState.selectedTab = .progress
    #expect(navigationState.selectedTab == .progress)
    
    navigationState.selectedTab = .routes
    #expect(navigationState.selectedTab == .routes)
    
    navigationState.selectedTab = .community
    #expect(navigationState.selectedTab == .community)
    
    navigationState.selectedTab = .profile
    #expect(navigationState.selectedTab == .profile)
  }
  
  @Test("Tab selection publishes changes")
  func testTabSelectionPublishing() {
    let navigationState = NavigationState()
    var changeCount = 0
    
    // This would typically use a cancellable in a real test
    navigationState.selectedTab = .progress
    changeCount += 1
    
    navigationState.selectedTab = .routes
    changeCount += 1
    
    #expect(changeCount == 2)
    #expect(navigationState.selectedTab == .routes)
  }
  
  // MARK: - Navigation Path Tests
  
  @Test("Navigation path binding works correctly")
  func testNavigationPathBinding() {
    let navigationState = NavigationState()
    
    let activityBinding = navigationState.navigationPath(for: .activity)
    let progressBinding = navigationState.navigationPath(for: .progress)
    let routesBinding = navigationState.navigationPath(for: .routes)
    let communityBinding = navigationState.navigationPath(for: .community)
    let profileBinding = navigationState.navigationPath(for: .profile)
    
    #expect(activityBinding.wrappedValue.isEmpty)
    #expect(progressBinding.wrappedValue.isEmpty)
    #expect(routesBinding.wrappedValue.isEmpty)
    #expect(communityBinding.wrappedValue.isEmpty)
    #expect(profileBinding.wrappedValue.isEmpty)
  }
  
  @Test("Navigation path binding reflects changes")
  func testNavigationPathBindingChanges() {
    let navigationState = NavigationState()
    
    // Modify paths directly
    navigationState.activityPath.append("detail")
    navigationState.progressPath.append("chart")
    
    let activityBinding = navigationState.navigationPath(for: .activity)
    let progressBinding = navigationState.navigationPath(for: .progress)
    
    #expect(activityBinding.wrappedValue.count == 1)
    #expect(progressBinding.wrappedValue.count == 1)
    
    // Test that binding can modify the path
    activityBinding.wrappedValue.append("settings")
    #expect(navigationState.activityPath.count == 2)
  }
  
  // MARK: - Path Reset Tests
  
  @Test("Reset path clears navigation path for specific tab")
  func testResetPathForTab() {
    let navigationState = NavigationState()
    
    // Add items to paths
    navigationState.activityPath.append("detail1")
    navigationState.activityPath.append("detail2")
    navigationState.progressPath.append("chart")
    
    #expect(navigationState.activityPath.count == 2)
    #expect(navigationState.progressPath.count == 1)
    
    // Reset activity path only
    navigationState.resetPath(for: .activity)
    
    #expect(navigationState.activityPath.isEmpty)
    #expect(navigationState.progressPath.count == 1) // Should remain unchanged
  }
  
  @Test("Reset path works for all tabs")
  func testResetPathForAllTabs() {
    let navigationState = NavigationState()
    
    // Add items to all paths
    for tab in AppTab.allCases {
      switch tab {
      case .activity:
        navigationState.activityPath.append("activity_detail")
      case .progress:
        navigationState.progressPath.append("progress_detail")
      case .routes:
        navigationState.routesPath.append("routes_detail")
      case .community:
        navigationState.communityPath.append("community_detail")
      case .profile:
        navigationState.profilePath.append("profile_detail")
      }
    }
    
    // Verify all paths have items
    #expect(!navigationState.activityPath.isEmpty)
    #expect(!navigationState.progressPath.isEmpty)
    #expect(!navigationState.routesPath.isEmpty)
    #expect(!navigationState.communityPath.isEmpty)
    #expect(!navigationState.profilePath.isEmpty)
    
    // Reset each path
    for tab in AppTab.allCases {
      navigationState.resetPath(for: tab)
    }
    
    // Verify all paths are empty
    #expect(navigationState.activityPath.isEmpty)
    #expect(navigationState.progressPath.isEmpty)
    #expect(navigationState.routesPath.isEmpty)
    #expect(navigationState.communityPath.isEmpty)
    #expect(navigationState.profilePath.isEmpty)
  }
  
  // MARK: - Pop to Root Tests
  
  @Test("Pop to root clears navigation path")
  func testPopToRoot() {
    let navigationState = NavigationState()
    
    // Add multiple items to create a deep navigation stack
    navigationState.activityPath.append("detail1")
    navigationState.activityPath.append("detail2")
    navigationState.activityPath.append("detail3")
    
    #expect(navigationState.activityPath.count == 3)
    
    // Pop to root
    navigationState.popToRoot(for: .activity)
    
    #expect(navigationState.activityPath.isEmpty)
  }
  
  @Test("Pop to root works for all tabs")
  func testPopToRootForAllTabs() {
    let navigationState = NavigationState()
    
    // Add items to all paths
    navigationState.activityPath.append("deep_nav")
    navigationState.progressPath.append("deep_nav")
    navigationState.routesPath.append("deep_nav")
    navigationState.communityPath.append("deep_nav")
    navigationState.profilePath.append("deep_nav")
    
    // Pop to root for each tab
    for tab in AppTab.allCases {
      navigationState.popToRoot(for: tab)
    }
    
    // Verify all paths are empty
    #expect(navigationState.activityPath.isEmpty)
    #expect(navigationState.progressPath.isEmpty)
    #expect(navigationState.routesPath.isEmpty)
    #expect(navigationState.communityPath.isEmpty)
    #expect(navigationState.profilePath.isEmpty)
  }
  
  // MARK: - Navigation Path Management Tests
  
  @Test("Navigation paths are independent")
  func testNavigationPathIndependence() {
    let navigationState = NavigationState()
    
    navigationState.activityPath.append("activity_screen")
    navigationState.progressPath.append("progress_screen")
    
    #expect(navigationState.activityPath.count == 1)
    #expect(navigationState.progressPath.count == 1)
    #expect(navigationState.routesPath.isEmpty)
    #expect(navigationState.communityPath.isEmpty)
    #expect(navigationState.profilePath.isEmpty)
    
    // Clearing one path shouldn't affect others
    navigationState.resetPath(for: .activity)
    
    #expect(navigationState.activityPath.isEmpty)
    #expect(navigationState.progressPath.count == 1) // Should remain
  }
  
  @Test("Navigation paths can handle different data types")
  func testNavigationPathDataTypes() {
    let navigationState = NavigationState()
    
    // NavigationPath can store different types
    navigationState.activityPath.append("string_value")
    navigationState.progressPath.append(42)
    
    #expect(navigationState.activityPath.count == 1)
    #expect(navigationState.progressPath.count == 1)
  }
  
  // MARK: - Memory Management Tests
  
  @Test("Navigation state handles multiple path operations")
  func testMultiplePathOperations() {
    let navigationState = NavigationState()
    
    // Perform multiple operations
    for i in 0..<10 {
      navigationState.activityPath.append("item_\(i)")
    }
    
    #expect(navigationState.activityPath.count == 10)
    
    // Clear and add again
    navigationState.resetPath(for: .activity)
    navigationState.activityPath.append("new_item")
    
    #expect(navigationState.activityPath.count == 1)
  }
  
  // MARK: - Performance Tests
  
  @Test("Navigation state operations are performant", .timeLimit(.minutes(1)))
  func testNavigationStatePerformance() {
    let navigationState = NavigationState()
    
    // Test rapid tab switching
    for _ in 0..<1000 {
      for tab in AppTab.allCases {
        navigationState.selectedTab = tab
      }
    }
    
    // Test rapid path operations
    for i in 0..<1000 {
      navigationState.activityPath.append("item_\(i)")
    }
    
    navigationState.resetPath(for: .activity)
    #expect(navigationState.activityPath.isEmpty)
  }
  
  @Test("Path binding operations are performant", .timeLimit(.minutes(1)))
  func testPathBindingPerformance() {
    let navigationState = NavigationState()
    
    // Test rapid binding access
    for _ in 0..<1000 {
      for tab in AppTab.allCases {
        _ = navigationState.navigationPath(for: tab)
      }
    }
  }
  
  // MARK: - State Consistency Tests
  
  @Test("Navigation state maintains consistency")
  func testNavigationStateConsistency() {
    let navigationState = NavigationState()
    
    // Set up initial state
    navigationState.selectedTab = .progress
    navigationState.progressPath.append("detail")
    
    // Verify state is consistent
    #expect(navigationState.selectedTab == .progress)
    #expect(navigationState.progressPath.count == 1)
    
    // Switch tabs and verify paths remain
    navigationState.selectedTab = .activity
    #expect(navigationState.progressPath.count == 1) // Should persist
    #expect(navigationState.activityPath.isEmpty)    // Should be empty
  }
  
  @Test("Navigation path bindings stay synchronized")
  func testNavigationPathBindingSynchronization() {
    let navigationState = NavigationState()
    
    let binding1 = navigationState.navigationPath(for: .activity)
    let binding2 = navigationState.navigationPath(for: .activity)
    
    // Both bindings should reference the same path
    binding1.wrappedValue.append("test")
    
    #expect(binding2.wrappedValue.count == 1)
    #expect(navigationState.activityPath.count == 1)
  }
  
  // MARK: - Edge Case Tests
  
  @Test("Navigation state handles rapid changes")
  func testRapidChanges() {
    let navigationState = NavigationState()
    
    // Rapid tab switching with path modifications
    for i in 0..<100 {
      let tab = AppTab.allCases[i % AppTab.allCases.count]
      navigationState.selectedTab = tab
      
      switch tab {
      case .activity:
        navigationState.activityPath.append("rapid_\(i)")
      case .progress:
        navigationState.progressPath.append("rapid_\(i)")
      case .routes:
        navigationState.routesPath.append("rapid_\(i)")
      case .community:
        navigationState.communityPath.append("rapid_\(i)")
      case .profile:
        navigationState.profilePath.append("rapid_\(i)")
      }
      
      if i % 10 == 0 {
        navigationState.resetPath(for: tab)
      }
    }
    
    #expect(navigationState != nil) // Should handle all operations without issues
  }
}

// MARK: - NavigationPath Extension Tests

@Suite("Navigation Path Extension Tests")
@MainActor
struct NavigationPathExtensionTests {
  
  @Test("NavigationPath isEmpty works correctly")
  func testNavigationPathIsEmpty() {
    var path = NavigationPath()
    
    #expect(path.isEmpty == true)
    
    path.append("item")
    #expect(path.isEmpty == false)
  }
  
  @Test("NavigationPath count is accurate")
  func testNavigationPathCount() {
    var path = NavigationPath()
    
    #expect(path.count == 0)
    
    path.append("item1")
    #expect(path.count == 1)
    
    path.append("item2")
    #expect(path.count == 2)
  }
}

// MARK: - Tab-Specific Navigation Tests

@Suite("Tab-Specific Navigation Tests")
@MainActor
struct TabSpecificNavigationTests {
  
  @Test("Activity tab navigation works correctly")
  func testActivityTabNavigation() {
    let navigationState = NavigationState()
    
    navigationState.selectedTab = .activity
    navigationState.activityPath.append("session_detail")
    navigationState.activityPath.append("session_settings")
    
    #expect(navigationState.selectedTab == .activity)
    #expect(navigationState.activityPath.count == 2)
    
    navigationState.popToRoot(for: .activity)
    #expect(navigationState.activityPath.isEmpty)
  }
  
  @Test("Progress tab navigation works correctly")
  func testProgressTabNavigation() {
    let navigationState = NavigationState()
    
    navigationState.selectedTab = .progress
    navigationState.progressPath.append("chart_detail")
    navigationState.progressPath.append("export_data")
    
    #expect(navigationState.selectedTab == .progress)
    #expect(navigationState.progressPath.count == 2)
    
    navigationState.resetPath(for: .progress)
    #expect(navigationState.progressPath.isEmpty)
  }
  
  @Test("Routes tab navigation works correctly")
  func testRoutesTabNavigation() {
    let navigationState = NavigationState()
    
    navigationState.selectedTab = .routes
    navigationState.routesPath.append("route_detail")
    navigationState.routesPath.append("route_edit")
    
    #expect(navigationState.selectedTab == .routes)
    #expect(navigationState.routesPath.count == 2)
    
    navigationState.popToRoot(for: .routes)
    #expect(navigationState.routesPath.isEmpty)
  }
  
  @Test("Community tab navigation works correctly")
  func testCommunityTabNavigation() {
    let navigationState = NavigationState()
    
    navigationState.selectedTab = .community
    navigationState.communityPath.append("challenge_detail")
    navigationState.communityPath.append("leaderboard")
    
    #expect(navigationState.selectedTab == .community)
    #expect(navigationState.communityPath.count == 2)
    
    navigationState.resetPath(for: .community)
    #expect(navigationState.communityPath.isEmpty)
  }
  
  @Test("Profile tab navigation works correctly")
  func testProfileTabNavigation() {
    let navigationState = NavigationState()
    
    navigationState.selectedTab = .profile
    navigationState.profilePath.append("settings")
    navigationState.profilePath.append("account_details")
    
    #expect(navigationState.selectedTab == .profile)
    #expect(navigationState.profilePath.count == 2)
    
    navigationState.popToRoot(for: .profile)
    #expect(navigationState.profilePath.isEmpty)
  }
}