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
 */
struct CLTextEditor: View {
  @Binding var text: String
  @FocusState private var isFocused: Bool
  var font: Font = .footnote

  var body: some View {
    ZStack(alignment: .topLeading) {
      TextEditor(text: $text)
        .font(font)
        .focused($isFocused)
        .padding(.top, -8.0)
        .padding(.leading, -5.0)
      if text.isEmpty {
        // Placeholder text when content is empty.
        Text("Notes")
          .font(font)
          .foregroundColor(.gray)
      }
    }
    .padding(.top, 2.0)
    .padding(.bottom, 4.0)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") {
          isFocused = false
        }
      }
    }
  }
}
