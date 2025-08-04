import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var locationManager = LocationTrackingManager()
    @State private var selectedTab: Tab = .home
    @State private var currentWeight: Double = 35.0

    /// Navigation tabs available in the app
    enum Tab: String, CaseIterable {
        case home = "Home"
        case history = "History"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .home:
                "house.fill"
            case .history:
                "clock.fill"
            case .profile:
                "person.circle.fill"
            }
        }

        var iconUnselected: String {
            switch self {
            case .home:
                "house"
            case .history:
                "clock"
            case .profile:
                "person.circle"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationStack {
                HomeTabView(
                    locationManager: locationManager,
                    currentWeight: $currentWeight,
                    selectedTab: $selectedTab
                )
            }
            .tabItem {
                Label(
                    Tab.home.rawValue,
                    systemImage: selectedTab == .home ? Tab.home.icon : Tab.home.iconUnselected
                )
            }
            .tag(Tab.home)

            // History Tab
            NavigationStack {
                HistoryTabView()
            }
            .tabItem {
                Label(
                    Tab.history.rawValue,
                    systemImage: selectedTab == .history ? Tab.history.icon : Tab.history.iconUnselected
                )
            }
            .tag(Tab.history)

            // Profile Tab
            NavigationStack {
                ProfileTabView()
            }
            .tabItem {
                Label(
                    Tab.profile.rawValue,
                    systemImage: selectedTab == .profile ? Tab.profile.icon : Tab.profile.iconUnselected
                )
            }
            .tag(Tab.profile)
        }
        .tint(Color.armyGreenPrimary)
        .onAppear {
            locationManager.setModelContext(modelContext)
            locationManager.requestLocationPermission()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: RuckSession.self, inMemory: true)
}