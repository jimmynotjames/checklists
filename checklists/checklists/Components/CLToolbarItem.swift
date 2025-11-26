//
//  CLToolbarItem.swift
//  checklists
//
//  Created by Jimmy Ho on 11/26/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

import SwiftUI

/// A convenience wrapper for toolbar items that hides the shared background,
/// useful when you want toolbar buttons to visually match a transparent/blurred
/// navigation bar background.
///
/// Basically, there were white circle backgrounds on my nav buttons, and I wanted to get rid of them with the .sharedBackgroundVisibility.
public struct CLToolbarItem<Content: View>: ToolbarContent {
  public let placement: ToolbarItemPlacement
  @ViewBuilder public let content: () -> Content

  public init(placement: ToolbarItemPlacement, @ViewBuilder content: @escaping () -> Content) {
    self.placement = placement
    self.content = content
  }

  public var body: some ToolbarContent {
    ToolbarItem(placement: placement) {
      content()
    }
    .sharedBackgroundVisibility(.hidden)
  }
}
