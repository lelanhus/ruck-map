import SwiftUI
import Charts
import Foundation

// MARK: - Personal Records Display

/// Visual indicators for PRs with comparison to averages
struct PersonalRecordsChart: View {
    let personalRecords: PersonalRecords
    let currentAnalytics: AnalyticsData
    @State private var selectedRecord: PersonalRecordType?
    @State private var showingComparison: Bool = true
    @StateObject private var accessibilityManager = ChartAccessibilityManager()
    @State private var showingDataTable = false
    
    private var recordData: [PersonalRecordData] {
        var data: [PersonalRecordData] = []
        
        if let longestDistance = personalRecords.longestDistance {
            data.append(PersonalRecordData(
                type: .distance,
                record: longestDistance.value / 1000.0, // Convert to km
                average: currentAnalytics.averageDistance / 1000.0,
                unit: "km",
                icon: "map",
                color: Color(red: 0.18, green: 0.31, blue: 0.18)
            ))
        }
        
        if let fastestPace = personalRecords.fastestPace {
            data.append(PersonalRecordData(
                type: .pace,
                record: fastestPace.value,
                average: currentAnalytics.averagePace,
                unit: "min/km",
                icon: "speedometer",
                color: .blue,
                isLowerBetter: true
            ))
        }
        
        if let heaviestLoad = personalRecords.heaviestLoad {
            data.append(PersonalRecordData(
                type: .load,
                record: heaviestLoad.value,
                average: currentAnalytics.averageLoadWeight,
                unit: "kg",
                icon: "scalemass",
                color: .orange
            ))
        }
        
        if let highestCalorieBurn = personalRecords.highestCalorieBurn {
            data.append(PersonalRecordData(
                type: .calories,
                record: highestCalorieBurn.value,
                average: currentAnalytics.averageCalories,
                unit: "cal",
                icon: "flame",
                color: .red
            ))
        }
        
        if let longestDuration = personalRecords.longestDuration {
            data.append(PersonalRecordData(
                type: .duration,
                record: longestDuration.value / 3600.0, // Convert to hours
                average: currentAnalytics.averageDuration / 3600.0,
                unit: "hrs",
                icon: "clock",
                color: .purple
            ))
        }
        
        if let mostWeightMoved = personalRecords.mostWeightMoved {
            data.append(PersonalRecordData(
                type: .weightMoved,
                record: mostWeightMoved.value,
                average: currentAnalytics.totalWeightMoved / Double(max(currentAnalytics.totalSessions, 1)),
                unit: "kg×km",
                icon: "arrow.up.and.down",
                color: .teal
            ))
        }
        
        return data.filter { $0.record > 0 } // Only show records that exist
    }
    
    struct PersonalRecordData: Identifiable {
        let id = UUID()
        let type: PersonalRecordType
        let record: Double
        let average: Double
        let unit: String
        let icon: String
        let color: Color
        let isLowerBetter: Bool
        
        init(type: PersonalRecordType, record: Double, average: Double, unit: String, icon: String, color: Color, isLowerBetter: Bool = false) {
            self.type = type
            self.record = record
            self.average = average
            self.unit = unit
            self.icon = icon
            self.color = color
            self.isLowerBetter = isLowerBetter
        }
        
        var improvementRatio: Double {
            guard average > 0 else { return 1.0 }
            
            if isLowerBetter {
                return average / record // For pace, lower is better
            } else {
                return record / average // For distance, calories, etc., higher is better
            }
        }
        
        var formattedRecord: String {
            switch type {
            case .pace:
                let minutes = Int(record)
                let seconds = Int((record - Double(minutes)) * 60)
                return String(format: "%d:%02d", minutes, seconds)
            case .duration:
                let hours = Int(record)
                let minutes = Int((record - Double(hours)) * 60)
                return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            default:
                return String(format: "%.1f", record)
            }
        }
        
        var formattedAverage: String {
            switch type {
            case .pace:
                let minutes = Int(average)
                let seconds = Int((average - Double(minutes)) * 60)
                return String(format: "%d:%02d", minutes, seconds)
            case .duration:
                let hours = Int(average)
                let minutes = Int((average - Double(hours)) * 60)
                return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            default:
                return String(format: "%.1f", average)
            }
        }
    }
    
    enum PersonalRecordType {
        case distance, pace, load, calories, duration, weightMoved
        
        var displayName: String {
            switch self {
            case .distance: return "Distance"
            case .pace: return "Pace"
            case .load: return "Load"
            case .calories: return "Calories"
            case .duration: return "Duration"
            case .weightMoved: return "Weight Moved"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Personal Records")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showingComparison.toggle() }) {
                    Label("vs Average", systemImage: showingComparison ? "chart.bar.xaxis" : "chart.bar")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            // Chart
            Chart {
                ForEach(recordData) { data in
                    // Personal record bars
                    BarMark(
                        x: .value("Record", normalizeValue(data.record, for: data.type)),
                        y: .value("Metric", data.type.displayName)
                    )
                    .foregroundStyle(data.color.gradient)
                    .cornerRadius(4)
                    .opacity(selectedRecord == nil || selectedRecord == data.type ? 1.0 : 0.3)
                    
                    // Average comparison (if enabled)
                    if showingComparison {
                        BarMark(
                            x: .value("Average", normalizeValue(data.average, for: data.type)),
                            y: .value("Metric", data.type.displayName)
                        )
                        .foregroundStyle(data.color.opacity(0.3))
                        .cornerRadius(4)
                        .opacity(selectedRecord == nil || selectedRecord == data.type ? 1.0 : 0.3)
                    }
                }
                
                // Selection indicator
                if let selectedType = selectedRecord,
                   let selectedData = recordData.first(where: { $0.type == selectedType }) {
                    RuleMark(y: .value("Metric", selectedData.type.displayName))
                        .foregroundStyle(.blue.opacity(0.5))
                        .annotation(position: .trailing, alignment: .leading) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Personal Record")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("\(selectedData.formattedRecord) \(selectedData.unit)")
                                        .font(.caption.bold())
                                        .foregroundStyle(selectedData.color)
                                }
                                
                                if showingComparison {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Average")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        
                                        Text("\(selectedData.formattedAverage) \(selectedData.unit)")
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("vs Average")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: selectedData.improvementRatio >= 1.2 ? "arrow.up.circle.fill" : 
                                                         selectedData.improvementRatio >= 1.0 ? "arrow.up.circle" : 
                                                         "minus.circle")
                                            .font(.caption2)
                                            .foregroundStyle(selectedData.improvementRatio >= 1.2 ? .green : 
                                                           selectedData.improvementRatio >= 1.0 ? .orange : .gray)
                                        
                                        Text("\(selectedData.improvementRatio, format: .number.precision(.fractionLength(1)))×")
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 2)
                        }
                }
            }
            .frame(height: CGFloat(recordData.count * 40))
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let metric = value.as(String.self),
                           let data = recordData.first(where: { $0.type.displayName == metric }) {
                            HStack(spacing: 6) {
                                Image(systemName: data.icon)
                                    .font(.caption)
                                    .foregroundStyle(data.color)
                                
                                Text(metric)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
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
                            selectRecord(at: location, geometry: geometry, proxy: chartProxy)
                        }
                }
            }
            .animation(AccessibilityPreferences.shared.reduceMotion ? .none : .easeInOut(duration: 0.3), value: selectedRecord)
            .animation(AccessibilityPreferences.shared.reduceMotion ? .none : .easeInOut(duration: 0.3), value: showingComparison)
            .chartAccessibility(
                label: "Personal records chart",
                hint: "Shows personal records compared to averages. Double tap to select records, triple tap for audio graph.",
                value: selectedRecord.map { "Selected: \($0.displayName)" } ?? "No record selected",
                traits: [.allowsDirectInteraction, .playsSound],
                actions: [
                    .playAudioGraph: {
                        playPersonalRecordsAudioGraph()
                    },
                    .showDataTable: {
                        showingDataTable = true
                    },
                    .announceDetails: {
                        announcePersonalRecordsSummary()
                    },
                    .toggleComparison: {
                        showingComparison.toggle()
                        accessibilityManager.announceMessage(showingComparison ? "Comparison view enabled" : "Comparison view disabled")
                    }
                ]
            )
            .chartRotorSupport(
                items: recordData,
                label: { data in
                    "\(data.type.displayName): \(data.formattedRecord) \(data.unit)"
                },
                onSelection: { data in
                    selectedRecord = data.type
                    let improvementText = data.improvementRatio >= 1.2 ? "significantly better than average" : 
                                         data.improvementRatio >= 1.0 ? "better than average" : "below average"
                    accessibilityManager.announceChartSelection(
                        "Selected \(data.type.displayName): \(data.formattedRecord) \(data.unit), \(improvementText)"
                    )
                }
            )
            
            // Legend and stats
            HStack(spacing: 16) {
                if showingComparison {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(.primary)
                            .frame(width: 12, height: 4)
                            .clipShape(Capsule())
                        Text("PR")
                            .font(.caption)
                    }
                    
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(.primary.opacity(0.3))
                            .frame(width: 12, height: 4)
                            .clipShape(Capsule())
                        Text("Average")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                Text("\(recordData.count) records")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(AccessibilityPreferences.shared.shouldUseHighContrast ? Color(.systemBackground) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: AccessibilityPreferences.shared.isReduceTransparencyEnabled ? 0 : 2, y: AccessibilityPreferences.shared.isReduceTransparencyEnabled ? 0 : 1)
        .sheet(isPresented: $showingDataTable) {
            ChartDataTableView(
                title: "Personal Records Data",
                headers: ["Metric", "Personal Record", "Average", "Improvement Ratio"],
                rows: recordData.map { data in
                    [
                        data.type.displayName,
                        "\(data.formattedRecord) \(data.unit)",
                        "\(data.formattedAverage) \(data.unit)",
                        String(format: "%.1fx", data.improvementRatio)
                    ]
                }
            )
        }
    }
    
    // MARK: - Accessibility Methods
    
    private func playPersonalRecordsAudioGraph() {
        let values = recordData.map { normalizeValue($0.record, for: $0.type) }
        accessibilityManager.playAudioGraph(for: values, metric: "personal records")
    }
    
    private func announcePersonalRecordsSummary() {
        let validRecords = recordData.filter { $0.record > 0 }
        guard !validRecords.isEmpty else {
            accessibilityManager.announceMessage("No personal records available")
            return
        }
        
        let summary = "Personal records chart shows \(validRecords.count) record categories. "
        
        let summaryText: String
        if let bestImprovement = validRecords.max(by: { $0.improvementRatio < $1.improvementRatio }) {
            summaryText = summary + "Best performance: \(bestImprovement.type.displayName) at \(bestImprovement.improvementRatio, format: .number.precision(.fractionLength(1))) times average."
        } else {
            summaryText = summary + "No records available for comparison."
        }
        
        accessibilityManager.announceMessage(summaryText)
        
        // Announce any exceptional records
        let exceptionalRecords = validRecords.filter { $0.improvementRatio >= 2.0 }
        if !exceptionalRecords.isEmpty {
            for record in exceptionalRecords {
                accessibilityManager.announcePersonalRecord("\(record.type.displayName): \(record.formattedRecord) \(record.unit)")
            }
        }
    }
    
    private func normalizeValue(_ value: Double, for type: PersonalRecordType) -> Double {
        // Normalize values to 0-100 scale for consistent bar chart display
        let maxValues: [PersonalRecordType: Double] = [
            .distance: 50.0, // 50km max
            .pace: 12.0,     // 12 min/km max (slow pace)
            .load: 50.0,     // 50kg max
            .calories: 2000.0, // 2000 cal max
            .duration: 8.0,   // 8 hours max
            .weightMoved: 1000.0 // 1000 kg×km max
        ]
        
        let maxValue = maxValues[type] ?? 100.0
        return min(value / maxValue * 100.0, 100.0)
    }
    
    private func selectRecord(at location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) {
        let plotFrame = proxy.plotAreaFrame
        guard let plotFrame = plotFrame else { return }
        
        let origin = geometry[plotFrame].origin
        let relativeYPosition = location.y - origin.y
        
        if let metricName = proxy.value(atY: relativeYPosition, as: String.self) {
            selectedRecord = recordData.first { $0.type.displayName == metricName }?.type
        }
    }
}

// MARK: - PR Progress Over Time Chart

/// Shows how personal records have evolved over time
struct PersonalRecordsProgressChart: View {
    let sessions: [RuckSession]
    @State private var selectedMetric: PRMetric = .distance
    @State private var selectedSession: RuckSession?
    
    enum PRMetric: String, CaseIterable {
        case distance = "Distance"
        case pace = "Pace"
        case load = "Load"
        case calories = "Calories"
        
        var unit: String {
            switch self {
            case .distance: return "km"
            case .pace: return "min/km"
            case .load: return "kg"
            case .calories: return "cal"
            }
        }
        
        var icon: String {
            switch self {
            case .distance: return "map"
            case .pace: return "speedometer"
            case .load: return "scalemass"
            case .calories: return "flame"
            }
        }
        
        var color: Color {
            switch self {
            case .distance: return Color(red: 0.18, green: 0.31, blue: 0.18)
            case .pace: return .blue
            case .load: return .orange
            case .calories: return .red
            }
        }
    }
    
    private var progressData: [PRProgressPoint] {
        let sortedSessions = sessions.sorted { $0.startDate < $1.startDate }
        var progressPoints: [PRProgressPoint] = []
        var currentRecords: [PRMetric: Double] = [:]
        
        for session in sortedSessions {
            var wasRecordBroken = false
            
            // Check each metric for new records
            let metrics: [(PRMetric, Double)] = [
                (.distance, session.totalDistance / 1000.0),
                (.pace, session.averagePace),
                (.load, session.loadWeight),
                (.calories, session.totalCalories)
            ]
            
            for (metric, value) in metrics {
                guard value > 0 else { continue }
                
                let isNewRecord: Bool
                if metric == .pace {
                    // For pace, lower is better
                    isNewRecord = currentRecords[metric] == nil || value < currentRecords[metric]!
                } else {
                    // For other metrics, higher is better
                    isNewRecord = currentRecords[metric] == nil || value > currentRecords[metric]!
                }
                
                if isNewRecord {
                    currentRecords[metric] = value
                    wasRecordBroken = true
                }
            }
            
            // Only add points where records were set
            if wasRecordBroken {
                for metric in PRMetric.allCases {
                    if let recordValue = currentRecords[metric] {
                        progressPoints.append(PRProgressPoint(
                            session: session,
                            metric: metric,
                            value: recordValue,
                            isNewRecord: true
                        ))
                    }
                }
            }
        }
        
        return progressPoints.filter { $0.metric == selectedMetric }
    }
    
    struct PRProgressPoint: Identifiable {
        let id = UUID()
        let session: RuckSession
        let metric: PRMetric
        let value: Double
        let isNewRecord: Bool
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with metric selector
            HStack {
                Text("Record Progression")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Menu {
                    ForEach(PRMetric.allCases, id: \.self) { metric in
                        Button(action: { selectedMetric = metric }) {
                            Label(metric.rawValue, systemImage: metric.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedMetric.icon)
                        Text(selectedMetric.rawValue)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            // Chart
            if !progressData.isEmpty {
                Chart {
                    ForEach(progressData) { point in
                        // Record progression line
                        LineMark(
                            x: .value("Date", point.session.startDate),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(selectedMetric.color)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .interpolationMethod(.stepAfter)
                        
                        // Record points
                        PointMark(
                            x: .value("Date", point.session.startDate),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(selectedMetric.color)
                        .symbol(.circle)
                        .symbolSize(point.session.id == selectedSession?.id ? 150 : 80)
                        
                        // Record markers
                        if point.isNewRecord {
                            PointMark(
                                x: .value("Date", point.session.startDate),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(.yellow)
                            .symbol(.star)
                            .symbolSize(60)
                        }
                    }
                    
                    // Selection indicator
                    if let selectedSession = selectedSession,
                       let selectedPoint = progressData.first(where: { $0.session.id == selectedSession.id }) {
                        RuleMark(x: .value("Date", selectedSession.startDate))
                            .foregroundStyle(.blue.opacity(0.5))
                            .annotation(position: .top, alignment: .center, spacing: 8) {
                                VStack(alignment: .center, spacing: 4) {
                                    Text(formatValue(selectedPoint.value, for: selectedMetric))
                                        .font(.caption.bold())
                                        .foregroundStyle(selectedMetric.color)
                                    
                                    Text("New Record!")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                    
                                    Text(selectedSession.startDate, format: .dateTime.month().day().year())
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
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated))
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
                            if let val = value.as(Double.self) {
                                Text(formatValue(val, for: selectedMetric))
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: selectedMetric != .pace))
                .chartBackground { chartProxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                selectSession(at: location, geometry: geometry, proxy: chartProxy)
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: selectedMetric)
                .animation(.easeInOut(duration: 0.3), value: selectedSession?.id)
                
                // Stats
                HStack {
                    if let firstRecord = progressData.first, let latestRecord = progressData.last {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("First Record")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(formatValue(firstRecord.value, for: selectedMetric))
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Current Record")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(formatValue(latestRecord.value, for: selectedMetric))
                                .font(.caption.bold())
                                .foregroundStyle(selectedMetric.color)
                        }
                    }
                }
                .padding(.top, 8)
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: selectedMetric.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No records yet for \(selectedMetric.rawValue.lowercased())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2, y: 1)
    }
    
    private func selectSession(at location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) {
        let plotFrame = proxy.plotAreaFrame
        guard let plotFrame = plotFrame else { return }
        
        let origin = geometry[plotFrame].origin
        let relativeXPosition = location.x - origin.x
        
        if let date = proxy.value(atX: relativeXPosition, as: Date.self) {
            selectedSession = progressData.min(by: { point1, point2 in
                abs(point1.session.startDate.timeIntervalSince(date)) < 
                abs(point2.session.startDate.timeIntervalSince(date))
            })?.session
        }
    }
    
    private func formatValue(_ value: Double, for metric: PRMetric) -> String {
        switch metric {
        case .distance:
            return String(format: "%.1f km", value)
        case .pace:
            let minutes = Int(value)
            let seconds = Int((value - Double(minutes)) * 60)
            return String(format: "%d:%02d/km", minutes, seconds)
        case .load:
            return String(format: "%.1f kg", value)
        case .calories:
            return String(format: "%.0f cal", value)
        }
    }
}