//
//  ChecklistsView.swift
//  checklists
//
//  Created by Jimmy Ho on 11/19/24.
//  Copyright © 2024 Jimmy Ho. All rights reserved.
//

import EasyToast
import SwiftUI
import RealmSwift

struct ChecklistsView: View {
  @ObservedRealmObject var group: Group
  @State private var checklists: [Checklist]

  // For deleting a Checklist.
  @State private var showingDeletionUndoToast = false
  @State private var deletedChecklist: Checklist? = nil

  // For resetting all Checklists.
  @State private var showingMoreMenu = false
  @State private var showingResetAlert = false

  var body: some View {
    NavigationView {
      List {
        ForEach(checklists) { checklist in
          ChecklistRowView(checklist: checklist)
            .swipeActions(edge: .trailing) {
              swipeDeleteButton(checklist: checklist)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 8.0, bottom: 0, trailing: 0))
        }
        .onMove(perform: moveChecklist)
      }
      .listStyle(.plain)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            menuButtonTapped()
          }) {
            Image("MenuIcon25x25")
              .renderingMode(.template)
              .accessibilityLabel("Miscellaneous Menu")
              .tint(Colors.teal)
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { showingMoreMenu = true }) {
            Image("MoreMenuIcon32x32")
              .renderingMode(.template)
              .accessibilityLabel("Checklists Menu")
              .tint(Colors.teal)
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
          checklists = group.displayedChecklists()
        }
      })
      .onDisappear {
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
  }
  
  init(group: Group) {
    self.group = group
    self.checklists = group.displayedChecklists()
  }

  private func menuButtonTapped() {
    // TODO
  }
  
  private func moveChecklist(from sourceIndexSet: IndexSet, to destination: Int) {
    for sourceIndex in sourceIndexSet {
      group.moveChecklist(from: sourceIndex, to: destination)
    }
  }

  private func swipeDeleteButton(checklist: Checklist) -> some View {
    Button(role: .destructive) {
      group.shallowDelete(checklist: checklist)
      deletedChecklist = checklist
      withAnimation {
        checklists = group.displayedChecklists()
      }
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
      CircularPercentStatusIcon(iconType: .tableViewCell, percentageComplete: checklist.percentageComplete)
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
        .foregroundColor(Colors.teal)
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
