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
 - TODO: Button in lower right to create new Checklist
 - TODO: Exact fonts and spacing need to be refined.
 - TODO: Add accessibility
 - TODO: Add Dynamic Type capability.
 - TODO: Update manual test plan to match code changes.
 - TODO: BUG: Reset All button no longer works.
 - TODO: BUG: 3 checklists. Delete last 2. Quickly try to open first one. -> crash.
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
  @State private var deletedChecklist: Checklist? = nil

  // For managing navigation state.
  @State private var navigationPath = NavigationPath()
  
  var body: some View {
      MainNavigationStack(path: $navigationPath) {
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
        .easyToast(isPresented: $showingDeletionUndoToast, message: "Undo checklist deletion", duration: 3.0, position: .bottom, onTap: {
          guard let deletedChecklist = deletedChecklist else { assertionFailure(); return }
          group.undoDeletion(checklist: deletedChecklist)
          showingDeletionUndoToast = false
          withAnimation {
            refreshID = UUID()
          }
        })
        .onAppear() {
          refreshID = UUID()
        }
        .onDisappear {
          showingDeletionUndoToast = false
          DBManager.cleanUpDeletedChecklists()
        }
      }
  }

  private func moveChecklist(from sourceIndexSet: IndexSet, to destination: Int) {
    for sourceIndex in sourceIndexSet {
      // In SwiftUI, it appears that dragging a Checklist to end of list goes to `count`.
      let destination = min(destination, group.checklists.count - 1)
      group.thaw()?.moveChecklist(from: sourceIndex, to: destination)
    }
  }

  private func swipeDeleteButton(checklist: Checklist) -> some View {
    Button(role: .destructive) {
      group.shallowDelete(checklist: checklist)
      deletedChecklist = checklist
      showingDeletionUndoToast = true
    } label: {
      Label("Delete", systemImage: "trash")
    }
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
        if let notes = checklist.notes, !notes.isEmpty {
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
  return ChecklistsView(group: realm.objects(Group.self).first!)
}

#Preview {
  MoreMenuView(onResetAll: {}).border(.black)
}
