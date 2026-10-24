//
//  ExportPDFView.swift
//  checklists
//

import SwiftData
import SwiftUI

/// The sheet behind the checklist menu's "Export as PDF…": a date, an optional Header, and Export,
/// which makes the PDF and opens the share sheet with it.
///
/// The PDF is a record to hand someone else, such as a client after a job. The date defaults to now
/// and can be set to when the work was done. The Header always starts empty, so one client's
/// details never carry over to the next; Saved Headers are how standing text comes back.
///
/// A completed share closes the sheet. A cancelled one leaves it open with everything as it was,
/// so the person can adjust and try again.
struct ExportPDFView: View {
  let checklist: Checklist

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Environment(\.analytics) private var analytics
  @Environment(\.layoutDirection) private var layoutDirection
  @Environment(SavedHeadersStore.self) private var savedHeaders
  /// Optional at the leaf, like `CopyCheckedItemsView`'s: a missing presenter means "no toast".
  @Environment(ToastPresenter.self) private var toasts: ToastPresenter?

  /// Kept to tell whether the person changed the date, for `date_changed`.
  @State private var initialDate = Date.now
  @State private var date = Date.now
  @State private var header = ""
  @State private var didInsertSavedHeader = false
  /// True from Export until the share sheet closes, so a second tap cannot start a second export.
  @State private var isExporting = false
  @State private var editorProxy = HeaderEditorProxy()
  @State private var activityPresenter = ActivityPresenterProxy()

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker(Self.dateLabel, selection: $date, displayedComponents: [.date, .hourAndMinute])
            .accessibilityIdentifier("exportPDF.date")
        }
        headerSection
      }
      .appBackground()
      .navigationTitle(Self.title)
      .navigationBarTitleDisplayMode(.inline)
      .background(ActivityPresenter(proxy: activityPresenter))
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(role: .close) {
            dismiss()
          }
          .tint(Color.accentColor)
        }
        ToolbarItem(placement: .topBarTrailing) {
          if isExporting {
            ProgressView()
              .accessibilityLabel(Self.exportingAccessibilityLabel)
          } else {
            Button(Self.exportTitle, role: .confirm) {
              Task { await export() }
            }
            .tint(Color.accentColor)
            .accessibilityIdentifier("exportPDF.export")
          }
        }
      }
    }
  }

  // MARK: - Header

  private var headerSection: some View {
    Section {
      HeaderTextEditor(text: $header, proxy: editorProxy, accessibilityLabel: Self.headerTitle)
      // Shown only when it would do something, so it never offers to save an empty field or a
      // duplicate.
      if savedHeaders.canSave(header) {
        Button(Self.saveForReuseTitle, action: saveHeader)
          .accessibilityIdentifier("exportPDF.saveForReuse")
      }
    } header: {
      HStack {
        Text(Self.headerTitle)
        Spacer()
        // Absent until something has been saved: an empty menu would be a button that does nothing.
        if !savedHeaders.headers.isEmpty {
          savedHeadersMenu
        }
      }
    }
  }

  private var savedHeadersMenu: some View {
    Menu {
      Section {
        // Newest first, as the store keeps them. Long entries are truncated by the menu itself.
        ForEach(savedHeaders.headers, id: \.self) { saved in
          Button(saved) {
            editorProxy.append(saved)
            didInsertSavedHeader = true
          }
        }
      }
      if savedHeaders.canSave(header) {
        Button(Self.saveForReuseTitle, systemImage: "plus", action: saveHeader)
      }
      // Unconfirmed: a Saved Header is only a shortcut, and the text it held can be typed again.
      Menu {
        ForEach(savedHeaders.headers, id: \.self) { saved in
          Button(saved, role: .destructive) {
            savedHeaders.delete(saved)
          }
        }
      } label: {
        Label(CommonStrings.delete, systemImage: "trash")
      }
      .accessibilityIdentifier("exportPDF.savedHeaders.delete")
    } label: {
      Label(Self.savedHeadersTitle, systemImage: "text.badge.plus")
        .labelStyle(.iconOnly)
        .font(.body)
        .foregroundStyle(Color.accentColor)
    }
    .accessibilityIdentifier("exportPDF.savedHeaders")
  }

  private func saveHeader() {
    savedHeaders.save(header)
    analytics.track(AnalyticsEvent.checklistPDFHeaderSaved)
  }

  // MARK: - Export

  private func export() async {
    // A merge from another device can delete the checklist while this sheet is up, and the
    // screen under it closes without closing this. Same response as `CopyCheckedItemsView`'s.
    // Looked up by record, as `ChecklistViewController.handleRemoteChange` does.
    guard !checklist.isDeleted, context.checklist(checklist.persistentModelID) != nil else {
      dismiss()
      toasts?.show(.checklistDeletedElsewhere)
      return
    }
    isExporting = true
    // One frame, so the progress indicator is on screen before rendering holds the main thread.
    try? await Task.sleep(for: .milliseconds(20))

    let snapshot = ChecklistPDFSnapshot.make(
      from: checklist,
      date: date,
      header: header,
      isRightToLeft: layoutDirection == .rightToLeft,
    )
    let url: URL
    do {
      let data = ChecklistPDFRenderer.render(snapshot)
      url = try PDFExportFile.write(data, fileName: PDFFileName.make(title: snapshot.title, date: snapshot.date, timeZone: snapshot.timeZone))
    } catch {
      AppLog.persistence.error("Could not write the exported PDF: \(error.localizedDescription, privacy: .public)")
      isExporting = false
      toasts?.show(.pdfExportFailed)
      return
    }

    let presented = activityPresenter.present(url: url) { completed in
      PDFExportFile.remove(url)
      isExporting = false
      guard completed else { return }
      trackExport(of: snapshot)
      dismiss()
    }
    if !presented {
      PDFExportFile.remove(url)
      isExporting = false
    }
  }

  /// Counts and flags only: never the Header or anything from the checklist
  /// (analytics-spec.md §Deny-list).
  private func trackExport(of snapshot: ChecklistPDFSnapshot) {
    analytics.track(
      AnalyticsEvent.checklistPDFExported,
      properties: [
        AnalyticsProperty.itemsCount: snapshot.rows.count,
        AnalyticsProperty.checkedItemsCount: snapshot.rows.count(where: \.isChecked),
        AnalyticsProperty.hasHeader: !snapshot.header.isEmpty,
        // To the minute, the picker's own precision.
        AnalyticsProperty.dateChanged: !Calendar.current.isDate(date, equalTo: initialDate, toGranularity: .minute),
        AnalyticsProperty.savedHeaderInserted: didInsertSavedHeader,
      ],
    )
  }

  // MARK: - Copy

  private static let title = String(
    localized: "exportPDF.title",
    defaultValue: "Export as PDF",
    comment: """
    Title of the sheet that turns a checklist into a PDF document to send to someone, for example \
    as a record of work done for a client. Reached from the checklist screen's Export as PDF… menu \
    entry; keep the two consistent. "PDF" is the file format; keep it as is.
    """,
  )

  private static let dateLabel = String(
    localized: "exportPDF.date.label",
    defaultValue: "Date",
    comment: """
    Label beside the date and time picker on the Export as PDF sheet. The chosen date and time are \
    printed at the top of the PDF; it defaults to now and can be changed, for example to when the \
    work was done.
    """,
  )

  private static let headerTitle = String(
    localized: "exportPDF.header.title",
    defaultValue: "Header",
    comment: """
    Header over the free-text field on the Export as PDF sheet, and that field's VoiceOver label. \
    Whatever is typed there is printed at the top of the PDF, above the checklist: typically a \
    business name, licence number or the client's address. Not the checklist's own notes, so \
    don't translate it with the same word as "Notes".
    """,
  )

  private static let savedHeadersTitle = String(
    localized: "exportPDF.savedHeaders.title",
    defaultValue: "Saved Headers",
    comment: """
    VoiceOver label for the icon button beside the Header field on the Export as PDF sheet. It \
    opens a menu of Header texts the person saved earlier, to insert one into the field. Use the \
    same word for Header as exportPDF.header.title.
    """,
  )

  private static let saveForReuseTitle = String(
    localized: "exportPDF.saveForReuse",
    defaultValue: "Save for Reuse",
    comment: """
    Button under the Header field on the Export as PDF sheet, and an entry in the Saved Headers \
    menu. Saves the text currently in the Header field so it can be inserted again in a later \
    export. Short; title case in English.
    """,
  )

  private static let exportTitle = String(
    localized: "exportPDF.export",
    defaultValue: "Export",
    comment: """
    Confirming button at the top of the Export as PDF sheet. Makes the PDF and opens the system \
    share sheet with it, to send by message, email or AirDrop or save to Files.
    """,
  )

  private static let exportingAccessibilityLabel = String(
    localized: "exportPDF.exporting.accessibilityLabel",
    defaultValue: "Creating PDF",
    comment: "VoiceOver label for the spinner that replaces the Export button on the Export as PDF sheet while the PDF is being made.",
  )
}

#if DEBUG
  #Preview("Export sheet") {
    ExportPDFView(checklist: PreviewSupport.checklist())
      .previewEnvironment()
  }

  #Preview("With Saved Headers") {
    ExportPDFView(checklist: PreviewSupport.checklist())
      .previewEnvironment(savedHeaders: {
        let store = SavedHeadersStore(store: InMemoryKeyValueStore())
        store.save("Acme Plumbing Ltd\nLicence 12345")
        store.save("All work guaranteed for 12 months.")
        return store
      }())
  }
#endif
