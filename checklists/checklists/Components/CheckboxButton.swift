//
//  CheckboxButton.swift
//  checklists
//
//  Created by jimmyho on 5/13/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

import SwiftUI
import RealmSwift

struct CheckboxButton: View {
  @ObservedRealmObject var item: Item

  var body: some View {
    Button(action: {
      DBManager.write {
        item.thaw()?.toggleStatus()
      }
    }) {
      Image(item.status == .checked ? "CheckboxCheckedIcon" : "CheckboxUncheckedIcon")
        .resizable()
        .frame(width: 24, height: 24)
        .padding(12)
        .accessibilityLabel("Checkbox")
        .accessibilityValue(item.status == .checked ? "Checked" : "Unchecked")
    }
    .foregroundColor(Color.teal)
    .frame(width: 48, height: 48)
    .contentShape(Rectangle())
  }
}

#Preview("CheckboxButton using Realm)") {
  DBManager.initializeDebugRealm()
  let checked = Item()
  checked.status = .checked
  let unchecked = Item()
  unchecked.status = .unchecked
  DBManager.write {
    let realm = DBManager.realm
    realm.add(checked)
    realm.add(unchecked)
  }
  return HStack(spacing: 16) {
    CheckboxButton(item: checked)
    CheckboxButton(item: unchecked)
  }
}

