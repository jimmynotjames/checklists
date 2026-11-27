---
name: appstore-push-release-build
description: "Cut a release-candidate build: set the chosen marketing version, upload that binary to TestFlight, open the version/build PR. Does not submit for review."
---

# Push a release-candidate build

Produce one binary for final TestFlight testing and later manual App Store submission. The tested build is the exact one attached to the editable App Store version — never a separate release upload.

## Before building

For an interrupted attempt or requested retry, use the **Recovery** section of [appstore-push-testflight-build](../appstore-push-testflight-build/SKILL.md) before the new-release preflight. Retain the existing release branch and marketing-version commit.

Read `AGENTS.md`, `fastlane/SETUP.md`, and any in-flight record under `releases/`. Resolve the new `MARKETING_VERSION` from the user's current instruction or a version they already chose in the active release record. Ask only when it is absent or conflicts with current state; do not make the user repeat an established choice.

Fetch `origin` and require a clean checkout attached to `main`; fast-forward it (`git pull --ff-only`) when it is behind. Preserve an existing confirmation that release copy is final; ask only if that state is unknown. The active release record must already be committed and merged — persist any new/modified record through `create-pr` first (AGENTS.md §"Commit and PR style"). Then create `u/jimmyho/<tool>/release-vX.Y.Z` before editing any file.

## Version, upload, and PR

1. Update every target configuration's `MARKETING_VERSION` in `checklists/checklists.xcodeproj/project.pbxproj` to the chosen value. Verify the occurrences, stage only that project file, and commit it using the repository subject/body conventions. If the chosen version is already set, skip the no-op commit. The `beta` lane requires tracked changes to be committed before it starts.
2. Run `fastlane ios beta`, capturing the complete log under `tmp/`. The lane allocates `CURRENT_PROJECT_VERSION` for the chosen marketing version, creates a recovery JSON under `tmp/releases/`, archives, and uploads to TestFlight. It commits the build-number bump only after confirmed upload success.
3. Verify the candidate's entitlements before it becomes a release candidate. Unzip the exported `tmp/releases/<timestamp>-<pid>/checklists.ipa` into a fresh folder under `tmp/` and read `Payload/checklists.app` with `codesign -d --entitlements :- <path>`. Never read the `.xcarchive` copy: it is development-signed and always shows `aps-environment` = `development`. Require:
   - `application-identifier` = `EDMB3Z5KAY.com.jimmyho.checklists`
   - `com.apple.developer.icloud-container-identifiers` contains `iCloud.com.jimmyho.checklists`
   - `com.apple.developer.icloud-services` contains `CloudKit`
   - `aps-environment` = `production` (checked-in value is `development`; Xcode rewrites it at export)

   Any mismatch is disqualifying — it silently breaks CloudKit sync for every user on that build (`core-docs/persistence-design.md`). Do not commit the bump, write the record, or open the PR; report which entitlement was wrong, fix the portal capability, and cut a fresh candidate.
4. Resolve upload bookkeeping (recovery guidance: see "Before building" above) before editing the tracked release record, so the recovery check can verify that only the expected project-file bump changed.
5. If the record is neither `uploaded` nor `committed`, do not commit the build bump or retry automatically. Preserve the branch and recovery state and report the stage reached. The existing marketing-version commit remains the restart point. If upload succeeded but the lane's commit failed, verify the recovery status is `uploaded` and the only tracked diff is the expected build-number change, then commit that project file manually. Do not repeat the upload.
6. After confirmed upload and commit, copy the version, build, source commit, upload status, and recovery path into the in-flight release record, then invoke `create-pr`. It performs review, `make gate` local build, push, and opens the PR (AGENTS.md §"Commit and PR style").

## Reusing an existing candidate

Reuse requires provenance, not an assumption that the latest TestFlight build or release commit is valid. The durable release record and merged PR/commit must identify the candidate's version, build, upload result, and source commit. A local recovery JSON is useful evidence but need not survive on another clone. Verify that:

- its marketing version is the user-chosen release version;
- its entitlements were verified per step 3 when it was cut, or are verified now against the retained `.ipa` — a candidate predating that check has not been cleared;
- the build still exists in TestFlight/App Store Connect;
- the recorded source commit is the intended release source; and
- every later diff changes no app code, resource, dependency, entitlement, or build setting that would alter the shipped binary — except the recorded build-number substitution and release-record edits, which do not invalidate reuse.

If provenance is missing or a later change could affect the binary, cut a new candidate. Record the reused version/build and evidence in the release record.

After the PR is eventually merged and Apple processes the upload, tell the user to install that exact version/build through TestFlight. Submission, availability, and phased release remain manual App Store Connect actions.
