---
name: appstore-prepare-for-release
description: "Start or resume the file-backed App Store release record, routing metadata, TestFlight, and candidate work to the other appstore skills."
---

# Prepare an App Store release

Drive one release across sessions using a small record under `releases/`. Conversation memory is never the release state. Keep the workflow focused on metadata, one candidate binary, manual testing, and manual App Store Connect submission.

## Sync with `origin/main`

Before anything else, run `git fetch origin`. On `main`, fast-forward when behind (`git pull --ff-only`); uncommitted edits may stay, and if git refuses, stop and ask. On another branch, don't switch or merge: say how far it is behind `origin/main` and confirm before continuing. The appstore skills this one routes to skip their own sync step in the same session.

## Start or resume

1. Read `AGENTS.md`, `fastlane/SETUP.md`, and every `releases/app-store-v*.md` whose status is not `complete` or `abandoned`. If more than one is active, ask which is authoritative.
2. If resuming, re-read the record and continue at the first incomplete item. Update the record immediately after every external result or user decision.
3. For a new release, use a version already chosen in the user's instruction; otherwise ask after showing the current `MARKETING_VERSION`. Copy [assets/release-record.md](assets/release-record.md) to `releases/app-store-vX.Y.Z.md`, replace the placeholders, and record the start date and source commit. Persist the new record through `create-pr` and stop with that PR open. Resume only after a later `merge-pr` request has merged it, so the binary lane starts from a clean `main`. Create no large release-plan document.

## Workflow

1. Review the English listing source with the user. Use `appstore-push-metadata` to validate and prepare the resolved staging tree. Upload it only when the user asks; App Store Connect must already have an editable version matching the explicit version number.
2. Before the candidate, sweep the specs for drift: spawn one read-only subagent to check each `core-docs/` spec's contract tables and status claims against the code — in particular that `analytics-spec.md` §Allow-list, §Event catalog, §Property catalog, and §Published disclosures match what the app actually sends and declares in `PrivacyInfo.xcprivacy`. Fix what it finds through `create-pr` before cutting the build; record "spec sweep clean" or the fix PR in the release record.
3. Confirm code and copy are ready for a candidate. Use `appstore-push-release-build`; it sets the user-chosen marketing version and uploads the same binary to TestFlight. If considering a prior beta, apply that skill's provenance checks. Copy the lane recovery evidence into the release record.
4. After Apple processes the upload, have the user update their existing App Store install to the exact recorded version/build through TestFlight, keeping its local data. Ask them to smoke-test core checklist behavior and confirm existing data and iCloud-backed changes still appear on another signed-in device when available. Record the device/sync result. A failure means fix the issue and cut a new build; never relabel an older or different binary as tested.
5. The user manually attaches that exact TestFlight build to the editable App Store version, completes App Store Connect questionnaires, checks the App Privacy label against `core-docs/analytics-spec.md` §Published disclosures (the label is edited by hand and does not follow the manifest), and submits it for review. Record the submission date and status only after their confirmation.
6. On approval, rejection, or release, resume from the record. Preserve rejection text or a concise link/reference, decide the fix with the user, and route any new binary through `appstore-push-release-build`. Availability, release timing, phased release, and final submission remain manual.
7. When released and the user has completed their desired smoke check, record the release date and mark the record `complete`. Mark cancelled attempts `abandoned` with a reason.

For screenshots, route per AGENTS.md; record the reviewed run and, after an authorized upload,
its target version and result.

Translation is a separate workflow with its own skills, not a step here. If a release needs new or
changed copy, route it before the release rather than inside it: `translate-new-strings` for in-app
strings, `appstore-translate-metadata` for the listing, and
`appstore-generate-screenshot-seeding` when the demo content changed. `check_translations.py` and
`check_metadata.py` already gate the release paths, so a missed translation fails the gate or the
upload lane rather than shipping.

Do not add CloudKit deployment, automated submission, or monitoring work to this workflow unless
the user separately requests and scopes it.
