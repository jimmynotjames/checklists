//
//  ContainerFailureView.swift
//  checklists
//

import SwiftUI

/**
 Shown when the store cannot be opened, or the one-time Realm copy cannot be completed.

 Shown rather than continuing into an empty checklist list, because to an upgrading user an empty
 list is indistinguishable from having lost everything. Nothing has been deleted at this point —
 the store simply would not open, and on the one launch that migrates, the old Realm file is still
 untouched on disk — so relaunching is a real chance of recovery.

 There is deliberately no Retry button. It re-ran the same startup sequence in the same process,
 which is what relaunching does anyway and more thoroughly, so it offered a second path to the same
 outcome while the copy was already telling the user to restart.

 The error code is not shown on screen (nobody acts on "134060"); it travels in the feedback mail
 body instead, where it is useful. Only the error's domain and code go in, never its description,
 which can carry the user's own content.

 By the time `onStoreReset` runs, every local store has already been deleted; the caller is
 responsible for re-running startup from there.
 */
struct ContainerFailureView: View {
  let failure: ContainerCreationFailure
  let onStoreReset: () -> Void

  @Environment(\.openURL) private var openURL
  @Environment(\.analytics) private var analytics
  @State private var isShowingStartOverConfirmation = false

  init(failure: ContainerCreationFailure, onStoreReset: @escaping () -> Void) {
    self.failure = failure
    self.onStoreReset = onStoreReset
  }

  var body: some View {
    VStack(spacing: 32) {
      VStack(spacing: 12) {
        Image(systemName: "externaldrive.badge.exclamationmark")
          .font(.system(size: 44))
          .foregroundStyle(Colors.inactiveTextColor)
          .accessibilityHidden(true)

        Text("Couldn't open your checklists")
          .font(.title2.bold())

        Text("Something went wrong. Try restarting the app? Also check if your storage is full?")
          .font(.body)
      }
      .multilineTextAlignment(.center)
      .accessibilityElement(children: .combine)

      VStack(spacing: 12) {
        Button {
          sendFeedbackTapped()
        } label: {
          Text("Send Feedback")
            .frame(maxWidth: .infinity)
        }
        // Approximates the UIKit CLButton's glass UIButtonConfiguration.
        .buttonStyle(.glass)
        .controlSize(.large)
        .accessibilityLabel("Send Feedback")
        .accessibilityHint("Opens an email with the error details. No personal data is included.")

        Button {
          // Destructive and irreversible, on a screen the user reaches while already alarmed — so
          // it confirms first, and the confirmation says plainly what is lost rather than "are you
          // sure?".
          isShowingStartOverConfirmation = true
        } label: {
          Text("Start over fresh")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .tint(Colors.destructiveColor)
        .accessibilityLabel("Start over fresh")
        .accessibilityHint("Starts the app as if it were newly installed. Any data on this device will be lost.")
      }
    }
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Colors.defaultBackgroundColor.ignoresSafeArea())
    .alert(
      "Start over fresh?",
      isPresented: $isShowingStartOverConfirmation
    ) {
      Button("Cancel", role: .cancel) {}
      Button("Start Over", role: .destructive) {
        analytics.track(AnalyticsEvent.startupStoreReset)
        StoreReset.startOverFresh()
        onStoreReset()
      }
    } message: {
      Text("This starts the app as if it were newly installed. Any data on this device will be lost. This cannot be undone.")
    }
  }

  private func sendFeedbackTapped() {
    analytics.track(AnalyticsEvent.feedbackTapped)

    var components = URLComponents()
    components.scheme = "mailto"
    components.path = "jimmyho.appfeedback@gmail.com"
    components.queryItems = [
      URLQueryItem(name: "subject", value: "Checklists data error"),
      URLQueryItem(name: "body", value: "Error: \(failure.diagnosticDescription)"),
    ]
    guard let url = components.url else { assertionFailure(); return }
    openURL(url)
  }
}
