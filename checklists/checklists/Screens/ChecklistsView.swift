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
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// Created on the first `.task` rather than at init: a `@State` initial value would be
  /// rebuilt on every re-render of the view struct, and this observer registers for a
  /// notification in its initializer.
  @State private var remoteChangeObserver: RemoteChangeObserver?

  /// The checklist the delete confirmation is currently about, held by `id` rather than by
  /// row or by model reference. See `ModelContext.deleteChecklists(ids:)`.
  @State private var pendingDeleteID: String?

  @State private var showsResetAllConfirmation = false

  @State private var editMode: EditMode = .inactive
  /// Checklist ids. May name a checklist another device has since deleted; read `liveSelection`.
  @State private var selection = Set<String>()
  /// The Edit mode toolbar action waiting on its confirmation alert.
  @State private var pendingBulkAction: ChecklistsBulkAction?

  /// Kept on the moved row after a move action, which re-sorts the list under VoiceOver.
  @AccessibilityFocusState private var focusedChecklistID: String?

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
              pendingDeleteID = checklist.id
            } label: {
              // Icon-only for the visible button, but the title is what VoiceOver reads and what
              // the UI tests match on, so it stays part of the label rather than being dropped.
              Label(CommonStrings.delete, systemImage: "trash")
                .labelStyle(.iconOnly)
            }
            .tint(Colors.destructiveColor)
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
            .tint(Color.accentColor)
            .accessibilityIdentifier("checklistRow.duplicate")
          }
      }
      // Drag handles in Edit mode; long-press drag outside it.
      .onMove(perform: move)
    }
    .listStyle(.plain)
    .environment(\.editMode, $editMode)
    .appBackground()
    .navigationTitle(Text(verbatim: ""))
    .navigationBarTitleDisplayMode(.inline)
    .overlay(alignment: .bottomTrailing) {
      // Hidden rather than disabled: the bottom toolbar takes its place, and a new checklist
      // appearing mid-selection would only confuse it.
      if !isEditing {
        addChecklistButton
      }
    }
    .toolbar {
      // Editing clears the bar down to Done, so the way out is obvious and nothing competes with
      // the bottom toolbar, which carries its own Reset.
      if !isEditing {
        ToolbarItem(placement: .topBarLeading) {
          mainMenuButton
        }

        ToolbarItem(placement: .topBarTrailing) {
          resetAllButton
        }

        // Keeps Reset All and Edit as two separate buttons rather than one shared capsule, so the
        // one that cannot be undone reads as its own target.
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
      }

      ToolbarItem(placement: .topBarTrailing) {
        editButton
      }

      // Separate items with flexible spacers rather than one group with `Spacer`s: iOS 26 gives each
      // item its own capsule, and in a group the outer two were pushed past the screen edges.
      // Delete and Reset cannot be undone, so they confirm; Duplicate takes nothing away.
      ToolbarItem(placement: .bottomBar) {
        bulkActionButton(
          CommonStrings.delete,
          systemImage: "trash",
          tint: Colors.destructiveColor,
          id: "editBar.delete"
        ) {
          pendingBulkAction = .delete
        }
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
          pendingBulkAction = .reset
        }
      }
    }
    .toolbar(isEditing ? .visible : .hidden, for: .bottomBar)
    .onChange(of: isEditing) { _, editing in
      if !editing {
        selection.removeAll()
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
    .alert(Text(verbatim: ""), isPresented: isPresentingBulkConfirmation, presenting: pendingBulkAction) { action in
      Button(action == .delete ? CommonStrings.delete : Self.resetSelectedTitle, role: .destructive) {
        perform(action)
      }
      Button(CommonStrings.cancel, role: .cancel) {}
    } message: { _ in
      Text(CommonStrings.irreversibleConfirmation)
    }
    .alert(Text(verbatim: ""), isPresented: $showsResetAllConfirmation) {
      Button(Self.resetAllTitle, role: .destructive) {
        context.resetChecklists(Array(checklists))
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

  private var mainMenuButton: some View {
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
    // Locale-invariant handle for `translation-accessibility-size-check`, which cannot
    // navigate by localized visible text.
    .accessibilityIdentifier("toolbar.mainMenu")
  }

  /// Always enabled, even with no checklists: the control stays visible so people learn it exists,
  /// and confirming with nothing to reset does nothing.
  private var resetAllButton: some View {
    Button {
      showsResetAllConfirmation = true
    } label: {
      barLabel(Self.resetAllTitle, systemImage: "arrow.counterclockwise")
    }
    .tint(Color.accentColor)
    .accessibilityIdentifier("toolbar.resetAll")
  }

  /// Words up to one step above the default text size, an icon from two steps up, in every
  /// language. At the largest sizes the longest translations overflow both bars: German and Tamil
  /// push Edit into the nav bar's "•••" menu, and German and Russian clip the bottom toolbar at the
  /// screen edges. Edit never collapses — it is how people find reordering. The words stay as the
  /// VoiceOver label and in the Large Content Viewer.
  private func barLabel(_ title: String, systemImage: String) -> some View {
    Group {
      if dynamicTypeSize >= .xxLarge {
        Image(systemName: systemImage)
      } else {
        Text(title)
      }
    }
    .accessibilityLabel(title)
    .accessibilityShowsLargeContentViewer {
      Label(title, systemImage: systemImage)
    }
  }

  /// Always enabled, like Reset All: with no checklists it opens an empty Edit mode.
  private var editButton: some View {
    Button {
      if !isEditing {
        analytics.track(AnalyticsEvent.checklistsEditModeEntered)
      }
      withAnimation {
        editMode = isEditing ? .inactive : .active
      }
    } label: {
      Text(isEditing ? CommonStrings.done : Self.editTitle)
        .fontWeight(isEditing ? .semibold : .regular)
    }
    .tint(Color.accentColor)
    .accessibilityIdentifier("toolbar.edit")
  }

  private func bulkActionButton(
    _ title: String,
    systemImage: String,
    tint: Color = .accentColor,
    id: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      barLabel(title, systemImage: systemImage)
    }
    .tint(tint)
    .disabled(liveSelection.isEmpty)
    .accessibilityIdentifier(id)
  }

  // MARK: - Add

  private var addChecklistButton: some View {
    Button {
      addChecklist()
    } label: {
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
    focusedChecklistID = checklist.id
    let announcement = String(
      localized: "checklists.accessibility.movedToPosition",
      defaultValue: "Moved to position \(destination + 1) of \(count)",
      comment: """
      VoiceOver announcement after a checklist is moved with a Move Up/Down/to Top/to Bottom \
      action. First placeholder is its new position counting from 1, second the number of checklists.
      """
    )
    // Posted after a beat: the list re-sorts and focus is restored in the same update, and an
    // announcement made during that is cut off by VoiceOver reading the refocused row.
    Task {
      try? await Task.sleep(for: .milliseconds(500))
      AccessibilityNotification.Announcement(announcement).post()
    }
  }

  private static func title(for action: ChecklistMoveAction) -> String {
    switch action {
    case .up:
      String(
        localized: "checklists.accessibilityAction.moveUp",
        defaultValue: "Move Up",
        comment: "VoiceOver action on a checklist row: moves it one place up the list."
      )
    case .down:
      String(
        localized: "checklists.accessibilityAction.moveDown",
        defaultValue: "Move Down",
        comment: "VoiceOver action on a checklist row: moves it one place down the list."
      )
    case .top:
      String(
        localized: "checklists.accessibilityAction.moveToTop",
        defaultValue: "Move to Top",
        comment: "VoiceOver action on a checklist row: moves it to the start of the list."
      )
    case .bottom:
      String(
        localized: "checklists.accessibilityAction.moveToBottom",
        defaultValue: "Move to Bottom",
        comment: "VoiceOver action on a checklist row: moves it to the end of the list."
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
      }
    )
  }

  private func confirmDelete(id checklistId: String) {
    // `0` means it is already gone — deleted on another device while the alert was up.
    guard context.deleteChecklists(ids: [checklistId]) > 0 else { return }
    analytics.track(AnalyticsEvent.checklistDeleted)
  }

  // MARK: - Duplicating

  /// The detail screen's menu entry opens the copy; this one does not, because here the result is
  /// already on screen.
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

  // MARK: - Edit mode actions

  private var isPresentingBulkConfirmation: Binding<Bool> {
    Binding(
      get: { pendingBulkAction != nil },
      set: { isPresented in
        if !isPresented {
          pendingBulkAction = nil
        }
      }
    )
  }

  /// Runs a toolbar action on the selection, then leaves Edit mode.
  private func perform(_ action: ChecklistsBulkAction) {
    let ids = liveSelection
    guard !ids.isEmpty else { return }
    switch action {
    case .delete:
      context.deleteChecklists(ids: ids)
    case .duplicate:
      context.duplicateChecklists(ids: ids)
    case .reset:
      context.resetChecklists(checklists.filter { ids.contains($0.id) })
    }
    analytics.track(
      AnalyticsEvent.checklistsBulkActionPerformed,
      properties: [
        AnalyticsProperty.bulkAction: action.rawValue,
        AnalyticsProperty.selectedCount: ids.count,
      ]
    )
    withAnimation {
      editMode = .inactive
    }
  }

  // MARK: - Strings

  private static let editTitle = String(
    localized: "checklists.action.edit",
    defaultValue: "Edit",
    comment: "Nav bar button that enters Edit mode on the list of checklists (select, reorder, delete, duplicate, reset). Becomes Done while editing."
  )

  private static let resetAllTitle = String(
    localized: "checklists.action.resetAll",
    defaultValue: "Reset All",
    comment: "Unchecks every item in every checklist. Nav bar button beside Edit, and its confirmation button; clears progress, never deletes lists."
  )

  private static let resetSelectedTitle = String(
    localized: "checklists.action.resetSelected",
    defaultValue: "Reset",
    comment: "Edit mode toolbar button, beside Delete and Duplicate, and its confirmation button: unchecks every item in the selected checklists. Clears progress, never deletes lists."
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

  //
  // The overflows these guard against showed up only in long translations, which a preview cannot
  // force: the labels resolve through `String(localized:)`, which follows the app's language, not
  // the preview environment. These pin the sizes either side of the icon threshold; the localized
  // check is `translation-accessibility-size-check`.

  // The largest size that keeps Reset All's words. At xxxLarge with words, German and Tamil pushed
  // Edit into the nav bar's "•••" menu (Tamil lost Reset All too).
  #Preview("Nav bar, xLarge: last size with words") {
    NavigationStack {
      ChecklistsView()
    }
    .previewEnvironment()
    .dynamicTypeSize(.xLarge)
  }

  // The icon threshold: Reset All is ↺ from here up, and Edit keeps its word.
  #Preview("Nav bar, xxLarge: icon") {
    NavigationStack {
      ChecklistsView()
    }
    .previewEnvironment()
    .dynamicTypeSize(.xxLarge)
  }

  // The largest size that keeps the toolbar's words. At xxxLarge with words, German and Russian
  // pushed Delete and Reset past the screen edges.
  #Preview("Edit mode, xLarge: last size with words") {
    NavigationStack {
      ChecklistsView(editingWith: [SampleData.morningRoutineId])
    }
    .previewEnvironment()
    .dynamicTypeSize(.xLarge)
  }

  // The largest standard size, where both bars are icons but Edit and Done keep their words.
  #Preview("Edit mode, xxxLarge: icons") {
    NavigationStack {
      ChecklistsView(editingWith: [SampleData.morningRoutineId])
    }
    .previewEnvironment()
    .dynamicTypeSize(.xxxLarge)
  }
#endif
