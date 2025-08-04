import SwiftUI

@main
struct RuckMapWatchApp: App {
    @State private var appCoordinator = WatchAppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appCoordinator)
                .onAppear {
                    appCoordinator.initialize()
                }
        }
    }
}

// MARK: - Watch App Coordinator

/// Central coordinator for Watch app dependencies and state
@MainActor
@Observable
final class WatchAppCoordinator {
    
    // Core managers
    private(set) var dataManager: WatchDataManager?
    private(set) var locationManager: WatchLocationManager?
    private(set) var healthKitManager: WatchHealthKitManager?
    
    // App state
    var isInitialized = false
    var initializationError: Error?
    var permissionsGranted = false
    
    func initialize() {
        Task {
            do {
                // Initialize core managers
                let dataManager = try WatchDataManager()
                let healthKitManager = WatchHealthKitManager()
                let locationManager = WatchLocationManager(
                    dataManager: dataManager,
                    healthKitManager: healthKitManager
                )
                
                self.dataManager = dataManager
                self.healthKitManager = healthKitManager
                self.locationManager = locationManager
                
                // Request permissions
                await requestPermissions()
                
                isInitialized = true
                
            } catch {
                print("Failed to initialize Watch app: \(error)")
                initializationError = error
                
                // Set as initialized even with errors to allow basic functionality
                isInitialized = true
            }
        }
    }
    
    private func requestPermissions() async {
        var allPermissionsGranted = true
        
        // Request HealthKit authorization
        do {
            try await healthKitManager?.requestAuthorization()
        } catch {
            print("HealthKit authorization failed: \(error)")
            allPermissionsGranted = false
        }
        
        // Request location permission
        locationManager?.requestLocationPermission()
        
        // Wait a moment for location permission response
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        permissionsGranted = allPermissionsGranted
    }
}