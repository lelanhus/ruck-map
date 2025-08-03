# RuckMap Swift Charts Analytics Dashboard

A comprehensive collection of Swift Charts visualizations designed specifically for RuckMap's analytics dashboard. These charts provide beautiful, interactive, and accessible data visualizations for fitness tracking and ruck march analytics.

## Overview

The RuckMap Charts Library provides 8 specialized chart components that integrate seamlessly with the existing analytics data models. All charts are optimized for performance, support dark mode, follow accessibility best practices, and use RuckMap's army green design system.

## Chart Components

### 1. Weekly Overview Chart (`WeeklyOverviewChart`)
**File:** `AnalyticsChartComponents.swift`

- **Purpose:** Line/bar chart showing distance by day/week with training goal indicators
- **Features:**
  - Interactive week selection with detailed annotations
  - Training goal visualization (2+ sessions/week)
  - Smooth animations and hover states
  - Goal achievement indicators
- **Data Required:** `[WeekData]`
- **Performance:** Optimized for 12-52 weeks of data

```swift
WeeklyOverviewChart(weeklyData: weeklyData.weeks)
```

### 2. Pace Trend Chart (`PaceTrendChart`)
**File:** `AnalyticsChartComponents.swift`

- **Purpose:** Line chart showing average pace over time with trend indicators
- **Features:**
  - 3-week moving average overlay
  - Trend direction indicators
  - Interactive data point selection
  - Best pace highlighting
- **Data Required:** `[WeekData]`, `TrendData?`
- **Performance:** Handles up to 100 data points efficiently

```swift
PaceTrendChart(
  weeklyData: weeklyData.weeks,
  trendData: paceTrend
)
```

### 3. Weight Moved Chart (`WeightMovedChart`)
**File:** `AnalyticsChartComponents.swift`

- **Purpose:** Bar chart showing total weight × distance with load breakdown
- **Features:**
  - Stacked bars by load category (light/medium/heavy)
  - Load distribution visualization
  - Peak performance indicators
  - Interactive week selection
- **Data Required:** `[WeekData]`
- **Performance:** Real-time calculation of weight moved metrics

```swift
WeightMovedChart(weeklyData: weeklyData.weeks)
```

### 4. Personal Records Chart (`PersonalRecordsChart`)
**File:** `PersonalRecordsCharts.swift`

- **Purpose:** Visual indicators for PRs with comparison to averages
- **Features:**
  - Horizontal bar chart comparing records to averages
  - Improvement ratio calculations
  - Multiple metric support (distance, pace, load, calories, duration, weight moved)
  - Interactive metric selection
- **Data Required:** `PersonalRecords`, `AnalyticsData`
- **Performance:** Normalized scaling for consistent visualization

```swift
PersonalRecordsChart(
  personalRecords: personalRecords,
  currentAnalytics: analyticsData
)
```

### 5. Personal Records Progress Chart (`PersonalRecordsProgressChart`)
**File:** `PersonalRecordsCharts.swift`

- **Purpose:** Shows how personal records have evolved over time
- **Features:**
  - Timeline visualization of record progression
  - Step-after interpolation for record plateaus
  - Multiple metric tracking
  - Record achievement markers
- **Data Required:** `[RuckSession]`
- **Performance:** Efficient filtering and sorting of session data

```swift
PersonalRecordsProgressChart(sessions: analyticsData.sessions)
```

### 6. Training Streak Chart (`TrainingStreakChart`)
**File:** `StreakVisualizationCharts.swift`

- **Purpose:** Calendar-style or progress chart for training consistency
- **Features:**
  - Three view modes: Calendar, Progress, Timeline
  - Current and longest streak tracking
  - Consistency rate calculation
  - Interactive streak exploration
- **Data Required:** `[WeekData]`, `currentStreak: Int`
- **Performance:** Dynamic calendar generation for 12 weeks

```swift
TrainingStreakChart(
  weeklyData: weeklyData.weeks,
  currentStreak: currentTrainingStreak
)
```

### 7. Period Comparison Chart (`PeriodComparisonChart`)
**File:** `PeriodComparisonCharts.swift`

- **Purpose:** Shows current vs previous period side-by-side comparisons
- **Features:**
  - Multiple metric comparison support
  - Percentage change calculations
  - Improvement indicators
  - Detailed comparison grid
- **Data Required:** `AnalyticsData` (current), `AnalyticsData?` (previous)
- **Performance:** Handles missing previous data gracefully

```swift
PeriodComparisonChart(
  currentPeriodData: currentData,
  previousPeriodData: previousData
)
```

### 8. Weekly Comparison Chart (`WeeklyComparisonChart`)
**File:** `PeriodComparisonCharts.swift`

- **Purpose:** Shows week-over-week progress with trend analysis
- **Features:**
  - Three comparison modes: consecutive, month-over-month, year-over-year
  - Improvement rate tracking
  - Change indicators with statistical significance
  - Flexible comparison logic
- **Data Required:** `[WeekData]`
- **Performance:** Efficient pairing algorithm for comparisons

```swift
WeeklyComparisonChart(weeklyData: weeklyData.weeks)
```

## Design System

### Color Palette
- **Primary Green:** `Color(red: 0.18, green: 0.31, blue: 0.18)` - Army green theme
- **Secondary Green:** Army green with 60% opacity
- **Accent Colors:** Orange, blue, red, purple, teal for different metrics
- **System Colors:** Adaptive colors for light/dark mode support

### Typography
- **Headlines:** `.headline` with `.fontWeight(.semibold)`
- **Captions:** `.caption` and `.caption2` for axis labels and annotations
- **Data Values:** `.subheadline.bold()` for emphasis

### Animations
- **Data Updates:** `Animation.easeInOut(duration: 0.3)`
- **Selections:** `Animation.easeInOut(duration: 0.2)`
- **View Changes:** `Animation.easeInOut(duration: 0.4)`

## Performance Optimizations

### Large Dataset Handling
- **Data Sampling:** Automatic sampling for datasets > 100 points
- **Lazy Loading:** Efficient memory usage for chart collections
- **Background Processing:** Heavy calculations on background threads
- **Caching:** Computed chart data cached to avoid recalculation

### Memory Management
- **@StateObject vs @ObservedObject:** Proper usage to prevent unnecessary object creation
- **Conditional Rendering:** Charts only render when data is available
- **View Recycling:** Efficient reuse of chart components

### Animation Performance
- **Selective Animation:** Only animate necessary elements
- **Reduced Motion:** Respect accessibility preferences
- **GPU Acceleration:** Use of vectorized plots where available

## Accessibility Features

### VoiceOver Support
- **Descriptive Labels:** All charts have comprehensive accessibility labels
- **Audio Graphs:** Support for audio representation of chart data
- **Navigation:** Logical focus order for screen readers

### Visual Accessibility
- **High Contrast:** Charts adapt to high contrast mode
- **Dynamic Type:** Text scales with user preferences
- **Color Independence:** Information not conveyed through color alone

### Motor Accessibility
- **Large Touch Targets:** Interactive elements meet minimum size requirements
- **Alternative Navigation:** Keyboard navigation support where applicable

## Integration Guide

### 1. Import Required Components

```swift
import SwiftUI
import Charts
import Foundation
```

### 2. Add to Analytics View

```swift
// Replace existing chart sections with:
weeklyChartsSection
personalRecordsChartsSection  
periodComparisonSection
```

### 3. Data Requirements

Ensure your `AnalyticsViewModel` provides:
- `weeklyAnalyticsData: WeeklyAnalyticsData?`
- `personalRecords: PersonalRecords?`
- `analyticsData: AnalyticsData?`
- `currentTrainingStreak: Int`

### 4. Error Handling

All charts handle missing or invalid data gracefully:
- Empty state views for no data
- Loading states during data fetch
- Fallback values for corrupted data

## Testing Strategy

### Unit Tests
- Data transformation accuracy
- Performance with large datasets
- Edge case handling (empty data, single data point)

### UI Tests
- Chart interaction functionality
- Accessibility compliance
- Animation performance

### Performance Tests
- Memory usage with large datasets
- Rendering time for complex charts
- Battery impact during extended use

## Browser Compatibility

### iOS Versions
- **Minimum:** iOS 18.0+ (Swift Charts requirement)
- **Recommended:** iOS 18.1+ for optimal performance
- **Future:** iOS 26+ for 3D chart capabilities

### Device Support
- **iPhone:** All models supporting iOS 18+
- **iPad:** Full support with adaptive layouts
- **Mac:** Native macOS support via Mac Catalyst

## Troubleshooting

### Common Issues

1. **Charts not displaying:**
   - Verify data models conform to expected structure
   - Check that `weeklyAnalyticsData` is not nil
   - Ensure proper import statements

2. **Performance issues:**
   - Implement data sampling for large datasets
   - Use `.chartXScale(domain:)` to limit visible range
   - Consider lazy loading for multiple charts

3. **Accessibility problems:**
   - Test with VoiceOver enabled
   - Verify all charts have accessibility labels
   - Check color contrast ratios

### Debug Mode

Enable debug mode by setting breakpoints in:
- Chart data preparation methods
- Gesture handlers for interactivity
- Animation completion handlers

## Future Enhancements

### Planned Features
- **3D Charts:** Elevation profile visualization (iOS 26+)
- **Export Functionality:** PDF/PNG chart export
- **Customization:** User-selectable color themes
- **Advanced Analytics:** Statistical trend analysis

### Performance Improvements
- **Vectorized Plots:** Migration to Chart3D components
- **Background Updates:** Real-time data synchronization
- **Caching Strategy:** Persistent chart data caching

## License

This implementation is part of the RuckMap project and follows the project's licensing terms. The charts are built using Apple's Swift Charts framework and comply with Apple's Human Interface Guidelines.

## Support

For issues or questions regarding the chart implementations:
1. Check the troubleshooting section above
2. Review the source code comments for implementation details
3. Test with sample data to isolate issues
4. Verify iOS version compatibility

---

**Version:** 1.0.0  
**Last Updated:** January 2025  
**Minimum iOS:** 18.0+  
**Swift Charts Version:** iOS 18.0+