---
name: appstore-push-release-build
description: Cut an App Store release-candidate build by setting a user-chosen marketing version, uploading the same binary to TestFlight, and opening the version/build PR. Use when release preparation is ready for its candidate binary. It does not submit the app for review.
---

# Push a release-candidate build

Produce one binary for final TestFlight testing and later manual App Store submission. The tested TestFlight build is the exact build the user attaches to the editable App Store version; do not create a separate release upload.

## Before building

For an interrupted attempt or requested retry, use the **Recovery** section of [appstore-push-testflight-build](../appstore-push-testflight-build/SKILL.md) before the new-release preflight. Retain the existing release branch and marketing-version commit.

Read `AGENTS.md`, `fastlane/SETUP.md`, and any in-flight record under `releases/`. Resolve the new `MARKETING_VERSION` from the user's current instruction or a version they already chose in the active release record. Ask only when it is absent or conflicts with current state; do not make the user repeat an established choice.

Likewise, preserve an existing confirmation that release copy is final and metadata is uploaded or deliberately unchanged. Ask only if that state is unknown. Confirm the source checkout is clean, attached, current with `origin/main`, and suitable for release. The active release record must already be committed and merged; if it is new or modified, persist it through `create-pr`, stop for review, and resume after a later `merge-pr`. Repo-local untracked `.codex/` tool state may remain when the lane accepts it, but never stage it. Then create `u/jimmyho/<tool>/release-vX.Y.Z` before editing any file.

## Version, upload, and PR

1. Update every target configuration's `MARKETING_VERSION` in `checklists/checklists.xcodeproj/project.pbxproj` to the chosen value. Verify the occurrences, stage only that project file, and commit it using the repository subject/body conventions. If the chosen version is already set, skip the no-op commit. The `beta` lane requires tracked changes to be committed before it starts.
2. Run `fastlane ios beta`, capturing the complete log under `tmp/`. The lane allocates `CURRENT_PROJECT_VERSION` for the chosen marketing version, creates a recovery JSON under `tmp/releases/`, archives, and uploads to TestFlight. It commits the build-number bump only after confirmed upload success.
3. Verify the candidate binary's entitlements before it becomes a release candidate. Read them from the archived app the lane produced — `tmp/releases/<timestamp>-<pid>/checklists.xcarchive/Products/Applications/checklists.app`, or `Payload/checklists.app` unzipped from `checklists.ipa` — with `codesign -d --entitlements :- <path>`. A device archive carries entitlements in its code signature, so this is a real check; do not carry over the simulator habit of treating an empty result as normal (see `scripts/build.sh` and #140 for why a simulator build reports nothing either way). Confirm `application-identifier` is `EDMB3Z5KAY.com.jimmyho.checklists`, that `com.apple.developer.icloud-container-identifiers` contains `iCloud.com.jimmyho.checklists`, that `com.apple.developer.icloud-services` contains `CloudKit`, and that `aps-environment` is present. A missing or altered value means the profile regenerated without a capability the app depends on — most likely iCloud — which silently breaks sync for every user on that build and, until the loader is hardened against ObjC exceptions, can abort the app outright when Settings is opened. Treat any mismatch as disqualifying: do not commit the build bump, write the release record, or open the PR. Report exactly which entitlement was wrong and stop. The uploaded build is harmless while it is never submitted; restore the capability in the developer portal and cut a fresh candidate rather than reusing it.
4. Inspect the recovery JSON, log, commit history, and worktree. Resolve upload bookkeeping before editing the tracked release record, so the recovery check can verify that only the expected project-file bump changed.
5. If the record is neither `uploaded` nor `committed`, do not commit the build bump or retry automatically. Preserve the branch and recovery state and report the stage reached. The existing marketing-version commit remains the restart point. If upload succeeded but the lane's commit failed, verify the recovery status is `uploaded` and the only tracked diff is the expected build-number change, then commit that project file manually. Do not repeat the upload.
6. After confirmed upload and commit, copy the version, build, source commit, upload status, and recovery path into the in-flight release record, then invoke `create-pr`. It performs review, `make gate` local build, push, and opens the PR. Stop with the PR open. Use `merge-pr` only in a later turn after the user has reviewed it.

## Reusing an existing candidate

Reuse requires provenance, not an assumption that the latest TestFlight build or latest release commit is valid. The durable release record and merged PR/commit must identify the candidate's version, build, upload result, and source commit. A local lane recovery JSON is useful evidence when available, but reuse does not require that gitignored file to survive on another clone. Verify that:

- its marketing version is the user-chosen release version;
- its entitlements were verified per step 3 when it was cut, or are verified now against the retained archive — a candidate predating that check has not been cleared;
- the build still exists in TestFlight/App Store Connect;
- the recorded source commit is the intended release source; and
- every later diff is reviewed and contains no app code, resources, dependencies, entitlements, or build-setting change that would alter the shipped binary. Account for the recorded build-number substitution separately: the uploaded binary includes that substitution even though `Source-commit` precedes it. That exact substitution and release-record documentation do not invalidate reuse.

If provenance is missing or a later change could affect the binary, cut a new candidate. Record the reused version/build and evidence in the release record.

After the PR is eventually merged and Apple processes the upload, tell the user to install that exact version/build through TestFlight. Submission, availability, and phased release remain manual App Store Connect actions.
