import Observation
import SwiftUI

/// Centralized navigation state management for RuckMap
/// Provides type-safe navigation and tab coordination following iOS 18+ patterns
@Observable
@MainActor
final class AppNavigation {
    // MARK: - Tab Navigation State

    /// Currently selected tab
    var selectedTab: ContentView.Tab = .home

    /// Navigation paths for each tab to maintain separate navigation stacks
    var homeNavigationPath = NavigationPath()
    var historyNavigationPath = NavigationPath()
    var profileNavigationPath = NavigationPath()

    // MARK: - Modal Navigation State

    /// Controls presentation of modal sheets
    var showingNewRuckSetup = false
    var showingSettings = false
    var showingSessionDetail = false

    /// Session for detail presentation
    var selectedSession: RuckSession?

    // MARK: - Deep Link Support

    /// Handles deep link navigation to specific destinations
    enum Destination: Hashable {
        case home
        case history
        case profile
        case sessionDetail(RuckSession)
        case settings
        case newRuck
    }

    // MARK: - Navigation Actions

    /// Navigate to a specific tab
    func navigateToTab(_ tab: ContentView.Tab) {
        selectedTab = tab
    }

    /// Navigate to a session detail from any tab
    func navigateToSession(_ session: RuckSession, from tab: ContentView.Tab? = nil) {
        selectedSession = session

        // Switch to history tab if not already there
        if let fromTab = tab {
            selectedTab = fromTab
        } else if selectedTab != .history {
            selectedTab = .history
        }

        // Add to appropriate navigation path
        switch selectedTab {
        case .home:
            homeNavigationPath.append(session)
        case .history:
            historyNavigationPath.append(session)
        case .profile:
            profileNavigationPath.append(session)
        }
    }

    /// Navigate to settings
    func navigateToSettings() {
        showingSettings = true
    }

    /// Navigate to new ruck setup
    func navigateToNewRuck() {
        showingNewRuckSetup = true
    }

    /// Reset navigation to root for a specific tab
    func popToRoot(for tab: ContentView.Tab) {
        switch tab {
        case .home:
            homeNavigationPath = NavigationPath()
        case .history:
            historyNavigationPath = NavigationPath()
        case .profile:
            profileNavigationPath = NavigationPath()
        }
    }

    /// Reset all navigation state
    func resetAll() {
        selectedTab = .home
        homeNavigationPath = NavigationPath()
        historyNavigationPath = NavigationPath()
        profileNavigationPath = NavigationPath()
        showingNewRuckSetup = false
        showingSettings = false
        showingSessionDetail = false
        selectedSession = nil
    }

    /// Handle deep link navigation
    func handle(destination: Destination) {
        switch destination {
        case .home:
            navigateToTab(.home)

        case .history:
            navigateToTab(.history)

        case .profile:
            navigateToTab(.profile)

        case let .sessionDetail(session):
            navigateToSession(session)

        case .settings:
            navigateToSettings()

        case .newRuck:
            navigateToNewRuck()
        }
    }

    /// Handle URL-based deep links
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host
        else {
            return
        }

        switch host {
        case "session":
            if let sessionId = components.queryItems?.first(where: { $0.name == "id" })?.value,
               let _ = UUID(uuidString: sessionId)
            {
                // In a real app, you'd fetch the session by ID
                // For now, we'll just navigate to history
                handle(destination: .history)
            }

        case "new-ruck":
            handle(destination: .newRuck)

        case "settings":
            handle(destination: .settings)

        default:
            handle(destination: .home)
        }
    }

    /// Get the current navigation path for a tab
    func navigationPath(for tab: ContentView.Tab) -> Binding<NavigationPath> {
        switch tab {
        case .home:
            Binding(
                get: { self.homeNavigationPath },
                set: { self.homeNavigationPath = $0 }
            )
        case .history:
            Binding(
                get: { self.historyNavigationPath },
                set: { self.historyNavigationPath = $0 }
            )
        case .profile:
            Binding(
                get: { self.profileNavigationPath },
                set: { self.profileNavigationPath = $0 }
            )
        }
    }
}

// MARK: - Environment Integration

/// Environment key for AppNavigation
struct AppNavigationKey: @preconcurrency EnvironmentKey {
    @MainActor
    static let defaultValue = AppNavigation()
}

extension EnvironmentValues {
    var appNavigation: AppNavigation {
        get { self[AppNavigationKey.self] }
        set { self[AppNavigationKey.self] = newValue }
    }
}

// MARK: - Navigation Preferences

/// User preferences for navigation behavior
@Observable
final class NavigationPreferences {
    /// Whether to show tab bar labels
    var showTabBarLabels = true

    /// Whether to use large navigation titles
    var useLargeNavigationTitles = true

    /// Whether to enable tab bar haptics
    var enableTabBarHaptics = true

    /// Preferred tab bar style
    var tabBarStyle: TabBarStyle = .automatic

    enum TabBarStyle: String, CaseIterable {
        case automatic = "Automatic"
        case always = "Always"
        case never = "Never"

        @MainActor var systemStyle: UITabBarAppearance {
            let appearance = UITabBarAppearance()
            switch self {
            case .automatic:
                appearance.configureWithDefaultBackground()
            case .always:
                appearance.configureWithOpaqueBackground()
            case .never:
                appearance.configureWithTransparentBackground()
            }
            return appearance
        }
    }
}

// MARK: - Navigation Analytics

/// Analytics helper for tracking navigation patterns
enum NavigationAnalytics {
    /// Track tab selection
    static func trackTabSelection(_ tab: ContentView.Tab) {
        // In a real app, you'd send this to your analytics service
        print("Analytics: Tab selected - \(tab.rawValue)")
    }

    /// Track navigation to session detail
    static func trackSessionDetailNavigation(_ sessionId: UUID, from tab: ContentView.Tab) {
        print("Analytics: Session detail viewed - \(sessionId) from \(tab.rawValue)")
    }

    /// Track modal presentation
    static func trackModalPresentation(_ modal: String) {
        print("Analytics: Modal presented - \(modal)")
    }

    /// Track deep link handling
    static func trackDeepLink(_ url: URL) {
        print("Analytics: Deep link handled - \(url)")
    }
}

// MARK: - Navigation Accessibility

/// Accessibility helpers for navigation
extension AppNavigation {
    /// Get accessibility label for current navigation state
    func accessibilityNavigationLabel() -> String {
        switch selectedTab {
        case .home:
            "Home tab, \(homeNavigationPath.count) screens deep"
        case .history:
            "History tab, \(historyNavigationPath.count) screens deep"
        case .profile:
            "Profile tab, \(profileNavigationPath.count) screens deep"
        }
    }

    /// Announce navigation changes for VoiceOver users
    func announceNavigationChange(to destination: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(
                notification: .screenChanged,
                argument: "Navigated to \(destination)"
            )
        }
    }
}
