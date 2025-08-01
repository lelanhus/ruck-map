//
//  CommunityView.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct CommunityView: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        Text("Community")
          .armyTextStyle(.largeTitle)
        
        Text("Community features coming soon")
          .armyTextStyle(.body)
      }
      .padding()
    }
    .background(Color.armyBackgroundPrimary)
  }
}

#Preview {
  NavigationStack {
    CommunityView()
      .navigationTitle("Community")
  }
}