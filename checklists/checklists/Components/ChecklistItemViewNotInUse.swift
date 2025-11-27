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
 - TODO: Done button keyboard should read Next when focus is on a Checklist Item Name.
 - TODO: Keyboard on notes field should have Return key as Newline, not Done.
 - TODO: Exact fonts and spacing need to be refined.
 */
import SwiftUI
import RealmSwift

struct ChecklistItemViewNotInUse: View {
  @ObservedRealmObject var item: Item

  // Passed from the parent for focusing on TextField when new Item is added.
  var focusedItemID: FocusState<ObjectId?>.Binding
  
  // For revealing the notes field when editing.
  @FocusState private var isEditing: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 0.0) {
      CheckboxButton(item: item)
      VStack(alignment: .leading, spacing: 0.0) {
        TextField("", text: $item.name)
          .font(.body)
          .lineLimit(1)
          .focused($isEditing)
          .focused(focusedItemID, equals: item._id)
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
