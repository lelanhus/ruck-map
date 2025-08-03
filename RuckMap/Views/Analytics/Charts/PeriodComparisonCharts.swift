import SwiftUI
import Charts
import Foundation

// MARK: - Period Comparison Chart

/// Shows current vs previous period side-by-side comparisons
struct PeriodComparisonChart: View {
    let currentPeriodData: AnalyticsData
    let previousPeriodData: AnalyticsData?
    @State private var selectedMetric: ComparisonMetric = .distance
    @State private var showingPercentageChange: Bool = true
    
    enum ComparisonMetric: String, CaseIterable {
        case distance = "Distance"
        case sessions = "Sessions" 
        case calories = "Calories"
        case pace = "Pace"
        case weightMoved = "Weight Moved"
        
        var unit: String {
            switch self {
            case .distance: return "km"
            case .sessions: return "sessions"
            case .calories: return "cal"
            case .pace: return "min/km"
            case .weightMoved: return "kg×km"
            }
        }
        
        var icon: String {
            switch self {
            case .distance: return "map"
            case .sessions: return "figure.run"
            case .calories: return "flame"
            case .pace: return "speedometer"
            case .weightMoved: return "scalemass"
            }
        }
        
        var color: Color {
            switch self {
            case .distance: return Color(red: 0.18, green: 0.31, blue: 0.18)
            case .sessions: return .blue
            case .calories: return .red
            case .pace: return .orange
            case .weightMoved: return .purple
            }
        }
    }
    
    private var comparisonData: [PeriodComparisonData] {
        guard let previousData = previousPeriodData else {
            return [
                PeriodComparisonData(
                    metric: selectedMetric,
                    currentValue: getValue(for: selectedMetric, from: currentPeriodData),
                    previousValue: 0,
                    period: "Current"
                )
            ]
        }
        
        return [
            PeriodComparisonData(
                metric: selectedMetric,
                currentValue: getValue(for: selectedMetric, from: previousData),
                previousValue: 0,
                period: "Previous"
            ),
            PeriodComparisonData(
                metric: selectedMetric,
                currentValue: getValue(for: selectedMetric, from: currentPeriodData),
                previousValue: getValue(for: selectedMetric, from: previousData),
                period: "Current"
            )
        ]
    }
    
    struct PeriodComparisonData: Identifiable {
        let id = UUID()
        let metric: ComparisonMetric
        let currentValue: Double
        let previousValue: Double
        let period: String
        
        var percentageChange: Double {
            guard previousValue > 0 else { return currentValue > 0 ? 100 : 0 }
            
            if metric == .pace {
                // For pace, lower is better
                return ((previousValue - currentValue) / previousValue) * 100
            } else {
                return ((currentValue - previousValue) / previousValue) * 100
            }
        }
        
        var isImprovement: Bool {
            if metric == .pace {
                return currentValue < previousValue && previousValue > 0
            } else {
                return currentValue > previousValue
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with metric selector
            HStack {
                Text("Period Comparison")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { showingPercentageChange.toggle() }) {
                        Label("Change %", systemImage: showingPercentageChange ? "percent" : "equal")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    
                    Menu {
                        ForEach(ComparisonMetric.allCases, id: \.self) { metric in
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
            }
            
            // Main comparison chart
            Chart {
                ForEach(comparisonData) { data in
                    BarMark(
                        x: .value("Period", data.period),
                        y: .value("Value", data.currentValue)
                    )
                    .foregroundStyle(selectedMetric.color.gradient)
                    .cornerRadius(8)
                    .annotation(position: .top, alignment: .center) {
                        Text(formatValue(data.currentValue, for: selectedMetric))
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                }
            }
            .frame(height: 150)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(formatValue(val, for: selectedMetric, compact: true))
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: selectedMetric != .pace))
            .animation(.easeInOut(duration: 0.3), value: selectedMetric)
            
            // Detailed comparison section
            if let previousData = previousPeriodData {
                detailedComparisonView(previousData)
            } else {
                noPreviousDataView
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2, y: 1)
    }
    
    // MARK: - Detailed Comparison View
    
    private func detailedComparisonView(_ previousData: AnalyticsData) -> some View {
        VStack(spacing: 12) {
            Divider()
            
            // All metrics comparison grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ComparisonMetric.allCases, id: \.self) { metric in
                    MetricComparisonCard(
                        metric: metric,
                        currentValue: getValue(for: metric, from: currentPeriodData),
                        previousValue: getValue(for: metric, from: previousData),
                        isSelected: selectedMetric == metric,
                        showingPercentageChange: showingPercentageChange
                    )
                    .onTapGesture {
                        selectedMetric = metric
                    }
                }
            }
            
            // Period information
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Previous Period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDateRange(previousData.dateRange))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Current Period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDateRange(currentPeriodData.dateRange))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 4)
        }
    }
    
    private var noPreviousDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            
            Text("No previous period data available")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Complete more sessions to enable period comparisons")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
    }
    
    // MARK: - Helper Methods
    
    private func getValue(for metric: ComparisonMetric, from data: AnalyticsData) -> Double {
        switch metric {
        case .distance:
            return data.totalDistance / 1000.0 // Convert to km
        case .sessions:
            return Double(data.totalSessions)
        case .calories:
            return data.totalCalories
        case .pace:
            return data.averagePace
        case .weightMoved:
            return data.totalWeightMoved
        }
    }
    
    private func formatValue(_ value: Double, for metric: ComparisonMetric, compact: Bool = false) -> String {
        switch metric {
        case .distance:
            return compact ? String(format: "%.0fkm", value) : String(format: "%.1f km", value)
        case .sessions:
            return String(format: "%.0f", value)
        case .calories:
            return compact ? String(format: "%.0f", value) : String(format: "%.0f cal", value)
        case .pace:
            let minutes = Int(value)
            let seconds = Int((value - Double(minutes)) * 60)
            return String(format: "%d:%02d", minutes, seconds) + (compact ? "" : "/km")
        case .weightMoved:
            return compact ? String(format: "%.0f", value) : String(format: "%.1f kg×km", value)
        }
    }
    
    private func formatDateRange(_ range: (start: Date, end: Date)) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
    }
}

// MARK: - Metric Comparison Card

struct MetricComparisonCard: View {
    let metric: PeriodComparisonChart.ComparisonMetric
    let currentValue: Double
    let previousValue: Double
    let isSelected: Bool
    let showingPercentageChange: Bool
    
    private var percentageChange: Double {
        guard previousValue > 0 else { return currentValue > 0 ? 100 : 0 }
        
        if metric == .pace {
            return ((previousValue - currentValue) / previousValue) * 100
        } else {
            return ((currentValue - previousValue) / previousValue) * 100
        }
    }
    
    private var isImprovement: Bool {
        if metric == .pace {
            return currentValue < previousValue && previousValue > 0
        } else {
            return currentValue > previousValue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: metric.icon)
                    .font(.caption)
                    .foregroundStyle(metric.color)
                
                Text(metric.rawValue)
                    .font(.caption)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if showingPercentageChange && previousValue > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: isImprovement ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        Text("\(abs(percentageChange), format: .number.precision(.fractionLength(0)))%")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(isImprovement ? .green : .red)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(formatValue(currentValue, for: metric))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                
                if previousValue > 0 {
                    Text("was \(formatValue(previousValue, for: metric))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(isSelected ? metric.color.opacity(0.1) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? metric.color : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private func formatValue(_ value: Double, for metric: PeriodComparisonChart.ComparisonMetric) -> String {
        switch metric {
        case .distance:
            return String(format: "%.1f km", value)
        case .sessions:
            return String(format: "%.0f", value)
        case .calories:
            return String(format: "%.0f cal", value)
        case .pace:
            let minutes = Int(value)
            let seconds = Int((value - Double(minutes)) * 60)
            return String(format: "%d:%02d/km", minutes, seconds)
        case .weightMoved:
            return String(format: "%.1f kg×km", value)
        }
    }
}

// MARK: - Weekly Comparison Chart

/// Shows week-over-week progress with trend analysis
struct WeeklyComparisonChart: View {
    let weeklyData: [WeekData]
    @State private var selectedWeeks: Set<UUID> = []
    @State private var comparisonMode: ComparisonMode = .consecutive
    
    enum ComparisonMode: String, CaseIterable {
        case consecutive = "Week-to-Week"
        case monthOverMonth = "Month-to-Month"
        case yearOverYear = "Year-to-Year"
        
        var icon: String {
            switch self {
            case .consecutive: return "arrow.left.arrow.right"
            case .monthOverMonth: return "calendar.circle"
            case .yearOverYear: return "calendar.badge.clock"
            }
        }
    }
    
    private var comparisonPairs: [WeekComparisonPair] {
        switch comparisonMode {
        case .consecutive:
            return generateConsecutiveComparisons()
        case .monthOverMonth:
            return generateMonthOverMonthComparisons()
        case .yearOverYear:
            return generateYearOverYearComparisons()
        }
    }
    
    struct WeekComparisonPair: Identifiable {
        let id = UUID()
        let currentWeek: WeekData
        let comparisonWeek: WeekData
        let changePercent: Double
        let isImprovement: Bool
        
        init(current: WeekData, comparison: WeekData) {
            self.currentWeek = current
            self.comparisonWeek = comparison
            
            let currentDistance = current.totalDistance
            let comparisonDistance = comparison.totalDistance
            
            if comparisonDistance > 0 {
                self.changePercent = ((currentDistance - comparisonDistance) / comparisonDistance) * 100
            } else {
                self.changePercent = currentDistance > 0 ? 100 : 0
            }
            
            self.isImprovement = currentDistance > comparisonDistance
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with comparison mode selector
            HStack {
                Text("Weekly Comparisons")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Menu {
                    ForEach(ComparisonMode.allCases, id: \.self) { mode in
                        Button(action: { comparisonMode = mode }) {
                            Label(mode.rawValue, systemImage: mode.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: comparisonMode.icon)
                        Text(comparisonMode.rawValue)
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
            
            // Comparison chart
            if !comparisonPairs.isEmpty {
                Chart {
                    ForEach(comparisonPairs.prefix(8)) { pair in
                        // Current week bar
                        BarMark(
                            x: .value("Week", pair.currentWeek.formattedWeekRange),
                            y: .value("Current", pair.currentWeek.totalDistance / 1000.0)
                        )
                        .foregroundStyle(Color(red: 0.18, green: 0.31, blue: 0.18))
                        .opacity(selectedWeeks.contains(pair.id) ? 1.0 : 0.8)
                        
                        // Comparison week bar (faded)
                        BarMark(
                            x: .value("Week", pair.currentWeek.formattedWeekRange),
                            y: .value("Comparison", pair.comparisonWeek.totalDistance / 1000.0)
                        )
                        .foregroundStyle(Color(red: 0.18, green: 0.31, blue: 0.18).opacity(0.3))
                        .opacity(selectedWeeks.contains(pair.id) ? 1.0 : 0.5)
                        
                        // Change indicator
                        if abs(pair.changePercent) > 5 { // Only show significant changes
                            PointMark(
                                x: .value("Week", pair.currentWeek.formattedWeekRange),
                                y: .value("Change", max(pair.currentWeek.totalDistance, pair.comparisonWeek.totalDistance) / 1000.0 + 2)
                            )
                            .foregroundStyle(pair.isImprovement ? .green : .red)
                            .symbol(pair.isImprovement ? .triangleUp : .triangleDown)
                            .symbolSize(60)
                        }
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let week = value.as(String.self) {
                                Text(week)
                                    .font(.caption2)
                                    .rotationEffect(.degrees(-45))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
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
                .animation(.easeInOut(duration: 0.3), value: comparisonMode)
                
                // Statistics summary
                let improvements = comparisonPairs.filter { $0.isImprovement }.count
                let totalComparisons = comparisonPairs.count
                let improvementRate = totalComparisons > 0 ? Double(improvements) / Double(totalComparisons) * 100 : 0
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Improvement Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("\(improvementRate, format: .number.precision(.fractionLength(0)))%")
                            .font(.subheadline.bold())
                            .foregroundStyle(improvementRate >= 60 ? .green : 
                                           improvementRate >= 40 ? .orange : .red)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Comparisons")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("\(improvements)/\(totalComparisons)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.top, 8)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    
                    Text("Not enough data for \(comparisonMode.rawValue.lowercased())")
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
    
    // MARK: - Comparison Generation Methods
    
    private func generateConsecutiveComparisons() -> [WeekComparisonPair] {
        let sortedWeeks = weeklyData.sorted { $0.weekStart < $1.weekStart }
        var pairs: [WeekComparisonPair] = []
        
        for i in 1..<sortedWeeks.count {
            let pair = WeekComparisonPair(
                current: sortedWeeks[i],
                comparison: sortedWeeks[i-1]
            )
            pairs.append(pair)
        }
        
        return pairs
    }
    
    private func generateMonthOverMonthComparisons() -> [WeekComparisonPair] {
        let calendar = Calendar.current
        var pairs: [WeekComparisonPair] = []
        
        for week in weeklyData {
            if let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: week.weekStart),
               let comparisonWeek = weeklyData.first(where: { 
                   calendar.isDate($0.weekStart, equalTo: previousMonthDate, toGranularity: .weekOfYear) 
               }) {
                let pair = WeekComparisonPair(current: week, comparison: comparisonWeek)
                pairs.append(pair)
            }
        }
        
        return pairs
    }
    
    private func generateYearOverYearComparisons() -> [WeekComparisonPair] {
        let calendar = Calendar.current
        var pairs: [WeekComparisonPair] = []
        
        for week in weeklyData {
            if let previousYearDate = calendar.date(byAdding: .year, value: -1, to: week.weekStart),
               let comparisonWeek = weeklyData.first(where: { 
                   calendar.isDate($0.weekStart, equalTo: previousYearDate, toGranularity: .weekOfYear) 
               }) {
                let pair = WeekComparisonPair(current: week, comparison: comparisonWeek)
                pairs.append(pair)
            }
        }
        
        return pairs
    }
}