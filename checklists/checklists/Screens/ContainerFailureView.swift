//
//  ContainerFailureView.swift
//  checklists
//

import SwiftUI

/**
 Shown when the store cannot be opened, or the one-time Realm copy or the first-launch seed cannot
 be completed — rather than continuing into an empty list, which an upgrading user could mistake
 for having lost everything.

 "Start over fresh" appears only when `failure.allowsStoreReset` says the store itself would not
 open. By the time `onStoreReset` runs, every local store has already been deleted; the caller
 reruns startup from there. See `persistence-design.md §The failure screen`.
 */
struct ContainerFailureView: View {
  let failure: ContainerCreationFailure
  let onStoreReset: () -> Void

  @Environment(\.openURL) private var openURL
  @Environment(\.analytics) private var analytics
  @State private var isShowingStartOverConfirmation = false
  @AccessibilityFocusState private var isMessageFocused: Bool

  init(failure: ContainerCreationFailure, onStoreReset: @escaping () -> Void) {
    self.failure = failure
    self.onStoreReset = onStoreReset
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        VStack(spacing: 12) {
          Image(systemName: "externaldrive.badge.exclamationmark")
            .font(.system(size: 44))
            .foregroundStyle(Colors.inactiveTextColor)
            .accessibilityHidden(true)

          Text(String(localized: "containerFailure.title", defaultValue: "Couldn't open your checklists", comment: "Title of the full-screen error shown when the local database cannot be opened."))
            .font(.title2.bold())
            .foregroundStyle(Colors.primaryTextColor)

          Text(String(
            localized: "containerFailure.message",
            defaultValue: "Something went wrong. Try restarting the app, and check whether your storage is full.",
            comment: """
            Body of the database-failure screen; suggests a restart and checking free storage. Word the \
            second sentence as a gentle suggestion, not a question.
            """,
          ))
          .font(.body)
          .foregroundStyle(Colors.primaryTextColor)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityFocused($isMessageFocused)

        VStack(spacing: 12) {
          Button {
            sendFeedbackTapped()
          } label: {
            Text(CommonStrings.sendFeedback)
              .frame(maxWidth: .infinity)
          }
          // Approximates the UIKit CLButton's glass UIButtonConfiguration.
          .buttonStyle(.glass)
          .controlSize(.large)
          .accessibilityLabel(CommonStrings.sendFeedback)
          .accessibilityHint(String(
            localized: "containerFailure.action.sendFeedback.hint",
            defaultValue: "Opens an email with the error details. No personal data is included.",
            comment: "VoiceOver hint for the Send Feedback button on the database-failure screen.",
          ))

          if failure.allowsStoreReset {
            Button {
              // Destructive and irreversible, on a screen the user reaches while already alarmed — so
              // it confirms first, and the confirmation says plainly what is lost rather than "are you
              // sure?".
              isShowingStartOverConfirmation = true
            } label: {
              Text(Self.startOverTitle)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .tint(Colors.destructiveColor)
            .accessibilityLabel(Self.startOverTitle)
            .accessibilityHint(String(
              localized: "containerFailure.action.startOver.hint",
              defaultValue: "Starts the app as if it were newly installed. Any data on this device will be lost.",
              comment: "VoiceOver hint for the Start over fresh button.",
            ))
          }
        }
      }
      .padding(.horizontal, 16)
    }
    // Centred while it fits; past that it scrolls from the top, so the buttons stay reachable.
    .defaultScrollAnchor(.center, for: .alignment)
    .scrollBounceBehavior(.basedOnSize)
    .background(Colors.defaultBackgroundColor.ignoresSafeArea())
    // The screen replaces the app unasked; see `core-docs/accessibility-spec.md` §Announcements and
    // focus. After a beat, so the view is in VoiceOver's tree by then, and with focus set as well as
    // posted, so the message is read even if the post resolves before the tree has caught up.
    .task {
      try? await Task.sleep(for: .milliseconds(500))
      AccessibilityNotification.ScreenChanged(nil).post()
      isMessageFocused = true
    }
    .alert(
      String(localized: "containerFailure.confirm.title", defaultValue: "Start over fresh?", comment: "Title of the confirmation alert before deleting local data on the database-failure screen."),
      isPresented: $isShowingStartOverConfirmation,
    ) {
      Button(CommonStrings.cancel, role: .cancel) {}
      Button(
        String(localized: "containerFailure.confirm.action", defaultValue: "Start Over", comment: "Destructive confirmation button: deletes local data and relaunches as a new install."),
        role: .destructive,
      ) {
        analytics.track(AnalyticsEvent.startupStoreReset)
        StoreReset.startOverFresh()
        onStoreReset()
      }
    } message: {
      Text(String(
        localized: "containerFailure.confirm.message",
        defaultValue: "This starts the app as if it were newly installed. Any data on this device will be lost. This cannot be undone.",
        comment: "Message of the confirmation alert before deleting local data.",
      ))
    }
  }

  private static let startOverTitle = String(
    localized: "containerFailure.action.startOver",
    defaultValue: "Start over fresh",
    comment: "Destructive button on the database-failure screen: deletes the local data and relaunches as a new install.",
  )

  private func sendFeedbackTapped() {
    analytics.track(AnalyticsEvent.feedbackTapped)

    guard let url = FeedbackMail.url(
      subject: String(localized: "containerFailure.mail.subject", defaultValue: "Checklists data error", comment: "Subject line of the support email opened from the database-failure screen."),
      body: "Error: \(failure.diagnosticDescription)",
    ) else { assertionFailure(); return }
    openURL(url)
  }
}

#if DEBUG
  #Preview("Store failure") {
    ContainerFailureView(
      failure: ContainerCreationFailure(stage: .storeOpen, errorDomain: "NSCocoaErrorDomain", errorCode: 134_060),
    ) {}
  }

  // The store opened here, so the same screen offers feedback without the destructive reset.
  #Preview("Import failure") {
    ContainerFailureView(
      failure: ContainerCreationFailure(stage: .legacyImport, errorDomain: "NSCocoaErrorDomain", errorCode: 134_060),
    ) {}
  }
#endif
