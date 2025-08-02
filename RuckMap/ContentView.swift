import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [RuckSession]

    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "figure.rucking")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("RuckMap")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Track your rucks with precision")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("RuckMap")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: RuckSession.self, inMemory: true)
}