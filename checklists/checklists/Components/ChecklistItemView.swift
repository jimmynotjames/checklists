//
//  ChecklistItemView.swift
//  checklists
//
//  Created by jimmyho on 5/13/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

/*
 For each individual Checklist Item.
 Features:
 - Consists of a checkbox, single-line name field, and multi-line notes field.
 - Tapping Checkbox toggles the status of the Item.
 - Tapping the name or notes field goes into edit mode, and reveals notes field if hidden.
 - Tapping outside of the fields dismisses the keyboard.
 - Tapping Done on the keyboard input accessory dismisses the keyboard.

 Notes:
 - This View presumes that there's zero leading edge padding. Because we want to maximize the
   tap target of the checkbox button, which is always on the leading edge.

 Remaining tasks:
 - TODO: Need to trim whitespace from notes field.
 - TODO: Tapping Next on the keyboard in the name field creates new Item and focuses on name field in new Item.
 - TODO: Tapping backspace on empty notes field goes to name field.
 - TODO: Tapping backspace on empty name field (with empty notes field) removes current Item, unless it's the first Item.
 - TODO: After Tapping backspace and focus shifts to previous Item, cursor needs to be placed at the end. Ideally notes field, but whatever works. Current app version only places in name field, which is a small bug, I guess.
 - TODO: Keyboard on notes field should have Return key as Newline, not Done.
 - TODO: Exact fonts and spacing need to be refined.
 - TODO: Add accessibility
 - TODO: Add Dynamic Type capability.
 - TODO: Update manual test plan to match code changes.
 */
import SwiftUI
import RealmSwift

struct ChecklistItemView: View {
  @ObservedRealmObject var item: Item
  
  // For revealing the notes field when editing.
  @FocusState private var isEditing: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 0.0) {
      CheckboxButton(item: item)
      VStack(alignment: .leading, spacing: 0.0) {
        TextField("", text: Binding(
          get: { item.name },
          set: { newName in
            DBManager.write { _ in
              item.thaw()?.name = newName
            }
          }
        ))
          .font(.body)
          .lineLimit(1)
          .focused($isEditing)
        if isEditing || !item.notes.isEmpty {
          CLTextEditor(text: $item.notes, minLines: 1)
            .focused($isEditing)
        }
      }
      // Next three lines are to prevent tapping on the cell's non-editable areas causing the checkbox button to toggle.
      // Apparently, it's a quirk of SwiftUI that tapping on the cell forwards the tap to the first tappable element, which is the CheckboxButton.
      .contentShape(Rectangle())
      .onTapGesture {}
      .onLongPressGesture {}
      // To align TextField with CheckboxButton properly.
      .padding(EdgeInsets(top: 4.0, leading: 0.0, bottom: 0.0, trailing: 0.0))
      Spacer()
    }
  }
}
