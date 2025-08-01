//
//  ProgressView.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI
import Charts

struct ProgressView: View {
  @StateObject private var viewModel = ProgressViewModel()
  @State private var selectedTimeRange: TimeRange = .week
  
  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        // Time Range Selector
        TimeRangePicker(selection: $selectedTimeRange)
          .padding(.horizontal)
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Time range selector")
          .accessibilityAddTraits(.isHeader)
        
        // Summary Stats
        SummaryStatsGrid(stats: viewModel.summaryStats(for: selectedTimeRange))
          .padding(.horizontal)
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Summary statistics for \(selectedTimeRange.rawValue)")
          .accessibilityAddTraits(.isHeader)
        
        // Progress Chart
        ProgressChart(data: viewModel.chartData(for: selectedTimeRange))
          .padding(.horizontal)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Progress chart for \(selectedTimeRange.rawValue)")
          .accessibilityAddTraits(.isImage)
        
        // Personal Records
        PersonalRecordsSection(records: viewModel.personalRecords)
          .padding(.horizontal)
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Personal records")
          .accessibilityAddTraits(.isHeader)
        
        // Achievement Progress
        AchievementProgressSection(achievements: viewModel.achievements)
          .padding(.horizontal)
          .padding(.bottom)
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Achievement progress")
          .accessibilityAddTraits(.isHeader)
      }
      .padding(.vertical)
    }
    .background(Color.armyBackgroundPrimary)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Progress screen")
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    ProgressView()
      .navigationTitle("Progress")
      .navigationBarTitleDisplayMode(.large)
  }
}