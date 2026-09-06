//
//  ChecklistsView.swift
//  checklists
//

import SwiftData
import SwiftUI

/// The app's top-level screen: every checklist, in the user's own order.
///
/// Replaces `ChecklistsViewController`, and absorbs `ChecklistsMenuViewController` — a
/// one-row table view presented as a popover, which is a `Button` in a `.popover` here.
///
/// The `navigationDestination` for `AppRoute` is attached once at the root of the
/// `NavigationStack`, not here, so this screen only produces routes (`NavigationLink(value:)`)
/// and never resolves them.
struct ChecklistsView: View {
  /// All checklists in display order.
  ///
  /// The sort is `ModelContext.fetchChecklistsSorted`'s, restated as a `@Query`: `id` breaks
  /// ties so the order is total and stable. Two records can genuinely share a `sortKey` once
  /// sync is involved — CloudKit cannot enforce uniqueness, so two devices editing while apart
  /// can both land on the same key — and a list whose row order flickers between refreshes is
  /// worse than an arbitrary but fixed choice. Keep this in step with `fetchChecklistsSorted`,
  /// which the dedupe path still uses.
  @Query(sort: [SortDescriptor(\Checklist.sortKey), SortDescriptor(\Checklist.id)])
  private var checklists: [Checklist]

  @Environment(\.modelContext) private var context
  @Environment(Router.self) private var router

  /// Created on the first `.task` rather than at init: a `@State` initial value would be
  /// rebuilt on every re-render of the view struct, and this observer registers for a
  /// notification in its initializer.
  @State private var remoteChangeObserver: RemoteChangeObserver?

  /// The checklist the delete confirmation is currently about, held by `id` rather than by
  /// row or by model reference. See `confirmDelete(id:)`.
  @State private var pendingDeleteID: String?

  @State private var showsResetMenu = false
  /// Set by the popover's "Reset All" and consumed in its `onDisappear` — see the comment there.
  @State private var isResetAllPending = false
  @State private var showsResetAllConfirmation = false

  var body: some View {
    List {
      ForEach(checklists) { checklist in
        NavigationLink(value: AppRoute.checklist(id: checklist.id)) {
          ChecklistRowView(checklist: checklist)
        }
        // The 16pt side margin the cell's visual-format string used for both labels.
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden) // Was `tableView.separatorStyle = .none`.
        .swipeActions(edge: .trailing) {
          // Deliberately NOT `role: .destructive`: a full swipe on a destructive action
          // optimistically animates the row away before any model change, but this action only
          // records intent — the delete itself waits for the confirmation alert, exactly as the
          // `commit editingStyle:` path did. A cancelled confirmation must leave the row visible,
          // so the red comes from an explicit tint instead of the role.
          Button("Delete") {
            pendingDeleteID = checklist.id
          }
          .tint(.red)
        }
      }
      .onMove(perform: move)
    }
    .listStyle(.plain)
    .appBackground()
    // The list has no title of its own: `ChecklistsViewController` never set one, and its
    // navigation controller did not use large titles.
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .overlay(alignment: .bottomTrailing) {
      addChecklistButton
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          router.isMainMenuVisible = true
        } label: {
          Image("MenuIcon25x25")
        }
        .accessibilityLabel("Miscellaneous Menu")
      }

      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showsResetMenu.toggle()
        } label: {
          Image("MoreMenuIcon32x32")
        }
        .accessibilityLabel("Checklists Menu")
        .popover(isPresented: $showsResetMenu) {
          Button("Reset All") {
            isResetAllPending = true
            showsResetMenu = false
          }
          .font(.body)
          .tint(Colors.tealColor)
          .padding()
          // Replaces the `UIPopoverPresentationControllerDelegate` returning `.none` from
          // `adaptivePresentationStyle(for:traitCollection:)`, which existed purely to stop
          // iPhone adapting this popover into a sheet.
          .presentationCompactAdaptation(.popover)
          // The confirmation alert can't be raised in the same turn that dismisses the
          // popover — SwiftUI drops a presentation started while another is tearing down —
          // so the tap above only records intent and the alert waits for the teardown.
          .onDisappear {
            if isResetAllPending {
              isResetAllPending = false
              showsResetAllConfirmation = true
            }
          }
        }
      }
    }
    .alert("", isPresented: isPresentingDeleteConfirmation, presenting: pendingDeleteID) { checklistId in
      Button("Delete", role: .destructive) {
        confirmDelete(id: checklistId)
      }
      Button("Cancel", role: .cancel) {}
    } message: { _ in
      Text("Are you sure? This cannot be undone.")
    }
    .alert("", isPresented: $showsResetAllConfirmation) {
      Button("Reset All", role: .destructive) {
        resetAllChecklists()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Are you sure? This cannot be undone.")
    }
    .task {
      guard remoteChangeObserver == nil else { return }
      // Refreshes when another device's changes are merged in. Inert until CloudKit is
      // switched on.
      //
      // `@Query` already re-runs itself when the store changes, so this observer no longer
      // has a list to reload — it exists only for the tidy-up below. The dedupe's own save
      // is what nudges `@Query` a second time, once the duplicates are gone. Together they
      // replace `refetchChecklists`, `reloadChecklists`, and the
      // `ChecklistViewControllerDelegate` callback that used to drive them.
      remoteChangeObserver = RemoteChangeObserver {
        // A duplicate untouched sample arriving from another device is exactly the change
        // that triggers this, and tidying it up here means the list settles to one copy
        // rather than sitting on two.
        try? SampleData.dedupeChecklists(in: context)
      }
    }
    .onAppear {
      AnalyticsManager.logChecklistsViewed(numChecklists: checklists.count)
    }
  }

  // MARK: - Add

  private var addChecklistButton: some View {
    Button {
      addChecklist()
    } label: {
      // Geometry and shadow mirror `CLCircleButton`: 60pt across, a 10pt inset around the
      // icon, and a gray shadow at 40% opacity, radius 3, offset 2pt down.
      Image("AddChecklistIcon")
        .resizable()
        .scaledToFit()
        .padding(10)
        .frame(width: 60, height: 60)
        .background(Circle().fill(Colors.defaultBackgroundColor))
        .shadow(color: .gray.opacity(0.4), radius: 3, x: 0, y: 2)
    }
    .accessibilityLabel("Add new checklist.")
    .padding(20)
  }

  private func addChecklist() {
    AnalyticsManager.logNewChecklist()
    let checklist = Checklist()
    do {
      try context.insert(checklist: checklist, at: 0, among: Array(checklists))
    } catch {
      return // Already logged and reported by `saveChanges`; nothing was added.
    }
    router.sheet = .newChecklist(id: checklist.id)
  }

  // MARK: - Reordering

  /// - Note: `@Query` re-derives order from the store, so the list can never show an order the
  ///   context doesn't hold — the desync class in issue #132 is structurally impossible here.
  private func move(from source: IndexSet, to destination: Int) {
    guard let sourceIndex = source.first else { return }
    // SwiftUI hands over an insertion offset in the list *as it stands*; `move(checklist:among:to:)`
    // wants the destination index in the list *after* the moved row is taken out, matching
    // `UITableViewDataSource.tableView(_:moveRowAt:to:)`. They differ by one for a downward move.
    let destinationIndex = destination > sourceIndex ? destination - 1 : destination
    try? context.move(checklist: checklists[sourceIndex], among: Array(checklists), to: destinationIndex)
  }

  // MARK: - Deleting

  private var isPresentingDeleteConfirmation: Binding<Bool> {
    Binding(
      get: { pendingDeleteID != nil },
      set: { isPresented in
        if !isPresented {
          pendingDeleteID = nil
        }
      }
    )
  }

  /// Resolves the pending delete by `id`, not by row. The alert is answered asynchronously, and
  /// once sync is on a merge can reorder the list while it is up — at which point a captured
  /// index would name a different checklist and this would silently delete the wrong one.
  private func confirmDelete(id checklistId: String) {
    // `nil` means it is already gone — deleted on another device while the alert was up.
    guard let checklist = context.checklist(id: checklistId) else { return }
    // The items go with it: the relationship's cascade delete rule replaces the explicit
    // two-step delete Realm needed, which had no cascade of its own.
    context.delete(checklist)
    context.saveChangesIgnoringFailure(operation: .delete)
  }

  // MARK: - Resetting

  private func resetAllChecklists() {
    for checklist in checklists {
      checklist.uncheckAllItems()
    }
    context.saveChangesIgnoringFailure(operation: .checklistEdit)
    // No reload to follow: each row's status icon reads `percentageComplete` in its own body,
    // so Observation redraws the rings. This is where the UIKit version called `reloadData`.
  }
}
