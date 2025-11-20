//
//  ChecklistView.swift
//  checklists
//
//  Created by Jimmy Ho on 12/9/24.
//  Copyright © 2024 Jimmy Ho. All rights reserved.
//

import SwiftUI
import RealmSwift

/*
 Features:
 - Displays a checklist with Checklist Name, Checklist Notes and list of Items.
 - All keyboards on this page will have a Done button in their toolbars.
 - TODO: Button to add new Item at end of list.
 - TODO: Account for when this is a new Checklist being created via Add Checklist button.
 - TODO: Reorder Items via drag/drop.
 - TODO: Make sure that drag/drop of Item onto the Notes or Name field of the Checklist does not try to paste the text in.
 - TODO: Update manual test plan to match code changes.
 - TODO: Refine formating/spacing/fonts
 - TODO: Add accessibility
 - TODO: Add Dynamic Type capability.
 - TODO: Update manual test plan to match code changes.
 - TODO: Write/update automated tests.
 */

struct ChecklistView: View {
  @ObservedRealmObject var checklist: Checklist

  var body: some View {
    VStack(spacing: 0.0) {
      ChecklistHeaderView(checklist: checklist)
        .fixedSize(horizontal: false, vertical: true)
        .padding(EdgeInsets(top: 0.0, leading: 16.0, bottom: 8.0, trailing: 16.0))
      List {
        ForEach(checklist.items, id: \.id) { item in
          ChecklistItemView(item: item)
        }
        .listRowSeparator(.hidden)
        // No insets due to tap target stuff.
        .listRowInsets(EdgeInsets(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 0.0))
        .listRowBackground(Color.clear) // To prevent highlighting when tapping on row.

        // Add button row at bottom
        Section {
          CLButton {
            let item = Item()
            DBManager.write { _ in
              checklist.thaw()?.items.append(item)
            }
          } label: {
            HStack {
              Spacer()
              Label("Add", systemImage: "plus.circle")
                .font(.callout)
              Spacer()
            }
          }
        }
        .listRowSeparator(.hidden)
      }
      .listStyle(.plain)
      Spacer()
    }
    // When I tried to add this to individual component views, a Done button appeared for every
    // Component that had this declaration. Unable to encapsulate in individual components.
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

  // To refresh the percentageComplete. Updates to Item.isChecked don't seem trigger a refresh without this.
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
      CLTextEditor(text: $checklist.notes, minLines: 3)
    }
  }
}

#Preview {
  let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "Preview"))
  SampleData.populateWithSampleData(realm: realm)
  return ChecklistView(checklist: realm.objects(Group.self).first!.checklists.first!)
}
