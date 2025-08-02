//
//  ElevationProfileView.swift
//  RuckMap
//
//  Created by Leland Husband on 8/2/25.
//

import SwiftUI
import Charts

struct ElevationProfileView: View {
    let locationPoints: [LocationPoint]
    let session: RuckSession
    
    // Computed properties for chart data
    private var elevationData: [(distance: Double, elevation: Double, grade: Double?)] {
        guard !locationPoints.isEmpty else { return [] }
        
        var data: [(distance: Double, elevation: Double, grade: Double?)] = []
        var cumulativeDistance: Double = 0
        
        for i in 0..<locationPoints.count {
            let point = locationPoints[i]
            let elevation = point.bestAltitude
            
            // Calculate distance from previous point
            if i > 0 {
                let prevPoint = locationPoints[i - 1]
                let distance = point.distance(to: prevPoint)
                cumulativeDistance += distance
            }
            
            // Calculate grade if we have a next point
            var grade: Double? = nil
            if i < locationPoints.count - 1 {
                // Use stored grade if available
                grade = point.instantaneousGrade
            }
            
            data.append((distance: cumulativeDistance, elevation: elevation, grade: grade))
        }
        
        return data
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Elevation Profile")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    Label("\(Int(session.elevationGain))m gained", systemImage: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Label("\(Int(session.elevationLoss))m lost", systemImage: "arrow.down.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    if session.elevationAccuracy > 0 {
                        Label("±\(Int(session.elevationAccuracy))m", systemImage: "location.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            
            // Elevation Chart
            if !elevationData.isEmpty {
                Chart(elevationData, id: \.distance) { dataPoint in
                    // Area mark for elevation profile
                    AreaMark(
                        x: .value("Distance", dataPoint.distance / 1000), // Convert to km
                        y: .value("Elevation", dataPoint.elevation)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Line mark for elevation
                    LineMark(
                        x: .value("Distance", dataPoint.distance / 1000),
                        y: .value("Elevation", dataPoint.elevation)
                    )
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .frame(height: 200)
                .chartYAxisLabel("Elevation (m)", position: .leading)
                .chartXAxisLabel("Distance (km)", position: .bottom)
                .chartYScale(domain: (session.minElevation - 10)...(session.maxElevation + 10))
            } else {
                // Empty state
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        Text("No elevation data available")
                            .foregroundColor(.secondary)
                    )
            }
            
            // Statistics
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(session.minElevation))m")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading) {
                    Text("Max")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(session.maxElevation))m")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading) {
                    Text("Avg Grade")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", session.averageGrade))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                if session.hasHighQualityElevationData {
                    VStack(alignment: .leading) {
                        Text("Quality")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Label("High", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Preview
#Preview {
    let session = RuckSession()
    session.loadWeight = 20
    
    return ElevationProfileView(
        locationPoints: [],
        session: session
    )
    .padding()
}