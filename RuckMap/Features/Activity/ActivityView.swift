//
//  ActivityView.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct ActivityView: View {
  @StateObject private var viewModel = ActivityViewModel()
  @Environment(\.scenePhase) private var scenePhase
  
  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        // Current Session or Start Card
        if let session = viewModel.activeSession {
          ActiveSessionCard(
            session: session,
            onPause: viewModel.pauseSession,
            onResume: viewModel.resumeSession,
            onStop: viewModel.stopSession
          )
          .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
          ))
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Active rucking session")
          .accessibilityAddTraits(.isHeader)
        } else {
          StartRuckCard(onStart: viewModel.startSession)
            .transition(.asymmetric(
              insertion: .move(edge: .bottom).combined(with: .opacity),
              removal: .move(edge: .top).combined(with: .opacity)
            ))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Start new ruck")
            .accessibilityAddTraits(.isHeader)
        }
        
        // Quick Stats
        QuickStatsSection(stats: viewModel.quickStats)
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Quick statistics")
          .accessibilityAddTraits(.isHeader)
        
        // Recent Activities
        RecentActivitiesSection(activities: viewModel.recentActivities)
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Recent activities")
          .accessibilityAddTraits(.isHeader)
      }
      .padding()
    }
    .background(Color.armyBackgroundPrimary)
    .animation(.easeInOut(duration: 0.3), value: viewModel.activeSession?.id)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Activity screen")
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        viewModel.refreshData()
      }
    }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    ActivityView()
      .navigationTitle("Activity")
      .navigationBarTitleDisplayMode(.large)
  }
}