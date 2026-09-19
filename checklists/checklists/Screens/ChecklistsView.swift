//
//  ChecklistsView.swift
//  checklists
//

import SwiftData
import SwiftUI

/// The app's top-level screen: every checklist, in the user's own order.
///
/// The reset-all menu is a popover on the toolbar button rather than a separate screen.
///
/// The `navigationDestination` for `AppRoute` is attached once at the root of the
/// `NavigationStack`, not here, so this screen only pushes routes onto the router's path and
/// never resolves them.
struct ChecklistsView: View {
  /// Display order; id breaks sortKey ties. Keep in step with ModelContext.fetchChecklistsSorted.
  @Query(sort: [SortDescriptor(\Checklist.sortKey), SortDescriptor(\Checklist.id)])
  private var checklists: [Checklist]

  @Environment(\.modelContext) private var context
  @Environment(Router.self) private var router
  @Environment(\.analytics) private var analytics

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
        // A `Button` pushing the route by hand rather than a `NavigationLink`: inside a `List` the
        // link draws a disclosure chevron that this screen deliberately does without, and SwiftUI
        // offers no way to suppress it.
        Button {
          router.path.append(.checklist(id: checklist.id))
        } label: {
          ChecklistRowView(checklist: checklist)
            // The row's own content is only as wide as its text, so widen it to make the whole
            // row tappable rather than just the words.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("checklistRow.\(checklist.id)")
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        // Lets the screen's background show through instead of the system's row fill.
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing) {
          // Deliberately NOT `role: .destructive`: a full swipe on a destructive action
          // optimistically animates the row away before any model change, but this action only
          // records intent — the delete itself waits for the confirmation alert. A cancelled
          // confirmation must leave the row visible, so the red comes from an explicit tint
          // instead of the role.
          Button {
            pendingDeleteID = checklist.id
          } label: {
            // Icon-only for the visible button, but the title is what VoiceOver reads and what
            // the UI tests match on, so it stays part of the label rather than being dropped.
            Label(CommonStrings.delete, systemImage: "trash")
              .labelStyle(.iconOnly)
          }
          .tint(Colors.destructiveColor)
          // Locale-invariant handle: the localized large-type check cannot match
          // the label text across 13 languages, and positional lookup on the
          // revealed buttons is not reliable straight after the swipe.
          .accessibilityIdentifier("checklistRow.delete")

          // Declared after Delete, so Delete keeps the outer edge and the full-swipe slot it has
          // today. Unconfirmed, unlike its neighbour: a copy takes nothing away, and the way to
          // undo one is to delete it.
          Button {
            duplicate(checklist: checklist)
          } label: {
            Label(CommonStrings.duplicate, systemImage: "plus.square.on.square")
              .labelStyle(.iconOnly)
          }
          .tint(Color.accentColor)
          .accessibilityIdentifier("checklistRow.duplicate")
        }
      }
      .onMove(perform: move)
    }
    .listStyle(.plain)
    .appBackground()
    .navigationTitle(Text(verbatim: ""))
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
        // iOS 26 renders bar buttons in `labelColor` unless the button itself carries a tint.
        .tint(Color.accentColor)
        .accessibilityLabel(String(
          localized: "checklists.menu.misc.accessibilityLabel",
          defaultValue: "Miscellaneous Menu",
          comment: "VoiceOver label for the toolbar button that opens the main menu (feedback, rating, settings)."
        ))
        // Locale-invariant handle for the localized large-type check, which
        // cannot navigate by visible text across 13 languages.
        .accessibilityIdentifier("toolbar.mainMenu")
      }

      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showsResetMenu.toggle()
        } label: {
          Image("MoreMenuIcon32x32")
        }
        .tint(Color.accentColor)
        .accessibilityLabel(String(
          localized: "checklists.menu.actions.accessibilityLabel",
          defaultValue: "Checklists Menu",
          comment: "VoiceOver label for the toolbar button that opens the checklist actions popover (Reset All)."
        ))
        .accessibilityIdentifier("toolbar.checklistsMenu")
        .popover(isPresented: $showsResetMenu) {
          Button(Self.resetAllTitle) {
            isResetAllPending = true
            showsResetMenu = false
          }
          .font(.body)
          .tint(Color.accentColor)
          .padding()
          // Stops iPhone adapting this popover into a sheet.
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
    .alert(Text(verbatim: ""), isPresented: isPresentingDeleteConfirmation, presenting: pendingDeleteID) { checklistId in
      Button(CommonStrings.delete, role: .destructive) {
        confirmDelete(id: checklistId)
      }
      Button(CommonStrings.cancel, role: .cancel) {}
    } message: { _ in
      Text(CommonStrings.irreversibleConfirmation)
    }
    .alert(Text(verbatim: ""), isPresented: $showsResetAllConfirmation) {
      Button(Self.resetAllTitle, role: .destructive) {
        resetAllChecklists()
      }
      Button(CommonStrings.cancel, role: .cancel) {}
    } message: {
      Text(CommonStrings.irreversibleConfirmation)
    }
    .task {
      guard remoteChangeObserver == nil else { return }
      // `@Query` already reloads on remote changes; this observer exists only to run the dedupe
      // when another device's duplicate sample lands.
      remoteChangeObserver = RemoteChangeObserver {
        try? SampleData.dedupeChecklists(in: context)
      }
    }
    .onAppear {
      analytics.track(
        AnalyticsEvent.checklistsViewed,
        properties: [AnalyticsProperty.checklistsCount: checklists.count]
      )
      analytics.refreshCohortPeopleProperties(checklistsCount: checklists.count)
    }
  }

  // MARK: - Add

  private var addChecklistButton: some View {
    Button {
      addChecklist()
    } label: {
      // Deliberately 60pt across, with a 10pt inset around the icon and a gray shadow at 40%
      // opacity, radius 3, offset 2pt down: matches the pre-SwiftUI design (see PR #136).
      Image("AddChecklistIcon")
        .resizable()
        .scaledToFit()
        .padding(10)
        .frame(width: 60, height: 60)
        .background(Circle().fill(Colors.defaultBackgroundColor))
        .shadow(color: Colors.shadowColor.opacity(0.4), radius: 3, x: 0, y: 2)
    }
    .accessibilityLabel(String(
      localized: "checklists.add.accessibilityLabel",
      defaultValue: "Add new checklist.",
      comment: "VoiceOver label for the round floating button that creates a checklist."
    ))
    .accessibilityIdentifier("toolbar.addChecklist")
    .padding(20)
  }

  private func addChecklist() {
    analytics.track(AnalyticsEvent.checklistCreated)
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
  private static let resetAllTitle = String(
    localized: "checklists.action.resetAll",
    defaultValue: "Reset All",
    comment: "Unchecks every item in every checklist. Popover row and confirmation button; clears progress, never deletes lists."
  )

  private func confirmDelete(id checklistId: String) {
    // `nil` means it is already gone — deleted on another device while the alert was up.
    guard let checklist = context.checklist(id: checklistId) else { return }
    analytics.track(AnalyticsEvent.checklistDeleted)
    // The items go with it: the relationship's cascade delete rule handles that automatically.
    context.delete(checklist)
    context.saveChangesIgnoringFailure(operation: .delete)
  }

  // MARK: - Duplicating

  /// No confirmation, no modal and no navigation: the copy appears in the row below the original,
  /// where the result is already on screen. The detail screen's menu entry opens the copy instead,
  /// because from in there it would not be.
  private func duplicate(checklist: Checklist) {
    do {
      try context.duplicate(checklist: checklist, among: Array(checklists))
    } catch {
      return // Already logged and reported by `saveChanges`; nothing was added, so nothing is tracked.
    }
    analytics.track(
      AnalyticsEvent.checklistDuplicated,
      properties: [AnalyticsProperty.source: ChecklistDuplicationSource.swipe.rawValue]
    )
  }

  // MARK: - Resetting

  private func resetAllChecklists() {
    // Stamped in the loop rather than through `saveStatusChange`, which saves per checklist: one
    // batched save for the whole sweep is the point of doing it here.
    let now = Date.now
    // The `where` call is the reset itself, not a filter — SwiftLint's `for_where` requires this
    // shape. Its result says whether the list had anything to reset, and so whether to date it.
    for checklist in checklists where checklist.uncheckAllItems() {
      checklist.recordUpdate(at: now)
    }
    context.saveChangesIgnoringFailure(operation: .itemUpdate)
    // No reload to follow: each row's status icon reads `percentageComplete` in its own body,
    // so Observation redraws the rings.
  }
}

#if DEBUG
  #Preview("Seeded") {
    NavigationStack {
      ChecklistsView()
    }
    .previewEnvironment()
  }

  #Preview("Empty") {
    NavigationStack {
      ChecklistsView()
    }
    .previewEnvironment(container: PreviewSupport.emptyContainer)
  }
#endif
