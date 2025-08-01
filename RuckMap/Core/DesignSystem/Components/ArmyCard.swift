//
//  ArmyCard.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct ArmyCard<Content: View>: View {
  let content: Content
  var padding: CGFloat = 16
  var backgroundColor: Color = .armyCardBackground
  
  init(
    padding: CGFloat = 16,
    backgroundColor: Color = .armyCardBackground,
    @ViewBuilder content: () -> Content
  ) {
    self.padding = padding
    self.backgroundColor = backgroundColor
    self.content = content()
  }
  
  var body: some View {
    content
      .padding(padding)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(backgroundColor)
      )
      .armyShadow()
      .accessibilityElement(children: .combine)
  }
}

// MARK: - Specialized Card Types

struct ArmyInfoCard: View {
  let title: String
  let subtitle: String?
  let systemImage: String
  
  init(
    title: String,
    subtitle: String? = nil,
    systemImage: String
  ) {
    self.title = title
    self.subtitle = subtitle
    self.systemImage = systemImage
  }
  
  var body: some View {
    ArmyCard {
      HStack(spacing: 12) {
        Image(systemName: systemImage)
          .font(.armyTitle3)
          .foregroundStyle(Color.armyGreenPrimary)
          .frame(width: 40, height: 40)
          .background(
            Circle()
              .fill(Color.armyGreenUltraLight)
          )
          .accessibilityHidden(true) // Icon is decorative
        
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .armyTextStyle(.headline)
          
          if let subtitle = subtitle {
            Text(subtitle)
              .armyTextStyle(.caption)
          }
        }
        
        Spacer()
      }
    }
    .accessibilityLabel(accessibilityLabel)
    .accessibilityIdentifier("infoCard_\(title.replacingOccurrences(of: " ", with: "_"))")
  }
  
  private var accessibilityLabel: String {
    if let subtitle = subtitle {
      return "\(title), \(subtitle)"
    } else {
      return title
    }
  }
}

// MARK: - Stat Card

struct ArmyStatCard: View {
  let label: String
  let value: String
  let unit: String?
  let trend: Trend?
  
  enum Trend {
    case up(Double)
    case down(Double)
    case neutral
    
    var color: Color {
      switch self {
      case .up: return .armyGreenSuccess
      case .down: return .armyGreenError
      case .neutral: return .armyTextSecondary
      }
    }
    
    var icon: String {
      switch self {
      case .up: return "arrow.up.right"
      case .down: return "arrow.down.right"
      case .neutral: return "minus"
      }
    }
    
    var text: String {
      switch self {
      case .up(let percent):
        return "+\(Int(percent))%"
      case .down(let percent):
        return "-\(Int(percent))%"
      case .neutral:
        return "0%"
      }
    }
  }
  
  init(
    label: String,
    value: String,
    unit: String? = nil,
    trend: Trend? = nil
  ) {
    self.label = label
    self.value = value
    self.unit = unit
    self.trend = trend
  }
  
  var body: some View {
    ArmyCard(padding: 12) {
      VStack(alignment: .leading, spacing: 8) {
        Text(label)
          .armyTextStyle(.caption)
        
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(value)
            .font(.armyNumberLarge)
            .foregroundStyle(Color.armyTextPrimary)
          
          if let unit = unit {
            Text(unit)
              .armyTextStyle(.callout)
          }
        }
        
        if let trend = trend {
          HStack(spacing: 4) {
            Image(systemName: trend.icon)
              .font(.system(size: 12, weight: .semibold))
              .accessibilityHidden(true) // Trend icon is decorative
            Text(trend.text)
              .armyTextStyle(.caption)
          }
          .foregroundStyle(trend.color)
        }
      }
    }
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue(accessibilityValue)
    .accessibilityIdentifier("statCard_\(label.replacingOccurrences(of: " ", with: "_"))")
  }
  
  private var accessibilityLabel: String {
    return label
  }
  
  private var accessibilityValue: String {
    var description = value
    if let unit = unit {
      description += " \(unit)"
    }
    if let trend = trend {
      switch trend {
      case .up(let percent):
        description += ", increased by \(Int(percent)) percent"
      case .down(let percent):
        description += ", decreased by \(Int(percent)) percent"
      case .neutral:
        description += ", no change"
      }
    }
    return description
  }
}

// MARK: - List Item Card

struct ArmyListItemCard: View {
  let title: String
  let subtitle: String?
  let trailing: String?
  let action: (() -> Void)?
  
  init(
    title: String,
    subtitle: String? = nil,
    trailing: String? = nil,
    action: (() -> Void)? = nil
  ) {
    self.title = title
    self.subtitle = subtitle
    self.trailing = trailing
    self.action = action
  }
  
  var body: some View {
    Button(action: action ?? {}) {
      ArmyCard(padding: 12) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(title)
              .armyTextStyle(.body)
            
            if let subtitle = subtitle {
              Text(subtitle)
                .armyTextStyle(.caption)
            }
          }
          
          Spacer()
          
          if let trailing = trailing {
            Text(trailing)
              .armyTextStyle(.callout)
          }
          
          if action != nil {
            Image(systemName: "chevron.right")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Color.armyTextTertiary)
              .accessibilityHidden(true) // Chevron is decorative
          }
        }
      }
    }
    .buttonStyle(PlainButtonStyle())
    .disabled(action == nil)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(action != nil ? "Tap to select" : nil)
    .accessibilityAddTraits(action != nil ? .isButton : [])
    .accessibilityIdentifier("listItemCard_\(title.replacingOccurrences(of: " ", with: "_"))")
    .frame(minHeight: 44) // Ensure minimum touch target
  }
  
  private var accessibilityLabel: String {
    var description = title
    if let subtitle = subtitle {
      description += ", \(subtitle)"
    }
    if let trailing = trailing {
      description += ", \(trailing)"
    }
    return description
  }
}

// MARK: - Preview

#Preview("Card Variations") {
  ScrollView {
    VStack(spacing: 16) {
      // Basic Card
      ArmyCard {
        Text("Basic Card Content")
          .armyTextStyle(.body)
      }
      
      // Info Cards
      ArmyInfoCard(
        title: "Morning Ruck",
        subtitle: "5.2 miles • 1:23:45",
        systemImage: "figure.walk"
      )
      
      ArmyInfoCard(
        title: "Rest Day",
        systemImage: "bed.double"
      )
      
      // Stat Cards
      HStack(spacing: 12) {
        ArmyStatCard(
          label: "Distance",
          value: "12.5",
          unit: "mi",
          trend: .up(15)
        )
        
        ArmyStatCard(
          label: "Calories",
          value: "1,245",
          trend: .down(5)
        )
      }
      
      // List Item Cards
      VStack(spacing: 8) {
        ArmyListItemCard(
          title: "Central Park Loop",
          subtitle: "4.2 miles • Moderate",
          trailing: "45 min",
          action: { print("Route selected") }
        )
        
        ArmyListItemCard(
          title: "Riverside Trail",
          subtitle: "6.8 miles • Challenging",
          trailing: "1h 20m"
        )
      }
    }
    .padding()
  }
  .background(Color.armyBackgroundPrimary)
}