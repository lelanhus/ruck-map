//
//  RoutesView.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct RoutesView: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        Text("Routes")
          .armyTextStyle(.largeTitle)
        
        Text("Route planning coming soon")
          .armyTextStyle(.body)
      }
      .padding()
    }
    .background(Color.armyBackgroundPrimary)
  }
}

#Preview {
  NavigationStack {
    RoutesView()
      .navigationTitle("Routes")
  }
}