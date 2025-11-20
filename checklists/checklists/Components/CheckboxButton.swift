//
//  CheckboxButton.swift
//  checklists
//
//  Created by jimmyho on 5/13/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

/*
 Features:
 - Tappable button that toggles the checkbox status on Realm object.
 */

import SwiftUI
import RealmSwift

struct CheckboxButton: View {
  @ObservedRealmObject var item: Item

  var body: some View {
    Button(action: {
      DBManager.write { _ in
        item.thaw()?.toggleStatus()
      }
    }) {
      Image(item.isChecked == true ? "CheckboxCheckedIcon" : "CheckboxUncheckedIcon")
        .resizable()
        .frame(width: 24, height: 24)
        // Implicit assumption of 16.0 margin from leading edge, with no padding applied externally, to maximize tap target.
        .padding(EdgeInsets(top: 4.0, leading: 16.0, bottom: 4.0, trailing: 8.0))
        .accessibilityLabel("Checkbox")
        .accessibilityValue(item.isChecked == true ? "Checked" : "Unchecked")
    }
    .foregroundColor(CLColors.teal)
    .contentShape(Rectangle()) // Maximize tap target
  }
}

#Preview("CheckboxButton using Realm)") {
  let checked = Item()
  checked.isChecked = true
  let unchecked = Item()
  unchecked.isChecked = false
  DBManager.write { realm in
    realm.add(checked)
    realm.add(unchecked)
  }
  return HStack(spacing: 16) {
    CheckboxButton(item: checked)
    CheckboxButton(item: unchecked)
  }
  .environment(\.realmConfiguration, Realm.Configuration(inMemoryIdentifier: "Preview"))
}

