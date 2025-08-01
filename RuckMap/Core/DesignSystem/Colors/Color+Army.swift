//
//  Color+Army.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

// MARK: - Army Green Theme Using Built-in Colors

extension Color {
  // MARK: - Primary Army Green Colors
  // Using SwiftUI's built-in green with iOS 18+ mix modifier
  
  static let armyGreenPrimary: Color = Color(hue: 0.25, saturation: 0.7, brightness: 0.6)
  
  static let armyGreenSecondary: Color = Color(hue: 0.25, saturation: 0.6, brightness: 0.7)
  
  static let armyGreenTertiary: Color = Color(hue: 0.25, saturation: 0.5, brightness: 0.5)
  
  // MARK: - Supporting Colors
  
  static let armyGreenLight: Color = Color(hue: 0.25, saturation: 0.4, brightness: 0.8)
  
  static let armyGreenUltraLight: Color = Color(hue: 0.25, saturation: 0.3, brightness: 0.9)
  
  static let armyGreenDark: Color = Color(hue: 0.25, saturation: 0.6, brightness: 0.4)
  
  // MARK: - Semantic Colors
  // Using system colors for better light/dark mode adaptation
  
  static let armyBackgroundPrimary = Color(UIColor.systemBackground)
  static let armyBackgroundSecondary = Color(UIColor.secondarySystemBackground)
  static let armyBackgroundTertiary = Color(UIColor.tertiarySystemBackground)
  
  // MARK: - System Colors
  // Built on system colors with army green tinting
  
  static let armyGreenSuccess: Color = Color(hue: 0.25, saturation: 0.8, brightness: 0.7)
  
  static let armyGreenWarning: Color = Color(hue: 0.08, saturation: 0.7, brightness: 0.8)
  
  static let armyGreenError: Color = Color(hue: 0.0, saturation: 0.7, brightness: 0.7)
  
  // MARK: - Text Colors
  // Using hierarchical colors for automatic adaptation
  
  static let armyTextPrimary = Color.primary
  static let armyTextSecondary = Color.secondary
  static let armyTextTertiary = Color.secondary.opacity(0.7)
  
  // MARK: - Utility Colors
  
  static let armySeparator = Color(UIColor.separator)
  static let armyBorder = Color.gray.opacity(0.3)
  static let armyShadow = Color.black.opacity(0.1)
}

// MARK: - Color Modifiers for Army Theme

extension ShapeStyle where Self == Color {
  // Convenience accessors for common army green variations
  static var armyPrimary: Color { .armyGreenPrimary }
  static var armySecondary: Color { .armyGreenSecondary }
  static var armyTertiary: Color { .armyGreenTertiary }
  static var armyLight: Color { .armyGreenLight }
  static var armyDark: Color { .armyGreenDark }
}

// MARK: - Gradient Support

extension Color {
  var armyGradient: LinearGradient {
    LinearGradient(
      colors: [self, self.opacity(0.8)],
      startPoint: .top,
      endPoint: .bottom
    )
  }
  
  static var armyBackgroundGradient: LinearGradient {
    LinearGradient(
      colors: [
        Color(UIColor.systemBackground),
        Color(UIColor.secondarySystemBackground)
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }
}