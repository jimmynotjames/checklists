---
name: appstore-prepare-for-release
description: Start or resume a lightweight, file-backed App Store release workflow and route metadata, TestFlight, and release-candidate work through the repository skills. Use for release planning, status updates, approval or rejection follow-up, and manual submission tracking.
---

# Prepare an App Store release

Drive one release across sessions using a small record under `releases/`. Conversation memory is never the release state. Keep the workflow focused on metadata, one candidate binary, manual testing, and manual App Store Connect submission.

## Start or resume

1. Read `AGENTS.md`, `fastlane/SETUP.md`, and every `releases/app-store-v*.md` whose status is not `complete` or `abandoned`. If more than one is active, ask which is authoritative.
2. If resuming, re-read the record and continue at the first incomplete item. Update the record immediately after every external result or user decision.
3. For a new release, use a version already chosen in the user's instruction; otherwise ask after showing the current `MARKETING_VERSION`. Copy [assets/release-record.md](assets/release-record.md) to `releases/app-store-vX.Y.Z.md`, replace the placeholders, and record the start date and source commit. Persist the new record through `create-pr` and stop with that PR open. Resume only after a later `merge-pr` request has merged it, so the binary lane starts from a clean `main`. Create no large release-plan document.

## Workflow

1. Review the English listing source with the user. Use `appstore-push-metadata` to validate and prepare the resolved 50-locale staging tree. Upload it only when the user asks; App Store Connect must already have an editable version matching the explicit version number.
2. Confirm code and copy are ready for a candidate. Use `appstore-push-release-build`; it sets the user-chosen marketing version and uploads the same binary to TestFlight. If considering a prior beta, apply that skill's provenance checks. Copy the lane recovery evidence into the release record.
3. After Apple processes the upload, have the user update their existing App Store install to the exact recorded version/build through TestFlight, keeping its local data. Ask them to smoke-test core checklist behavior and confirm existing data and iCloud-backed changes still appear on another signed-in device when available. Record the device/sync result. A failure means fix the issue and cut a new build; never relabel an older or different binary as tested.
4. The user manually attaches that exact TestFlight build to the editable App Store version, completes App Store Connect questionnaires, and submits it for review. Record the submission date and status only after their confirmation.
5. On approval, rejection, or release, resume from the record. Preserve rejection text or a concise link/reference, decide the fix with the user, and route any new binary through `appstore-push-release-build`. Availability, release timing, phased release, and final submission remain manual.
6. When released and the user has completed their desired smoke check, record the release date and mark the record `complete`. Mark cancelled attempts `abandoned` with a reason.

Use `create-pr` to persist release-record edits at sensible boundaries. It opens a PR and stops; merge only through a later explicit `merge-pr` request. This repository has disabled CI, so the skills rely on the local `make gate` build rather than waiting for CI.

Do not add screenshot capture/upload, translation generation, CloudKit deployment, automated submission, or monitoring work to this workflow unless the user separately requests and scopes it.
