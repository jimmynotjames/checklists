//
//  CLTextEditor.swift
//  checklists
//
//  Created by jimmyho on 5/13/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

import SwiftUI

/*
Features:
 - Allows for placeholder text in gray.
 - Keyboard has a Done button aboe keyboard to dismiss the keyboard with correct color.
 - Minimum line height measured in newlines.
 - TODO: Create custom shade of gray for placeholder text.
 - TODO: Add accessibility
 - TODO: Add Dynamic Type capability. Can placeholder and text still align when font size changes?
 - TODO: Refine font and spacing/padding
 - TODO: Update manual test plan with any new features
 */
struct CLTextEditor: View {
  @Binding var text: String
  let minLines: Int

  var body: some View {
    ZStack(alignment: .topLeading) {
      TextEditor(text: $text)
        .padding(.leading, -5.0) // Left-align text to overcome internal padding of TextEditor.
        .accessibilityHidden(true)
      // Placeholder text
      if text.isEmpty {
        Text("Notes")
          .foregroundColor(.gray)
          .padding(.top, 8.0)
          .accessibilityHidden(true)
      }
      // Mininum height using newlines. Allows for Dynamic Type more easily than measuring in points.
      Text(String(repeating: "\n", count: minLines))
        .foregroundColor(.clear)
        .accessibilityHidden(true)
        .background(Color.clear)
    }
    .font(.footnote)
    .padding(.top, 2.0)
    .padding(.bottom, 4.0)
  }
}
