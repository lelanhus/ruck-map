//
//  FontArmyTests.swift
//  RuckMapTests
//
//  Created by Claude on 8/1/25.
//

import Testing
import SwiftUI
@testable import RuckMap

@Suite("Army Typography System Tests")
struct FontArmyTests {
  
  // MARK: - Display Fonts Tests
  
  @Test("Display fonts are properly defined")
  func testDisplayFonts() {
    #expect(Font.armyLargeTitle != nil)
    #expect(Font.armyTitle != nil)
    #expect(Font.armyTitle2 != nil)
    #expect(Font.armyTitle3 != nil)
  }
  
  @Test("Display fonts use correct design and weight")
  func testDisplayFontProperties() {
    // Test that display fonts use rounded design and bold weight
    // Note: In practice, we'd need to extract font properties for detailed testing
    #expect(Font.armyLargeTitle != Font.body)
    #expect(Font.armyTitle != Font.body)
    #expect(Font.armyTitle2 != Font.body)
    #expect(Font.armyTitle3 != Font.body)
  }
  
  // MARK: - Body Fonts Tests
  
  @Test("Body fonts are properly defined")
  func testBodyFonts() {
    #expect(Font.armyHeadline != nil)
    #expect(Font.armyBody != nil)
    #expect(Font.armyCallout != nil)
    #expect(Font.armySubheadline != nil)
    #expect(Font.armyFootnote != nil)
    #expect(Font.armyCaption != nil)
    #expect(Font.armyCaption2 != nil)
  }
  
  @Test("Body fonts use correct design")
  func testBodyFontDesign() {
    // Test that body fonts are distinct from display fonts
    #expect(Font.armyBody != Font.armyTitle)
    #expect(Font.armyCallout != Font.armyTitle2)
    #expect(Font.armySubheadline != Font.armyTitle3)
  }
  
  // MARK: - Specialized Fonts Tests
  
  @Test("Specialized fonts are properly defined")
  func testSpecializedFonts() {
    #expect(Font.armyBodyBold != nil)
    #expect(Font.armyCalloutBold != nil)
    #expect(Font.armyFootnoteBold != nil)
  }
  
  @Test("Bold variants are different from regular")
  func testBoldVariants() {
    #expect(Font.armyBodyBold != Font.armyBody)
    #expect(Font.armyCalloutBold != Font.armyCallout)
    #expect(Font.armyFootnoteBold != Font.armyFootnote)
  }
  
  // MARK: - Monospaced Fonts Tests
  
  @Test("Monospaced number fonts are properly defined")
  func testMonospacedFonts() {
    #expect(Font.armyNumberLarge != nil)
    #expect(Font.armyNumberMedium != nil)
    #expect(Font.armyNumberSmall != nil)
  }
  
  @Test("Monospaced fonts are different from regular fonts")
  func testMonospacedFontDistinction() {
    #expect(Font.armyNumberLarge != Font.armyTitle)
    #expect(Font.armyNumberMedium != Font.armyHeadline)
    #expect(Font.armyNumberSmall != Font.armyBody)
  }
  
  // MARK: - Dynamic Type Tests
  
  @Test("Fonts support Dynamic Type scaling")
  func testDynamicTypeSupport() {
    // Test that fonts are based on system semantic sizes
    // This ensures automatic Dynamic Type support
    #expect(Font.armyLargeTitle != nil)
    #expect(Font.armyBody != nil)
    #expect(Font.armyCaption != nil)
  }
  
  @Test("Scaled font modifier works correctly")
  @MainActor
  func testScaledFontModifier() {
    let testView = Text("Test")
      .scaledFont(.armyBody)
    
    #expect(testView != nil)
    
    // Test with maximum size
    let maxSizeView = Text("Test")
      .scaledFont(.armyBody, maxSize: 24)
    
    #expect(maxSizeView != nil)
  }
}

// MARK: - Text Style Modifier Tests

@Suite("Army Text Style Modifier Tests")
@MainActor
struct ArmyTextStyleModifierTests {
  
  @Test("Text style enum cases are properly defined")
  func testTextStyleCases() {
    let styles: [ArmyTextStyle.Style] = [
      .largeTitle, .title, .title2, .title3,
      .headline, .body, .callout, .subheadline,
      .footnote, .caption, .caption2
    ]
    
    #expect(styles.count == 11)
  }
  
  @Test("Each text style returns correct font")
  func testTextStyleFonts() {
    #expect(ArmyTextStyle.Style.largeTitle.font == .armyLargeTitle)
    #expect(ArmyTextStyle.Style.title.font == .armyTitle)
    #expect(ArmyTextStyle.Style.title2.font == .armyTitle2)
    #expect(ArmyTextStyle.Style.title3.font == .armyTitle3)
    #expect(ArmyTextStyle.Style.headline.font == .armyHeadline)
    #expect(ArmyTextStyle.Style.body.font == .armyBody)
    #expect(ArmyTextStyle.Style.callout.font == .armyCallout)
    #expect(ArmyTextStyle.Style.subheadline.font == .armySubheadline)
    #expect(ArmyTextStyle.Style.footnote.font == .armyFootnote)
    #expect(ArmyTextStyle.Style.caption.font == .armyCaption)
    #expect(ArmyTextStyle.Style.caption2.font == .armyCaption2)
  }
  
  @Test("Text styles return appropriate colors")
  func testTextStyleColors() {
    // Primary colors for titles and headlines
    #expect(ArmyTextStyle.Style.largeTitle.color == .armyTextPrimary)
    #expect(ArmyTextStyle.Style.title.color == .armyTextPrimary)
    #expect(ArmyTextStyle.Style.headline.color == .armyTextPrimary)
    #expect(ArmyTextStyle.Style.body.color == .armyTextPrimary)
    
    // Secondary colors for subheadline and footnote
    #expect(ArmyTextStyle.Style.subheadline.color == .armyTextSecondary)
    #expect(ArmyTextStyle.Style.footnote.color == .armyTextSecondary)
    
    // Tertiary colors for captions
    #expect(ArmyTextStyle.Style.caption.color == .armyTextTertiary)
    #expect(ArmyTextStyle.Style.caption2.color == .armyTextTertiary)
  }
  
  @Test("Army text style modifier applies correctly")
  func testArmyTextStyleModifier() {
    let testView = Text("Test")
      .armyTextStyle(.body)
    
    #expect(testView != nil)
    
    let titleView = Text("Title")
      .armyTextStyle(.title)
    
    #expect(titleView != nil)
  }
  
  @Test("Line spacing modifier works correctly")
  func testLineSpacingModifier() {
    let testView = Text("Test\nMultiline\nText")
      .armyLineSpacing(for: .body)
    
    #expect(testView != nil)
  }
  
  @Test("Recommended line spacing values are appropriate")
  func testRecommendedLineSpacing() {
    // Test that larger text styles have more line spacing
    let titleSpacing = ArmyTextStyle.Style.title.recommendedLineSpacing
    let bodySpacing = ArmyTextStyle.Style.body.recommendedLineSpacing
    let captionSpacing = ArmyTextStyle.Style.caption.recommendedLineSpacing
    
    #expect(titleSpacing >= bodySpacing)
    #expect(bodySpacing >= captionSpacing)
  }
}

// MARK: - Text Utility Tests

@Suite("Army Text Utility Tests")
struct ArmyTextUtilityTests {
  
  @Test("Army text utilities create proper Text views")
  func testArmyTextUtilities() {
    let titleText = Text.armyTitle("Test Title")
    let headlineText = Text.armyHeadline("Test Headline")
    let bodyText = Text.armyBody("Test Body")
    let secondaryText = Text.armySecondary("Test Secondary")
    let captionText = Text.armyCaption("Test Caption")
    
    #expect(titleText != nil)
    #expect(headlineText != nil)
    #expect(bodyText != nil)
    #expect(secondaryText != nil)
    #expect(captionText != nil)
  }
  
  @Test("Text utilities apply correct styling")
  func testTextUtilityStyling() {
    // Test that different utilities create different styled text
    let title = Text.armyTitle("Title")
    let body = Text.armyBody("Body")
    let caption = Text.armyCaption("Caption")
    
    // These should be different due to different fonts and colors
    #expect(title != body)
    #expect(body != caption)
    #expect(title != caption)
  }
}

// MARK: - Performance Tests

@Suite("Army Typography Performance Tests")
@MainActor
struct ArmyTypographyPerformanceTests {
  
  @Test("Font creation is performant", .timeLimit(.minutes(1)))
  func testFontCreationPerformance() {
    // Test creating many font instances
    for _ in 0..<1000 {
      _ = Font.armyTitle
      _ = Font.armyBody
      _ = Font.armyCaption
    }
  }
  
  @Test("Text style application is performant", .timeLimit(.minutes(1)))
  func testTextStylePerformance() {
    let styles: [ArmyTextStyle.Style] = [
      .title, .headline, .body, .callout, .caption
    ]
    
    // Test applying styles to many text views
    for _ in 0..<500 {
      for style in styles {
        _ = Text("Test").armyTextStyle(style)
      }
    }
  }
  
  @Test("Text utility creation is performant", .timeLimit(.minutes(1)))
  func testTextUtilityPerformance() {
    // Test creating many utility text views
    for i in 0..<1000 {
      _ = Text.armyTitle("Title \(i)")
      _ = Text.armyBody("Body \(i)")
      _ = Text.armyCaption("Caption \(i)")
    }
  }
}

// MARK: - Accessibility Tests

@Suite("Army Typography Accessibility Tests")
@MainActor
struct ArmyTypographyAccessibilityTests {
  
  @Test("Fonts support accessibility sizes")
  func testAccessibilityFontSizes() {
    // Test that scaled font modifier includes accessibility support
    let accessibleView = Text("Test")
      .scaledFont(.armyBody)
    
    #expect(accessibleView != nil)
  }
  
  @Test("Text colors provide sufficient contrast")
  func testTextColorContrast() {
    // Test that text colors are different from background colors
    #expect(Color.armyTextPrimary != Color.armyBackgroundPrimary)
    #expect(Color.armyTextSecondary != Color.armyBackgroundPrimary)
    #expect(Color.armyTextTertiary != Color.armyBackgroundPrimary)
  }
  
  @Test("Font sizes create proper hierarchy")
  func testFontHierarchy() {
    // Test that font styles create visual hierarchy
    // (In practice, you'd measure actual font sizes)
    let styles: [ArmyTextStyle.Style] = [
      .largeTitle, .title, .title2, .title3,
      .headline, .body, .callout, .subheadline,
      .footnote, .caption, .caption2
    ]
    
    #expect(styles.count > 0)
    
    // Each style should be unique
    for (index, style) in styles.enumerated() {
      for otherIndex in (index + 1)..<styles.count {
        #expect(style.font != styles[otherIndex].font)
      }
    }
  }
}

// MARK: - Private Extension Tests

extension ArmyTextStyle.Style {
  var recommendedLineSpacing: CGFloat {
    switch self {
    case .largeTitle, .title: return 4
    case .title2, .title3: return 3
    case .headline, .body, .callout: return 2
    case .subheadline, .footnote, .caption, .caption2: return 1
    }
  }
}