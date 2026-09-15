//
//  ContainerFailureView.swift
//  checklists
//

import SwiftUI

/**
 Shown when the store cannot be opened, or the one-time Realm copy cannot be completed — rather
 than continuing into an empty list, which an upgrading user could mistake for having lost
 everything. By the time `onStoreReset` runs, every local store has already been deleted; the
 caller reruns startup from there. See core-docs/persistence-design.md §The failure screen.
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

#if DEBUG
  #Preview("Store failure") {
    ContainerFailureView(
      failure: ContainerCreationFailure(errorDomain: "NSCocoaErrorDomain", errorCode: 134_060)
    ) {}
  }
#endif
