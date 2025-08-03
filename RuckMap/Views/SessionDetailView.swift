import SwiftUI
import SwiftData
import MapKit
import Charts
import CoreLocation
import Observation

/// Session detail view - displays session information and route on map
struct SessionDetailView: View {
    let session: RuckSession
    @EnvironmentObject private var dataCoordinator: DataCoordinator
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Map View
                Map {
                    MapPolyline(coordinates: session.locationPoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                        .stroke(.blue, lineWidth: 3)
                }
                .frame(height: 300)
                .cornerRadius(12)
                
                // Session Stats
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("\(FormatUtilities.formatDistance(session.distance))", systemImage: "figure.walk")
                        Spacer()
                        Label("\(FormatUtilities.formatDuration(session.duration))", systemImage: "clock")
                    }
                    
                    HStack {
                        Label("\(Int(session.totalCalories)) kcal", systemImage: "flame")
                        Spacer()
                        Label("\(FormatUtilities.formatWeight(session.loadWeight))", systemImage: "scalemass")
                    }
                    
                    if session.elevationGain > 0 {
                        HStack {
                            Label("↑ \(Int(session.elevationGain))m", systemImage: "arrow.up.right")
                            Spacer()
                            Label("↓ \(Int(session.elevationLoss))m", systemImage: "arrow.down.right")
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Notes
                if let notes = session.notes, !notes.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview (kept for compatibility)

#Preview {
    let session = RuckSession()
    
    SessionDetailView(session: session)
        .environmentObject(try! DataCoordinator())
}