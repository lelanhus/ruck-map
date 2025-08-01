//
//  ActiveSessionCard.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct ActiveSessionCard: View {
  let session: RuckingSession
  let onPause: () -> Void
  let onResume: () -> Void
  let onStop: () -> Void
  
  @State private var elapsedTime: TimeInterval = 0
  let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  
  var body: some View {
    ArmyCard {
      VStack(spacing: 16) {
        // Header
        HStack {
          Label("Active Session", systemImage: "figure.walk")
            .font(.armyHeadline)
            .foregroundStyle(Color.armyGreenPrimary)
          
          Spacer()
          
          if !session.isPaused {
            PulsingIndicator()
              .accessibilityLabel("Session is active")
          } else {
            Image(systemName: "pause.circle.fill")
              .font(.system(size: 20))
              .foregroundStyle(Color.armyGreenWarning)
              .accessibilityLabel("Session is paused")
          }
        }
        
        // Stats Grid
        HStack(spacing: 24) {
          StatItem(
            label: "Time",
            value: formatTime(elapsedTime),
            icon: "clock"
          )
          
          StatItem(
            label: "Distance",
            value: String(format: "%.2f mi", session.distance),
            icon: "map"
          )
          
          StatItem(
            label: "Calories",
            value: "\(Int(session.calories))",
            icon: "flame"
          )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session statistics")
        
        // Control Buttons
        HStack(spacing: 12) {
          if session.isPaused {
            ArmyButton.secondary("Resume", action: onResume)
          } else {
            ArmyButton.secondary("Pause", action: onPause)
          }
          
          ArmyButton.destructive("Stop", action: onStop)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session controls")
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Active rucking session")
    .accessibilityValue(sessionAccessibilityValue)
    .accessibilityIdentifier("activeSessionCard")
    .onReceive(timer) { _ in
      if !session.isPaused {
        elapsedTime = Date().timeIntervalSince(session.startTime)
      }
    }
    .onAppear {
      elapsedTime = Date().timeIntervalSince(session.startTime)
    }
  }
  
  private var sessionAccessibilityValue: String {
    let status = session.isPaused ? "paused" : "active"
    let time = formatTime(elapsedTime)
    let distance = String(format: "%.2f miles", session.distance)
    let calories = "\(Int(session.calories)) calories"
    return "Session is \(status), time elapsed: \(time), distance: \(distance), calories burned: \(calories)"
  }
  }
  
  private func formatTime(_ interval: TimeInterval) -> String {
    let hours = Int(interval) / 3600
    let minutes = Int(interval) % 3600 / 60
    let seconds = Int(interval) % 60
    
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
      return String(format: "%d:%02d", minutes, seconds)
    }
  }
}

// MARK: - Supporting Views

struct StatItem: View {
  let label: String
  let value: String
  let icon: String
  
  var body: some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.system(size: 16))
        .foregroundStyle(Color.armyGreenSecondary)
        .accessibilityHidden(true) // Icon is decorative
      
      Text(value)
        .font(.armyNumberMedium)
        .foregroundStyle(Color.armyTextPrimary)
      
      Text(label)
        .armyTextStyle(.caption2)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value)")
    .accessibilityIdentifier("statItem_\(label.replacingOccurrences(of: " ", with: "_"))")
  }
}

struct PulsingIndicator: View {
  @State private var scale: CGFloat = 1.0
  @State private var opacity: Double = 1.0
  
  var body: some View {
    Circle()
      .fill(Color.armyGreenSuccess)
      .frame(width: 12, height: 12)
      .scaleEffect(scale)
      .opacity(opacity)
      .onAppear {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
          scale = 1.3
          opacity = 0.6
        }
      }
      .accessibilityLabel("Session active indicator")
      .accessibilityAddTraits(.playsSound) // Indicates this is a dynamic element
      .accessibilityIdentifier("pulsingIndicator")
  }
}