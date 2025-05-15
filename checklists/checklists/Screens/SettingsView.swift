//
//  SettingsView.swift
//  checklists
//
//  Created by jimmyho on 5/15/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

/*
 Features:
 TODO: Shows app version, including if it's a debug build.
 TODO: Shows Privacy Policy link.
 */

import SwiftUI

struct SettingsView: View {
  var onDismiss: (() -> Void)? = nil

  var body: some View {
      VStack {
          Text("Settings")
          Button("Close") {
              onDismiss?()
          }
          .padding()
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
  }
}
