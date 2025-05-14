//
//  ChecklistView.swift
//  checklists
//
//  Created by Jimmy Ho on 12/9/24.
//  Copyright © 2024 Jimmy Ho. All rights reserved.
//

import SwiftUI
import RealmSwift

struct ChecklistView: View {
  @ObservedRealmObject var checklist: Checklist

  var body: some View {
    VStack(spacing: 0.0) {
      ChecklistHeaderView(checklist: checklist)
        .fixedSize(horizontal: false, vertical: true)
      List {
        ForEach(checklist.items, id: \.id) { item in
          ChecklistItemView(item: item)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 0.0, bottom: 0, trailing: 16.0))
      }
      .listStyle(.plain)
      Spacer()
    }
    .padding(.leading, 16.0)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") {
          UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
      }
    }
  }
}

// For completion icon, title and general notes.
struct ChecklistHeaderView: View {
  @ObservedRealmObject var checklist: Checklist

  // To refresh the percentageComplete. Updates to Item.statusRaw don't seem trigger a refresh without this.
  // Slightly hacky, as I'm observing all Items, not just this Checklist's Items.
  @ObservedResults(Item.self) var allItems

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        CircularPercentStatusIcon(iconType: .header, percentageComplete: checklist.percentageComplete)
          .onChange(of: allItems) { _, _ in } // Triggering refresh.
        TextField("Name", text: $checklist.name)
          .font(.title)
          .fontWeight(.bold)
          .foregroundColor(Color.black)
        Spacer()
      }
      CLTextEditor(text: Binding(
        // The only reason this is so convoluted is because my original Realm schema had .notes
        // as an Optional. If it were not-Optional, it would probably just be `text: $checklist.notes`.
        // Decided against this, given the risks in migrating on app launch when updating app versions.
        get: { checklist.notes ?? "" },
        set: { text in
          DBManager.write {
            checklist.thaw()?.notes = (text.trimmed() == "") ? nil : text
          }
        }
      ))
    }
  }
}

#Preview {
  let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "Preview"))
  SampleData.populateWithSampleData(realm: realm)
  return ChecklistView(checklist: realm.objects(Group.self).first!.checklists.first!)
}
