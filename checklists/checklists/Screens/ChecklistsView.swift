//
//  ChecklistsView.swift
//  checklists
//
//  Created by Jimmy Ho on 11/19/24.
//  Copyright © 2024 Jimmy Ho. All rights reserved.
//

import SwiftUI
import RealmSwift

struct ChecklistsView: View {
  @ObservedRealmObject var group: Group

  // For deleting a Checklist.
  @State private var showingDeleteAlert = false
  @State private var itemToDelete: Checklist? = nil

  // For resetting all Checklists.
  @State private var showingMoreMenu = false
  @State private var showingResetAlert = false

  var body: some View {
    NavigationView {
      List {
        ForEach(group.checklists) { checklist in
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
      .alert("Are you sure? This cannot be undone.", isPresented: $showingDeleteAlert, presenting: itemToDelete) { checklist in
        Button("Delete", role: .destructive) {
          withAnimation {
            group.delete(checklist: checklist)
          }
          itemToDelete = nil
        }
        Button("Cancel", role: .cancel) {
          itemToDelete = nil
        }
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
  
  private func menuButtonTapped() {
    // TODO
  }
  
  private func moveChecklist(from sourceIndexSet: IndexSet, to destination: Int) {
    for sourceIndex in sourceIndexSet {
      group.moveChecklist(from: sourceIndex, to: destination)
    }
  }
  
  private func swipeDeleteButton(checklist: Checklist) -> some View {
    // Setting to .destructive causes SwiftUI to auto-remove the row when button is tapped,
    // causing a weird flicker, so setting to .none and manually tinting the color.
    Button(role: .none) {
      itemToDelete = checklist
      showingDeleteAlert = true
    } label: {
      Label("Delete", systemImage: "trash")
    }
    .tint(.red)
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
