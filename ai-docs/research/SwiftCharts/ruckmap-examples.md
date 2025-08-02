# Swift Charts Examples for RuckMap

## Elevation Profile Chart

```swift
import SwiftUI
import Charts

struct ElevationProfileChart: View {
    let waypoints: [Waypoint]
    @State private var selectedWaypoint: Waypoint?
    
    var body: some View {
        Chart(waypoints) { waypoint in
            AreaMark(
                x: .value("Distance", waypoint.cumulativeDistance / 1000), // km
                y: .value("Elevation", waypoint.elevation)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [.armyGreen.opacity(0.8), .armyGreen.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            LineMark(
                x: .value("Distance", waypoint.cumulativeDistance / 1000),
                y: .value("Elevation", waypoint.elevation)
            )
            .foregroundStyle(.armyGreen)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            if waypoint == selectedWaypoint {
                RuleMark(
                    x: .value("Distance", waypoint.cumulativeDistance / 1000)
                )
                .foregroundStyle(.secondary.opacity(0.5))
                .annotation(position: .top, alignment: .center) {
                    VStack(spacing: 4) {
                        Text("\(waypoint.elevation, format: .number.precision(.fractionLength(0)))m")
                            .font(.caption.bold())
                        Text("\(waypoint.cumulativeDistance / 1000, format: .number.precision(.fractionLength(1)))km")
                            .font(.caption2)
                    }
                    .padding(4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let distance = value.as(Double.self) {
                        Text("\(distance, format: .number.precision(.fractionLength(0)))km")
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let elevation = value.as(Double.self) {
                        Text("\(elevation, format: .number.precision(.fractionLength(0)))m")
                    }
                }
            }
        }
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        selectNearestWaypoint(
                            at: location,
                            geometry: geometry,
                            proxy: chartProxy
                        )
                    }
            }
        }
    }
    
    private func selectNearestWaypoint(at location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) {
        let xPosition = location.x
        let plotAreaFrame = proxy.plotAreaFrame
        
        guard let plotAreaFrame = plotAreaFrame,
              let distance = proxy.value(atX: xPosition, as: Double.self) else {
            return
        }
        
        // Find nearest waypoint
        let targetDistance = distance * 1000 // Convert to meters
        selectedWaypoint = waypoints.min(by: { waypoint1, waypoint2 in
            abs(waypoint1.cumulativeDistance - targetDistance) <
            abs(waypoint2.cumulativeDistance - targetDistance)
        })
    }
}
```

## Heart Rate and Pace Combined Chart

```swift
struct HeartRatePaceChart: View {
    let dataPoints: [SessionDataPoint]
    
    struct SessionDataPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let heartRate: Int
        let pace: Double // min/km
    }
    
    var body: some View {
        Chart(dataPoints) { point in
            // Heart rate line
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Heart Rate", point.heartRate),
                series: .value("Metric", "Heart Rate")
            )
            .foregroundStyle(.red)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            // Pace line (on secondary axis)
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Pace", point.pace),
                series: .value("Metric", "Pace")
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
        }
        .frame(height: 250)
        .chartForegroundStyleScale([
            "Heart Rate": .red,
            "Pace": .blue
        ])
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let hr = value.as(Int.self) {
                        Text("\(hr) bpm")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic) { value in
                AxisTick()
                AxisValueLabel {
                    if let pace = value.as(Double.self) {
                        let minutes = Int(pace)
                        let seconds = Int((pace - Double(minutes)) * 60)
                        Text("\(minutes):\(String(format: "%02d", seconds))")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .chartLegend(position: .top)
    }
}
```

## Weekly Progress Chart

```swift
struct WeeklyProgressChart: View {
    let weeklyData: [WeeklySummary]
    
    struct WeeklySummary: Identifiable {
        let id = UUID()
        let week: Date
        let distance: Double
        let sessions: Int
        let calories: Double
    }
    
    var body: some View {
        Chart(weeklyData) { summary in
            BarMark(
                x: .value("Week", summary.week, unit: .weekOfYear),
                y: .value("Distance", summary.distance / 1000) // km
            )
            .foregroundStyle(.armyGreen)
            .cornerRadius(4)
            .annotation(position: .top) {
                Text("\(summary.sessions)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.week())
            }
        }
        .chartYAxisLabel("Distance (km)", position: .leading)
    }
}
```

## Calorie Burn Rate Chart

```swift
struct CalorieBurnRateChart: View {
    let segments: [SessionSegment]
    @State private var selectedSegment: SessionSegment?
    
    var body: some View {
        Chart(segments) { segment in
            RectangleMark(
                xStart: .value("Start", segment.startTime),
                xEnd: .value("End", segment.endTime),
                yStart: .value("Min Rate", 0),
                yEnd: .value("Burn Rate", segment.caloriesPerMinute)
            )
            .foregroundStyle(by: .value("Terrain", segment.terrainType.rawValue))
            .opacity(selectedSegment == nil || selectedSegment == segment ? 1 : 0.5)
        }
        .frame(height: 200)
        .chartForegroundStyleScale([
            "Pavement": Color.gray,
            "Trail": Color.brown,
            "Sand": Color.orange,
            "Snow": Color.blue.opacity(0.7)
        ])
        .chartYAxisLabel("Cal/min")
        .chartLegend(position: .bottom, alignment: .center)
        .overlay(alignment: .topTrailing) {
            if let segment = selectedSegment {
                VStack(alignment: .leading, spacing: 4) {
                    Label(segment.terrainType.rawValue, systemImage: "map")
                        .font(.caption.bold())
                    Text("\(segment.caloriesPerMinute, format: .number.precision(.fractionLength(1))) cal/min")
                        .font(.caption)
                    Text("\(segment.duration, format: .number.precision(.fractionLength(0))) min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding()
            }
        }
    }
}
```

## Performance Comparison Chart

```swift
struct PerformanceComparisonChart: View {
    let currentSession: RuckSession
    let historicalAverage: [DataPoint]
    let personalBest: [DataPoint]
    
    struct DataPoint: Identifiable {
        let id = UUID()
        let distance: Double
        let time: TimeInterval
    }
    
    var body: some View {
        Chart {
            // Current session
            ForEach(currentSession.splitTimes) { split in
                LineMark(
                    x: .value("Distance", split.distance / 1000),
                    y: .value("Time", split.time / 60),
                    series: .value("Session", "Current")
                )
                .foregroundStyle(.armyGreen)
                .lineStyle(StrokeStyle(lineWidth: 3))
            }
            
            // Historical average
            ForEach(historicalAverage) { point in
                LineMark(
                    x: .value("Distance", point.distance / 1000),
                    y: .value("Time", point.time / 60),
                    series: .value("Session", "Average")
                )
                .foregroundStyle(.gray)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
            
            // Personal best
            ForEach(personalBest) { point in
                LineMark(
                    x: .value("Distance", point.distance / 1000),
                    y: .value("Time", point.time / 60),
                    series: .value("Session", "Personal Best")
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .frame(height: 250)
        .chartXAxisLabel("Distance (km)")
        .chartYAxisLabel("Time (min)")
        .chartLegend(position: .top)
        .chartForegroundStyleScale([
            "Current": Color.armyGreen,
            "Average": Color.gray,
            "Personal Best": Color.orange
        ])
    }
}
```

## Monthly Statistics Grid

```swift
struct MonthlyStatsChart: View {
    let monthlyStats: [DailyStat]
    
    struct DailyStat: Identifiable {
        let id = UUID()
        let date: Date
        let sessions: Int
        let totalDistance: Double
    }
    
    var body: some View {
        Chart(monthlyStats) { stat in
            RectangleMark(
                x: .value("Week", stat.date, unit: .weekOfMonth),
                y: .value("Weekday", stat.date, unit: .weekday),
                width: .ratio(1),
                height: .ratio(1)
            )
            .foregroundStyle(by: .value("Distance", stat.totalDistance))
            .cornerRadius(4)
        }
        .chartForegroundStyleScale(
            range: Gradient(colors: [
                .armyGreen.opacity(0.2),
                .armyGreen.opacity(0.6),
                .armyGreen
            ])
        )
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfMonth)) { _ in
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 7)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let weekday = value.as(Date.self) {
                        Text(weekday, format: .dateTime.weekday(.abbreviated))
                    }
                }
            }
        }
        .frame(height: 200)
        .overlay(alignment: .bottomTrailing) {
            VStack(alignment: .trailing, spacing: 2) {
                ForEach([0, 5, 10], id: \.self) { distance in
                    HStack(spacing: 4) {
                        Text("\(distance)km")
                            .font(.caption2)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorForDistance(Double(distance)))
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding()
        }
    }
    
    private func colorForDistance(_ distance: Double) -> Color {
        let normalized = min(distance / 10.0, 1.0)
        return .armyGreen.opacity(0.2 + normalized * 0.8)
    }
}
```

## Key Implementation Notes

1. **Performance**: Use `.chartXScale(domain:)` to limit visible data range for large datasets
2. **Interactivity**: Implement tap/drag gestures for selection
3. **Accessibility**: Ensure all charts have proper labels and audio graph support
4. **Animation**: Use `.animation(.easeInOut, value:)` for smooth transitions
5. **Colors**: Use consistent color scheme aligned with army green theme
6. **Responsiveness**: Adjust chart height based on device size and orientation