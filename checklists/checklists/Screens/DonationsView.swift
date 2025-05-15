//
//  DonationsView.swift
//  checklists
//
//  Created by jimmyho on 5/15/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

/*
 Allows users to donate to the app.
 TODO: Implement updated StoreKit.
 */

import SwiftUI

struct DonationsView: View {
  var onDismiss: (() -> Void)? = nil

  var body: some View {
      VStack {
          Text("Donations")
          Button("Close") {
              onDismiss?()
          }
          .padding()
      }
      .navigationTitle("Donate")
      .navigationBarTitleDisplayMode(.inline)
  }
}
