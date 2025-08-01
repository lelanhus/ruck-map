//
//  ActivityViewModel.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI
import Combine

@MainActor
class ActivityViewModel: ObservableObject {
  @Published var activeSession: RuckingSession?
  @Published var quickStats: QuickStats
  @Published var recentActivities: [RecentActivity] = []
  
  private var timer: Timer?
  
  init() {
    // Mock data for UI development
    self.quickStats = QuickStats(
      weeklyDistance: 24.5,
      weeklyCalories: 3850,
      weeklyDuration: 3.5 * 3600, // 3.5 hours
      weeklySessionCount: 4,
      monthlyProgress: 0.72
    )
    
    self.recentActivities = [
      RecentActivity(
        date: Date().addingTimeInterval(-86400),
        distance: 5.2,
        duration: 4815,
        calories: 650,
        route: "Morning Trail"
      ),
      RecentActivity(
        date: Date().addingTimeInterval(-172800),
        distance: 3.8,
        duration: 3240,
        calories: 480,
        route: nil
      ),
      RecentActivity(
        date: Date().addingTimeInterval(-259200),
        distance: 6.1,
        duration: 5580,
        calories: 820,
        route: "River Path"
      )
    ]
  }
  
  func startSession() {
    activeSession = RuckingSession(
      startTime: Date(),
      distance: 0,
      calories: 0,
      averageSpeed: 0,
      packWeight: 45, // Default pack weight
      userWeight: 180 // Default user weight
    )
    
    // Start timer for updating session
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      Task { @MainActor in
        self.updateSession()
      }
    }
  }
  
  func pauseSession() {
    guard var session = activeSession else { return }
    session.isPaused = true
    activeSession = session
    timer?.invalidate()
  }
  
  func resumeSession() {
    guard var session = activeSession else { return }
    session.isPaused = false
    activeSession = session
    
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      Task { @MainActor in
        self.updateSession()
      }
    }
  }
  
  func stopSession() {
    guard var session = activeSession else { return }
    session.endTime = Date()
    
    // Save session to recent activities
    let activity = RecentActivity(
      date: session.startTime,
      distance: session.distance,
      duration: session.duration,
      calories: session.calories,
      route: nil
    )
    recentActivities.insert(activity, at: 0)
    
    activeSession = nil
    timer?.invalidate()
  }
  
  func refreshData() {
    // Placeholder for refreshing data
  }
  
  private func updateSession() {
    guard var session = activeSession, !session.isPaused else { return }
    
    // Mock data updates - in real app this would come from location/sensor data
    let elapsedMinutes = session.duration / 60
    session.distance = elapsedMinutes * 0.05 // Mock: 0.05 miles per minute (3 mph)
    session.averageSpeed = 3.0
    
    // RUCKCAL™ formula approximation
    let metValue = 5.5 // MET for rucking at 3 mph with 45lb pack
    session.calories = (metValue * session.userWeight * 0.453592 * session.duration) / 3600
    
    activeSession = session
  }
}