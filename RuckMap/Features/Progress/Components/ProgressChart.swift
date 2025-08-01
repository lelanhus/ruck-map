//
//  ProgressChart.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI
import Charts

struct ProgressChart: View {
  let data: [ChartDataPoint]
  
  var body: some View {
    ArmyCard {
      VStack(alignment: .leading, spacing: 12) {
        Text("Distance Over Time")
          .armyTextStyle(.headline)
        
        Chart(data) { point in
          BarMark(
            x: .value("Date", point.label),
            y: .value("Distance", point.value)
          )
          .foregroundStyle(Color.armyGreenPrimary.gradient)
          .cornerRadius(4)
        }
        .frame(height: 200)
        .chartYAxis {
          AxisMarks(position: .leading) { value in
            AxisValueLabel {
              if let miles = value.as(Double.self) {
                Text("\(Int(miles))")
                  .armyTextStyle(.caption2)
              }
            }
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
              .foregroundStyle(Color.armySeparator)
          }
        }
        .chartXAxis {
          AxisMarks { value in
            AxisValueLabel {
              if let label = value.as(String.self) {
                Text(label)
                  .armyTextStyle(.caption2)
              }
            }
          }
        }
        .chartPlotStyle { plotArea in
          plotArea
            .background(Color.armyBackgroundSecondary.opacity(0.3))
            .cornerRadius(8)
        }
      }
    }
  }
}