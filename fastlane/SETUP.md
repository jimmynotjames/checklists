# Fastlane setup

This repo uses Homebrew fastlane, ported from budgets1 and verified with 2.236.1.
Run commands from the repository root. Install on a new machine with
`brew install fastlane`. There is no Gemfile or plugin dependency. Supply a UTF-8
locale per command if your shell does not already have one:
`LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 fastlane lanes`.

## Credentials

Copy `.env.template` to `.env` in this directory and fill in the team API key ID,
issuer ID, and absolute private-key path. Both apps can reuse a team API key;
the bundle ID in Appfile selects checklists. Keep the `.p8` outside the repo.
Never paste its contents into configuration or logs. `.env` is ignored by git.
Fastlane loads it automatically and reads the key internally for authentication.

Binary archives also require a valid Apple Distribution identity in the login
keychain and automatic signing for team `EDMB3Z5KAY`. `archive_validation` does
not request provisioning updates, so a matching App Store provisioning profile
must already be installed for its export to pass. The real beta lane allows Xcode
to update provisioning through an existing signed-in Xcode account. It also
requires the Release values checked by `scripts/verify_release_secrets.sh`.

## Authentication check

`fastlane ios verify_auth` confirms read-only access to the app configured in Appfile
and prints its App Store Connect ID. It does not upload, build, change version
numbers, or alter storefront availability.

## Initial marketing copy

The live version 1.1 English listing was imported once to establish the baseline.
`metadata-source.json` records that initial import's app, version, record IDs,
locale lists, and UTC retrieval time; it is historical provenance, not a claim
that subsequently edited copy still matches App Store Connect.

The files under `metadata/` are now the source of truth for future publishing.
Edit them in the repository and review changes through PRs. There is no ongoing
download lane. The initial public copy includes name, subtitle, privacy URL,
description, keywords, support URL, release notes, and copyright. Marketing URL
and promotional text were absent from the source listing.

## English fallback and future overrides

`metadata/en-US/` is the American English source copy. The locale manifest records
the 50 metadata locales supported by the installed Fastlane version. Preparation
resolves each field for all of them from an explicit locale override when present,
or from English otherwise. Preserve App Store Connect locale codes in sibling
directories when translated overrides are eventually introduced.

The app is currently English-only and intended for worldwide distribution.
Storefront availability is separate from listing languages and remains unchanged.
Do not create duplicate locale directories or generate translations in this
phase. The initial import preserves the live listing exactly, including existing
URLs and release notes; it is not newly authored marketing copy.

## Workflow routing and validation

Route every fastlane run through the repository App Store skills, including
read-only diagnostics and archive-only tests. Use `appstore-push-testflight-build`
for `fastlane lanes`, `fastlane ios verify_auth`, local `archive_validation`, and
ordinary TestFlight uploads; `appstore-push-release-build` for a versioned release
candidate; `appstore-push-metadata` for listing validation and upload; and
`appstore-prepare-for-release` to start or resume the overall release record.

`fastlane ios archive_validation` tests the local archive/signing path without
changing versions, committing, contacting App Store Connect, or uploading. Never
use an upload lane as an infrastructure test. `make gate` remains the repository
build gate.

## Publishing behavior

The beta lane uses scheme `checklists`, project
`checklists/checklists.xcodeproj`, and `scripts/verify_release_secrets.sh`. It
allocates `CURRENT_PROJECT_VERSION` for the explicit marketing version and writes
a recovery record under `tmp/releases/`. It commits the project-file bump only
after a successful TestFlight upload. Failed uploads retain their local recovery
state and are never retried automatically.

`python3 scripts/appstore_metadata.py prepare --output tmp/appstore-metadata`
builds a reviewable resolved metadata tree for every locale listed in
`fastlane/metadata-locales.json`. Future per-field translated files override the
English source; missing fields fall back to English. Blank present values are
rejected, while absent optional fields remain omitted.

`fastlane ios push_metadata app_version:X.Y.Z` requires that exact editable iOS
version to already exist in App Store Connect. Create or select it manually first.
The lane does not create or rename a version, and changes no screenshots, binary,
submission state, availability, pricing, or phased-release setting.

Screenshot automation, translation generation, and automatic submission remain
out of scope. The user manually attaches the tested TestFlight build and submits
the release in App Store Connect.
