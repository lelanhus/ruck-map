//
//  ArmyProgressView.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct ArmyProgressView: View {
  let progress: Double
  let total: Double
  var label: String? = nil
  var showPercentage: Bool = true
  
  private var percentage: Double {
    guard total > 0 else { return 0 }
    return min(max(progress / total, 0), 1)
  }
  
  private var percentageText: String {
    "\(Int(percentage * 100))%"
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if label != nil || showPercentage {
        HStack {
          if let label = label {
            Text(label)
              .armyTextStyle(.caption)
          }
          
          Spacer()
          
          if showPercentage {
            Text(percentageText)
              .armyTextStyle(.caption)
          }
        }
      }
      
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          // Background track
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.armyBackgroundTertiary)
            .frame(height: 8)
          
          // Progress fill
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.armyGreenPrimary.gradient)
            .frame(width: geometry.size.width * percentage, height: 8)
            .animation(.easeInOut(duration: 0.3), value: percentage)
        }
      }
      .frame(height: 8)
      .accessibilityLabel(label ?? "Progress")
      .accessibilityValue("\(Int(progress)) of \(Int(total))")
      .accessibilityAddTraits(.updatesFrequently)
      .accessibilityIdentifier("progressView_\((label ?? "progress").replacingOccurrences(of: " ", with: "_"))")
      .accessibilityActions {
        // Custom action for users to get more detailed progress information
        AccessibilityAction("Get detailed progress") {
          // This would announce the detailed progress information
        }
      }
    }
  }
}

// MARK: - Circular Progress View

struct ArmyCircularProgressView: View {
  let progress: Double
  let total: Double
  var lineWidth: CGFloat = 8
  var size: CGFloat = 100
  var showLabel: Bool = true
  
  private var percentage: Double {
    guard total > 0 else { return 0 }
    return min(max(progress / total, 0), 1)
  }
  
  var body: some View {
    ZStack {
      // Background circle
      Circle()
        .stroke(
          Color.armyBackgroundTertiary,
          lineWidth: lineWidth
        )
      
      // Progress circle
      Circle()
        .trim(from: 0, to: percentage)
        .stroke(
          Color.armyGreenPrimary.gradient,
          style: StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round
          )
        )
        .rotationEffect(.degrees(-90))
        .animation(.easeInOut(duration: 0.3), value: percentage)
      
      if showLabel {
        VStack(spacing: 2) {
          Text("\(Int(percentage * 100))")
            .font(.armyNumberMedium)
            .foregroundStyle(Color.armyTextPrimary)
          
          Text("%")
            .armyTextStyle(.caption)
        }
      }
    }
    .frame(width: size, height: size)
    .accessibilityLabel("Circular progress")
    .accessibilityValue("\(Int(percentage * 100)) percent complete")
    .accessibilityAddTraits(.updatesFrequently)
    .accessibilityIdentifier("circularProgressView")
  }
}

// MARK: - Progress Ring

struct ArmyProgressRing: View {
  let value: Double
  let goal: Double
  let label: String
  let unit: String?
  var ringWidth: CGFloat = 12
  var size: CGFloat = 120
  
  private var percentage: Double {
    guard goal > 0 else { return 0 }
    return min(max(value / goal, 0), 1)
  }
  
  private var ringColor: Color {
    if percentage >= 1 {
      return .armyGreenSuccess
    } else if percentage >= 0.7 {
      return .armyGreenPrimary
    } else if percentage >= 0.3 {
      return .armyGreenWarning
    } else {
      return .armyGreenLight
    }
  }
  
  var body: some View {
    VStack(spacing: 16) {
      ZStack {
        // Background ring
        Circle()
          .stroke(
            Color.armyBackgroundTertiary,
            lineWidth: ringWidth
          )
        
        // Progress ring
        Circle()
          .trim(from: 0, to: percentage)
          .stroke(
            ringColor.gradient,
            style: StrokeStyle(
              lineWidth: ringWidth,
              lineCap: .round
            )
          )
          .rotationEffect(.degrees(-90))
          .animation(.easeInOut(duration: 0.5), value: percentage)
        
        // Center content
        VStack(spacing: 4) {
          HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(Int(value))")
              .font(.armyNumberLarge)
              .foregroundStyle(Color.armyTextPrimary)
            
            if let unit = unit {
              Text(unit)
                .armyTextStyle(.caption)
            }
          }
          
          Text("of \(Int(goal))")
            .armyTextStyle(.caption)
        }
      }
      .frame(width: size, height: size)
      
      Text(label)
        .armyTextStyle(.callout)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label) progress ring")
    .accessibilityValue(accessibilityValue)
    .accessibilityAddTraits(.updatesFrequently)
    .accessibilityIdentifier("progressRing_\(label.replacingOccurrences(of: " ", with: "_"))")
  }
  
  private var accessibilityValue: String {
    let unitText = unit ?? ""
    let progressText = "\(Int(value)) \(unitText) of \(Int(goal)) \(unitText)"
    let percentText = "\(Int(percentage * 100)) percent complete"
    
    if percentage >= 1.0 {
      return "\(progressText), goal achieved, \(percentText)"
    } else {
      return "\(progressText), \(percentText)"
    }
  }
}

// MARK: - Loading Indicator

struct ArmyLoadingIndicator: View {
  @State private var rotation: Double = 0
  var size: CGFloat = 40
  
  var body: some View {
    Circle()
      .trim(from: 0, to: 0.7)
      .stroke(
        Color.armyGreenPrimary.gradient,
        style: StrokeStyle(
          lineWidth: 4,
          lineCap: .round
        )
      )
      .frame(width: size, height: size)
      .rotationEffect(.degrees(rotation))
      .onAppear {
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
          rotation = 360
        }
      }
      .accessibilityLabel("Loading")
      .accessibilityAddTraits(.updatesFrequently)
      .accessibilityIdentifier("loadingIndicator")
  }
}

// MARK: - Preview

#Preview("Progress Components") {
  ScrollView {
    VStack(spacing: 32) {
      // Linear Progress
      VStack(spacing: 16) {
        ArmyProgressView(
          progress: 7,
          total: 10,
          label: "Daily Goal"
        )
        
        ArmyProgressView(
          progress: 45,
          total: 100,
          label: "Weekly Progress",
          showPercentage: false
        )
        
        ArmyProgressView(
          progress: 85,
          total: 100
        )
      }
      .padding(.horizontal)
      
      // Circular Progress
      HStack(spacing: 24) {
        ArmyCircularProgressView(
          progress: 3,
          total: 5,
          size: 80
        )
        
        ArmyCircularProgressView(
          progress: 75,
          total: 100,
          lineWidth: 12,
          size: 100
        )
        
        ArmyCircularProgressView(
          progress: 1,
          total: 3,
          lineWidth: 6,
          size: 60,
          showLabel: false
        )
      }
      
      // Progress Rings
      HStack(spacing: 24) {
        ArmyProgressRing(
          value: 8.5,
          goal: 10,
          label: "Distance",
          unit: "mi"
        )
        
        ArmyProgressRing(
          value: 450,
          goal: 600,
          label: "Calories",
          unit: nil,
          size: 100
        )
      }
      
      // Loading Indicator
      ArmyLoadingIndicator()
    }
    .padding()
  }
  .background(Color.armyBackgroundPrimary)
}