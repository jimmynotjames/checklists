//
//  CLNavigationStack.swift
//  checklists
//
//  Created by jimmyho on 5/15/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

/*
 Main navigation stack to try to separate out some things to keep things somewhat cleaner.

 TODO: Update toolbar buttons in nav bar to have same background as rest of screen.
 */

import SwiftUI

struct MainNavigationStack<Content: View>: View {
  @Binding var path: NavigationPath
  @ViewBuilder var content: () -> Content

  @State private var showingMainMenuView = false

  // For showing More Menu, to reset all Checklists.
  @State private var showingMoreMenu = false
  @State private var showingResetAlert = false

  var body: some View {
    ZStack {
      NavigationStack(path: $path) {
        content()
          .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
              Button(action: {
                menuButtonTapped()
              }) {
                Image("MenuIcon25x25")
                  .renderingMode(.template)
                  .accessibilityLabel("Miscellaneous Menu")
              }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
              Button(action: { showingMoreMenu = true }) {
                Image("MoreMenuIcon32x32")
                  .renderingMode(.template)
                  .accessibilityLabel("Checklists Menu")
              }
              .popover(isPresented: $showingMoreMenu, arrowEdge: .top) {
                MoreMenuView {
                  showingMoreMenu = false
                  showingResetAlert = true
                }
                .presentationCompactAdaptation(.popover)
              }
            }
          }
          .alert("Are you sure? This cannot be undone.", isPresented: $showingResetAlert) {
            Button("Reset All", role: .destructive) {
              DBManager.resetAllChecklists()
              showingResetAlert = false
            }
            Button("Cancel", role: .cancel) {
              showingResetAlert = false
            }
          }
      }
      .tint(CLColors.teal)
      if showingMainMenuView {
        // Full-cover nav transition doesn't go from left to right, so using a ZStack instead.
        MainMenuView(onDismiss: { showingMainMenuView = false })
          .transition(.move(edge: .leading))
          .zIndex(1)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: showingMainMenuView)
  }

  private func menuButtonTapped() {
    showingMainMenuView = true
  }
}

struct MoreMenuView: View {
  let onResetAll: () -> Void

  var body: some View {
    VStack {
      Button("Reset All", action: onResetAll)
        .foregroundColor(CLColors.teal)
        .padding(.horizontal, 16.0)
    }
  }
}
