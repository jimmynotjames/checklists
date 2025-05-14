//
//  CLTextEditor.swift
//  checklists
//
//  Created by jimmyho on 5/13/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

import SwiftUI

/*
Major features:
 - Added placeholder text.
 - Keyboard has a Done button to dismiss the keyboard and it has the appropriate color.
 - Minimum line height measured in newlines.
 */
struct CLTextEditor: View {
  @Binding var text: String
  let minLines: Int

  var body: some View {
    ZStack(alignment: .topLeading) {
      TextEditor(text: $text)
        .padding(.leading, -5.0)
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
