//
//  ArmyButton.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct ArmyButton: View {
  enum ButtonStyle {
    case primary
    case secondary
    case tertiary
    case destructive
  }
  
  let title: String
  let style: ButtonStyle
  let action: () -> Void
  
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.colorScheme) private var colorScheme
  
  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.armyHeadline)
        .foregroundStyle(foregroundColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(backgroundView)
        .overlay(borderOverlay)
    }
    .buttonStyle(ArmyButtonPressStyle())
    .accessibilityLabel(title)
    .accessibilityHint(accessibilityHint)
    .accessibilityAddTraits(.isButton)
    .accessibilityIdentifier(accessibilityIdentifier)
    .frame(minHeight: 44) // Ensure minimum touch target
  }
  
  private var accessibilityHint: String {
    switch style {
    case .primary:
      return "Primary action button"
    case .secondary:
      return "Secondary action button"
    case .tertiary:
      return "Additional action button"
    case .destructive:
      return "Destructive action - this action cannot be undone"
    }
  }
  
  private var accessibilityIdentifier: String {
    let stylePrefix = switch style {
    case .primary: "primary"
    case .secondary: "secondary"
    case .tertiary: "tertiary"
    case .destructive: "destructive"
    }
    return "\(stylePrefix)Button_\(title.replacingOccurrences(of: " ", with: "_"))"
  }
  
  @ViewBuilder
  private var backgroundView: some View {
    switch style {
    case .primary:
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(isEnabled ? Color.armyGreenPrimary : Color.armyGreenLight)
    case .secondary:
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.clear)
    case .tertiary:
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.armyBackgroundSecondary)
    case .destructive:
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(isEnabled ? Color.armyGreenError : Color.armyGreenLight)
    }
  }
  
  @ViewBuilder
  private var borderOverlay: some View {
    if style == .secondary {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.armyGreenPrimary, lineWidth: 2)
    }
  }
  
  private var foregroundColor: Color {
    switch style {
    case .primary:
      return .white
    case .secondary:
      return .armyGreenPrimary
    case .tertiary:
      return .armyGreenPrimary
    case .destructive:
      return .white
    }
  }
}

// MARK: - Button Press Style

struct ArmyButtonPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .opacity(configuration.isPressed ? 0.8 : 1.0)
      .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
  }
}

// MARK: - Button Variants

extension ArmyButton {
  /// Creates a primary action button
  static func primary(_ title: String, action: @escaping () -> Void) -> ArmyButton {
    ArmyButton(title: title, style: .primary, action: action)
  }
  
  /// Creates a secondary action button
  static func secondary(_ title: String, action: @escaping () -> Void) -> ArmyButton {
    ArmyButton(title: title, style: .secondary, action: action)
  }
  
  /// Creates a tertiary action button
  static func tertiary(_ title: String, action: @escaping () -> Void) -> ArmyButton {
    ArmyButton(title: title, style: .tertiary, action: action)
  }
  
  /// Creates a destructive action button
  static func destructive(_ title: String, action: @escaping () -> Void) -> ArmyButton {
    ArmyButton(title: title, style: .destructive, action: action)
  }
}

// MARK: - Compact Button

struct ArmyCompactButton: View {
  let title: String
  let systemImage: String
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.armyCallout)
        .foregroundStyle(Color.armyGreenPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.armyBackgroundSecondary)
        )
    }
    .buttonStyle(ArmyButtonPressStyle())
    .accessibilityLabel(title)
    .accessibilityHint("Compact action button")
    .accessibilityAddTraits(.isButton)
    .accessibilityIdentifier("compactButton_\(title.replacingOccurrences(of: " ", with: "_"))")
    .frame(minHeight: 44) // Ensure minimum touch target
  }
}

// MARK: - Preview

#Preview("Button Styles") {
  VStack(spacing: 16) {
    ArmyButton.primary("Start Ruck") {
      print("Primary tapped")
    }
    
    ArmyButton.secondary("View Routes") {
      print("Secondary tapped")
    }
    
    ArmyButton.tertiary("Settings") {
      print("Tertiary tapped")
    }
    
    ArmyButton.destructive("End Session") {
      print("Destructive tapped")
    }
    
    ArmyCompactButton(
      title: "Add Route",
      systemImage: "plus.circle"
    ) {
      print("Compact tapped")
    }
  }
  .padding()
  .background(Color.armyBackgroundPrimary)
}