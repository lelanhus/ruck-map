//
//  Color+Extensions.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

// MARK: - Additional Color Utilities

extension Color {
  /// Adjusts HSB values of a color
  /// - Parameters:
  ///   - hue: Hue adjustment (-1.0 to 1.0)
  ///   - saturation: Saturation adjustment (-1.0 to 1.0)
  ///   - brightness: Brightness adjustment (-1.0 to 1.0)
  /// - Returns: Adjusted color
  func adjust(
    hue: Double = 0,
    saturation: Double = 0,
    brightness: Double = 0
  ) -> Color {
    let uiColor = UIColor(self)
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    
    uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    
    // Apply adjustments with bounds checking
    let newHue = (h + CGFloat(hue)).truncatingRemainder(dividingBy: 1.0)
    let newSaturation = max(0, min(1, s + CGFloat(saturation)))
    let newBrightness = max(0, min(1, b + CGFloat(brightness)))
    
    return Color(hue: newHue, saturation: newSaturation, brightness: newBrightness, opacity: a)
  }
}

// MARK: - View Modifiers for Colors

extension View {
  /// Applies army green accent color to the view
  func armyAccent() -> some View {
    self.tint(.armyGreenPrimary)
  }
  
  /// Applies army green gradient background
  func armyGradientBackground() -> some View {
    self.background(Color.armyBackgroundGradient)
  }
  
  /// Applies subtle army shadow
  func armyShadow(radius: CGFloat = 4) -> some View {
    self.shadow(
      color: .armyShadow,
      radius: radius,
      x: 0,
      y: 2
    )
  }
}

// MARK: - Dynamic Color Creation

extension Color {
  /// Creates a dynamic color that adapts to color scheme
  /// - Parameters:
  ///   - light: Color for light mode
  ///   - dark: Color for dark mode
  /// - Returns: Adaptive color
  static func adaptive(light: Color, dark: Color) -> Color {
    Color(UIColor { traitCollection in
      traitCollection.userInterfaceStyle == .dark
        ? UIColor(dark)
        : UIColor(light)
    })
  }
}

// MARK: - Semantic Army Colors

extension Color {
  static let armyCardBackground = adaptive(
    light: .white,
    dark: Color(hue: 0.25, saturation: 0.05, brightness: 0.15)
  )
  
  static let armyGroupedBackground = adaptive(
    light: Color(UIColor.systemGroupedBackground),
    dark: Color(hue: 0.25, saturation: 0.08, brightness: 0.1)
  )
  
  static let armyAccent = adaptive(
    light: .armyGreenPrimary,
    dark: .armyGreenSecondary
  )
}