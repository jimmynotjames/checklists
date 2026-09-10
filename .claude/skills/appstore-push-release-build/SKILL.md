---
name: appstore-push-release-build
description: Cut an App Store release-candidate build by setting a user-chosen marketing version, uploading the same binary to TestFlight, and opening the version/build PR. Use when release preparation is ready for its candidate binary. It does not submit the app for review.
---

# Push a release-candidate build

Produce one binary for final TestFlight testing and later manual App Store submission. The tested TestFlight build is the exact build the user attaches to the editable App Store version; do not create a separate release upload.

## Before building

Read `AGENTS.md`, `fastlane/SETUP.md`, and any in-flight record under `releases/`. Resolve the new `MARKETING_VERSION` from the user's current instruction or a version they already chose in the active release record. Ask only when it is absent or conflicts with current state; do not make the user repeat an established choice.

Likewise, preserve an existing confirmation that release copy is final and metadata is uploaded or deliberately unchanged. Ask only if that state is unknown. Confirm the source checkout is clean, attached, current with `origin/main`, and suitable for release. The active release record must already be committed and merged; if it is new or modified, persist it through `create-pr`, stop for review, and resume after a later `merge-pr`. Repo-local untracked `.codex/` tool state may remain when the lane accepts it, but never stage it. Then create `u/jimmyho/<tool>/release-vX.Y.Z` before editing any file.

## Version, upload, and PR

1. Update every target configuration's `MARKETING_VERSION` in `checklists/checklists.xcodeproj/project.pbxproj` to the chosen value. Verify the occurrences, stage only that project file, and commit it using the repository subject/body conventions. The `beta` lane requires this tracked change to be committed before it starts.
2. Run `fastlane ios beta`, capturing the complete log under `tmp/`. The lane allocates `CURRENT_PROJECT_VERSION` for the chosen marketing version, creates a recovery JSON under `tmp/releases/`, archives, and uploads to TestFlight. It commits the build-number bump only after confirmed upload success.
3. Inspect the recovery JSON, log, commit history, and worktree. Copy the version, build, source commit, upload status, and recovery path into the in-flight release record immediately.
4. If the record does not say `uploaded`, do not commit the build bump or retry automatically. Preserve the branch and recovery state and report the stage reached. The existing marketing-version commit remains the restart point. If upload succeeded but the lane's commit failed, verify the recovery status is `uploaded` and the only tracked diff is the expected build-number change, then commit that project file manually. Do not repeat the upload.
5. After confirmed upload and lane commit, invoke `create-pr`. It performs review, `make gate` local build, push, and opens the PR. Stop with the PR open. Use `merge-pr` only in a later turn after the user has reviewed it.

## Reusing an existing candidate

Reuse requires provenance, not an assumption that the latest TestFlight build or latest release commit is valid. The durable release record and merged PR/commit must identify the candidate's version, build, upload result, and source commit. A local lane recovery JSON is useful evidence when available, but reuse does not require that gitignored file to survive on another clone. Verify that:

- its marketing version is the user-chosen release version;
- the build still exists in TestFlight/App Store Connect;
- the recorded source commit is the intended release source; and
- every later diff is reviewed and contains no app code, resources, dependencies, entitlements, or build-setting change that would alter the shipped binary.

If provenance is missing or a later change could affect the binary, cut a new candidate. Record the reused version/build and evidence in the release record.

After the PR is eventually merged and Apple processes the upload, tell the user to install that exact version/build through TestFlight. Submission, availability, and phased release remain manual App Store Connect actions.
