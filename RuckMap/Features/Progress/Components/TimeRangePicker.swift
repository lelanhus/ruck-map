//
//  TimeRangePicker.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct TimeRangePicker: View {
  @Binding var selection: TimeRange
  
  var body: some View {
    HStack(spacing: 0) {
      ForEach(TimeRange.allCases, id: \.self) { range in
        Button(action: { 
          withAnimation(.easeInOut(duration: 0.2)) {
            selection = range
          }
        }) {
          Text(range.rawValue)
            .font(.armyCallout)
            .foregroundStyle(selection == range ? .white : .armyGreenPrimary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selection == range ? Color.armyGreenPrimary : Color.clear)
            )
        }
        .accessibilityLabel("Time range: \(range.rawValue)")
        .accessibilityHint("Tap to select \(range.rawValue) time range")
        .accessibilityAddTraits(selection == range ? .isSelected : [])
        .accessibilityIdentifier("timeRangeButton_\(range.rawValue)")
        .frame(minHeight: 44) // Ensure minimum touch target
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.armyBackgroundSecondary)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(Color.armyGreenPrimary, lineWidth: 1)
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Time range picker")
    .accessibilityHint("Select a time range to view data for that period")
    .accessibilityIdentifier("timeRangePicker")
  }
}