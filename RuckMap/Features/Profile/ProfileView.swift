//
//  ProfileView.swift
//  RuckMap
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct ProfileView: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        Text("Profile")
          .armyTextStyle(.largeTitle)
        
        Text("Profile settings coming soon")
          .armyTextStyle(.body)
      }
      .padding()
    }
    .background(Color.armyBackgroundPrimary)
  }
}

#Preview {
  NavigationStack {
    ProfileView()
      .navigationTitle("Profile")
  }
}