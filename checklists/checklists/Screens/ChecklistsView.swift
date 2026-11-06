//
//  ChecklistsView.swift
//  checklists
//

import SwiftData
import SwiftUI

/// The app's top-level screen: every checklist, in the user's own order.
///
/// Edit mode is selection mode: rows gain selection circles and drag handles, and a bottom toolbar
/// acts on the selection. Every row also carries move actions for assistive technologies, in or out
/// of Edit mode, since neither the handles nor the long-press drag can be used without dragging.
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

  /// The Add artwork's size, a little over a bar symbol's since the drawing sits inside some
  /// padding. Left to itself it fills the bar's height and stretches the glass capsule. Fixed, like
  /// the other bar icons; larger text sizes get the Large Content Viewer.
  private static let addIconSize: CGFloat = 28

  /// Created on the first `.task` rather than at init: a `@State` initial value would be
  /// rebuilt on every re-render of the view struct, and this observer registers for a
  /// notification in its initializer.
  @State private var remoteChangeObserver: RemoteChangeObserver?

  /// The checklist the delete confirmation is currently about: the row's own record, not its
  /// `id`, since two records can share an `id` until sample dedupe runs and deleting by `id` could
  /// take the other one. See `ModelContext.deleteChecklists(_:)`.
  @State private var pendingDeleteID: PersistentIdentifier?
  /// The delete alert's title, fixed when the alert opens. Worked out live, it would fall back to the
  /// untitled name as the alert closes, once the confirmed checklist is gone.
  @State private var deleteConfirmationTitle = ""

  @State private var showsResetAllConfirmation = false

  @State private var editMode: EditMode = .inactive
  /// Checklist ids. May name a checklist another device has since deleted; read `liveSelection`.
  @State private var selection = Set<String>()
  /// The Edit mode toolbar action waiting on its confirmation alert.
  @State private var pendingBulkAction: ChecklistsBulkAction?
  /// The bulk alert's title, fixed when the alert opens, for the same reason as
  /// `deleteConfirmationTitle`: confirming clears the selection while the alert is still closing.
  @State private var bulkConfirmationTitle = ""

  /// Where VoiceOver goes after a move (the moved row, as the list re-sorts) or a delete (its neighbour).
  @AccessibilityFocusState private var focusedChecklistID: String?
  /// Where VoiceOver goes on leaving Edit mode, by Done or by an Edit mode action, either of which
  /// takes the button it was on away.
  @AccessibilityFocusState private var isMoreMenuFocused: Bool
  /// Where VoiceOver goes on entering Edit mode, from a menu that has closed.
  @AccessibilityFocusState private var isEditDoneFocused: Bool
  /// Where VoiceOver goes when deleting a checklist leaves none.
  @AccessibilityFocusState private var isAddButtonFocused: Bool

  /// Read back from the list so rows can center in a readable column on a wide window.
  @State private var listWidth: CGFloat = 0

  private var listColumnMargin: CGFloat? {
    let margin = readableColumnMargin(for: listWidth)
    return margin > 0 ? margin : nil
  }

  private var isEditing: Bool {
    editMode.isEditing
  }

  /// The selection minus anything deleted elsewhere since it was made.
  private var liveSelection: Set<String> {
    selection.intersection(checklists.map(\.id))
  }

  var body: some View {
    List(selection: $selection) {
      ForEach(checklists) { checklist in
        row(for: checklist)
          .tag(checklist.id)
          .accessibilityIdentifier("checklistRow.\(checklist.id)")
          .accessibilityFocused($focusedChecklistID, equals: checklist.id)
          .accessibilityActions {
            ForEach(availableMoves(for: checklist), id: \.self) { action in
              Button(Self.title(for: action)) {
                move(checklist, action)
              }
            }
          }
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
          .listRowSeparator(.hidden)
          // Lets the screen's background show through instead of the system's row fill.
          .listRowBackground(Color.clear)
          .swipeActions(edge: .trailing) {
            // Deliberately NOT `role: .destructive`: a full swipe on one animates the row away
            // before the confirmation alert, and a cancelled confirmation must leave the row
            // visible. The red comes from an explicit tint instead.
            Button {
              deleteConfirmationTitle = Self.deleteConfirmationTitle(name: checklist.name)
              pendingDeleteID = checklist.persistentModelID
            } label: {
              // Icon-only for the visible button, but the title is what VoiceOver reads and what
              // the UI tests match on, so it stays part of the label rather than being dropped.
              Label(CommonStrings.delete, systemImage: "trash")
                .labelStyle(.iconOnly)
            }
            .tint(Colors.destructiveFillColor)
            // Locale-invariant handle for `translation-accessibility-size-check`, which cannot
            // match localized label text, and positional lookup on the revealed buttons is not
            // reliable straight after the swipe.
            .accessibilityIdentifier("checklistRow.delete")

            // Declared after Delete, so Delete keeps the outer edge and the full-swipe slot.
            // Unconfirmed: a copy takes nothing away, and the way to undo one is to delete it.
            Button {
              duplicate(checklist: checklist)
            } label: {
              Label(CommonStrings.duplicate, systemImage: "plus.square.on.square")
                .labelStyle(.iconOnly)
            }
            .tint(Colors.accentFillColor)
            .accessibilityIdentifier("checklistRow.duplicate")
          }
          // The swipe actions again, for long-press and right-click. `.onMove`'s long-press drag
          // still works: moving the finger once the menu is up lifts the row into the drag. Absent
          // in Edit mode, like the swipe, where the bottom bar acts on the selection instead.
          .contextMenu {
            if !isEditing {
              Button(CommonStrings.duplicate, systemImage: "plus.square.on.square") {
                duplicate(checklist: checklist, source: .contextMenu)
              }
              Button(CommonStrings.delete, systemImage: "trash", role: .destructive) {
                deleteConfirmationTitle = Self.deleteConfirmationTitle(name: checklist.name)
                pendingDeleteID = checklist.persistentModelID
              }
            }
          }
      }
      // Drag handles in Edit mode; long-press drag outside it.
      .onMove(perform: move)
    }
    .listStyle(.plain)
    // Insets whole rows, so Edit mode's controls and swipe actions stay beside them. `nil` below
    // the cap keeps the list's stock margins on a narrow window.
    .contentMargins(.horizontal, listColumnMargin, for: .scrollContent)
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { listWidth = $0 }
    .environment(\.editMode, $editMode)
    .appBackground()
    .background { keyboardShortcuts }
    // Named for VoiceOver, but not drawn.
    .navigationTitle(Self.screenTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(removing: .title)
    .toolbar {
      // Every bar button is an icon, so on iPhone Duo's outer display the whole bar moves into the
      // vertical bar and the list gets the screen's full height; a word would keep a top bar alive.
      // Editing clears the bar down to Done, so the way out is obvious and nothing competes with
      // the bottom toolbar, which carries its own Reset.
      if isEditing {
        // Pinned: at the top of the vertical bar, and never in its overflow.
        ToolbarItem(placement: .topBarPinnedTrailing) {
          editDoneButton
        }
      } else {
        ToolbarItem(placement: .topBarLeading) {
          settingsButton
        }

        ToolbarItem(placement: .topBarTrailing) {
          moreMenu
        }
      }

      // The bottom bar is always up: Edit mode's bulk actions, otherwise Add. On iPhone Duo's
      // outer display it moves to the bottom of the vertical bar, lined up with the rest.
      if isEditing {
        // Separate items with flexible spacers rather than one group with `Spacer`s: iOS 26 gives each
        // item its own capsule, and in a group the outer two were pushed past the screen edges.
        // Delete and Reset cannot be undone, so they confirm; Duplicate takes nothing away.
        ToolbarItem(placement: .bottomBar) {
          bulkActionButton(
            CommonStrings.delete,
            systemImage: "trash",
            tint: Colors.destructiveColor,
            id: "editBar.delete",
          ) {
            confirm(.delete)
          }
          // ⌘⌫, behind the same confirmation: a checklist never goes unasked.
          .keyboardShortcut(shortcut(KeyboardShortcut(.delete)))
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
          bulkActionButton(CommonStrings.duplicate, systemImage: "plus.square.on.square", id: "editBar.duplicate") {
            perform(.duplicate)
          }
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
          bulkActionButton(Self.resetSelectedTitle, systemImage: "arrow.counterclockwise", id: "editBar.reset") {
            confirm(.reset)
          }
        }
      } else {
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
          addChecklistButton
        }
        .visibilityPriority(.high)
      }
    }
    .onChange(of: isEditing) { _, editing in
      if !editing {
        selection.removeAll()
      }
    }
    .alert(Text(deleteConfirmationTitle), isPresented: isPresentingDeleteConfirmation, presenting: pendingDeleteID) { persistentID in
      Button(CommonStrings.delete, role: .destructive) {
        confirmDelete(persistentID)
      }
      Button(CommonStrings.cancel, role: .cancel) {}
    } message: { _ in
      Text(CommonStrings.irreversibleConfirmation)
    }
    .alert(Text(bulkConfirmationTitle), isPresented: isPresentingBulkConfirmation, presenting: pendingBulkAction) { action in
      Button(action == .delete ? CommonStrings.delete : Self.resetSelectedTitle, role: .destructive) {
        perform(action)
      }
      Button(CommonStrings.cancel, role: .cancel) {}
    } message: { _ in
      Text(CommonStrings.irreversibleConfirmation)
    }
    .alert(Text(Self.resetAllConfirmationTitle), isPresented: $showsResetAllConfirmation) {
      Button(Self.resetAllTitle, role: .destructive) {
        if context.resetChecklists(Array(checklists)) > 0 {
          analytics.track(AnalyticsEvent.allChecklistsReset)
          postAccessibilityFeedback(Self.allResetAnnouncement, afterAlert: true)
        }
      }
      Button(CommonStrings.cancel, role: .cancel) {}
    } message: {
      Text(CommonStrings.irreversibleConfirmation)
    }
    .task {
      guard remoteChangeObserver == nil else { return }
      // `@Query` already reloads on remote changes; this observer exists only to run the dedupe
      // when the account's copy of a sample lands.
      remoteChangeObserver = RemoteChangeObserver {
        try? SampleData.dedupeChecklists(in: context)
      }
    }
    .onAppear {
      analytics.track(
        AnalyticsEvent.checklistsViewed,
        properties: [AnalyticsProperty.checklistsCount: checklists.count],
      )
      analytics.refreshCohortPeopleProperties(checklistsCount: checklists.count)
    }
  }

  // MARK: - Rows

  /// Outside Edit mode a row is a `Button` pushing the route by hand rather than a
  /// `NavigationLink`: inside a `List` the link draws a disclosure chevron that this screen
  /// deliberately does without, and SwiftUI offers no way to suppress it. In Edit mode it is bare
  /// content, so a tap selects it instead of opening it.
  @ViewBuilder
  private func row(for checklist: Checklist) -> some View {
    if isEditing {
      rowContent(for: checklist)
    } else {
      Button {
        router.path.append(.checklist(id: checklist.id))
      } label: {
        rowContent(for: checklist)
      }
      .buttonStyle(.plain)
    }
  }

  private func rowContent(for checklist: Checklist) -> some View {
    ChecklistRowView(checklist: checklist)
      // The row's own content is only as wide as its text, so widen it to make the whole row
      // tappable rather than just the words.
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
  }

  // MARK: - Toolbar

  private var settingsButton: some View {
    Button {
      router.sheet = .settings
    } label: {
      // A label rather than a bare image, as with "•••".
      Label(CommonStrings.settingsTitle, systemImage: "gearshape")
        .accessibilityShowsLargeContentViewer()
    }
    // iOS 26 renders bar buttons in `labelColor` unless the button itself carries a tint.
    .tint(Color.accentColor)
    // Locale-invariant handle for `translation-accessibility-size-check`, which cannot
    // navigate by localized visible text.
    .accessibilityIdentifier("toolbar.settings")
    .keyboardShortcut(shortcut(KeyboardShortcut(",")))
  }

  /// Edit and Reset All, behind one "•••" as on a checklist's own screen. Both entries are always
  /// enabled, even with no checklists: they stay visible so people learn they exist; Edit then
  /// opens an empty Edit mode, and confirming Reset All with nothing to reset does nothing.
  private var moreMenu: some View {
    Menu {
      // Rows in the system's own colors, as on a checklist's screen: the menu's accent tint would
      // otherwise reach them, leaving Reset All a teal icon beside red words.
      Group {
        Button(Self.editTitle, systemImage: "pencil") {
          analytics.track(AnalyticsEvent.checklistsEditModeEntered)
          withAnimation {
            editMode = .active
          }
          // The menu VoiceOver was in has closed and its button gone with Edit mode.
          postAccessibilityFeedback(nil, afterAlert: true) {
            isEditDoneFocused = true
          }
        }
        .accessibilityIdentifier("toolbar.edit")

        // Divided off, so a thumb reaching for Edit cannot land on the one that cannot be undone.
        Divider()

        Button(Self.resetAllTitle, systemImage: "arrow.counterclockwise", role: .destructive) {
          showsResetAllConfirmation = true
        }
        .accessibilityIdentifier("toolbar.resetAll")
      }
      .tint(nil)
    } label: {
      // A label rather than a bare image: its title is what VoiceOver reads and what the Large
      // Content Viewer shows.
      Label(CommonStrings.more, systemImage: "ellipsis")
        .accessibilityShowsLargeContentViewer()
    }
    .tint(Color.accentColor)
    .accessibilityIdentifier("toolbar.more")
    .accessibilityFocused($isMoreMenuFocused)
  }

  private var editDoneButton: some View {
    Button(role: .confirm) {
      withAnimation {
        editMode = .inactive
      }
      postAccessibilityFeedback(nil, afterAlert: true) {
        isMoreMenuFocused = true
      }
    }
    // `accentFill`: iOS draws a white checkmark on a capsule of this tint.
    .tint(Colors.accentFillColor)
    // The system's own checkmark and "Done" label, enlarged on a long press like the other icons.
    .accessibilityShowsLargeContentViewer()
    .accessibilityIdentifier("toolbar.editDone")
    .keyboardShortcut(shortcut(.cancelAction))
    .accessibilityFocused($isEditDoneFocused)
  }

  /// Always an icon, at every text size and in every language: a word would keep a bottom toolbar
  /// on iPhone Duo's outer display, and the longest translations clip at the screen edges at large
  /// sizes. The title is the VoiceOver label and what the Large Content Viewer shows.
  private func bulkActionButton(
    _ title: String,
    systemImage: String,
    tint: Color = .accentColor,
    id: String,
    action: @escaping () -> Void,
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .labelStyle(.iconOnly)
        .accessibilityShowsLargeContentViewer()
    }
    .tint(tint)
    .disabled(liveSelection.isEmpty)
    .accessibilityIdentifier(id)
  }

  // MARK: - Keyboard shortcuts

  /// Shortcuts are off while ChecklistScreen or a sheet is up. The stack keeps this screen alive
  /// under them, and ⌘N there would otherwise make a checklist.
  private var isFrontmost: Bool {
    router.path.isEmpty && router.sheet == nil
  }

  private func shortcut(_ shortcut: KeyboardShortcut) -> KeyboardShortcut? {
    isFrontmost ? shortcut : nil
  }

  private var keyboardShortcuts: some View {
    ChecklistsNewChecklistShortcut(isEnabled: isFrontmost && !isEditing, newChecklist: addChecklist)
  }

  // MARK: - Add

  private var addChecklistButton: some View {
    Button {
      addChecklist()
    } label: {
      // The artwork in its own colours, not the bar's tint. The image alone, no title: given a
      // Label, the toolbar sizes its glass capsule for the title even when it draws only the icon.
      Image("AddChecklistIcon")
        .renderingMode(.original)
        .resizable()
        .scaledToFit()
        .frame(width: Self.addIconSize, height: Self.addIconSize)
    }
    .accessibilityLabel(Self.addLabel)
    .accessibilityShowsLargeContentViewer {
      Label(Self.addLabel, image: "AddChecklistIcon")
    }
    .accessibilityIdentifier("toolbar.addChecklist")
    .accessibilityFocused($isAddButtonFocused)
  }

  private static let addLabel = String(
    localized: "checklists.add.accessibilityLabel",
    defaultValue: "Add new checklist.",
    comment: "VoiceOver label for the bottom-bar button that creates a checklist.",
  )

  private func addChecklist() {
    analytics.track(AnalyticsEvent.checklistCreated)
    let checklist = Checklist()
    do {
      try context.insert(checklist: checklist, at: 0, among: Array(checklists))
    } catch {
      return // `saveChanges` told the person, and the insert has taken the checklist back out.
    }
    router.sheet = .newChecklist(id: checklist.id)
  }

  // MARK: - Reordering

  /// - Note: `@Query` re-derives order from the store, so the list can never show an order the
  ///   context doesn't hold.
  private func move(from source: IndexSet, to destination: Int) {
    guard let sourceIndex = source.first else { return }
    // SwiftUI hands over an insertion offset in the list *as it stands*; `move(checklist:among:to:)`
    // wants the destination index in the list *after* the moved row is taken out, matching
    // `UITableViewDataSource.tableView(_:moveRowAt:to:)`. They differ by one for a downward move.
    let destinationIndex = destination > sourceIndex ? destination - 1 : destination
    try? context.move(checklist: checklists[sourceIndex], among: Array(checklists), to: destinationIndex)
  }

  private func availableMoves(for checklist: Checklist) -> [ChecklistMoveAction] {
    guard let index = checklists.firstIndex(where: { $0.id == checklist.id }) else { return [] }
    return ChecklistMoveAction.allCases.filter { $0.destination(from: index, count: checklists.count) != nil }
  }

  /// A move action's reorder. SwiftUI's own reorder says nothing to VoiceOver about where a row
  /// landed, so this announces it.
  private func move(_ checklist: Checklist, _ action: ChecklistMoveAction) {
    let count = checklists.count
    guard let index = checklists.firstIndex(where: { $0.id == checklist.id }),
          let destination = action.destination(from: index, count: count)
    else { return }
    do {
      try context.move(checklist: checklist, among: Array(checklists), to: destination)
    } catch {
      return // `saveChanges` told the person, and the order has been put back.
    }
    // At once, not after the beat: the list re-sorts in this same update, and focus has to follow
    // the row while it moves.
    focusedChecklistID = checklist.id
    postAccessibilityFeedback(String(
      localized: "checklists.accessibility.movedToPosition",
      defaultValue: "Moved to position \(destination + 1) of \(count)",
      comment: """
      VoiceOver announcement after a checklist is moved with a Move Up/Down/to Top/to Bottom \
      action. First placeholder is its new position counting from 1, second the number of checklists.
      """,
    ))
  }

  private static func title(for action: ChecklistMoveAction) -> String {
    switch action {
    case .up:
      String(
        localized: "checklists.accessibilityAction.moveUp",
        defaultValue: "Move Up",
        comment: "VoiceOver action on a checklist row: moves it one place up the list.",
      )
    case .down:
      String(
        localized: "checklists.accessibilityAction.moveDown",
        defaultValue: "Move Down",
        comment: "VoiceOver action on a checklist row: moves it one place down the list.",
      )
    case .top:
      String(
        localized: "checklists.accessibilityAction.moveToTop",
        defaultValue: "Move to Top",
        comment: "VoiceOver action on a checklist row: moves it to the start of the list.",
      )
    case .bottom:
      String(
        localized: "checklists.accessibilityAction.moveToBottom",
        defaultValue: "Move to Bottom",
        comment: "VoiceOver action on a checklist row: moves it to the end of the list.",
      )
    }
  }

  // MARK: - Deleting

  private var isPresentingDeleteConfirmation: Binding<Bool> {
    Binding(
      get: { pendingDeleteID != nil },
      set: { isPresented in
        if !isPresented {
          pendingDeleteID = nil
        }
      },
    )
  }

  private func confirmDelete(_ persistentID: PersistentIdentifier) {
    let ids = checklists.map(\.id)
    let index = checklists.firstIndex { $0.persistentModelID == persistentID }
    // `0` means that record is already gone while the alert was up — deleted on another device, or
    // removed by sample dedupe. Its twin, if any, is deliberately left alone.
    guard context.deleteChecklists([persistentID]) > 0 else { return }
    analytics.track(AnalyticsEvent.checklistDeleted)
    let neighbour = index.flatMap { DeletionFocus.neighbourID(afterRemoving: $0, from: ids) }
    postAccessibilityFeedback(Self.deletedAnnouncement, afterAlert: true) {
      if let neighbour {
        focusedChecklistID = neighbour
      } else {
        isAddButtonFocused = true
      }
    }
  }

  // MARK: - Duplicating

  /// The detail screen's menu entry opens the copy; this one does not, because here the result is
  /// already on screen.
  private func duplicate(checklist: Checklist, source: ChecklistDuplicationSource = .swipe) {
    do {
      try context.duplicate(checklist: checklist, among: Array(checklists))
    } catch {
      return // Already logged and reported by `saveChanges`; nothing was added, so nothing is tracked.
    }
    analytics.track(
      AnalyticsEvent.checklistDuplicated,
      properties: [AnalyticsProperty.source: source.rawValue],
    )
    postAccessibilityFeedback(Self.duplicatedAnnouncement, afterAlert: source == .contextMenu)
  }

  // MARK: - Edit mode actions

  /// Asks before a bulk action that can't be undone, titled with how many it will act on.
  private func confirm(_ action: ChecklistsBulkAction) {
    bulkConfirmationTitle = Self.bulkConfirmationTitle(for: action, count: liveSelection.count)
    pendingBulkAction = action
  }

  private var isPresentingBulkConfirmation: Binding<Bool> {
    Binding(
      get: { pendingBulkAction != nil },
      set: { isPresented in
        if !isPresented {
          pendingBulkAction = nil
        }
      },
    )
  }

  /// Runs a toolbar action on the selection, then leaves Edit mode.
  private func perform(_ action: ChecklistsBulkAction) {
    let ids = liveSelection
    guard !ids.isEmpty else { return }
    let changedCount = switch action {
    case .delete:
      context.deleteChecklists(ids: ids)
    case .duplicate:
      context.duplicateChecklists(ids: ids)
    case .reset:
      context.resetChecklists(checklists.filter { ids.contains($0.id) })
    }
    // Like the single-row paths: a save that failed outright has already told the person, and
    // nothing happened to measure or announce.
    if changedCount > 0 {
      analytics.track(
        AnalyticsEvent.checklistsBulkActionPerformed,
        properties: [
          AnalyticsProperty.bulkAction: action.rawValue,
          AnalyticsProperty.selectedCount: ids.count,
        ],
      )
    }
    withAnimation {
      editMode = .inactive
    }
    guard changedCount > 0 else { return }
    // "•••", because the bulk action VoiceOver was on has gone with Edit mode.
    postAccessibilityFeedback(Self.bulkAnnouncement(for: action, count: changedCount), afterAlert: true) {
      isMoreMenuFocused = true
    }
  }

  // MARK: - VoiceOver feedback

  /// Moves VoiceOver with `focus`, when given, then says `announcement`, when given. Neither shows
  /// when VoiceOver is off.
  ///
  /// `afterAlert` waits for a confirmation alert, a menu, or Edit mode's entry or exit to finish
  /// first: the system moves VoiceOver itself as each closes, which would undo the focus and cut off
  /// the words.
  private func postAccessibilityFeedback(
    _ announcement: String?,
    afterAlert: Bool = false,
    focus: (() -> Void)? = nil,
  ) {
    Task {
      if afterAlert {
        try? await Task.sleep(for: .milliseconds(500))
      }
      if let focus {
        // Cleared first, then set a turn later: a focus state still holding its target from an
        // earlier move or action would not move VoiceOver when set to the same value.
        focusedChecklistID = nil
        isMoreMenuFocused = false
        isEditDoneFocused = false
        isAddButtonFocused = false
        await Task.yield()
        focus()
      }
      guard let announcement else { return }
      // After a beat, or VoiceOver reading the refocused element cuts it off.
      try? await Task.sleep(for: .milliseconds(500))
      AccessibilityNotification.Announcement(announcement).post()
    }
  }

  // MARK: - Strings

  private static let editTitle = String(
    localized: "checklists.action.edit",
    defaultValue: "Edit",
    comment: "Entry in the overflow menu of the list of checklists that enters Edit mode (select, reorder, delete, duplicate, reset).",
  )

  private static let resetAllTitle = String(
    localized: "checklists.action.resetAll",
    defaultValue: "Reset All",
    comment: "Unchecks every item in every checklist. Entry in the overflow menu of the list of checklists, below Edit, and its confirmation button; clears progress, never deletes lists.",
  )

  private static let resetSelectedTitle = String(
    localized: "checklists.action.resetSelected",
    defaultValue: "Reset",
    comment: "Edit mode toolbar button, beside Delete and Duplicate, and its confirmation button: unchecks every item in the selected checklists. Clears progress, never deletes lists.",
  )
}

#if DEBUG
  extension ChecklistsView {
    /// Opens straight into Edit mode with `selection` made, so a preview shows the bottom toolbar
    /// enabled.
    init(editingWith selection: Set<String>) {
      self.init()
      _editMode = State(initialValue: .active)
      _selection = State(initialValue: selection)
    }
  }

  #Preview("Seeded") {
    NavigationStack {
      ChecklistsView()
    }
    .previewEnvironment()
  }

  #Preview("Edit mode") {
    NavigationStack {
      ChecklistsView(editingWith: [SampleData.morningRoutineId])
    }
    .previewEnvironment()
  }

  #Preview("Empty") {
    NavigationStack {
      ChecklistsView()
    }
    .previewEnvironment(container: PreviewSupport.emptyContainer)
  }

  // MARK: Dynamic Type

  // The largest standard size. The bars hold icons at every size, so one preview stands for all
  // of them; the localized check is `translation-accessibility-size-check`.
  #Preview("Edit mode, xxxLarge") {
    NavigationStack {
      ChecklistsView(editingWith: [SampleData.morningRoutineId])
    }
    .previewEnvironment()
    .dynamicTypeSize(.xxxLarge)
  }
#endif
