//
//  PersonalRecordsSection.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct PersonalRecordsSection: View {
  let records: [PersonalRecord]
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Personal Records")
        .armyTextStyle(.headline)
      
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(records) { record in
          RecordCard(record: record)
        }
      }
    }
  }
}

// MARK: - Record Card

struct RecordCard: View {
  let record: PersonalRecord
  
  var body: some View {
    ArmyCard(padding: 12) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: "trophy.fill")
            .font(.system(size: 14))
            .foregroundStyle(Color.armyGreenWarning)
          
          Text(record.title)
            .armyTextStyle(.caption)
            .lineLimit(1)
        }
        
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(record.value)
            .font(.armyNumberMedium)
            .foregroundStyle(Color.armyTextPrimary)
          
          if let unit = record.unit {
            Text(unit)
              .armyTextStyle(.caption2)
          }
        }
        
        if let improvement = record.improvement {
          HStack(spacing: 4) {
            Image(systemName: "arrow.up.right")
              .font(.system(size: 10, weight: .semibold))
            Text("+\(Int(improvement))%")
              .armyTextStyle(.caption2)
          }
          .foregroundStyle(Color.armyGreenSuccess)
        }
        
        Text(formatDate(record.date))
          .armyTextStyle(.caption2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
  
  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter.string(from: date)
  }
}