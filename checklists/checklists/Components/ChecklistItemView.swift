//
//  ChecklistItemView.swift
//  checklists
//
//  Created by jimmyho on 5/13/25.
//  Copyright © 2025 Jimmy Ho. All rights reserved.
//

import SwiftUI
import RealmSwift

// For each individual Checklist Item
struct ChecklistItemView: View {
  @ObservedRealmObject var item: Item

  var body: some View {
    HStack(alignment: .top, spacing: 0.0) {
      CheckboxButton(item: item)
      VStack(alignment: .leading, spacing: 2.0) {
        TextField("", text: Binding(
          get: { item.name },
          set: { newName in
            DBManager.write {
              item.thaw()?.name = newName
            }
          }
        ))
          .font(.body)
          .lineLimit(1)
        CLTextEditor(text: Binding(
          // The only reason this is so convoluted is because my original Realm schema had .notes
          // as an Optional. If it were not-Optional, it would probably just be `text: $item.notes`.
          // Decided against this, given the risks in migrating on app launch when updating app versions.
          get: { item.notes ?? "" },
          set: { text in
            DBManager.write {
              item.thaw()?.notes = (text.trimmed() == "") ? nil : text
            }
          }
        ))
      }
      .padding(EdgeInsets(top: 4.0, leading: 0.0, bottom: 0.0, trailing: 0.0))
      Spacer()
    }
    // We want a big tap target for the Checkbox button, so shift it left into
    // the margin instead of trying to truncate the tappable area.
    .padding(EdgeInsets(top: 0, leading: -6.0, bottom: 4.0, trailing: 0.0))
  }
}
