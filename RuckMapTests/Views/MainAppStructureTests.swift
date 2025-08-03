import Testing
import SwiftUI
import SwiftData
@testable import RuckMap

/// Tests for the main app structure including tab navigation and view coordination
struct MainAppStructureTests {
    
    // MARK: - Tab Navigation Tests
    
    @Test("Tab navigation state management")
    func testTabNavigationState() async {
        let navigation = AppNavigation()
        
        // Test initial state
        #expect(navigation.selectedTab == .home)
        #expect(navigation.homeNavigationPath.count == 0)
        #expect(navigation.historyNavigationPath.count == 0)
        #expect(navigation.profileNavigationPath.count == 0)
        
        // Test tab switching
        navigation.navigateToTab(.history)
        #expect(navigation.selectedTab == .history)
        
        navigation.navigateToTab(.profile)
        #expect(navigation.selectedTab == .profile)
    }
    
    @Test("Navigation path isolation between tabs")
    func testNavigationPathIsolation() async {
        let navigation = AppNavigation()
        let mockSession = createMockSession()
        
        // Navigate in home tab
        navigation.selectedTab = .home
        navigation.homeNavigationPath.append(mockSession)
        
        // Switch to history tab
        navigation.selectedTab = .history
        navigation.historyNavigationPath.append(mockSession)
        
        // Verify paths are isolated
        #expect(navigation.homeNavigationPath.count == 1)
        #expect(navigation.historyNavigationPath.count == 1)
        #expect(navigation.profileNavigationPath.count == 0)
    }
    
    @Test("Reset navigation functionality")
    func testResetNavigation() async {
        let navigation = AppNavigation()
        let mockSession = createMockSession()
        
        // Set up navigation state
        navigation.selectedTab = .history
        navigation.homeNavigationPath.append(mockSession)
        navigation.historyNavigationPath.append(mockSession)
        navigation.showingSettings = true
        
        // Reset all navigation
        navigation.resetAll()
        
        // Verify reset state
        #expect(navigation.selectedTab == .home)
        #expect(navigation.homeNavigationPath.count == 0)
        #expect(navigation.historyNavigationPath.count == 0)
        #expect(navigation.profileNavigationPath.count == 0)
        #expect(navigation.showingSettings == false)
    }
    
    // MARK: - Deep Link Tests
    
    @Test("Deep link URL handling")
    func testDeepLinkHandling() async {
        let navigation = AppNavigation()
        
        // Test session deep link
        let sessionURL = URL(string: "ruckmap://session?id=123")!
        navigation.handleDeepLink(sessionURL)
        #expect(navigation.selectedTab == .history) // Should navigate to history for sessions
        
        // Test settings deep link
        let settingsURL = URL(string: "ruckmap://settings")!
        navigation.handleDeepLink(settingsURL)
        #expect(navigation.showingSettings == true)
        
        // Test new ruck deep link
        let newRuckURL = URL(string: "ruckmap://new-ruck")!
        navigation.handleDeepLink(newRuckURL)
        #expect(navigation.showingNewRuckSetup == true)
    }
    
    @Test("Invalid deep link handling")
    func testInvalidDeepLinkHandling() async {
        let navigation = AppNavigation()
        let originalTab = navigation.selectedTab
        
        // Test invalid URL
        let invalidURL = URL(string: "invalid://url")!
        navigation.handleDeepLink(invalidURL)
        
        // Should default to home
        #expect(navigation.selectedTab == .home)
    }
    
    // MARK: - ContentView Tab Enum Tests
    
    @Test("Tab enum properties")
    func testTabEnumProperties() async {
        // Test icon names
        #expect(ContentView.Tab.home.icon == "house.fill")
        #expect(ContentView.Tab.history.icon == "clock.fill")
        #expect(ContentView.Tab.profile.icon == "person.circle.fill")
        
        #expect(ContentView.Tab.home.iconUnselected == "house")
        #expect(ContentView.Tab.history.iconUnselected == "clock")
        #expect(ContentView.Tab.profile.iconUnselected == "person.circle")
        
        // Test raw values
        #expect(ContentView.Tab.home.rawValue == "Home")
        #expect(ContentView.Tab.history.rawValue == "History")
        #expect(ContentView.Tab.profile.rawValue == "Profile")
    }
    
    @Test("Tab enum case iteration")
    func testTabEnumIteration() async {
        let allTabs = ContentView.Tab.allCases
        #expect(allTabs.count == 3)
        #expect(allTabs.contains(.home))
        #expect(allTabs.contains(.history))
        #expect(allTabs.contains(.profile))
    }
    
    // MARK: - Navigation Preferences Tests
    
    @Test("Navigation preferences initialization")
    func testNavigationPreferencesInit() async {
        let preferences = NavigationPreferences()
        
        #expect(preferences.showTabBarLabels == true)
        #expect(preferences.useLargeNavigationTitles == true)
        #expect(preferences.enableTabBarHaptics == true)
        #expect(preferences.tabBarStyle == .automatic)
    }
    
    @Test("Tab bar style system appearance")
    func testTabBarStyleAppearance() async {
        let automaticStyle = NavigationPreferences.TabBarStyle.automatic
        let alwaysStyle = NavigationPreferences.TabBarStyle.always
        let neverStyle = NavigationPreferences.TabBarStyle.never
        
        // Test that system appearances are created without errors
        let automaticAppearance = automaticStyle.systemStyle
        let alwaysAppearance = alwaysStyle.systemStyle
        let neverAppearance = neverStyle.systemStyle
        
        #expect(automaticAppearance != nil)
        #expect(alwaysAppearance != nil)
        #expect(neverAppearance != nil)
    }
    
    // MARK: - Session Navigation Tests
    
    @Test("Session detail navigation")
    func testSessionDetailNavigation() async {
        let navigation = AppNavigation()
        let mockSession = createMockSession()
        
        // Test navigation from history tab
        navigation.selectedTab = .history
        navigation.navigateToSession(mockSession)
        
        #expect(navigation.selectedSession == mockSession)
        #expect(navigation.historyNavigationPath.count == 1)
        
        // Test navigation from home tab
        navigation.resetAll()
        navigation.selectedTab = .home
        navigation.navigateToSession(mockSession, from: .home)
        
        #expect(navigation.selectedTab == .home)
        #expect(navigation.homeNavigationPath.count == 1)
    }
    
    @Test("Session navigation with tab switching")
    func testSessionNavigationWithTabSwitching() async {
        let navigation = AppNavigation()
        let mockSession = createMockSession()
        
        // Start on home tab
        navigation.selectedTab = .home
        
        // Navigate to session without specifying tab (should switch to history)
        navigation.navigateToSession(mockSession)
        
        #expect(navigation.selectedTab == .history)
        #expect(navigation.historyNavigationPath.count == 1)
        #expect(navigation.selectedSession == mockSession)
    }
    
    // MARK: - Modal Navigation Tests
    
    @Test("Modal presentation state")
    func testModalPresentationState() async {
        let navigation = AppNavigation()
        
        // Test settings modal
        navigation.navigateToSettings()
        #expect(navigation.showingSettings == true)
        
        // Test new ruck modal
        navigation.navigateToNewRuck()
        #expect(navigation.showingNewRuckSetup == true)
        
        // Test reset clears modals
        navigation.resetAll()
        #expect(navigation.showingSettings == false)
        #expect(navigation.showingNewRuckSetup == false)
    }
    
    // MARK: - Navigation Path Binding Tests
    
    @Test("Navigation path binding for tabs")
    func testNavigationPathBinding() async {
        let navigation = AppNavigation()
        
        // Test home path binding
        let homeBinding = navigation.navigationPath(for: .home)
        homeBinding.wrappedValue.append("test")
        #expect(navigation.homeNavigationPath.count == 1)
        
        // Test history path binding
        let historyBinding = navigation.navigationPath(for: .history)
        historyBinding.wrappedValue.append("test")
        #expect(navigation.historyNavigationPath.count == 1)
        
        // Test profile path binding
        let profileBinding = navigation.navigationPath(for: .profile)
        profileBinding.wrappedValue.append("test")
        #expect(navigation.profileNavigationPath.count == 1)
    }
    
    // MARK: - Accessibility Tests
    
    @Test("Navigation accessibility labels")
    func testNavigationAccessibilityLabels() async {
        let navigation = AppNavigation()
        
        // Test initial state
        let initialLabel = navigation.accessibilityNavigationLabel()
        #expect(initialLabel.contains("Home tab"))
        #expect(initialLabel.contains("0 screens deep"))
        
        // Test with navigation depth
        navigation.homeNavigationPath.append("test")
        let withDepthLabel = navigation.accessibilityNavigationLabel()
        #expect(withDepthLabel.contains("1 screens deep"))
        
        // Test different tabs
        navigation.selectedTab = .history
        let historyLabel = navigation.accessibilityNavigationLabel()
        #expect(historyLabel.contains("History tab"))
        
        navigation.selectedTab = .profile
        let profileLabel = navigation.accessibilityNavigationLabel()
        #expect(profileLabel.contains("Profile tab"))
    }
    
    // MARK: - Helper Methods
    
    private func createMockSession() -> RuckSession {
        let session = RuckSession()
        session.totalDistance = 5000.0 // 5km
        session.totalDuration = 3600.0 // 1 hour
        session.loadWeight = 20.0 // 20kg
        session.endDate = Date()
        return session
    }
}

// MARK: - Profile Statistics Tests

struct ProfileStatisticsTests {
    
    @Test("Profile statistics calculations")
    func testProfileStatisticsCalculations() async {
        let sessions = createMockSessions()
        let stats = ProfileStatistics(sessions: sessions)
        
        #expect(stats.totalSessions == 3)
        #expect(stats.totalDistance == 15000.0) // 5km + 5km + 5km
        #expect(stats.totalDuration == 10800.0) // 1h + 1h + 1h
        #expect(stats.averageDistance == 5000.0)
        #expect(stats.longestDistance == 5000.0)
    }
    
    @Test("Empty sessions statistics")
    func testEmptySessionsStatistics() async {
        let stats = ProfileStatistics(sessions: [])
        
        #expect(stats.totalSessions == 0)
        #expect(stats.totalDistance == 0.0)
        #expect(stats.totalDuration == 0.0)
        #expect(stats.averageDistance == 0.0)
        #expect(stats.longestDistance == 0.0)
    }
    
    @Test("Time-based statistics")
    func testTimeBasedStatistics() async {
        let sessions = createMockSessionsWithDates()
        let stats = ProfileStatistics(sessions: sessions)
        
        // Should have sessions from this week and month
        #expect(stats.thisWeekSessions >= 0)
        #expect(stats.thisMonthSessions >= 0)
        #expect(stats.thisWeekDistance >= 0)
        #expect(stats.thisMonthDistance >= 0)
    }
    
    private func createMockSessions() -> [RuckSession] {
        return (0..<3).map { _ in
            let session = RuckSession()
            session.totalDistance = 5000.0
            session.totalDuration = 3600.0
            session.loadWeight = 20.0
            session.endDate = Date()
            return session
        }
    }
    
    private func createMockSessionsWithDates() -> [RuckSession] {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        let monthAgo = Calendar.current.date(byAdding: .day, value: -15, to: now)!
        
        return [
            createMockSessionWithDate(now),
            createMockSessionWithDate(weekAgo),
            createMockSessionWithDate(monthAgo)
        ]
    }
    
    private func createMockSessionWithDate(_ date: Date) -> RuckSession {
        let session = RuckSession()
        session.startDate = date
        session.endDate = date.addingTimeInterval(3600)
        session.totalDistance = 5000.0
        session.totalDuration = 3600.0
        session.loadWeight = 20.0
        return session
    }
}

// MARK: - History Statistics Tests

struct HistoryStatisticsTests {
    
    @Test("History statistics calculations")
    func testHistoryStatisticsCalculations() async {
        let sessions = createMockSessions()
        let stats = HistoryStatistics(sessions: sessions)
        
        #expect(stats.totalSessions == 2)
        #expect(stats.totalDistance == 10000.0)
        #expect(stats.totalDuration == 7200.0)
        #expect(stats.averageDistance == 5000.0)
        #expect(stats.averageDuration == 3600.0)
    }
    
    @Test("Single session statistics")
    func testSingleSessionStatistics() async {
        let session = RuckSession()
        session.totalDistance = 3000.0
        session.totalDuration = 2400.0
        session.endDate = Date()
        
        let stats = HistoryStatistics(sessions: [session])
        
        #expect(stats.totalSessions == 1)
        #expect(stats.totalDistance == 3000.0)
        #expect(stats.totalDuration == 2400.0)
        #expect(stats.averageDistance == 3000.0)
        #expect(stats.averageDuration == 2400.0)
    }
    
    private func createMockSessions() -> [RuckSession] {
        return (0..<2).map { _ in
            let session = RuckSession()
            session.totalDistance = 5000.0
            session.totalDuration = 3600.0
            session.loadWeight = 20.0
            session.endDate = Date()
            return session
        }
    }
}