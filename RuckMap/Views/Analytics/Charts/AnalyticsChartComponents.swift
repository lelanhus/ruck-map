import SwiftUI
import Charts
import Foundation

// MARK: - Weekly/Monthly Overview Chart

/// Line/bar chart showing distance by day/week with trend indicators
struct WeeklyOverviewChart: View {
    let weeklyData: [WeekData]
    @State private var selectedWeek: WeekData?
    @State private var showingDistanceGoal: Bool = true
    @StateObject private var accessibilityManager = ChartAccessibilityManager()
    @StateObject private var optimizedData = OptimizedChartData<WeekData>(strategy: .adaptive)
    @StateObject private var performanceMonitor = ChartPerformanceMonitor()
    @State private var showingDataTable = false
    
    private let distanceGoal: Double = 20.0 // km per week
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with controls
            HStack {
                Text("Weekly Distance")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showingDistanceGoal.toggle() }) {
                    Label("Goal", systemImage: showingDistanceGoal ? "target" : "target.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            // Chart
            Chart {
                // Distance bars - use optimized data
                ForEach(optimizedData.displayData) { week in
                    BarMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Distance", week.totalDistance / 1000.0)
                    )
                    .foregroundStyle(
                        week.meetsTrainingGoal ? 
                            Color(red: 0.18, green: 0.31, blue: 0.18) : // Army green
                            Color(red: 0.18, green: 0.31, blue: 0.18).opacity(0.4)
                    )
                    .cornerRadius(6)
                    .opacity(selectedWeek == nil || selectedWeek?.id == week.id ? 1.0 : 0.3)
                }
                
                // Goal line
                if showingDistanceGoal {
                    RuleMark(y: .value("Goal", distanceGoal))
                        .foregroundStyle(.orange.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .annotation(position: .topTrailing, alignment: .leading) {
                            Text("Goal: \(distanceGoal, format: .number.precision(.fractionLength(0)))km")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 4)
                                .background(.regularMaterial, in: Capsule())
                        }
                }
                
                // Selection indicator
                if let selectedWeek = selectedWeek {
                    RuleMark(x: .value("Week", selectedWeek.weekStart, unit: .weekOfYear))
                        .foregroundStyle(.blue.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .annotation(position: .top, alignment: .center, spacing: 8) {
                            VStack(alignment: .center, spacing: 4) {
                                Text("\(selectedWeek.totalDistance / 1000.0, format: .number.precision(.fractionLength(1)))km")
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                
                                Text("\(selectedWeek.sessionCount) sessions")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: selectedWeek.meetsTrainingGoal ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(selectedWeek.meetsTrainingGoal ? .green : .red)
                                    
                                    Text("Training Goal")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 2)
                        }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(preset: .automatic, values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let distance = value.as(Double.self) {
                            Text("\(distance, format: .number.precision(.fractionLength(0)))km")
                                .font(.caption)
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
                            selectWeek(at: location, geometry: geometry, proxy: chartProxy)
                        }
                }
            }
            .animation(ChartAnimationProvider.selectionAnimation(), value: selectedWeek?.id)
            .animation(ChartAnimationProvider.chartUpdateAnimation(), value: showingDistanceGoal)
            .opacity(optimizedData.isOptimizing ? 0.7 : 1.0)
            .chartAccessibility(
                label: "Weekly distance chart",
                hint: "Shows distance covered each week. Double tap to select weeks, triple tap for audio graph.",
                value: selectedWeek != nil ? "Selected week: \(selectedWeek!.formattedWeekRange)" : "No week selected",
                traits: [.allowsDirectInteraction, .playsSound],
                actions: [
                    .playAudioGraph: {
                        playAudioGraph()
                    },
                    .showDataTable: {
                        showingDataTable = true
                    },
                    .announceDetails: {
                        announceChartSummary()
                    }
                ]
            )
            .chartRotorSupport(
                items: optimizedData.displayData,
                label: { week in
                    "Week \(week.formattedWeekRange): \(week.totalDistance / 1000.0, format: .number.precision(.fractionLength(1))) km"
                },
                onSelection: { week in
                    selectedWeek = week
                    accessibilityManager.announceChartSelection(
                        "Selected \(week.formattedWeekRange): \(week.totalDistance / 1000.0, format: .number.precision(.fractionLength(1))) kilometers, \(week.sessionCount) sessions"
                    )
                }
            )
            
            // Legend
            HStack(spacing: 16) {
                Label("Goal Met", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                Label("Goal Missed", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                
                if showingDistanceGoal {
                    Label("Weekly Goal", systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(AccessibilityPreferences.shared.shouldUseHighContrast ? Color(.systemBackground) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: AccessibilityPreferences.shared.isReduceTransparencyEnabled ? 0 : 2, y: AccessibilityPreferences.shared.isReduceTransparencyEnabled ? 0 : 1)
        .sheet(isPresented: $showingDataTable) {
            ChartDataTableView(
                title: "Weekly Distance Data",
                headers: ["Week", "Distance (km)", "Sessions", "Goal Status"],
                rows: weeklyData.map { week in
                    [
                        week.formattedWeekRange,
                        String(format: "%.1f", week.totalDistance / 1000.0),
                        "\(week.sessionCount)",
                        week.meetsTrainingGoal ? "Met" : "Not Met"
                    ]
                }
            )
        }
        .task {
            await optimizedData.updateData(weeklyData)
        }
        .onChange(of: weeklyData) { _, newData in
            Task {
                await optimizedData.updateData(newData)
            }
        }
    }
    
    // MARK: - Accessibility Methods
    
    private func playAudioGraph() {
        let distances = weeklyData.map { $0.totalDistance / 1000.0 }
        accessibilityManager.playAudioGraph(for: distances, metric: "weekly distance")
    }
    
    private func announceChartSummary() {
        let totalWeeks = weeklyData.count
        let weeksWithGoal = weeklyData.filter { $0.meetsTrainingGoal }.count
        let averageDistance = weeklyData.reduce(0) { $0 + $1.totalDistance } / Double(totalWeeks) / 1000.0
        
        let summary = "Weekly distance chart shows \(totalWeeks) weeks of data. Average distance: \(averageDistance, format: .number.precision(.fractionLength(1))) kilometers per week. \(weeksWithGoal) of \(totalWeeks) weeks met the training goal."
        
        accessibilityManager.announceMessage(summary)
    }
    
    private func selectWeek(at location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) {
        let plotFrame = proxy.plotAreaFrame
        guard let plotFrame = plotFrame else { return }
        
        let origin = geometry[plotFrame].origin
        let relativeXPosition = location.x - origin.x
        
        if let weekDate = proxy.value(atX: relativeXPosition, as: Date.self) {
            // Find the closest week from optimized data first, fallback to original data
            let dataToSearch = optimizedData.displayData.isEmpty ? weeklyData : optimizedData.displayData
            selectedWeek = dataToSearch.min(by: { week1, week2 in
                abs(week1.weekStart.timeIntervalSince(weekDate)) < 
                abs(week2.weekStart.timeIntervalSince(weekDate))
            })
        }
    }
}

// MARK: - Pace Trend Chart

/// Line chart showing average pace over time with trend indicators
struct PaceTrendChart: View {
    let weeklyData: [WeekData]
    let trendData: TrendData?
    @State private var selectedDataPoint: WeekData?
    @State private var showingMovingAverage: Bool = true
    @StateObject private var accessibilityManager = ChartAccessibilityManager()
    @State private var showingDataTable = false
    
    private var movingAverageData: [MovingAveragePoint] {
        guard weeklyData.count >= 3 else { return [] }
        
        return weeklyData.enumerated().compactMap { index, week in
            guard index >= 2 else { return nil }
            
            let window = Array(weeklyData[max(0, index - 2)...index])
            let avgPace = window.reduce(0.0) { $0 + $1.averagePace } / Double(window.count)
            
            return MovingAveragePoint(date: week.weekStart, pace: avgPace)
        }
    }
    
    struct MovingAveragePoint: Identifiable {
        let id = UUID()
        let date: Date
        let pace: Double
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with trend indicator
            HStack {
                Text("Pace Trend")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let trend = trendData {
                    HStack(spacing: 4) {
                        Image(systemName: trend.direction.systemImage)
                            .font(.caption)
                        Text(trend.formattedPercentageChange)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color(trend.direction.color))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(trend.direction.color).opacity(0.1))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                Button(action: { showingMovingAverage.toggle() }) {
                    Label("3-Week Avg", systemImage: showingMovingAverage ? "chart.line.uptrend.xyaxis" : "chart.line.uptrend.xyaxis.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            // Chart
            Chart {
                // Individual pace points
                ForEach(weeklyData.filter { $0.averagePace > 0 }) { week in
                    LineMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Pace", week.averagePace)
                    )
                    .foregroundStyle(Color(red: 0.18, green: 0.31, blue: 0.18))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Pace", week.averagePace)
                    )
                    .foregroundStyle(Color(red: 0.18, green: 0.31, blue: 0.18))
                    .symbol(.circle)
                    .symbolSize(week.id == selectedDataPoint?.id ? 120 : 60)
                    .opacity(selectedDataPoint == nil || selectedDataPoint?.id == week.id ? 1.0 : 0.4)
                }
                
                // Moving average line
                if showingMovingAverage {
                    ForEach(movingAverageData) { point in
                        LineMark(
                            x: .value("Week", point.date, unit: .weekOfYear),
                            y: .value("Average Pace", point.pace)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 3, dash: [8, 4]))
                    }
                }
                
                // Selection indicator
                if let selectedPoint = selectedDataPoint, selectedPoint.averagePace > 0 {
                    RuleMark(x: .value("Week", selectedPoint.weekStart, unit: .weekOfYear))
                        .foregroundStyle(.blue.opacity(0.5))
                        .annotation(position: .top, alignment: .center, spacing: 8) {
                            VStack(alignment: .center, spacing: 4) {
                                Text(formatPace(selectedPoint.averagePace))
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                
                                Text("\(selectedPoint.totalDistance / 1000.0, format: .number.precision(.fractionLength(1)))km")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Text(selectedPoint.weekStart, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 2)
                        }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(preset: .automatic, values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let pace = value.as(Double.self) {
                            Text(formatPace(pace))
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            selectDataPoint(at: location, geometry: geometry, proxy: chartProxy)
                        }
                }
            }
            .animation(AccessibilityPreferences.shared.reduceMotion ? .none : .easeInOut(duration: 0.3), value: selectedDataPoint?.id)
            .animation(AccessibilityPreferences.shared.reduceMotion ? .none : .easeInOut(duration: 0.3), value: showingMovingAverage)
            .chartAccessibility(
                label: "Pace trend chart",
                hint: "Shows pace improvements over time. Double tap to select data points, triple tap for audio graph.",
                value: selectedDataPoint != nil ? "Selected: \(formatPace(selectedDataPoint!.averagePace))" : "No data point selected",
                traits: [.allowsDirectInteraction, .playsSound],
                actions: [
                    .playAudioGraph: {
                        playPaceAudioGraph()
                    },
                    .showDataTable: {
                        showingDataTable = true
                    },
                    .announceDetails: {
                        announcePaceSummary()
                    }
                ]
            )
            .chartRotorSupport(
                items: weeklyData.filter { $0.averagePace > 0 },
                label: { week in
                    "Week \(week.formattedWeekRange): \(formatPace(week.averagePace))"
                },
                onSelection: { week in
                    selectedDataPoint = week
                    accessibilityManager.announceChartSelection(
                        "Selected \(week.formattedWeekRange): pace \(formatPace(week.averagePace)), distance \(week.totalDistance / 1000.0, format: .number.precision(.fractionLength(1))) kilometers"
                    )
                }
            )
            
            // Legend and stats
            HStack(spacing: 16) {
                Label("Weekly Pace", systemImage: "speedometer")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.18, green: 0.31, blue: 0.18))
                
                if showingMovingAverage {
                    Label("3-Week Average", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                
                Spacer()
                
                if let bestPace = weeklyData.filter({ $0.averagePace > 0 }).min(by: { $0.averagePace < $1.averagePace }) {
                    Text("Best: \(formatPace(bestPace.averagePace))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(AccessibilityPreferences.shared.shouldUseHighContrast ? Color(.systemBackground) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: AccessibilityPreferences.shared.isReduceTransparencyEnabled ? 0 : 2, y: AccessibilityPreferences.shared.isReduceTransparencyEnabled ? 0 : 1)
        .sheet(isPresented: $showingDataTable) {
            ChartDataTableView(
                title: "Pace Trend Data",
                headers: ["Week", "Pace (min/km)", "Distance (km)", "Trend"],
                rows: weeklyData.filter { $0.averagePace > 0 }.map { week in
                    [
                        week.formattedWeekRange,
                        formatPace(week.averagePace),
                        String(format: "%.1f", week.totalDistance / 1000.0),
                        trendData?.direction.systemImage ?? "—"
                    ]
                }
            )
        }
    }
    
    // MARK: - Accessibility Methods
    
    private func playPaceAudioGraph() {
        let paces = weeklyData.filter { $0.averagePace > 0 }.map { $0.averagePace }
        // For pace, we invert the values since lower pace (faster) should sound higher
        let invertedPaces = paces.map { 1.0 / max($0, 0.1) }
        accessibilityManager.playAudioGraph(for: invertedPaces, metric: "pace trend")
    }
    
    private func announcePaceSummary() {
        let validPaces = weeklyData.filter { $0.averagePace > 0 }
        guard !validPaces.isEmpty else {
            accessibilityManager.announceMessage("No pace data available")
            return
        }
        
        let bestPace = validPaces.min { $0.averagePace < $1.averagePace }!
        let averagePace = validPaces.reduce(0) { $0 + $1.averagePace } / Double(validPaces.count)
        
        let summary = "Pace trend chart shows \(validPaces.count) weeks with pace data. Best pace: \(formatPace(bestPace.averagePace)). Average pace: \(formatPace(averagePace))."
        
        accessibilityManager.announceMessage(summary)
        
        if let trend = trendData {
            let trendMessage = "Overall trend: \(trend.direction == .improving ? "improving" : trend.direction == .declining ? "declining" : "stable") by \(trend.formattedPercentageChange)"
            accessibilityManager.announceMessage(trendMessage)
        }
    }
    
    private func selectDataPoint(at location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) {
        let plotFrame = proxy.plotAreaFrame
        guard let plotFrame = plotFrame else { return }
        
        let origin = geometry[plotFrame].origin
        let relativeXPosition = location.x - origin.x
        
        if let weekDate = proxy.value(atX: relativeXPosition, as: Date.self) {
            selectedDataPoint = weeklyData.min(by: { week1, week2 in
                abs(week1.weekStart.timeIntervalSince(weekDate)) < 
                abs(week2.weekStart.timeIntervalSince(weekDate))
            })
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "N/A" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d/km", minutes, seconds)
    }
}

// MARK: - Weight Moved Chart

/// Bar chart showing total weight × distance with load breakdown
struct WeightMovedChart: View {
    let weeklyData: [WeekData]
    @State private var selectedWeek: WeekData?
    @State private var showingLoadBreakdown: Bool = false
    @StateObject private var accessibilityManager = ChartAccessibilityManager()
    @State private var showingDataTable = false
    
    private var weightMovedData: [WeightMovedDataPoint] {
        weeklyData.map { week in
            let avgLoad = week.sessions.isEmpty ? 0 : 
                week.sessions.reduce(0) { $0 + $1.loadWeight } / Double(week.sessions.count)
            let weightMoved = avgLoad * (week.totalDistance / 1000.0)
            
            return WeightMovedDataPoint(
                week: week,
                weightMoved: weightMoved,
                averageLoad: avgLoad,
                totalDistance: week.totalDistance / 1000.0
            )
        }
    }
    
    struct WeightMovedDataPoint: Identifiable {
        let id = UUID()
        let week: WeekData
        let weightMoved: Double
        let averageLoad: Double
        let totalDistance: Double
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weight Moved")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Load × Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingLoadBreakdown.toggle() }) {
                    Label("Breakdown", systemImage: showingLoadBreakdown ? "chart.bar.fill" : "chart.bar")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            // Chart
            Chart {
                ForEach(weightMovedData) { dataPoint in
                    if showingLoadBreakdown {
                        // Stacked bars showing load categories
                        let lightLoad = min(dataPoint.averageLoad, 15.0) * dataPoint.totalDistance
                        let mediumLoad = min(max(dataPoint.averageLoad - 15.0, 0), 15.0) * dataPoint.totalDistance
                        let heavyLoad = max(dataPoint.averageLoad - 30.0, 0) * dataPoint.totalDistance
                        
                        if lightLoad > 0 {
                            BarMark(
                                x: .value("Week", dataPoint.week.weekStart, unit: .weekOfYear),
                                y: .value("Light Load", lightLoad),
                                stacking: .standard
                            )
                            .foregroundStyle(.green.opacity(0.7))
                        }
                        
                        if mediumLoad > 0 {
                            BarMark(
                                x: .value("Week", dataPoint.week.weekStart, unit: .weekOfYear),
                                y: .value("Medium Load", mediumLoad),
                                stacking: .standard
                            )
                            .foregroundStyle(.orange.opacity(0.7))
                        }
                        
                        if heavyLoad > 0 {
                            BarMark(
                                x: .value("Week", dataPoint.week.weekStart, unit: .weekOfYear),
                                y: .value("Heavy Load", heavyLoad),
                                stacking: .standard
                            )
                            .foregroundStyle(.red.opacity(0.7))
                        }
                    } else {
                        // Single bars showing total weight moved
                        BarMark(
                            x: .value("Week", dataPoint.week.weekStart, unit: .weekOfYear),
                            y: .value("Weight Moved", dataPoint.weightMoved)
                        )
                        .foregroundStyle(Color(red: 0.18, green: 0.31, blue: 0.18))
                        .cornerRadius(6)
                        .opacity(selectedWeek == nil || selectedWeek?.id == dataPoint.week.id ? 1.0 : 0.3)
                    }
                }
                
                // Selection indicator
                if let selectedWeek = selectedWeek,
                   let selectedData = weightMovedData.first(where: { $0.week.id == selectedWeek.id }) {
                    RuleMark(x: .value("Week", selectedWeek.weekStart, unit: .weekOfYear))
                        .foregroundStyle(.blue.opacity(0.5))
                        .annotation(position: .top, alignment: .center, spacing: 8) {
                            VStack(alignment: .center, spacing: 4) {
                                Text("\(selectedData.weightMoved, format: .number.precision(.fractionLength(1))) kg×km")
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                
                                Text("Avg Load: \(selectedData.averageLoad, format: .number.precision(.fractionLength(1)))kg")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Text("Distance: \(selectedData.totalDistance, format: .number.precision(.fractionLength(1)))km")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 2)
                        }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(preset: .automatic, values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let weight = value.as(Double.self) {
                            Text("\(weight, format: .number.precision(.fractionLength(0))) kg×km")
                                .font(.caption)
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
                            selectWeek(at: location, geometry: geometry, proxy: chartProxy)
                        }
                }
            }
            .animation(AccessibilityPreferences.shared.reduceMotion ? .none : .easeInOut(duration: 0.3), value: selectedWeek?.id)
            .animation(AccessibilityPreferences.shared.reduceMotion ? .none : .easeInOut(duration: 0.3), value: showingLoadBreakdown)
            .chartAccessibility(
                label: "Weight moved chart",
                hint: "Shows total weight moved each week. Double tap to select weeks, triple tap for audio graph.",
                value: selectedWeek != nil ? "Selected week: \(selectedWeek!.formattedWeekRange)" : "No week selected",
                traits: [.allowsDirectInteraction, .playsSound],
                actions: [
                    .playAudioGraph: {
                        playWeightMovedAudioGraph()
                    },
                    .showDataTable: {
                        showingDataTable = true
                    },
                    .announceDetails: {
                        announceWeightMovedSummary()
                    },
                    .toggleComparison: {
                        showingLoadBreakdown.toggle()
                        accessibilityManager.announceMessage(showingLoadBreakdown ? "Load breakdown enabled" : "Load breakdown disabled")
                    }
                ]
            )
            .chartRotorSupport(
                items: weightMovedData,
                label: { dataPoint in
                    "Week \(dataPoint.week.formattedWeekRange): \(dataPoint.weightMoved, format: .number.precision(.fractionLength(1))) kg×km"
                },
                onSelection: { dataPoint in
                    selectedWeek = dataPoint.week
                    accessibilityManager.announceChartSelection(
                        "Selected \(dataPoint.week.formattedWeekRange): \(dataPoint.weightMoved, format: .number.precision(.fractionLength(1))) kilograms times kilometers moved"
                    )
                }
            )
            
            // Legend
            if showingLoadBreakdown {
                HStack(spacing: 16) {
                    Label("Light (≤15kg)", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    Label("Medium (15-30kg)", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    
                    Label("Heavy (>30kg)", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.top, 4)
            } else {
                HStack {
                    Label("Total Weight Moved", systemImage: "scalemass")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.18, green: 0.31, blue: 0.18))
                    
                    Spacer()
                    
                    if let maxWeightMoved = weightMovedData.max(by: { $0.weightMoved < $1.weightMoved }) {
                        Text("Peak: \(maxWeightMoved.weightMoved, format: .number.precision(.fractionLength(1))) kg×km")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(AccessibilityPreferences.shared.shouldUseHighContrast ? Color(.systemBackground) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: AccessibilityPreferences.shared.isReduceTransparencyEnabled ? 0 : 2, y: AccessibilityPreferences.shared.isReduceTransparencyEnabled ? 0 : 1)
        .sheet(isPresented: $showingDataTable) {
            ChartDataTableView(
                title: "Weight Moved Data",
                headers: ["Week", "Weight Moved (kg×km)", "Avg Load (kg)", "Distance (km)"],
                rows: weightMovedData.map { dataPoint in
                    [
                        dataPoint.week.formattedWeekRange,
                        String(format: "%.1f", dataPoint.weightMoved),
                        String(format: "%.1f", dataPoint.averageLoad),
                        String(format: "%.1f", dataPoint.totalDistance)
                    ]
                }
            )
        }
    }
    
    // MARK: - Accessibility Methods
    
    private func playWeightMovedAudioGraph() {
        let weightMoved = weightMovedData.map { $0.weightMoved }
        accessibilityManager.playAudioGraph(for: weightMoved, metric: "weight moved")
    }
    
    private func announceWeightMovedSummary() {
        guard !weightMovedData.isEmpty else {
            accessibilityManager.announceMessage("No weight moved data available")
            return
        }
        
        let totalWeightMoved = weightMovedData.reduce(0) { $0 + $1.weightMoved }
        let averageWeightMoved = totalWeightMoved / Double(weightMovedData.count)
        let maxWeightMoved = weightMovedData.max { $0.weightMoved < $1.weightMoved }!
        
        let summary = "Weight moved chart shows \(weightMovedData.count) weeks of data. Total weight moved: \(totalWeightMoved, format: .number.precision(.fractionLength(1))) kilograms times kilometers. Average per week: \(averageWeightMoved, format: .number.precision(.fractionLength(1))). Peak week: \(maxWeightMoved.weightMoved, format: .number.precision(.fractionLength(1)))."
        
        accessibilityManager.announceMessage(summary)
    }
    
    private func selectWeek(at location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) {
        let plotFrame = proxy.plotAreaFrame
        guard let plotFrame = plotFrame else { return }
        
        let origin = geometry[plotFrame].origin  
        let relativeXPosition = location.x - origin.x
        
        if let weekDate = proxy.value(atX: relativeXPosition, as: Date.self) {
            selectedWeek = weeklyData.min(by: { week1, week2 in
                abs(week1.weekStart.timeIntervalSince(weekDate)) < 
                abs(week2.weekStart.timeIntervalSince(weekDate))
            })
        }
    }
}