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
 TODO: BUG: Done button has wrong background color.
 */
/// Wrapper View for new checklist modal.
struct NewChecklistView: View {
  @ObservedRealmObject var checklist: Checklist
  @Environment(\.dismiss) private var dismiss
  let onDismiss: () -> Void

  var body: some View {
    NavigationStack {
      ChecklistView(checklist: checklist, shouldFocusChecklistNameOnAppear: true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Done") {
              if checklist.name.trimmed().isEmpty {
                DBManager.write { _ in
                  checklist.thaw()?.name = "Untitled"
                }
              }
              onDismiss()
              dismiss()
            }
          }
        }
    }
  }
}

/*
 Features:
 - Displays a checklist with Checklist Name, Checklist Notes and list of Items.
 - All keyboards on this page will have a Done button in their toolbars.

 - TODO: Tapping Done/Next on Checklist Name moves cursor/focus to first Item if new Checklist.
 - TODO: Tapping Next on Item Name inserts new Item below and moves focus to new Item.
 - TODO: Tapping delete on empty Item Name will delete Item and move focus up to prior Item Name end of line. Unless it's the first Item, in which case, do nothing.
 - TODO: Tapping delete on empty Item Notes will move focus to Item Name end of line.
 - TODO: Refine formatting/spacing/fonts
 - TODO: Add accessibility
 - TODO: Add Dynamic Type capability.
 - TODO: Update manual test plan to match code changes.
 - TODO: Write/update automated tests.
 */

struct ChecklistView: View {
  @ObservedRealmObject var checklist: Checklist

  // For shifting cursor/focus to newly created Item.
  @FocusState private var focusedItemID: ObjectId?
  @FocusState private var isNameFocused: Bool
  var shouldFocusChecklistNameOnAppear: Bool = false

  var body: some View {
    VStack(spacing: 0.0) {
      ChecklistHeaderView(checklist: checklist, isNameFocused: $isNameFocused)
        .fixedSize(horizontal: false, vertical: true)
        .padding(EdgeInsets(top: 0.0, leading: 16.0, bottom: 8.0, trailing: 16.0))
      List {
        ForEach(checklist.items, id: \._id) { item in
          ChecklistItemView(item: item, focusedItemID: $focusedItemID)
            .swipeActions(edge: .trailing) {
              Button(role: .destructive) {
                checklist.remove(item)
              } label: {
                Label("", systemImage: "trash")
              }
              .tint(.red) // Override global tint.
            }
        }
        .onMove { indexSet, destination in
          for sourceIndex in indexSet {
            let adjustedDestinationIndex = realmDestinationIndex(sourceIndex: sourceIndex, swiftUIDestinationIndex: destination)
            checklist.thaw()?.moveItem(from: sourceIndex, to: adjustedDestinationIndex)
          }
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
            focusedItemID = item._id // Set cursor to newly created item.
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
    .onAppear {
      if shouldFocusChecklistNameOnAppear {
        isNameFocused = true
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

  @FocusState.Binding var isNameFocused: Bool

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        CircularPercentStatusIcon(iconType: .header, percentageComplete: checklist.percentageComplete)
          .onChange(of: allItems) { _, _ in } // Triggering refresh.
        TextField("Name", text: $checklist.name)
          .font(.title)
          .fontWeight(.bold)
          .foregroundColor(Color.black)
          .focused($isNameFocused)
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
