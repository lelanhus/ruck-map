import SwiftUI
import SwiftData

@main
struct RuckMapApp: App {
    @StateObject private var dataCoordinator: DataCoordinator
    
    init() {
        do {
            _dataCoordinator = StateObject(wrappedValue: try DataCoordinator())
        } catch {
            fatalError("Failed to initialize DataCoordinator: \(error)")
        }
    }

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