import SwiftUI
import SwiftData
import Charts

// Import all chart components
// These provide comprehensive Swift Charts implementations for analytics dashboard

/// Main analytics dashboard view showcasing key metrics and trends
struct AnalyticsView: View {
  @State private var viewModel: AnalyticsViewModel
  @StateObject private var accessibilityManager = ChartAccessibilityManager()
  @State private var isAnnouncingOverview = false
  
  init(modelContainer: ModelContainer) {
    self._viewModel = State(wrappedValue: AnalyticsViewModel(modelContainer: modelContainer))
  }
  
  var body: some View {
    NavigationView {
      ScrollView {
        LazyVStack(spacing: 16) {
          // Time Period Selector
          timePeriodSelector
          
          // Loading State
          if viewModel.isLoading {
            ProgressView("Loading analytics...")
              .frame(maxWidth: .infinity, minHeight: 200)
          } else if viewModel.hasAnalyticsData {
            // Main Analytics Content
            overviewCards
            trendsSection
            personalRecordsSection
            weeklyChartsSection
            personalRecordsChartsSection
            periodComparisonSection
          } else {
            // Empty State
            emptyStateView
          }
        }
        .padding()
      }
      .navigationTitle("Analytics")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Button(action: { announceAnalyticsOverview() }) {
              Label("Announce Overview", systemImage: "speaker.wave.2")
            }
            
            Button(action: { accessibilityManager.isAudioGraphEnabled.toggle() }) {
              Label(
                accessibilityManager.isAudioGraphEnabled ? "Disable Audio Graphs" : "Enable Audio Graphs",
                systemImage: accessibilityManager.isAudioGraphEnabled ? "speaker.slash" : "speaker.wave.3"
              )
            }
            
            Button(action: { accessibilityManager.announceDataChanges.toggle() }) {
              Label(
                accessibilityManager.announceDataChanges ? "Disable Announcements" : "Enable Announcements",
                systemImage: accessibilityManager.announceDataChanges ? "bell.slash" : "bell"
              )
            }
          } label: {
            Image(systemName: "accessibility")
              .accessibilityLabel("Accessibility options")
          }
        }
      }
      .refreshable {
        await viewModel.refreshAnalytics()
        if viewModel.hasAnalyticsData {
          accessibilityManager.announceDataUpdate("Analytics data refreshed")
        }
      }
      .task {
        await viewModel.loadAllAnalyticsData()
      }
      .onChange(of: viewModel.selectedTimePeriod) { _, newPeriod in
        accessibilityManager.announceMessage("Time period changed to \(newPeriod.displayName)")
      }
      .alert("Analytics Error", isPresented: $viewModel.showingErrorAlert) {
        Button("OK") {
          viewModel.dismissError()
        }
      } message: {
        Text(viewModel.errorMessage)
      }
      .sheet(isPresented: $viewModel.showingDetailedMetrics) {
        if let detailedMetrics = viewModel.detailedMetrics {
          DetailedMetricsView(metrics: detailedMetrics)
        }
      }
    }
  }
  
  // MARK: - Time Period Selector
  
  private var timePeriodSelector: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Time Period")
        .font(.headline)
        .foregroundStyle(.primary)
        .accessibilityAddTraits(.isHeader)
      
      Picker("Select Time Period", selection: $viewModel.selectedTimePeriod) {
        ForEach(AnalyticsTimePeriod.allCases, id: \.self) { period in
          Label(period.displayName, systemImage: period.systemImage)
            .tag(period)
        }
      }
      .pickerStyle(.segmented)
      .accessibilityLabel("Time period selector")
      .accessibilityHint("Choose the time range for analytics data")
    }
    .padding()
    .background(AccessibilityPreferences.shared.shouldUseHighContrast ? Color(.systemBackground) : Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(radius: AccessibilityPreferences.shared.isReduceTransparencyEnabled ? 0 : 2, y: AccessibilityPreferences.shared.isReduceTransparencyEnabled ? 0 : 1)
  }
  
  // MARK: - Overview Cards
  
  private var overviewCards: some View {
    LazyVGrid(columns: [
      GridItem(.flexible()),
      GridItem(.flexible())
    ], spacing: 12) {
      // Total Sessions
      MetricCard(
        title: "Sessions",
        value: "\(viewModel.totalSessions)",
        subtitle: viewModel.selectedTimePeriod.displayName,
        systemImage: "figure.run",
        trend: viewModel.sessionCountTrend
      )
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Sessions metric")
      .accessibilityValue("\(viewModel.totalSessions) sessions in \(viewModel.selectedTimePeriod.displayName)")
      .accessibilityHint(trendHint(for: viewModel.sessionCountTrend))
      
      // Total Distance
      MetricCard(
        title: "Distance",
        value: viewModel.formatDistance(viewModel.totalDistanceKm * 1000),
        subtitle: "Total covered",
        systemImage: "map",
        trend: viewModel.distanceTrend
      )
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Distance metric")
      .accessibilityValue("\(viewModel.formatDistance(viewModel.totalDistanceKm * 1000)) total distance covered")
      .accessibilityHint(trendHint(for: viewModel.distanceTrend))
      
      // Average Pace
      MetricCard(
        title: "Avg Pace",
        value: viewModel.formatPace(viewModel.averagePace),
        subtitle: "Per kilometer",
        systemImage: "speedometer",
        trend: viewModel.paceTrend
      )
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Average pace metric")
      .accessibilityValue("Average pace \(viewModel.formatPace(viewModel.averagePace)) per kilometer")
      .accessibilityHint(trendHint(for: viewModel.paceTrend))
      
      // Total Calories
      MetricCard(
        title: "Calories",
        value: viewModel.formatCalories(viewModel.totalCalories),
        subtitle: "Energy burned",
        systemImage: "flame",
        trend: viewModel.calorieTrend
      )
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Calories metric")
      .accessibilityValue("\(viewModel.formatCalories(viewModel.totalCalories)) energy burned")
      .accessibilityHint(trendHint(for: viewModel.calorieTrend))
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Performance metrics overview")
  }
  
  // MARK: - Trends Section
  
  private var trendsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Performance Trends")
          .font(.headline)
        
        Spacer()
        
        Button("View Details") {
          viewModel.showDetailedMetrics()
        }
        .font(.caption)
        .foregroundStyle(.blue)
      }
      
      VStack(spacing: 8) {
        if let trend = viewModel.distanceTrend {
          TrendRow(
            title: "Distance",
            trend: trend,
            metricType: .distance
          )
        }
        
        if let trend = viewModel.paceTrend {
          TrendRow(
            title: "Pace",
            trend: trend,
            metricType: .pace
          )
        }
        
        if let trend = viewModel.calorieTrend {
          TrendRow(
            title: "Calories",
            trend: trend,
            metricType: .calories
          )
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(radius: 2, y: 1)
  }
  
  // MARK: - Personal Records Section
  
  private var personalRecordsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Personal Records")
          .font(.headline)
        
        Spacer()
        
        Button("View All") {
          viewModel.showPersonalRecordsDetail()
        }
        .font(.caption)
        .foregroundStyle(.blue)
      }
      
      LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
      ], spacing: 8) {
        if let record = viewModel.longestDistanceRecord, record.isValid {
          PersonalRecordCard(
            title: "Longest Distance",
            value: viewModel.formatDistance(record.value),
            date: record.date,
            systemImage: "map"
          )
        }
        
        if let record = viewModel.fastestPaceRecord, record.isValid {
          PersonalRecordCard(
            title: "Fastest Pace",
            value: viewModel.formatPace(record.value),
            date: record.date,
            systemImage: "speedometer"
          )
        }
        
        if let record = viewModel.heaviestLoadRecord, record.isValid {
          PersonalRecordCard(
            title: "Heaviest Load",
            value: viewModel.formatWeight(record.value),
            date: record.date,
            systemImage: "scalemass"
          )
        }
        
        if let record = viewModel.mostWeightMovedRecord, record.isValid {
          PersonalRecordCard(
            title: "Most Weight Moved",
            value: viewModel.formatWeightMoved(record.value),
            date: record.date,
            systemImage: "arrow.up.and.down"
          )
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(radius: 2, y: 1)
  }
  
  // MARK: - Advanced Charts Section
  
  private var weeklyChartsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Analytics Dashboard")
        .font(.headline)
      
      if viewModel.hasWeeklyData, let weeklyData = viewModel.weeklyAnalyticsData {
        // Weekly Overview Chart
        WeeklyOverviewChart(weeklyData: weeklyData.weeks)
        
        // Pace Trend Chart
        if let paceTrend = viewModel.paceTrend {
          PaceTrendChart(
            weeklyData: weeklyData.weeks,
            trendData: paceTrend
          )
        }
        
        // Weight Moved Chart
        WeightMovedChart(weeklyData: weeklyData.weeks)
        
        // Training Streak Visualization
        TrainingStreakChart(
          weeklyData: weeklyData.weeks,
          currentStreak: viewModel.currentTrainingStreak
        )
      } else {
        Text("Loading analytics data...")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 100)
      }
    }
  }
  
  // MARK: - Personal Records Charts Section
  
  private var personalRecordsChartsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let personalRecords = viewModel.personalRecords,
         let analyticsData = viewModel.analyticsData {
        
        // Personal Records Comparison Chart
        PersonalRecordsChart(
          personalRecords: personalRecords,
          currentAnalytics: analyticsData
        )
        
        // PR Progress Over Time
        PersonalRecordsProgressChart(
          sessions: analyticsData.sessions
        )
      }
    }
  }
  
  // MARK: - Period Comparison Section
  
  private var periodComparisonSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let currentData = viewModel.analyticsData {
        // Main period comparison chart
        PeriodComparisonChart(
          currentPeriodData: currentData,
          previousPeriodData: getPreviousPeriodData()
        )
        
        // Weekly comparison chart
        if let weeklyData = viewModel.weeklyAnalyticsData {
          WeeklyComparisonChart(weeklyData: weeklyData.weeks)
        }
      }
    }
  }
  
  // MARK: - Empty State
  
  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "chart.line.uptrend.xyaxis")
        .font(.system(size: 60))
        .foregroundStyle(.secondary)
      
      Text("No Analytics Data")
        .font(.title2)
        .fontWeight(.semibold)
      
      Text("Complete some ruck sessions to see your analytics and performance trends.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      
      Button("Start Your First Ruck") {
        // Navigate to session start
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
    .frame(maxWidth: .infinity, minHeight: 300)
  }
  
  // MARK: - Helper Methods
  
  private func getPreviousPeriodData() -> AnalyticsData? {
    // This would typically be fetched from the view model
    // For now, we'll return nil and let the chart handle the no-data case
    // In a full implementation, you'd want to add this to AnalyticsViewModel
    return nil
  }
  
  // MARK: - Accessibility Methods
  
  private func announceAnalyticsOverview() {
    guard !isAnnouncingOverview else { return }
    isAnnouncingOverview = true
    
    let overview = buildAnalyticsOverview()
    accessibilityManager.announceMessage(overview)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
      isAnnouncingOverview = false
    }
  }
  
  private func buildAnalyticsOverview() -> String {
    guard viewModel.hasAnalyticsData else {
      return "No analytics data available. Complete some ruck sessions to see analytics."
    }
    
    var overview = "Analytics overview for \(viewModel.selectedTimePeriod.displayName). "
    overview += "\(viewModel.totalSessions) sessions completed. "
    overview += "Total distance: \(viewModel.formatDistance(viewModel.totalDistanceKm * 1000)). "
    overview += "Average pace: \(viewModel.formatPace(viewModel.averagePace)). "
    overview += "Total calories burned: \(viewModel.formatCalories(viewModel.totalCalories)). "
    
    // Add trend information
    if let sessionTrend = viewModel.sessionCountTrend {
      overview += "Session count is \(trendDescription(for: sessionTrend)). "
    }
    
    if let distanceTrend = viewModel.distanceTrend {
      overview += "Distance is \(trendDescription(for: distanceTrend)). "
    }
    
    if let paceTrend = viewModel.paceTrend {
      overview += "Pace is \(trendDescription(for: paceTrend)). "
    }
    
    return overview
  }
  
  private func trendHint(for trend: TrendData?) -> String {
    guard let trend = trend else { return "" }
    return "Trend: \(trendDescription(for: trend))"
  }
  
  private func trendDescription(for trend: TrendData) -> String {
    let direction = trend.direction == .improving ? "improving" : 
                   trend.direction == .declining ? "declining" : "stable"
    return "\(direction) by \(trend.formattedPercentageChange)"
  }
}

// MARK: - Supporting Views

struct MetricCard: View {
  let title: String
  let value: String
  let subtitle: String
  let systemImage: String
  let trend: TrendData?
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: systemImage)
          .foregroundStyle(.blue)
        
        Spacer()
        
        if let trend = trend {
          HStack(spacing: 4) {
            Image(systemName: trend.direction.systemImage)
              .font(.caption)
            Text(trend.formattedPercentageChange)
              .font(.caption)
              .fontWeight(.medium)
          }
          .foregroundStyle(Color(trend.direction.color))
        }
      }
      
      Text(value)
        .font(.title2)
        .fontWeight(.bold)
      
      Text(subtitle)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .shadow(radius: 1, y: 0.5)
  }
}

struct TrendRow: View {
  let title: String
  let trend: TrendData
  let metricType: MetricType
  
  var body: some View {
    HStack {
      Text(title)
        .font(.subheadline)
      
      Spacer()
      
      HStack(spacing: 8) {
        Text(AnalyticsFormatters.formatTrendDescription(trend, metricType: metricType))
          .font(.caption)
          .foregroundStyle(.secondary)
        
        HStack(spacing: 4) {
          Image(systemName: trend.direction.systemImage)
            .font(.caption)
          Text(trend.formattedPercentageChange)
            .font(.caption)
            .fontWeight(.medium)
        }
        .foregroundStyle(Color(trend.direction.color))
      }
    }
    .padding(.vertical, 4)
  }
}

struct PersonalRecordCard: View {
  let title: String
  let value: String
  let date: Date
  let systemImage: String
  
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Image(systemName: systemImage)
          .foregroundStyle(.orange)
          .font(.headline)
        
        Spacer()
        
        Image(systemName: "trophy.fill")
          .foregroundStyle(.yellow)
          .font(.caption)
      }
      
      Text(value)
        .font(.title3)
        .fontWeight(.bold)
      
      Text(title)
        .font(.caption)
        .foregroundStyle(.primary)
      
      Text(AnalyticsFormatters.formatPersonalRecordDate(date))
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .shadow(radius: 1, y: 0.5)
  }
}

// MARK: - Chart Components
// Chart implementations have been moved to separate files:
// - WeeklyOverviewChart in AnalyticsChartComponents.swift
// - PaceTrendChart in AnalyticsChartComponents.swift  
// - WeightMovedChart in AnalyticsChartComponents.swift
// - PersonalRecordsChart in PersonalRecordsCharts.swift
// - TrainingStreakChart in StreakVisualizationCharts.swift
// - PeriodComparisonChart in PeriodComparisonCharts.swift

// MARK: - Detailed Metrics View Placeholder

struct DetailedMetricsView: View {
  let metrics: DetailedMetrics
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Detailed metrics view would go here")
          Text("Pace Distribution, Terrain Analysis, Weather Impact, etc.")
        }
        .padding()
      }
      .navigationTitle("Detailed Metrics")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

// MARK: - Preview

#Preview {
  // Create preview with sample data
  do {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: RuckSession.self, LocationPoint.self, TerrainSegment.self, WeatherConditions.self,
      configurations: config
    )
    
    return AnalyticsView(modelContainer: container)
  } catch {
    return Text("Preview unavailable: \(error.localizedDescription)")
  }
}