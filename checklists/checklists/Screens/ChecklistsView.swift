//
//  ChecklistsView.swift
//  checklists
//
//  Created by Jimmy Ho on 11/19/24.
//  Copyright © 2024 Jimmy Ho. All rights reserved.
//

/*
 Features:
 - Shows list of Checklists
 - Shows percentage complete for each Checklist
 - Shows notes for each Checklist, first three lines with ellipsis
 - Swipe-delete to remove a Checklist with Toast to undo
 - Reorder Checklists via drag/drop.
 - Tap on a Checklist to view its items
 - More Menu options:
   - Reset All - Resets all Checklists to 0% complete.
 - Main Menu button in upper left uses custom transition left-to-right to reveal MainMenuView.

 - TODO: Consider adjust left-alignment of list to match the new placement of menu icon up top.
 - TODO: Exact fonts and spacing need to be refined.
 - TODO: Add accessibility
 - TODO: Add Dynamic Type capability.
 - TODO: Update manual test plan to match code changes.
 - TODO: BUG: Reset All button no longer works.
 - TODO: Write/update automated tests.
 */

import EasyToast
import SwiftUI
import RealmSwift

struct ChecklistsView: View {
  @ObservedRealmObject var group: Group

  @State private var refreshID = UUID()

  // For deleting a Checklist.
  @State private var showingDeletionUndoToast = false
  @State private var toastDismissedByTap = false
  @State private var deletedChecklist: Checklist? = nil

  // For managing navigation state.
  @State private var navigationPath = NavigationPath()
  
  @State private var newChecklistCreated: Checklist? = nil

  var body: some View {
    MainNavigationStack(path: $navigationPath) {
      ZStack(alignment: .bottomTrailing) {
        List {
          ForEach(group.displayedChecklists(), id: \.id) { checklist in
            // Not using NavigationLink because it has a Disclosure Indicator that cannot be removed.
            Button(action: {
              navigationPath.append(checklist)
            }) {
              ChecklistRowView(checklist: checklist)
            }
            .swipeActions(edge: .trailing) {
              swipeDeleteButton(checklist: checklist)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 8.0, bottom: 0, trailing: 16.0))
          }
          .onMove(perform: moveChecklist)
        }
        .id(refreshID)
        .listStyle(.plain)
        .navigationDestination(for: Checklist.self) { checklist in
          ChecklistView(checklist: checklist)
        }
        .toast(isPresented: $showingDeletionUndoToast, message: "Undo checklist deletion", duration: 3.0, position: .bottom, onTap: {
          guard let deletedChecklist = deletedChecklist else { assertionFailure(); return }
          group.undoDeletion(checklist: deletedChecklist)
          toastDismissedByTap = true
          showingDeletionUndoToast = false
          withAnimation {
            refreshID = UUID()
          }
        })
        .onChange(of: showingDeletionUndoToast) { _, isShowing in
          // If toast dismisses due to timeout or leaving the screen, then clean up deleted Checklist.
          if isShowing == false && !toastDismissedByTap {
            group.thaw()?.cleanUpSoftDeletedChecklists()
          }
        }
        .onAppear() {
          refreshID = UUID()
        }
        .onDisappear {
          showingDeletionUndoToast = false
        }
        .sheet(item: $newChecklistCreated) { checklist in
          NewChecklistView(checklist: checklist, onDismiss: {
            newChecklistCreated = nil // General clean-up, though code works fine regardless.
            refreshID = UUID() // Otherwise, the name/notes of new Checklist won't show.
          })
          .presentationDetents([.large])
          .presentationDragIndicator(.hidden)
        }
        AddChecklistButton {
          let checklist = Checklist()
          checklist.items.append(Item())
          DBManager.write { realm in
            realm.add(checklist)
            group.thaw()?.checklists.insert(checklist, at: 0)
          }
          newChecklistCreated = checklist
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
      }
    }
  }

  private func moveChecklist(from sourceIndexSet: IndexSet, to destination: Int) {
    guard let group = group.thaw() else { return }

    // The indices from this move is on the filtered list, removing soft-deleted items.
    // Whereas the underlying move is on the full list. Let's just remove the soft-deleted
    // Checklists so the lists are consistent.
    showingDeletionUndoToast = false
    deletedChecklist = nil
    group.cleanUpSoftDeletedChecklists()

    for sourceIndex in sourceIndexSet {
      let adjustedDestinationIndex = realmDestinationIndex(sourceIndex: sourceIndex, swiftUIDestinationIndex: destination)
      group.moveChecklist(from: sourceIndex, to: adjustedDestinationIndex)
    }
  }

  private func swipeDeleteButton(checklist: Checklist) -> some View {
    Button(role: .destructive) {
      group.shallowDelete(checklist: checklist)
      deletedChecklist = checklist
      toastDismissedByTap = false // General reset, in case lingering value from prior.
      showingDeletionUndoToast = true
    } label: {
      Label("Delete", systemImage: "trash")
    }
    .tint(.red) // Override global tint.
  }
}

struct ChecklistRowView: View {
  var checklist: Checklist

  var body: some View {
    HStack(alignment: .top, spacing: 7.0) {
      CircularPercentStatusIcon(iconType: .item, percentageComplete: checklist.percentageComplete)
      VStack(alignment: .leading, spacing: 4.0) {
        Text(checklist.name)
          .font(.system(size: 18.0, weight: .semibold))
          .foregroundColor(.black)
        let notes = checklist.notes
        if !notes.isEmpty {
          Text(notes)
            .font(.system(size: 15.0))
            .foregroundColor(.black)
            .lineLimit(3)
            .accessibilityIdentifier("checklistNotesLabel")
        }
      }
      Spacer()
    }
    .padding(.vertical, 8.0)
    .padding(.horizontal, 8.0)
  }
}

#Preview {
  let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "Preview"))
  SampleData.populateWithSampleData(realm: realm)
  return
    ChecklistsView(group: realm.objects(Group.self).first!)
    .environment(\.realmConfiguration, Realm.Configuration(inMemoryIdentifier: "Preview"))
}

#Preview {
  MoreMenuView(onResetAll: {}).border(.black)
}
