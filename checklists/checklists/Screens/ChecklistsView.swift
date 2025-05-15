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
 - Swipe-delete to remvoe a Checklist with Toast to undo
 - Reorder Checklists via drag/drop.
 - Tap on a Checklist to view its items
 - More Menu options:
   - Reset All - Resets all Checklists to 0% complete.
 - TODO: Main Menu button in upper left
 - TODO: Button in lower right to create new Checklist
 - TODO: Exact fonts and spacing need to be refined.
 - TODO: Add accessibility
 - TODO: Add Dynamic Type capability.
 - TODO: Update manual test plan to match code changes.
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

  // For resetting all Checklists.
  @State private var showingMoreMenu = false
  @State private var showingResetAlert = false

  // For managing navigation state.
  @State private var navigationPath = NavigationPath()

  var body: some View {
    NavigationStack(path: $navigationPath) {
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
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            menuButtonTapped()
          }) {
            Image("MenuIcon25x25")
              .renderingMode(.template)
              .accessibilityLabel("Miscellaneous Menu")
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { showingMoreMenu = true }) {
            Image("MoreMenuIcon32x32")
              .renderingMode(.template)
              .accessibilityLabel("Checklists Menu")
          }
          .popover(isPresented: $showingMoreMenu, arrowEdge: .top) {
            MoreMenuView {
              showingMoreMenu = false
              showingResetAlert = true
            }
            .presentationCompactAdaptation(.popover)
          }
        }
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
      .alert("Are you sure? This cannot be undone.", isPresented: $showingResetAlert) {
        Button("Reset All", role: .destructive) {
          DBManager.resetAllChecklists()
          showingResetAlert = false
        }
        Button("Cancel", role: .cancel) {
          showingResetAlert = false
        }
      }
    }
    .tint(CLColors.teal)
  }

  private func menuButtonTapped() {
    // TODO
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
          .lineLimit(1)
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

struct MoreMenuView: View {
  let onResetAll: () -> Void

  var body: some View {
    VStack {
      Button("Reset All", action: onResetAll)
        .foregroundColor(CLColors.teal)
        .padding(.horizontal, 16.0)
    }
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
