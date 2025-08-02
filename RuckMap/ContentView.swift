import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [RuckSession]
    @State private var locationManager = LocationTrackingManager()
    @State private var showStartRuckView = false
    @State private var currentWeight: Double = 35.0 // Default 35 lbs

    var body: some View {
        NavigationStack {
            if locationManager.trackingState == .stopped {
                // Home view when not tracking
                VStack(spacing: 30) {
                    // Logo and title
                    VStack(spacing: 10) {
                        Image(systemName: "figure.rucking")
                            .font(.system(size: 80))
                            .foregroundStyle(.tint)
                        Text("RuckMap")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Track your rucks with precision")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // Quick start button
                    Button(action: startQuickRuck) {
                        Label("Start Ruck", systemImage: "play.fill")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal)
                    
                    // Weight adjustment
                    HStack {
                        Text("Load Weight:")
                        Text("\(Int(currentWeight)) lbs")
                            .fontWeight(.semibold)
                        Stepper("", value: $currentWeight, in: 0...200, step: 5)
                            .labelsHidden()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 50)
                }
                .navigationTitle("RuckMap")
                .onAppear {
                    locationManager.setModelContext(modelContext)
                    locationManager.requestLocationPermission()
                }
            } else {
                // Active tracking view
                ActiveTrackingView(locationManager: locationManager)
            }
        }
    }
    
    private func startQuickRuck() {
        let session = RuckSession()
        session.loadWeight = currentWeight * 0.453592 // Convert lbs to kg
        modelContext.insert(session)
        
        do {
            try modelContext.save()
            locationManager.startTracking(with: session)
        } catch {
            print("Failed to save session: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: RuckSession.self, inMemory: true)
}