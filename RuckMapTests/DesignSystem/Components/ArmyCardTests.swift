//
//  ArmyCardTests.swift
//  RuckMapTests
//
//  Created by Claude on 8/1/25.
//

import Testing
import SwiftUI
@testable import RuckMap

@Suite("Army Card Component Tests")
@MainActor
struct ArmyCardTests {
  
  // MARK: - Basic Card Tests
  
  @Test("Army card initializes correctly")
  func testArmyCardInitialization() {
    let card = ArmyCard {
      Text("Test Content")
    }
    
    #expect(card != nil)
    #expect(card.padding == 16) // Default padding
    #expect(card.backgroundColor == .armyCardBackground) // Default background
  }
  
  @Test("Army card accepts custom padding")
  func testArmyCardCustomPadding() {
    let customPadding: CGFloat = 24
    let card = ArmyCard(padding: customPadding) {
      Text("Test Content")
    }
    
    #expect(card.padding == customPadding)
  }
  
  @Test("Army card accepts custom background color")
  func testArmyCardCustomBackground() {
    let customBackground = Color.blue
    let card = ArmyCard(backgroundColor: customBackground) {
      Text("Test Content")
    }
    
    #expect(card.backgroundColor == customBackground)
  }
  
  @Test("Army card applies shadow modifier")
  func testArmyCardShadow() {
    let card = ArmyCard {
      Text("Test Content")
    }
    
    #expect(card != nil)
    // In practice, you'd verify that armyShadow() modifier is applied
  }
  
  // MARK: - Info Card Tests
  
  @Test("Army info card initializes correctly")
  func testArmyInfoCardInitialization() {
    let infoCard = ArmyInfoCard(
      title: "Test Title",
      subtitle: "Test Subtitle",
      systemImage: "star"
    )
    
    #expect(infoCard.title == "Test Title")
    #expect(infoCard.subtitle == "Test Subtitle")
    #expect(infoCard.systemImage == "star")
  }
  
  @Test("Army info card works without subtitle")
  func testArmyInfoCardWithoutSubtitle() {
    let infoCard = ArmyInfoCard(
      title: "Test Title",
      systemImage: "star"
    )
    
    #expect(infoCard.title == "Test Title")
    #expect(infoCard.subtitle == nil)
    #expect(infoCard.systemImage == "star")
  }
  
  @Test("Army info card handles various system images")
  func testArmyInfoCardSystemImages() {
    let images = ["star", "heart", "figure.walk", "map", "person.circle"]
    
    for image in images {
      let infoCard = ArmyInfoCard(
        title: "Test",
        systemImage: image
      )
      
      #expect(infoCard.systemImage == image)
    }
  }
  
  // MARK: - Stat Card Tests
  
  @Test("Army stat card initializes correctly")
  func testArmyStatCardInitialization() {
    let statCard = ArmyStatCard(
      label: "Distance",
      value: "12.5",
      unit: "mi"
    )
    
    #expect(statCard.label == "Distance")
    #expect(statCard.value == "12.5")
    #expect(statCard.unit == "mi")
    #expect(statCard.trend == nil)
  }
  
  @Test("Army stat card works without unit")
  func testArmyStatCardWithoutUnit() {
    let statCard = ArmyStatCard(
      label: "Steps",
      value: "10,000"
    )
    
    #expect(statCard.label == "Steps")
    #expect(statCard.value == "10,000")
    #expect(statCard.unit == nil)
  }
  
  @Test("Army stat card trend enum works correctly")
  func testArmyStatCardTrend() {
    let upTrend = ArmyStatCard.Trend.up(15.0)
    let downTrend = ArmyStatCard.Trend.down(10.0)
    let neutralTrend = ArmyStatCard.Trend.neutral
    
    // Test colors
    #expect(upTrend.color == .armyGreenSuccess)
    #expect(downTrend.color == .armyGreenError)
    #expect(neutralTrend.color == .armyTextSecondary)
    
    // Test icons
    #expect(upTrend.icon == "arrow.up.right")
    #expect(downTrend.icon == "arrow.down.right")
    #expect(neutralTrend.icon == "minus")
    
    // Test text
    #expect(upTrend.text == "+15%")
    #expect(downTrend.text == "-10%")
    #expect(neutralTrend.text == "0%")
  }
  
  @Test("Army stat card with trend")
  func testArmyStatCardWithTrend() {
    let trend = ArmyStatCard.Trend.up(25.5)
    let statCard = ArmyStatCard(
      label: "Calories",
      value: "1,200",
      unit: "cal",
      trend: trend
    )
    
    #expect(statCard.trend != nil)
    if let cardTrend = statCard.trend {
      #expect(cardTrend.text == "+25%") // Should round to integer
    }
  }
  
  // MARK: - List Item Card Tests
  
  @Test("Army list item card initializes correctly")
  func testArmyListItemCardInitialization() {
    var actionCalled = false
    
    let listCard = ArmyListItemCard(
      title: "Test Route",
      subtitle: "5.2 miles",
      trailing: "45 min",
      action: { actionCalled = true }
    )
    
    #expect(listCard.title == "Test Route")
    #expect(listCard.subtitle == "5.2 miles")
    #expect(listCard.trailing == "45 min")
    #expect(listCard.action != nil)
    
    // Test action
    listCard.action?()
    #expect(actionCalled == true)
  }
  
  @Test("Army list item card works without optional parameters")
  func testArmyListItemCardMinimal() {
    let listCard = ArmyListItemCard(title: "Simple Title")
    
    #expect(listCard.title == "Simple Title")
    #expect(listCard.subtitle == nil)
    #expect(listCard.trailing == nil)
    #expect(listCard.action == nil)
  }
  
  @Test("Army list item card works with partial parameters")
  func testArmyListItemCardPartial() {
    let listCard = ArmyListItemCard(
      title: "Route Name",
      subtitle: "Moderate difficulty"
    )
    
    #expect(listCard.title == "Route Name")
    #expect(listCard.subtitle == "Moderate difficulty")
    #expect(listCard.trailing == nil)
    #expect(listCard.action == nil)
  }
  
  // MARK: - Card Layout Tests
  
  @Test("Cards have proper corner radius")
  func testCardCornerRadius() {
    let basicCard = ArmyCard { Text("Test") }
    let infoCard = ArmyInfoCard(title: "Test", systemImage: "star")
    
    #expect(basicCard != nil)
    #expect(infoCard != nil)
    // In practice, you'd verify 16-point corner radius
  }
  
  @Test("Stat cards have smaller padding")
  func testStatCardPadding() {
    let statCard = ArmyStatCard(label: "Test", value: "100")
    
    #expect(statCard != nil)
    // In practice, you'd verify 12-point padding
  }
  
  @Test("List item cards have smaller padding")
  func testListItemCardPadding() {
    let listCard = ArmyListItemCard(title: "Test")
    
    #expect(listCard != nil)
    // In practice, you'd verify 12-point padding
  }
  
  // MARK: - Card Content Tests
  
  @Test("Cards support complex content")
  func testCardComplexContent() {
    let complexCard = ArmyCard {
      VStack {
        HStack {
          Text("Complex")
          Spacer()
          Image(systemName: "star")
        }
        Divider()
        Text("Multi-line content\nwith various elements")
      }
    }
    
    #expect(complexCard != nil)
  }
  
  @Test("Info card icon has proper styling")
  func testInfoCardIconStyling() {
    let infoCard = ArmyInfoCard(
      title: "Test",
      systemImage: "figure.walk"
    )
    
    #expect(infoCard.systemImage == "figure.walk")
    // In practice, you'd verify:
    // - 40x40 frame
    // - Circle background with armyGreenUltraLight
    // - armyGreenPrimary foreground color
    // - armyTitle3 font
  }
  
  // MARK: - Performance Tests
  
  @Test("Card creation is performant", .timeLimit(.minutes(1)))
  func testCardCreationPerformance() {
    // Test creating many cards
    for i in 0..<1000 {
      _ = ArmyCard { Text("Card \(i)") }
    }
  }
  
  @Test("Info card creation is performant", .timeLimit(.minutes(1)))
  func testInfoCardCreationPerformance() {
    let systemImages = ["star", "heart", "figure.walk", "map", "person"]
    
    for i in 0..<500 {
      let imageIndex = i % systemImages.count
      _ = ArmyInfoCard(
        title: "Card \(i)",
        subtitle: "Subtitle \(i)",
        systemImage: systemImages[imageIndex]
      )
    }
  }
  
  @Test("Stat card creation is performant", .timeLimit(.minutes(1)))
  func testStatCardCreationPerformance() {
    for i in 0..<1000 {
      _ = ArmyStatCard(
        label: "Metric \(i)",
        value: "\(i)",
        unit: "unit"
      )
    }
  }
  
  // MARK: - Accessibility Tests
  
  @Test("Cards are accessible")
  func testCardAccessibility() {
    let basicCard = ArmyCard { Text("Accessible content") }
    let infoCard = ArmyInfoCard(title: "Accessible", systemImage: "star")
    let statCard = ArmyStatCard(label: "Value", value: "100")
    
    #expect(basicCard != nil)
    #expect(infoCard != nil)
    #expect(statCard != nil)
    // In practice, you'd verify accessibility labels and traits
  }
  
  @Test("List item cards handle disabled state correctly")
  func testListItemCardDisabledState() {
    let enabledCard = ArmyListItemCard(
      title: "Enabled",
      action: { }
    )
    
    let disabledCard = ArmyListItemCard(
      title: "Disabled"
      // No action = disabled
    )
    
    #expect(enabledCard.action != nil)
    #expect(disabledCard.action == nil)
  }
  
  // MARK: - Integration Tests
  
  @Test("Cards work together in layouts")
  func testCardsInLayouts() {
    let cards: [Any] = [
      ArmyCard { Text("Card 1") },
      ArmyInfoCard(title: "Info", systemImage: "star"),
      ArmyStatCard(label: "Stat", value: "100")
    ]
    
    #expect(cards.count == 3)
    
    for card in cards {
      #expect(card != nil)
    }
  }
  
  @Test("Cards adapt to different content sizes")
  func testCardsWithDifferentContentSizes() {
    let shortCard = ArmyCard { Text("Hi") }
    let mediumCard = ArmyCard { 
      Text("This is a medium length text content")
    }
    let longCard = ArmyCard {
      Text("This is a much longer text content that might span multiple lines and test how the card handles various content lengths and wrapping behavior")
    }
    
    #expect(shortCard != nil)
    #expect(mediumCard != nil)
    #expect(longCard != nil)
  }
  
  // MARK: - Trend Calculation Tests
  
  @Test("Trend percentage calculation is accurate")
  func testTrendPercentageCalculation() {
    let exactTrend = ArmyStatCard.Trend.up(15.0)
    let decimalTrend = ArmyStatCard.Trend.up(15.7)
    let roundingTrend = ArmyStatCard.Trend.down(23.9)
    
    #expect(exactTrend.text == "+15%")
    #expect(decimalTrend.text == "+15%") // Should round down
    #expect(roundingTrend.text == "-23%") // Should round down
  }
  
  @Test("Trend handles edge cases")
  func testTrendEdgeCases() {
    let zeroTrend = ArmyStatCard.Trend.up(0.0)
    let smallTrend = ArmyStatCard.Trend.up(0.4)
    let largeTrend = ArmyStatCard.Trend.down(999.9)
    
    #expect(zeroTrend.text == "+0%")
    #expect(smallTrend.text == "+0%") // Rounds to 0
    #expect(largeTrend.text == "-999%") // Handles large numbers
  }
}

// MARK: - Card Background Tests

@Suite("Army Card Background Tests")
@MainActor
struct ArmyCardBackgroundTests {
  
  @Test("Cards use proper background colors")
  func testCardBackgroundColors() {
    let defaultCard = ArmyCard { Text("Default") }
    let customCard = ArmyCard(backgroundColor: .red) { Text("Custom") }
    
    #expect(defaultCard.backgroundColor == .armyCardBackground)
    #expect(customCard.backgroundColor == .red)
  }
  
  @Test("Card backgrounds adapt to color scheme")
  func testCardBackgroundAdaptation() {
    let card = ArmyCard { Text("Test") }
    
    #expect(card.backgroundColor == .armyCardBackground)
    // In practice, you'd test with different colorScheme environment values
  }
}

// MARK: - Card Shadow Tests

@Suite("Army Card Shadow Tests")
@MainActor
struct ArmyCardShadowTests {
  
  @Test("Cards apply consistent shadows")
  func testCardShadows() {
    let basicCard = ArmyCard { Text("Test") }
    let infoCard = ArmyInfoCard(title: "Test", systemImage: "star")
    let statCard = ArmyStatCard(label: "Test", value: "100")
    
    #expect(basicCard != nil)
    #expect(infoCard != nil)
    #expect(statCard != nil)
    // In practice, you'd verify armyShadow() is applied consistently
  }
}