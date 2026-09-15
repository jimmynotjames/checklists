---
name: appstore-push-testflight-build
description: "Fastlane diagnostics, local archive validation, or an ordinary TestFlight upload. Release-candidate version bumps use appstore-push-release-build."
---

# Push a TestFlight build

Use this skill for the repository's Fastlane diagnostics and binary pipeline. A real build cut creates a release branch before any version change, runs `fastlane ios beta`, and hands the resulting commit to `create-pr`.

## Choose the mode

- For lane discovery or read-only authentication diagnostics, run the smallest relevant command (`fastlane lanes`, `fastlane ios verify_auth`) on an infrastructure feature branch. Report the result without changing release state.
- To test archiving and export with already-installed signing assets, run `fastlane ios archive_validation`. Report archive and export outcomes separately; a successful archive followed by an export failure is not a full pass.
- To upload a TestFlight build, follow the workflow below. An upload is authorized only when the user asks to push or upload a build.

## Upload workflow

For a retry or interrupted release, follow **Recovery** first instead of creating a new branch.

1. Read `AGENTS.md`, `fastlane/SETUP.md`, and `core-docs/persistence-design.md` §"Before the first TestFlight build". Inspect `git status --short`, the current branch, the current `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, and fetch `origin`. Require a clean, attached checkout of current `main`; fast-forward it when it is behind. Repo-local untracked `.codex/` tool state may remain when the lane accepts it, but never stage it. Preserve unrelated work and stop if the release source is ambiguous.
2. Before changing anything, create `u/jimmyho/<tool>/testflight-build-<next-local-build>`. The suffix is only a local hint; App Store Connect allocates the actual build number for the current marketing version.
3. Run `fastlane ios beta`, capturing full output under `tmp/`. Lane behaviour: `fastlane/SETUP.md` §"Publishing behavior".
4. Read the lane's final status, log, recovery JSON, `git status`, and new commit. Record the marketing version, allocated build, source commit, uploaded status, and recovery-record path. Do not infer success from an archive alone.
5. If the record is neither `uploaded` nor `committed`, do not commit or retry automatically. Preserve the recovery record and changed build number, explain the exact stage reached, and stop. A retry may allocate a different build and requires a fresh user request. If upload succeeded but the lane's commit failed, verify the recovery status is `uploaded` and the only tracked diff is the expected build-number change, then commit that project file manually. Never upload the same artifact again merely to recover the commit.
6. After confirmed upload and commit, invoke `create-pr`. That skill performs the review, `make gate` local build, push, and PR creation. Use a subject such as `Uploaded TestFlight build <N>.` and include the version/build, source commit, and upload evidence in the PR body.

Apple processing is asynchronous. Report the uploaded build as processing until App Store Connect shows otherwise.

## Recovery

Read the previous `tmp/releases/*/release.json`, its log, branch, and `Source-commit` evidence before changing anything. Keep the log and record. A successful record may say `committed`; do not treat that as a failed upload.

- **`committed`:** verify the commit and resume `create-pr`, or report its existing PR. Do not upload again.
- **`uploaded`:** upload succeeded but bookkeeping may be incomplete. Verify HEAD still equals the recorded source and the project diff contains only the recorded build-number substitutions. Before editing any release snapshot, commit only the project file using a file-backed message with `Source-commit`, `Version`, and `Build` fields. If the selected build number already equalled the committed value, a provenance-only empty commit is valid. Then update the release record and resume `create-pr`.
- **`upload_started`:** the outcome is uncertain. Check the exact app/version/build in App Store Connect and the upload log. If accepted, recover bookkeeping as above without uploading again. If acceptance or failure cannot be established, report the uncertainty and stop; absence during processing is not proof of failure.
- **Archive failed or upload conclusively failed:** on a requested retry, verify HEAD still equals the recorded source and the only project change is that attempt's build-number substitution. Restore only that failed substitution from the recorded source, preserving the marketing-version commit, logs, and unrelated work. Never reset the branch or discard an unexplained diff. Commit any necessary code/signing-configuration fix through the repo workflow, ensure the release branch is clean, then rerun `beta` on that same branch. It will query ASC again for the number.

If source or project differences cannot be explained by the record, resolve those differences before committing or retrying. Keep release-snapshot edits out of the worktree until upload bookkeeping is recovered.
