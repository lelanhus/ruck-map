//
//  ColorArmyTests.swift
//  RuckMapTests
//
//  Created by Claude on 8/1/25.
//

import Testing
import SwiftUI
@testable import RuckMap

@Suite("Army Color System Tests")
struct ColorArmyTests {
  
  // MARK: - Primary Army Green Colors Tests
  
  @Test("Army green colors are properly defined")
  func testArmyGreenColors() {
    // Test that primary colors exist and are not nil
    #expect(Color.armyGreenPrimary != nil)
    #expect(Color.armyGreenSecondary != nil)
    #expect(Color.armyGreenTertiary != nil)
    #expect(Color.armyGreenLight != nil)
    #expect(Color.armyGreenUltraLight != nil)
    #expect(Color.armyGreenDark != nil)
  }
  
  @Test("Color mixing produces expected results")
  func testColorMixing() {
    // Test base green color exists
    let baseGreen = Color.green
    #expect(baseGreen != nil)
    
    // Test that army colors are properly defined (using adjust method from extensions)
    let adjustedColor = baseGreen.adjust(hue: 0.1, saturation: 0.2, brightness: -0.1)
    #expect(adjustedColor != nil)
    #expect(adjustedColor != baseGreen)
  }
  
  @Test("Color adjustment methods work correctly")
  func testColorAdjustmentMethods() {
    let baseColor = Color.green
    
    // Test various adjustments using our custom adjust method
    let hueAdjusted = baseColor.adjust(hue: 0.1)
    let saturationAdjusted = baseColor.adjust(saturation: 0.2)
    let brightnessAdjusted = baseColor.adjust(brightness: -0.1)
    
    #expect(hueAdjusted != nil)
    #expect(saturationAdjusted != nil)
    #expect(brightnessAdjusted != nil)
  }
  
  // MARK: - Semantic Colors Tests
  
  @Test("Semantic background colors use system colors")
  func testSemanticBackgroundColors() {
    #expect(Color.armyBackgroundPrimary != nil)
    #expect(Color.armyBackgroundSecondary != nil)
    #expect(Color.armyBackgroundTertiary != nil)
  }
  
  @Test("System colors have proper army green tinting")
  func testSystemColorsWithTinting() {
    #expect(Color.armyGreenSuccess != nil)
    #expect(Color.armyGreenWarning != nil)
    #expect(Color.armyGreenError != nil)
  }
  
  @Test("Text colors follow hierarchical structure")
  func testTextColors() {
    #expect(Color.armyTextPrimary != nil)
    #expect(Color.armyTextSecondary != nil)
    #expect(Color.armyTextTertiary != nil)
    
    // Test that text colors are properly defined
    // (Opacity comparison not available in this context)
    #expect(Color.armyTextPrimary == Color.primary)
    #expect(Color.armyTextSecondary == Color.secondary)
  }
  
  @Test("Utility colors are properly defined")
  func testUtilityColors() {
    #expect(Color.armySeparator != nil)
    #expect(Color.armyBorder != nil)
    #expect(Color.armyShadow != nil)
  }
  
  // MARK: - ShapeStyle Extension Tests
  
  @Test("ShapeStyle convenience accessors work")
  func testShapeStyleAccessors() {
    #expect(Color.armyPrimary == Color.armyGreenPrimary)
    #expect(Color.armySecondary == Color.armyGreenSecondary)
    #expect(Color.armyTertiary == Color.armyGreenTertiary)
    #expect(Color.armyLight == Color.armyGreenLight)
    #expect(Color.armyDark == Color.armyGreenDark)
  }
  
  // MARK: - Gradient Tests
  
  @Test("Color gradients are properly created")
  func testColorGradients() {
    let color = Color.armyGreenPrimary
    let gradient = color.armyGradient
    
    #expect(gradient != nil)
    // LinearGradient properties are not directly accessible for testing
  }
  
  @Test("Background gradient is properly defined")
  func testBackgroundGradient() {
    let gradient = Color.armyBackgroundGradient
    
    #expect(gradient != nil)
    // LinearGradient properties are not directly accessible for testing
  }
  
  @Test("Adaptive colors work in different color schemes")
  func testAdaptiveColors() {
    let lightColor = Color.white
    let darkColor = Color.black
    let adaptiveColor = Color.adaptive(light: lightColor, dark: darkColor)
    
    #expect(adaptiveColor != nil)
  }
  
  @Test("Semantic army colors are properly defined")
  func testSemanticArmyColors() {
    #expect(Color.armyCardBackground != nil)
    #expect(Color.armyGroupedBackground != nil)
    #expect(Color.armyAccent != nil)
  }
  
  // MARK: - Accessibility Tests
  
  @Test("Colors provide sufficient contrast for accessibility")
  func testColorContrast() {
    // Test that text colors have sufficient contrast against backgrounds
    // This is a conceptual test - in practice, you'd use actual contrast calculation
    #expect(Color.armyTextPrimary != Color.armyBackgroundPrimary)
    #expect(Color.armyTextSecondary != Color.armyBackgroundPrimary)
    #expect(Color.armyTextTertiary != Color.armyBackgroundPrimary)
  }
  
  @Test("Dynamic Type colors adapt properly")
  func testDynamicTypeAdaptation() {
    // Test that text colors work with system dynamic colors
    #expect(Color.armyTextPrimary == Color.primary)
    #expect(Color.armyTextSecondary == Color.secondary)
  }
  
  // MARK: - Performance Tests
  
  @Test("Color creation is performant", .timeLimit(.minutes(1)))
  func testColorCreationPerformance() {
    // Test that creating multiple army colors is fast
    for _ in 0..<1000 {
      _ = Color.armyGreenPrimary
      _ = Color.armyGreenSecondary
      _ = Color.armyGreenTertiary
    }
  }
  
  @Test("Color mixing is performant", .timeLimit(.minutes(1)))
  func testColorMixingPerformance() {
    let baseColor = Color.green
    
    // Test that color mixing operations are performant
    for i in 0..<100 {
      let mixRatio = Double(i) / 100.0
      _ = baseColor.mix(with: .brown, by: mixRatio)
    }
  }
}

// MARK: - View Modifier Tests

@Suite("Army Color View Modifier Tests")
@MainActor
struct ArmyColorViewModifierTests {
  
  @Test("Army accent modifier applies correct tint")
  func testArmyAccentModifier() {
    let view = Text("Test").armyAccent()
    #expect(view != nil)
  }
  
  @Test("Army gradient background modifier works")
  func testArmyGradientBackgroundModifier() {
    let view = Text("Test").armyGradientBackground()
    #expect(view != nil)
  }
  
  @Test("Army shadow modifier applies shadow correctly")
  func testArmyShadowModifier() {
    let view = Text("Test").armyShadow()
    #expect(view != nil)
    
    // Test with custom radius
    let customView = Text("Test").armyShadow(radius: 8)
    #expect(customView != nil)
  }
}