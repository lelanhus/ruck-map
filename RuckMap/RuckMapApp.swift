import SwiftUI
import SwiftData

@main
struct RuckMapApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RuckSession.self,
            LocationPoint.self,
            TerrainSegment.self,
            WeatherConditions.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: URL.documentsDirectory.appending(path: "RuckMap.store"),
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Configure for background processing
            container.mainContext.automaticallyMergesChangesFromParent = true
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}