import SwiftUI
import SwiftData
import OSLog

@main
struct RuckMapApp: App {
    private let logger = Logger(subsystem: "com.ruckmap.app", category: "RuckMapApp")
    
    @StateObject private var dataCoordinator: DataCoordinator = {
        var coordinator: DataCoordinator?
        var attempts = 0
        let maxAttempts = 3
        
        while attempts < maxAttempts {
            do {
                coordinator = try DataCoordinator()
                break
            } catch {
                attempts += 1
                Logger(subsystem: "com.ruckmap.app", category: "RuckMapApp")
                    .error("DataCoordinator initialization attempt \(attempts) failed: \(error.localizedDescription)")
                
                if attempts >= maxAttempts {
                    Logger(subsystem: "com.ruckmap.app", category: "RuckMapApp")
                        .critical("All DataCoordinator initialization attempts failed. Creating fallback coordinator.")
                    
                    // Create a fallback coordinator with minimal functionality
                    coordinator = DataCoordinator.createFallback()
                    break
                }
                
                // Brief delay between attempts
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        
        return coordinator ?? DataCoordinator.createFallback()
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataCoordinator)
                .modelContainer(dataCoordinator.modelContainer)
                .task {
                    await dataCoordinator.initialize()
                }
        }
    }
}