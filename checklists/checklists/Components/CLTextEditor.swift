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

 To use, set a >= minimum height constraint and it will show with a minimum height and grow as it expands beyond that.

 - TODO: Adjust so that it grows/shrinks height as user is typing. See CLTextView
 - TODO: Add accessibility
 - TODO: Add Dynamic Type capability. Can placeholder and text still align when font size changes?
 - TODO: Refine font and spacing/padding
 - TODO: Update manual test plan with any new features
 */
struct CLTextEditor: View {
  @Binding var text: String
  @FocusState private var isFocused: Bool

  let minLines: Int

  var body: some View {
    ZStack(alignment: .topLeading) {
      TextEditor(text: $text)
        .focused($isFocused)
        .padding(.leading, -3.0) // Left-align text to overcome internal padding of TextEditor.
        .accessibilityHidden(true)
      // Placeholder text
      if text.isEmpty {
        Text("Notes")
          .foregroundColor(CLColors.placeholderText)
          .padding(.top, 8.0)
          .padding(.leading, 2.0)
          .accessibilityHidden(true)
      }
      // Mininum height using newlines. Allows for Dynamic Type more easily than measuring in points.
      Text(String(repeating: "\n", count: minLines))
        .foregroundColor(.clear)
        .accessibilityHidden(true)
        .background(Color.clear)
    }
    .onChange(of: isFocused, initial: false) { oldValue, newValue in
      // Trim only when focus transitions from true -> false
      if oldValue == true && newValue == false {
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    .font(.footnote)
    .padding(EdgeInsets(top: 2.0, leading: 0.0, bottom: 4.0, trailing: 0.0))
  }
}
