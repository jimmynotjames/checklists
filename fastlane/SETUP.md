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

## Authentication check

`fastlane verify_auth` confirms read-only access to the app configured in Appfile
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

## English now, translations later

`metadata/en-US/` is the American English source copy. Preserve App Store Connect
locale codes in sibling directories when translations are eventually introduced.
The initial import preserves the live listing exactly, including existing URLs
and release notes; it is not newly authored marketing copy.

The app is currently English-only and intended for worldwide distribution.
Storefront availability is separate from listing languages and remains unchanged.
Do not create duplicate locale directories or translate copy in this phase. A
later publishing phase will define English distribution across listing locales
and explicit translated overrides. No translation pipeline is installed yet.

## Validation

Run `fastlane lanes` to check lane discovery and `fastlane verify_auth` for
integration verification. `make gate` remains the repository build gate;
fastlane does not alter it.

## Future publishing phase (second PR)

Deferred components from the port plan:

7. TestFlight beta lane: archive/sign/upload, ASC build numbering, release-secrets guard.
8. App Store release lane and release workflow.
9. Metadata publishing, English locale distribution, validation, and future translations.
10. Screenshot capture, screenshot UI tests, and upload tooling.

Future build lanes must use scheme `checklists`, project
`checklists/checklists.xcodeproj`, and the existing `scripts/verify_release_secrets.sh`
before archiving. No signing repository, CI changes, automatic build-number commits,
or publishing lanes are installed in this phase.
