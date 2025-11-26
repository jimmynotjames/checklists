//
//  SettingsView.swift
//  checklists
//
//  Created by jimmyho on 5/15/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

/*
 Features:
 TODO: BUG - Done button has wrong background.
 */

import SwiftUI

struct SettingsView: View {
  var onDismiss: (() -> Void)? = nil

  var body: some View {
    NavigationStack {
      List {
        Section("INFO") {
          Button(action: openPrivacyPolicy) {
            HStack(spacing: 12) {
              Image("PrivacyPolicyIcon25x25")
                .renderingMode(.original)
              Text("Privacy Policy")
                .foregroundColor(.black)
            }
          }
          .accessibilityLabel("Privacy Policy")
          .listRowBackground(Color.clear)
        }

        Section(footer: versionFooter) {
          EmptyView()
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(Color.clear)
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { onDismiss?() }
            .foregroundStyle(CLColors.teal)
        }
      }
      .onAppear {
        AnalyticsManager.logSettingsViewed()
      }
    }
  }

  private var versionFooter: some View {
    HStack {
      Spacer()
      Text("Version \(SettingsManager.shared.versionBuildString)")
        .font(.footnote)
        .foregroundStyle(.secondary)
      Spacer()
    }
  }

  private func openPrivacyPolicy() {
    AnalyticsManager.logViewPrivacyPolicy()
    if let url = URL(string: "https://www.termsfeed.com/privacy-policy/0420e699b562320b2beb80af0a4e08b9") {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }
}

