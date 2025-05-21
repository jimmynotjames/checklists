//
//  CLNavigationStack.swift
//  checklists
//
//  Created by jimmyho on 5/15/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

/*
 Features:
 - Applies consistent look and feel across all uses of NavigationStack.
 // TODO: Remove this class if I only have the tint? Because the one in MainMenuView uses a white X button.
 */

import SwiftUI

struct CLNavigationStack<Content: View>: View {
  @Binding var path: NavigationPath
  @ViewBuilder var content: () -> Content

  var body: some View {
    NavigationStack(path: $path) {
      content()
    }
    .tint(CLColors.teal)
  }
}
