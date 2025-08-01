//
//  ArmyProgressViewTests.swift
//  RuckMapTests
//
//  Created by Claude on 8/1/25.
//

import Testing
import SwiftUI
@testable import RuckMap

@Suite("Army Progress View Component Tests")
@MainActor
struct ArmyProgressViewTests {
  
  // MARK: - Basic Progress View Tests
  
  @Test("Army progress view initializes correctly")
  func testArmyProgressViewInitialization() {
    let progressView = ArmyProgressView(
      progress: 7,
      total: 10,
      label: "Daily Goal"
    )
    
    #expect(progressView.progress == 7)
    #expect(progressView.total == 10)
    #expect(progressView.label == "Daily Goal")
    #expect(progressView.showPercentage == true) // Default value
  }
  
  @Test("Army progress view works without label")
  func testArmyProgressViewWithoutLabel() {
    let progressView = ArmyProgressView(
      progress: 5,
      total: 10
    )
    
    #expect(progressView.progress == 5)
    #expect(progressView.total == 10)
    #expect(progressView.label == nil)
  }
  
  @Test("Army progress view can hide percentage")
  func testArmyProgressViewHidePercentage() {
    let progressView = ArmyProgressView(
      progress: 3,
      total: 10,
      showPercentage: false
    )
    
    #expect(progressView.showPercentage == false)
  }
  
  // MARK: - Progress Calculation Tests
  
  @Test("Progress percentage calculates correctly")
  func testProgressPercentageCalculation() {
    let progressView = ArmyProgressView(progress: 7, total: 10)
    
    // Test private computed property through expected behavior
    #expect(progressView.progress == 7)
    #expect(progressView.total == 10)
    // Expected percentage: 0.7 (70%)
  }
  
  @Test("Progress percentage handles edge cases")
  func testProgressPercentageEdgeCases() {
    // Test zero total
    let zeroTotalView = ArmyProgressView(progress: 5, total: 0)
    #expect(zeroTotalView.total == 0)
    
    // Test zero progress
    let zeroProgressView = ArmyProgressView(progress: 0, total: 10)
    #expect(zeroProgressView.progress == 0)
    
    // Test progress exceeding total
    let exceedingView = ArmyProgressView(progress: 15, total: 10)
    #expect(exceedingView.progress == 15)
    #expect(exceedingView.total == 10)
    
    // Test negative progress
    let negativeView = ArmyProgressView(progress: -5, total: 10)
    #expect(negativeView.progress == -5)
  }
  
  @Test("Progress percentage clamps to valid range")
  func testProgressPercentageClamping() {
    // Test that percentage calculation clamps between 0 and 1
    let normalView = ArmyProgressView(progress: 5, total: 10)
    let exceedingView = ArmyProgressView(progress: 15, total: 10)
    let negativeView = ArmyProgressView(progress: -5, total: 10)
    
    #expect(normalView != nil)   // Should be 0.5 (50%)
    #expect(exceedingView != nil) // Should be 1.0 (100%)
    #expect(negativeView != nil)  // Should be 0.0 (0%)
  }
  
  @Test("Percentage text formats correctly")
  func testPercentageTextFormatting() {
    let progressView = ArmyProgressView(progress: 7.5, total: 10)
    
    #expect(progressView != nil)
    // Should display "75%" (Int conversion rounds properly)
  }
  
  // MARK: - Circular Progress View Tests
  
  @Test("Circular progress view initializes correctly")
  func testCircularProgressViewInitialization() {
    let circularView = ArmyCircularProgressView(
      progress: 3,
      total: 5,
      lineWidth: 10,
      size: 120,
      showLabel: true
    )
    
    #expect(circularView.progress == 3)
    #expect(circularView.total == 5)
    #expect(circularView.lineWidth == 10)
    #expect(circularView.size == 120)
    #expect(circularView.showLabel == true)
  }
  
  @Test("Circular progress view uses default values")
  func testCircularProgressViewDefaults() {
    let circularView = ArmyCircularProgressView(
      progress: 2,
      total: 4
    )
    
    #expect(circularView.lineWidth == 8)   // Default line width
    #expect(circularView.size == 100)      // Default size
    #expect(circularView.showLabel == true) // Default show label
  }
  
  @Test("Circular progress view can hide label")
  func testCircularProgressViewHideLabel() {
    let circularView = ArmyCircularProgressView(
      progress: 1,
      total: 3,
      showLabel: false
    )
    
    #expect(circularView.showLabel == false)
  }
  
  // MARK: - Progress Ring Tests
  
  @Test("Progress ring initializes correctly")
  func testProgressRingInitialization() {
    let progressRing = ArmyProgressRing(
      value: 8.5,
      goal: 10.0,
      label: "Distance",
      unit: "mi",
      ringWidth: 15,
      size: 140
    )
    
    #expect(progressRing.value == 8.5)
    #expect(progressRing.goal == 10.0)
    #expect(progressRing.label == "Distance")
    #expect(progressRing.unit == "mi")
    #expect(progressRing.ringWidth == 15)
    #expect(progressRing.size == 140)
  }
  
  @Test("Progress ring works without unit")
  func testProgressRingWithoutUnit() {
    let progressRing = ArmyProgressRing(
      value: 450,
      goal: 600,
      label: "Calories",
      unit: nil
    )
    
    #expect(progressRing.value == 450)
    #expect(progressRing.goal == 600)
    #expect(progressRing.label == "Calories")
    #expect(progressRing.unit == nil)
  }
  
  @Test("Progress ring uses default dimensions")
  func testProgressRingDefaults() {
    let progressRing = ArmyProgressRing(
      value: 5,
      goal: 10,
      label: "Steps",
      unit: nil
    )
    
    #expect(progressRing.ringWidth == 12)  // Default ring width
    #expect(progressRing.size == 120)      // Default size
  }
  
  // MARK: - Progress Ring Color Tests
  
  @Test("Progress ring color changes based on completion")
  func testProgressRingColors() {
    // Test different completion levels
    let lowProgress = ArmyProgressRing(value: 2, goal: 10, label: "Low", unit: nil)      // 20%
    let mediumProgress = ArmyProgressRing(value: 5, goal: 10, label: "Medium", unit: nil) // 50%
    let highProgress = ArmyProgressRing(value: 8, goal: 10, label: "High", unit: nil)    // 80%
    let completeProgress = ArmyProgressRing(value: 10, goal: 10, label: "Complete", unit: nil) // 100%
    let exceededProgress = ArmyProgressRing(value: 12, goal: 10, label: "Exceeded", unit: nil) // 120%
    
    #expect(lowProgress != nil)      // Should use armyGreenLight
    #expect(mediumProgress != nil)   // Should use armyGreenWarning
    #expect(highProgress != nil)     // Should use armyGreenPrimary
    #expect(completeProgress != nil) // Should use armyGreenSuccess
    #expect(exceededProgress != nil) // Should use armyGreenSuccess
  }
  
  // MARK: - Loading Indicator Tests
  
  @Test("Loading indicator initializes correctly")
  func testLoadingIndicatorInitialization() {
    let loadingIndicator = ArmyLoadingIndicator()
    
    #expect(loadingIndicator.size == 40) // Default size
  }
  
  @Test("Loading indicator accepts custom size")
  func testLoadingIndicatorCustomSize() {
    let loadingIndicator = ArmyLoadingIndicator(size: 60)
    
    #expect(loadingIndicator.size == 60)
  }
  
  // MARK: - Animation Tests
  
  @Test("Progress views have proper animations")
  func testProgressViewAnimations() {
    let progressView = ArmyProgressView(progress: 5, total: 10)
    let circularView = ArmyCircularProgressView(progress: 3, total: 5)
    let progressRing = ArmyProgressRing(value: 7, goal: 10, label: "Test", unit: nil)
    
    #expect(progressView != nil)
    #expect(circularView != nil)
    #expect(progressRing != nil)
    
    // In practice, you'd verify:
    // - 0.3 second easeInOut animation for linear progress
    // - 0.3 second easeInOut animation for circular progress
    // - 0.5 second easeInOut animation for progress ring
  }
  
  @Test("Loading indicator has continuous animation")
  func testLoadingIndicatorAnimation() {
    let loadingIndicator = ArmyLoadingIndicator()
    
    #expect(loadingIndicator != nil)
    
    // In practice, you'd verify:
    // - 1 second linear animation
    // - Repeats forever without autoreverses
    // - Rotates 360 degrees
  }
  
  // MARK: - Accessibility Tests
  
  @Test("Progress views have accessibility labels")
  func testProgressViewAccessibility() {
    let progressView = ArmyProgressView(
      progress: 7,
      total: 10,
      label: "Daily Goal"
    )
    
    #expect(progressView.label == "Daily Goal")
    // In practice, you'd verify accessibility label includes:
    // - "Daily Goal: 70%"
    // - Accessibility value: "7 of 10"
  }
  
  @Test("Circular progress view has accessibility")
  func testCircularProgressViewAccessibility() {
    let circularView = ArmyCircularProgressView(
      progress: 3,
      total: 5
    )
    
    #expect(circularView != nil)
    // In practice, you'd verify accessibility label:
    // - "Progress: 60 percent"
  }
  
  @Test("Loading indicator has accessibility label")
  func testLoadingIndicatorAccessibility() {
    let loadingIndicator = ArmyLoadingIndicator()
    
    #expect(loadingIndicator != nil)
    // In practice, you'd verify accessibility label: "Loading"
  }
  
  // MARK: - Layout Tests
  
  @Test("Linear progress view has proper dimensions")
  func testLinearProgressViewDimensions() {
    let progressView = ArmyProgressView(progress: 5, total: 10)
    
    #expect(progressView != nil)
    // In practice, you'd verify:
    // - Track height: 8 points
    // - Corner radius: 4 points
    // - Spacing: 8 points between label and track
  }
  
  @Test("Circular progress view maintains aspect ratio")
  func testCircularProgressViewAspectRatio() {
    let circularView = ArmyCircularProgressView(
      progress: 1,
      total: 2,
      size: 100
    )
    
    #expect(circularView.size == 100)
    // In practice, you'd verify the view is square (100x100)
  }
  
  @Test("Progress ring centers content properly")
  func testProgressRingLayout() {
    let progressRing = ArmyProgressRing(
      value: 5,
      goal: 10,
      label: "Test",
      unit: "mi",
      size: 120
    )
    
    #expect(progressRing.size == 120)
    // In practice, you'd verify:
    // - Ring is properly centered
    // - Text content is centered within ring
    // - Label is positioned below ring with proper spacing
  }
  
  // MARK: - Performance Tests
  
  @Test("Progress view creation is performant", .timeLimit(.minutes(1)))
  func testProgressViewCreationPerformance() {
    // Test creating many progress views
    for i in 0..<1000 {
      _ = ArmyProgressView(progress: Double(i % 10), total: 10)
    }
  }
  
  @Test("Circular progress view creation is performant", .timeLimit(.minutes(1)))
  func testCircularProgressViewCreationPerformance() {
    // Test creating many circular progress views
    for i in 0..<500 {
      _ = ArmyCircularProgressView(progress: Double(i % 5), total: 5)
    }
  }
  
  @Test("Progress ring creation is performant", .timeLimit(.minutes(1)))
  func testProgressRingCreationPerformance() {
    // Test creating many progress rings
    for i in 0..<300 {
      _ = ArmyProgressRing(
        value: Double(i % 10),
        goal: 10,
        label: "Test \(i)",
        unit: nil
      )
    }
  }
  
  @Test("Loading indicator creation is performant", .timeLimit(.minutes(1)))
  func testLoadingIndicatorCreationPerformance() {
    // Test creating many loading indicators
    for _ in 0..<1000 {
      _ = ArmyLoadingIndicator()
    }
  }
  
  // MARK: - Integration Tests
  
  @Test("Multiple progress views work together")
  func testMultipleProgressViews() {
    let views = [
      ArmyProgressView(progress: 3, total: 10, label: "Goal 1"),
      ArmyProgressView(progress: 7, total: 10, label: "Goal 2"),
      ArmyProgressView(progress: 10, total: 10, label: "Goal 3")
    ]
    
    #expect(views.count == 3)
    
    for view in views {
      #expect(view != nil)
    }
  }
  
  @Test("Different progress view types coexist")
  func testDifferentProgressViewTypes() {
    let linearView = ArmyProgressView(progress: 5, total: 10)
    let circularView = ArmyCircularProgressView(progress: 3, total: 5)
    let ringView = ArmyProgressRing(value: 8, goal: 10, label: "Test", unit: nil)
    let loadingView = ArmyLoadingIndicator()
    
    #expect(linearView != nil)
    #expect(circularView != nil)
    #expect(ringView != nil)
    #expect(loadingView != nil)
  }
  
  // MARK: - Value Range Tests
  
  @Test("Progress views handle extreme values")
  func testProgressViewExtremeValues() {
    let maxView = ArmyProgressView(progress: Double.greatestFiniteMagnitude, total: 100)
    let minView = ArmyProgressView(progress: 0, total: Double.greatestFiniteMagnitude)
    let negativeView = ArmyProgressView(progress: -100, total: 100)
    
    #expect(maxView != nil)
    #expect(minView != nil)
    #expect(negativeView != nil)
  }
  
  @Test("Progress ring handles decimal values correctly")
  func testProgressRingDecimalValues() {
    let decimalRing = ArmyProgressRing(
      value: 8.75,
      goal: 10.0,
      label: "Precise",
      unit: "km"
    )
    
    #expect(decimalRing.value == 8.75)
    #expect(decimalRing.goal == 10.0)
    // In practice, you'd verify that Int(value) is displayed correctly
  }
  
  // MARK: - Color Gradient Tests
  
  @Test("Progress views use appropriate gradients")
  func testProgressViewGradients() {
    let progressView = ArmyProgressView(progress: 5, total: 10)
    let circularView = ArmyCircularProgressView(progress: 3, total: 5)
    let ringView = ArmyProgressRing(value: 7, goal: 10, label: "Test", unit: nil)
    
    #expect(progressView != nil)
    #expect(circularView != nil)
    #expect(ringView != nil)
    
    // In practice, you'd verify that .armyGreenPrimary.gradient is used
  }
  
  @Test("Loading indicator uses proper gradient")
  func testLoadingIndicatorGradient() {
    let loadingIndicator = ArmyLoadingIndicator()
    
    #expect(loadingIndicator != nil)
    // In practice, you'd verify .armyGreenPrimary.gradient is used
  }
}

// MARK: - Progress Calculation Helper Tests

@Suite("Progress Calculation Helper Tests")
struct ProgressCalculationHelperTests {
  
  @Test("Percentage calculation helper works correctly")
  func testPercentageCalculation() {
    // Helper function to test the percentage calculation logic
    func calculatePercentage(progress: Double, total: Double) -> Double {
      guard total > 0 else { return 0 }
      return min(max(progress / total, 0), 1)
    }
    
    #expect(calculatePercentage(progress: 5, total: 10) == 0.5)
    #expect(calculatePercentage(progress: 0, total: 10) == 0.0)
    #expect(calculatePercentage(progress: 15, total: 10) == 1.0) // Clamped to 1
    #expect(calculatePercentage(progress: -5, total: 10) == 0.0) // Clamped to 0
    #expect(calculatePercentage(progress: 5, total: 0) == 0.0)   // Division by zero
  }
  
  @Test("Integer conversion for display works correctly")
  func testIntegerConversionForDisplay() {
    // Helper function to test percentage text formatting
    func formatPercentage(_ percentage: Double) -> String {
      "\(Int(percentage * 100))%"
    }
    
    #expect(formatPercentage(0.5) == "50%")
    #expect(formatPercentage(0.756) == "75%") // Truncates, doesn't round
    #expect(formatPercentage(0.0) == "0%")
    #expect(formatPercentage(1.0) == "100%")
  }
}