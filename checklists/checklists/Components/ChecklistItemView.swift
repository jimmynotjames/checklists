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
    VStack(alignment: .leading) {
      HStack {
        TextField("", text: Binding(
          get: { item.name },
          set: { newName in
            DBManager.write {
              item.thaw()?.name = newName
            }
          }
        ))
        .font(.subheadline)
        .foregroundColor(Color.black)
      }
    }
  }
}
