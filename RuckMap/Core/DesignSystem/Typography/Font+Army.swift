//
//  Font+Army.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

// MARK: - Typography System with Dynamic Type Support

extension Font {
  // MARK: - Display Fonts
  // Using system semantic sizes for automatic Dynamic Type support
  
  static let armyLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
  static let armyTitle = Font.system(.title, design: .rounded, weight: .bold)
  static let armyTitle2 = Font.system(.title2, design: .rounded, weight: .bold)
  static let armyTitle3 = Font.system(.title3, design: .rounded, weight: .semibold)
  
  // MARK: - Body Fonts
  
  static let armyHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
  static let armyBody = Font.system(.body, design: .default, weight: .regular)
  static let armyCallout = Font.system(.callout, design: .default, weight: .regular)
  static let armySubheadline = Font.system(.subheadline, design: .default, weight: .regular)
  static let armyFootnote = Font.system(.footnote, design: .default, weight: .regular)
  static let armyCaption = Font.system(.caption, design: .default, weight: .regular)
  static let armyCaption2 = Font.system(.caption2, design: .default, weight: .regular)
  
  // MARK: - Specialized Fonts
  
  static let armyBodyBold = Font.system(.body, design: .default, weight: .bold)
  static let armyCalloutBold = Font.system(.callout, design: .default, weight: .semibold)
  static let armyFootnoteBold = Font.system(.footnote, design: .default, weight: .semibold)
  
  // MARK: - Monospaced Fonts for Numbers
  
  static let armyNumberLarge = Font.system(.title, design: .monospaced, weight: .bold)
  static let armyNumberMedium = Font.system(.headline, design: .monospaced, weight: .semibold)
  static let armyNumberSmall = Font.system(.body, design: .monospaced, weight: .regular)
}

// MARK: - Text Style Modifiers

struct ArmyTextStyle: ViewModifier {
  enum Style {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case body
    case callout
    case subheadline
    case footnote
    case caption
    case caption2
    
    var font: Font {
      switch self {
      case .largeTitle: return .armyLargeTitle
      case .title: return .armyTitle
      case .title2: return .armyTitle2
      case .title3: return .armyTitle3
      case .headline: return .armyHeadline
      case .body: return .armyBody
      case .callout: return .armyCallout
      case .subheadline: return .armySubheadline
      case .footnote: return .armyFootnote
      case .caption: return .armyCaption
      case .caption2: return .armyCaption2
      }
    }
    
    var color: Color {
      switch self {
      case .largeTitle, .title, .title2, .title3, .headline:
        return .armyTextPrimary
      case .body, .callout:
        return .armyTextPrimary
      case .subheadline, .footnote:
        return .armyTextSecondary
      case .caption, .caption2:
        return .armyTextTertiary
      }
    }
  }
  
  let style: Style
  
  func body(content: Content) -> some View {
    content
      .font(style.font)
      .foregroundStyle(style.color)
  }
}

// MARK: - View Extensions

extension View {
  /// Applies army text style with appropriate font and color
  func armyTextStyle(_ style: ArmyTextStyle.Style) -> some View {
    modifier(ArmyTextStyle(style: style))
  }
  
  /// Makes text scale with Dynamic Type up to a maximum size
  func scaledFont(_ font: Font, maxSize: CGFloat? = nil) -> some View {
    self.font(font)
      .dynamicTypeSize(...DynamicTypeSize.accessibility3)
  }
}

// MARK: - Text Utilities

extension Text {
  /// Creates a title with army styling
  static func armyTitle(_ text: String) -> Text {
    Text(text)
      .font(.armyTitle)
      .foregroundStyle(Color.armyTextPrimary)
  }
  
  /// Creates a headline with army styling
  static func armyHeadline(_ text: String) -> Text {
    Text(text)
      .font(.armyHeadline)
      .foregroundStyle(Color.armyTextPrimary)
  }
  
  /// Creates body text with army styling
  static func armyBody(_ text: String) -> Text {
    Text(text)
      .font(.armyBody)
      .foregroundStyle(Color.armyTextPrimary)
  }
  
  /// Creates secondary text with army styling
  static func armySecondary(_ text: String) -> Text {
    Text(text)
      .font(.armySubheadline)
      .foregroundStyle(Color.armyTextSecondary)
  }
  
  /// Creates caption text with army styling
  static func armyCaption(_ text: String) -> Text {
    Text(text)
      .font(.armyCaption)
      .foregroundStyle(Color.armyTextTertiary)
  }
}

// MARK: - Line Spacing

extension View {
  /// Applies consistent line spacing based on text style
  func armyLineSpacing(for style: ArmyTextStyle.Style) -> some View {
    self.lineSpacing(style.recommendedLineSpacing)
  }
}

private extension ArmyTextStyle.Style {
  var recommendedLineSpacing: CGFloat {
    switch self {
    case .largeTitle, .title: return 4
    case .title2, .title3: return 3
    case .headline, .body, .callout: return 2
    case .subheadline, .footnote, .caption, .caption2: return 1
    }
  }
}