//
//  StartRuckCard.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct StartRuckCard: View {
  let onStart: () -> Void
  
  var body: some View {
    ArmyCard {
      VStack(spacing: 20) {
        // Icon
        ZStack {
          Circle()
            .fill(Color.armyGreenUltraLight)
            .frame(width: 80, height: 80)
          
          Image(systemName: "figure.walk")
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(Color.armyGreenPrimary)
        }
        .accessibilityHidden(true) // Decorative icon
        
        // Text
        VStack(spacing: 8) {
          Text("Ready to Ruck?")
            .armyTextStyle(.title3)
          
          Text("Track your distance, pace, and calories")
            .armyTextStyle(.subheadline)
            .multilineTextAlignment(.center)
        }
        
        // Start Button
        ArmyButton.primary("Start Ruck", action: onStart)
      }
      .frame(maxWidth: .infinity)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Start new ruck session")
    .accessibilityHint("Track your distance, pace, and calories during your ruck")
    .accessibilityIdentifier("startRuckCard")
  }
}