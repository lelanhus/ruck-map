import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appCoordinator: WatchAppCoordinator
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if appCoordinator.isInitialized {
                if let error = appCoordinator.initializationError {
                    ErrorView(error: error)
                } else {
                    MainTabView(selectedTab: $selectedTab)
                }
            } else {
                LoadingView()
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var appCoordinator: WatchAppCoordinator
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Main Tracking View
            TrackingView()
                .tag(0)
            
            // Session History
            HistoryView()
                .tag(1)
            
            // Settings
            SettingsView()
                .tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("RuckMap")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Initializing...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: Error
    @EnvironmentObject var appCoordinator: WatchAppCoordinator
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("Setup Error")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Retry") {
                appCoordinator.initialize()
            }
            .buttonStyle(.borderedProminent)
            .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchAppCoordinator())
}