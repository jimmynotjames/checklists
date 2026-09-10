---
name: appstore-push-testflight-build
description: Validate App Store release tooling, make a local archive without uploading, or upload a new TestFlight build through the repository Fastlane lane. Use for Fastlane diagnostics, archive validation, and ordinary TestFlight build cuts. Release-candidate version bumps use appstore-push-release-build instead.
---

# Push a TestFlight build

Use this skill for the repository's Fastlane diagnostics and binary pipeline. A real build cut creates a release branch before any version change, runs `fastlane ios beta`, and hands the resulting commit to `create-pr`. It never merges the PR in the same turn.

## Choose the mode

- For lane discovery or read-only authentication diagnostics, run the smallest relevant command, such as `fastlane lanes` or `fastlane ios verify_auth`. These checks may run on an infrastructure feature branch. Report the result without changing release state.
- To test archiving and export with already-installed signing assets, run `fastlane ios archive_validation`. This validation-only mode may run on an infrastructure feature branch and does not contact App Store Connect, request provisioning updates, change source or a version, commit, or upload. Report archive and export outcomes separately; a successful archive followed by an export failure is not a full pass. Never substitute `beta` for an infrastructure test.
- To upload a TestFlight build, follow the workflow below. An upload is authorized only when the user asks to push or upload a build.

## Upload workflow

1. Read `AGENTS.md` and `fastlane/SETUP.md`. Inspect `git status --short`, the current branch, the current `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, and fetch `origin`. Require a clean, attached checkout of current `main`; fast-forward it when it is behind. Repo-local untracked `.codex/` tool state may remain when the lane accepts it, but never stage it. Preserve unrelated work and stop if the release source is ambiguous.
2. Before changing anything, create `u/jimmyho/<tool>/testflight-build-<next-local-build>`. The suffix is only a local hint; App Store Connect allocates the actual build number for the current marketing version.
3. Run `fastlane ios beta` with its complete output captured under `tmp/`. The lane requires a clean branch, verifies release secrets, records recovery state under `tmp/releases/`, allocates the build number, updates only `CURRENT_PROJECT_VERSION` in `checklists/checklists.xcodeproj/project.pbxproj`, archives, and uploads. It commits the project-file bump only after upload succeeds.
4. Read the lane's final status, log, recovery JSON, `git status`, and new commit. Record the marketing version, allocated build, source commit, uploaded status, and recovery-record path. Do not infer success from an archive alone.
5. If the record does not say `uploaded`, do not commit or retry automatically. Preserve the recovery record and changed build number, explain the exact stage reached, and stop. A retry may allocate a different build and requires a fresh user request. If upload succeeded but the lane's commit failed, verify the recovery status is `uploaded` and the only tracked diff is the expected build-number change, then commit that project file manually. Never upload the same artifact again merely to recover the commit.
6. After confirmed upload and commit, invoke `create-pr`. That skill performs the review, `make gate` local build, push, and PR creation. Use a subject such as `Uploaded TestFlight build <N>.` and include the version/build, source commit, and upload evidence in the PR body.
7. Stop with the PR open for review. A later, explicit merge request uses `merge-pr`; never invoke it in the turn that opened the PR.

Apple processing is asynchronous. Report the uploaded build as processing until App Store Connect shows otherwise.
