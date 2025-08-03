# RuckMap Analytics System

This document describes the analytics data models and calculations implemented for RuckMap's analytics dashboard, following the specifications in MVP User Stories 5.1 and 5.2.

## Overview

The analytics system provides comprehensive insights into ruck training performance, including:

- Weekly/monthly distance totals and trends  
- Average pace analysis and improvement tracking
- Total weight moved calculations (load × distance)
- Personal records across all metrics
- Training streak tracking (2+ rucks per week)
- Period-over-period comparisons
- Detailed performance breakdowns

## Architecture

The analytics system follows the established patterns in RuckMap:

- **Repository Pattern**: `AnalyticsRepository` handles all SwiftData queries and caching
- **MVVM Pattern**: `AnalyticsViewModel` manages UI state and user interactions
- **SwiftData Integration**: Efficient querying of existing `RuckSession` models
- **Swift 6 Concurrency**: Full `@ModelActor` and `async/await` support
- **Google Swift Style Guide**: Consistent code formatting and naming

## Core Components

### 1. Analytics Data Models (`AnalyticsModels.swift`)

#### `AnalyticsData`
Main analytics container with comprehensive metrics:

```swift
struct AnalyticsData: Sendable {
  let timePeriod: AnalyticsTimePeriod
  let totalSessions: Int
  let totalDistance: Double
  let totalWeightMoved: Double
  let averagePace: Double
  let trainingStreak: Int
  let distanceTrend: TrendData?
  // ... more properties
}
```

#### `PersonalRecords`
Tracks best performances across all metrics:

```swift
struct PersonalRecords: Sendable {
  let longestDistance: PersonalRecord<Double>
  let fastestPace: PersonalRecord<Double>
  let heaviestLoad: PersonalRecord<Double>
  let highestCalorieBurn: PersonalRecord<Double>
  let mostWeightMoved: PersonalRecord<Double>
}
```

#### `WeeklyAnalyticsData`
Optimized for chart visualization:

```swift
struct WeeklyAnalyticsData: Sendable {
  let weeks: [WeekData]
  let averageSessionsPerWeek: Double
  let averageDistancePerWeek: Double
}
```

### 2. Analytics Repository (`AnalyticsRepository.swift`)

#### Efficient Querying
- Optimized SwiftData queries with property-specific fetching
- Time-range filtering with predicate-based queries
- Batch processing for large datasets

#### Intelligent Caching
- 5-minute cache expiration for real-time accuracy
- Automatic cache invalidation on data changes
- Memory-efficient cache management

#### Background Processing
- Precomputation of common analytics scenarios
- Concurrent processing with TaskGroup
- Cache maintenance and cleanup

```swift
@ModelActor
actor AnalyticsRepository {
  func fetchAnalyticsData(for timePeriod: AnalyticsTimePeriod) async throws -> AnalyticsData
  func fetchPersonalRecords() async throws -> PersonalRecords
  func fetchWeeklyAnalyticsData(numberOfWeeks: Int = 12) async throws -> WeeklyAnalyticsData
}
```

### 3. Analytics View Model (`AnalyticsViewModel.swift`)

#### State Management
- `@Observable` pattern for SwiftUI integration
- Loading states for all async operations
- Error handling with user-friendly messages

#### User Interactions
- Time period selection and filtering
- Data refresh and cache invalidation
- Navigation to detailed views

```swift
@Observable
final class AnalyticsViewModel {
  var analyticsData: AnalyticsData?
  var selectedTimePeriod: AnalyticsTimePeriod = .monthly
  var isLoadingAnalytics: Bool = false
  
  func loadAllAnalyticsData() async
  func changeTimePeriod(to newPeriod: AnalyticsTimePeriod)
}
```

### 4. Formatting Utilities (`AnalyticsFormatters.swift`)

Consistent data presentation across all analytics views:

```swift
struct AnalyticsFormatters {
  static func formatDistance(_ distance: Double) -> String
  static func formatPace(_ pace: Double) -> String
  static func formatDuration(_ duration: TimeInterval) -> String
  static func formatTrendDescription(_ trend: TrendData, metricType: MetricType) -> String
}
```

## Integration Guide

### 1. Add to App Architecture

Update your main app setup to include analytics:

```swift
// In DataCoordinator or equivalent
private let analyticsRepository: AnalyticsRepository

init() throws {
  // ... existing setup
  self.analyticsRepository = AnalyticsRepository(modelContainer: modelContainer)
}

func makeAnalyticsView() -> some View {
  AnalyticsView(viewModel: AnalyticsViewModel(modelContainer: modelContainer))
}
```

### 2. Create Analytics Views

Use the view model in your SwiftUI views:

```swift
struct AnalyticsView: View {
  @State private var viewModel: AnalyticsViewModel
  
  init(viewModel: AnalyticsViewModel) {
    self.viewModel = viewModel
  }
  
  var body: some View {
    NavigationView {
      VStack {
        // Time period picker
        Picker("Period", selection: $viewModel.selectedTimePeriod) {
          ForEach(AnalyticsTimePeriod.allCases, id: \.self) { period in
            Text(period.displayName).tag(period)
          }
        }
        
        // Analytics cards
        if let data = viewModel.analyticsData {
          AnalyticsCardView(data: data)
          PersonalRecordsView(records: viewModel.personalRecords)
          WeeklyTrendsChart(weeklyData: viewModel.weeklyAnalyticsData)
        }
      }
      .task {
        await viewModel.loadAllAnalyticsData()
      }
      .refreshable {
        await viewModel.refreshAnalytics()
      }
    }
  }
}
```

### 3. Cache Invalidation

Ensure analytics cache is invalidated when sessions change:

```swift
// In SessionManager or equivalent
func completeSession(_ session: RuckSession) async throws {
  // ... existing completion logic
  
  // Invalidate analytics cache
  await analyticsRepository.invalidateCache()
}
```

### 4. Testing Integration

The system includes comprehensive tests:

```swift
// Run analytics tests
@MainActor
func testAnalyticsIntegration() async throws {
  let viewModel = AnalyticsViewModel(modelContainer: testContainer)
  await viewModel.loadAllAnalyticsData()
  
  XCTAssertNotNil(viewModel.analyticsData)
  XCTAssertTrue(viewModel.hasAnalyticsData)
}
```

## Performance Considerations

### Memory Management
- Uses `@ModelActor` for thread-safe SwiftData access
- Implements property-specific fetching to reduce memory usage
- Automatic cache cleanup prevents memory leaks

### Query Optimization
- Predicate-based filtering reduces data transfer
- Batch processing for large datasets
- Background precomputation for common scenarios

### UI Responsiveness
- All heavy calculations performed off main thread  
- Progressive loading with individual loading states
- Smooth data updates with `@Observable` pattern

## Metrics Calculated

### Story 5.1: Progress Overview
✅ Weekly distance totals  
✅ Monthly distance totals  
✅ Average pace trends with period comparison  
✅ Total weight moved (load × distance)  
✅ Personal records highlighting  
✅ Period-over-period comparisons  
✅ Swift Charts compatible data structures

### Story 5.2: Streak Tracking  
✅ Current training streak (2+ rucks per week)  
✅ Longest historical streak  
✅ Weekly goal achievement tracking  
✅ Rest day accommodation  
✅ Milestone celebration data

### Additional Analytics
✅ Detailed pace distribution analysis  
✅ Terrain impact on performance  
✅ Weather condition correlations  
✅ Load progression tracking  
✅ Calorie burn rate analysis

## Usage Examples

### Basic Analytics Display
```swift
if let data = viewModel.analyticsData {
  Text("Total Distance: \(viewModel.formatDistance(data.totalDistance))")
  Text("Average Pace: \(viewModel.formatPace(data.averagePace))")
  Text("Training Streak: \(data.trainingStreak) weeks")
}
```

### Trend Indicators
```swift  
if let trend = viewModel.distanceTrend {
  HStack {
    Image(systemName: trend.direction.systemImage)
      .foregroundStyle(Color(trend.direction.color))
    Text(AnalyticsFormatters.formatTrendDescription(trend, metricType: .distance))
  }
}
```

### Personal Records
```swift
if let record = viewModel.longestDistanceRecord {
  VStack {
    Text("Longest Distance")
    Text(viewModel.formatDistance(record.value))
    Text(AnalyticsFormatters.formatPersonalRecordDate(record.date))
      .font(.caption)
      .foregroundStyle(.secondary)
  }
}
```

## Error Handling

The system provides comprehensive error handling:

```swift
// Repository level
enum AnalyticsError: LocalizedError {
  case invalidDateRange
  case noDataAvailable
  case cacheCorrupted
}

// View model level
if viewModel.showingErrorAlert {
  Alert(
    title: Text("Analytics Error"),
    message: Text(viewModel.errorMessage),
    dismissButton: .default(Text("OK")) {
      viewModel.dismissError()
    }
  )
}
```

## Future Enhancements

The architecture supports easy extension for:

- Export analytics reports (PDF/CSV)
- Custom time range selection
- Goal setting and progress tracking
- Social comparison features
- Advanced machine learning insights
- Apple Health integration for additional metrics

## Testing

Run the analytics tests to verify integration:

```bash
xcodebuild test -scheme RuckMap -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:RuckMapTests/AnalyticsIntegrationTests
```

The tests cover:
- Data model calculations
- Repository caching behavior  
- View model state management
- Performance with large datasets
- Error handling scenarios

---

For questions about the analytics system implementation, refer to the comprehensive test suite in `AnalyticsIntegrationTests.swift` or review the inline documentation in each source file.