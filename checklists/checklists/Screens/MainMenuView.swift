//
//  MainMenuView.swift
//  checklists
//
//  Created by jimmyho on 5/15/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

/*
 Features:
 - Tapping Feedback button opens mail client to send feedback email.
 - Tapping Rate in App Store button opens App Store to write-a-review page.
 - TODO: Donate!
 - TODO: Refine formating/spacing/fonts
 */

import SwiftUI
import RealmSwift

struct MainMenuView: View {
  var onDismiss: (() -> Void)? = nil

  // For managing navigation state.
  @State private var navigationPath = NavigationPath()
  @State private var showingSettingsView = false

  var body: some View {
    NavigationStack(path: $navigationPath) {
      ZStack {
        CLColors.darkBlueGray.ignoresSafeArea()
        List {
          MainMenuRowButton(action: openFeedback, imageName: "MainMenuFeedbackIcon", text: "Feedback")
          MainMenuRowButton(action: openRateInAppStore, imageName: "MainMenuRateInAppStoreIcon", text: "Rate in App Store")
          MainMenuRowButton(action: { navigationPath.append("donate") }, imageName: "MainMenuDonateIcon", text: "Donate!")
          MainMenuRowButton(action: openSettings, imageName: "MainMenuSettingsIcon", text: "Settings")
        }
        .listStyle(.plain)
      }
      .toolbar {
        CLToolbarItem(placement: .navigationBarLeading) {
          Button(action: { onDismiss?() }) {
            Image("StopIcon")
              .imageScale(.large)
              .accessibilityLabel("Close Menu")
              .tint(.white)
          }
        }
      }
      .sheet(isPresented: $showingSettingsView) {
        SettingsView(onDismiss: { showingSettingsView = false })
          .presentationDetents([.large])
      }
      .navigationDestination(for: String.self) { value in
        switch value {
        case "donate": DonationsView(onDismiss: { navigationPath.removeLast() })
        default:
          EmptyView()
        }
      }
    }
  }

  private func openFeedback() {
    guard let url = URL(string: "mailto:jimmyho.appfeedback@gmail.com?subject=Feedback%20for%20reChecklist%20App") else { return }
    UIApplication.shared.open(url)
  }

  private func openRateInAppStore() {
    guard let url = URL(string: "https://itunes.apple.com/app/id1475724536?action=write-review") else { return }
    UIApplication.shared.open(url)
  }

  private func openSettings() {
    showingSettingsView = true
    /* TODO: BUG - This isn't working
      DispatchQueue.main.async {
        withAnimation(.none) {
          onDismiss?()
        }
      }
     */
  }
}

struct MainMenuRowButton: View {
  let action: () -> Void
  let imageName: String
  let text: String

  var body: some View {
    Button(action: action) {
      MainMenuRowLabel(imageName: imageName, text: text)
    }
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
  }
}

// The icons were 195x195 pixels, and blew up the size of each row.
// Label did not have a way to constrain the size of the image,
// and I did not want to resize the icons myself.
struct MainMenuRowLabel: View {
  let imageName: String
  let text: String

  var body: some View {
    HStack {
      Image(imageName)
        .resizable()
        .frame(width: 48, height: 48)
      Text(text)
        .font(.title2)
        .foregroundColor(.white)
    }
  }
}

#Preview {
  MainMenuView()
}
