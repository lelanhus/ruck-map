import SwiftUI
import Charts
import Foundation

// MARK: - Training Streak Visualization

/// Calendar-style or progress chart for training consistency
struct TrainingStreakChart: View {
    let weeklyData: [WeekData]
    let currentStreak: Int
    @State private var viewMode: ViewMode = .calendar
    @State private var selectedWeek: WeekData?
    @StateObject private var accessibilityManager = ChartAccessibilityManager()
    @State private var showingDataTable = false
    
    enum ViewMode: String, CaseIterable {
        case calendar = "Calendar"
        case progress = "Progress"
        case timeline = "Timeline"
        
        var icon: String {
            switch self {
            case .calendar: return "calendar"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .timeline: return "timeline.selection"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with view mode selector
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Training Streak")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        Image(systemName: currentStreak > 0 ? "flame.fill" : "flame")
                            .foregroundStyle(currentStreak > 0 ? .orange : .gray)
                        
                        Text(currentStreak > 0 ? "\(currentStreak) weeks" : "No current streak")
                            .font(.caption)
                            .foregroundStyle(currentStreak > 0 ? .orange : .secondary)
                    }
                }
                
                Spacer()
                
                Menu {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Button(action: { viewMode = mode }) {
                            Label(mode.rawValue, systemImage: mode.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewMode.icon)
                        Text(viewMode.rawValue)
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
            
            // Chart content based on view mode
            Group {
                switch viewMode {
                case .calendar:
                    calendarView
                case .progress:
                    progressView
                case .timeline:
                    timelineView
                }
            }
            .animation(AccessibilityPreferences.shared.reduceMotion ? .none : .easeInOut(duration: 0.3), value: viewMode)
            .chartAccessibility(
                label: "Training streak chart",
                hint: "Shows training consistency and streaks. Use rotor to navigate through weeks.",
                value: "Current streak: \(currentStreak) weeks",
                traits: [.allowsDirectInteraction],
                actions: [
                    .announceDetails: {
                        announceStreakSummary()
                    },
                    .showDataTable: {
                        showingDataTable = true
                    }
                ]
            )
            .chartRotorSupport(
                items: weeklyData,
                label: { week in
                    "Week \(week.formattedWeekRange): \(week.sessionCount) sessions, \(week.meetsTrainingGoal ? "goal met" : "goal missed")"
                },
                onSelection: { week in
                    selectedWeek = week
                    accessibilityManager.announceChartSelection(
                        "Selected \(week.formattedWeekRange): \(week.sessionCount) sessions, training goal \(week.meetsTrainingGoal ? "achieved" : "not met")"
                    )
                }
            )
            
            // Legend and stats
            legendView
        }
        .padding()
        .background(AccessibilityPreferences.shared.shouldUseHighContrast ? Color(.systemBackground) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: AccessibilityPreferences.shared.isReduceTransparencyEnabled ? 0 : 2, y: AccessibilityPreferences.shared.isReduceTransparencyEnabled ? 0 : 1)
        .sheet(isPresented: $showingDataTable) {
            ChartDataTableView(
                title: "Training Streak Data",
                headers: ["Week", "Sessions", "Distance (km)", "Goal Status"],
                rows: weeklyData.map { week in
                    [
                        week.formattedWeekRange,
                        "\(week.sessionCount)",
                        String(format: "%.1f", week.totalDistance / 1000.0),
                        week.meetsTrainingGoal ? "Met" : "Not Met"
                    ]
                }
            )
        }
    }
    
    // MARK: - Accessibility Methods
    
    private func announceStreakSummary() {
        let totalWeeks = weeklyData.count
        let successfulWeeks = weeklyData.filter { $0.meetsTrainingGoal }.count
        let longestStreak = calculateLongestStreak()
        let consistencyRate = Double(successfulWeeks) / Double(max(totalWeeks, 1)) * 100
        
        var summary = "Training streak summary: Current streak is \(currentStreak) weeks. "
        summary += "Longest streak: \(longestStreak) weeks. "
        summary += "Consistency rate: \(consistencyRate, format: .number.precision(.fractionLength(0))) percent. "
        summary += "\(successfulWeeks) of \(totalWeeks) weeks met training goals."
        
        accessibilityManager.announceMessage(summary)
        
        if currentStreak > 0 {
            accessibilityManager.announceStreakAchievement(currentStreak)
        }
    }
    
    // MARK: - Calendar View
    
    private var calendarView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let calendar = Calendar.current
        
        return VStack(alignment: .leading, spacing: 8) {
            // Weekday headers
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(generateCalendarDays(), id: \.id) { day in
                    CalendarDayView(
                        day: day,
                        isSelected: selectedWeek?.id == day.week?.id
                    )
                    .onTapGesture {
                        selectedWeek = day.week
                    }
                }
            }
            
            // Selection details
            if let selectedWeek = selectedWeek {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .padding(.vertical, 4)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedWeek.formattedWeekRange)
                                .font(.caption.bold())
                            
                            Text("\(selectedWeek.sessionCount) sessions")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: selectedWeek.meetsTrainingGoal ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(selectedWeek.meetsTrainingGoal ? .green : .red)
                                
                                Text(selectedWeek.meetsTrainingGoal ? "Goal Met" : "Goal Missed")
                                    .font(.caption)
                                    .foregroundStyle(selectedWeek.meetsTrainingGoal ? .green : .red)
                            }
                            
                            Text("\(selectedWeek.totalDistance / 1000.0, format: .number.precision(.fractionLength(1)))km")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(height: selectedWeek != nil ? 280 : 220)
    }
    
    // MARK: - Progress View
    
    private var progressView: some View {
        Chart {
            ForEach(weeklyData) { week in
                BarMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Sessions", week.sessionCount)
                )
                .foregroundStyle(week.meetsTrainingGoal ? 
                    Color(red: 0.18, green: 0.31, blue: 0.18) : 
                    Color(red: 0.18, green: 0.31, blue: 0.18).opacity(0.3))
                .cornerRadius(4)
                .opacity(selectedWeek == nil || selectedWeek?.id == week.id ? 1.0 : 0.3)
                
                // Goal line
                RuleMark(y: .value("Goal", 2))
                    .foregroundStyle(.orange.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 2]))
            }
            
            // Selection indicator
            if let selectedWeek = selectedWeek {
                RuleMark(x: .value("Week", selectedWeek.weekStart, unit: .weekOfYear))
                    .foregroundStyle(.blue.opacity(0.5))
                    .annotation(position: .top, alignment: .center, spacing: 8) {
                        VStack(alignment: .center, spacing: 4) {
                            Text("\(selectedWeek.sessionCount) sessions")
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            
                            Text(selectedWeek.meetsTrainingGoal ? "Goal achieved" : "Goal missed")
                                .font(.caption2)
                                .foregroundStyle(selectedWeek.meetsTrainingGoal ? .green : .red)
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
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let sessions = value.as(Int.self) {
                        Text("\(sessions)")
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
    }
    
    // MARK: - Timeline View
    
    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Streak timeline
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(weeklyData.reversed()) { week in
                        StreakTimelineSegment(
                            week: week,
                            isSelected: selectedWeek?.id == week.id
                        )
                        .onTapGesture {
                            selectedWeek = week
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 60)
            
            // Streak stats
            VStack(spacing: 12) {
                // Current streak info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(currentStreak) weeks")
                                .font(.subheadline.bold())
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Longest Streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 6) {
                            Text("\(calculateLongestStreak()) weeks")
                                .font(.subheadline.bold())
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                }
                
                // Consistency percentage
                let consistencyRate = Double(weeklyData.filter { $0.meetsTrainingGoal }.count) / 
                                    Double(max(weeklyData.count, 1)) * 100
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Consistency Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("\(consistencyRate, format: .number.precision(.fractionLength(0)))%")
                            .font(.caption.bold())
                            .foregroundStyle(consistencyRate >= 80 ? .green : 
                                           consistencyRate >= 60 ? .orange : .red)
                    }
                    
                    ProgressView(value: consistencyRate, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: 
                            consistencyRate >= 80 ? .green : 
                            consistencyRate >= 60 ? .orange : .red))
                        .frame(height: 6)
                }
            }
            .padding(.top, 8)
        }
        .frame(height: 180)
    }
    
    // MARK: - Legend View
    
    private var legendView: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Goal Met (2+ sessions)")
                    .font(.caption)
            }
            
            HStack(spacing: 4) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("Goal Missed")
                    .font(.caption)
            }
            
            Spacer()
            
            Text("Goal: 2 sessions/week")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
    
    // MARK: - Helper Methods
    
    private func generateCalendarDays() -> [CalendarDay] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .weekOfYear, value: -11, to: endDate) ?? endDate
        
        guard let dateInterval = calendar.dateInterval(of: .weekOfYear, for: startDate) else {
            return []
        }
        
        var days: [CalendarDay] = []
        var currentDate = dateInterval.start
        
        // Generate 12 weeks of days
        for _ in 0..<84 { // 12 weeks × 7 days
            let week = weeklyData.first { calendar.isDate($0.weekStart, equalTo: currentDate, toGranularity: .weekOfYear) }
            
            days.append(CalendarDay(
                date: currentDate,
                week: week,
                isInCurrentMonth: calendar.isDate(currentDate, equalTo: endDate, toGranularity: .month)
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
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
    
    private func calculateLongestStreak() -> Int {
        var longestStreak = 0
        var currentStreakCount = 0
        
        for week in weeklyData.sorted(by: { $0.weekStart < $1.weekStart }) {
            if week.meetsTrainingGoal {
                currentStreakCount += 1
                longestStreak = max(longestStreak, currentStreakCount)
            } else {
                currentStreakCount = 0
            }
        }
        
        return longestStreak
    }
}

// MARK: - Supporting Views

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let week: WeekData?
    let isInCurrentMonth: Bool
}

struct CalendarDayView: View {
    let day: CalendarDay
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: day.date))")
                .font(.caption2)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(day.isInCurrentMonth ? .primary : .secondary)
            
            Circle()
                .fill(fillColor)
                .frame(width: 6, height: 6)
        }
        .frame(width: 32, height: 32)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var fillColor: Color {
        guard let week = day.week else { return .clear }
        
        if week.meetsTrainingGoal {
            return .green
        } else if week.sessionCount > 0 {
            return .orange.opacity(0.6)
        } else {
            return .red.opacity(0.3)
        }
    }
}

struct StreakTimelineSegment: View {
    let week: WeekData
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(week.meetsTrainingGoal ? .green : .red.opacity(0.6))
                .frame(width: 12, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(isSelected ? .blue : .clear, lineWidth: 2)
                )
            
            Text("\(week.sessionCount)")
                .font(.caption2)
                .foregroundStyle(.primary)
                .fontWeight(isSelected ? .bold : .regular)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}