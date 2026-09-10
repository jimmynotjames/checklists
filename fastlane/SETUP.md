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

## Read-only commands

`fastlane verify_auth` confirms access to `com.jimmyho.checklists` and prints its
App Store Connect ID. `fastlane download_metadata` retrieves the distributed iOS
version and distributed app information. It fails if either is absent, rather
than falling back to draft data. Neither command uploads, builds, changes version
numbers, or alters storefront availability.

The download uses fastlane's Spaceship API with an explicit public-field list:
name, subtitle, privacy URL, description, keywords, marketing URL, promotional
text, support URL, release notes, and copyright. Missing values are omitted;
empty values are preserved. It does not export review contacts, credentials,
screenshots, categories, pricing, or availability. API failures fail the lane.

Each run creates a new directory under `tmp/app-store-metadata/live-*`, containing
`metadata/` and `metadata-source.json`. The provenance file records the source app,
version, record IDs, locale lists, and UTC retrieval time. Tracked marketing copy
is never overwritten by a lane. Compare the downloaded files with
`fastlane/metadata/`, review additions/removals, then explicitly copy the approved
files and provenance into `fastlane/` and review the git diff before committing.
Treat absent fields/locales as review items, not instructions to delete local copy.

## English now, translations later

`metadata/en-US/` is the American English source copy. Preserve App Store Connect
locale codes in sibling directories when translations are eventually introduced.
The initial import preserves the live listing exactly, including existing URLs
and release notes; it is not newly authored marketing copy.

The app is currently English-only and intended for worldwide distribution.
Storefront availability is separate from listing languages and remains unchanged.
Do not create duplicate locale directories or translate copy in this phase. A
later publishing phase will define English distribution across listing locales
and explicit translated overrides. Review unexpected non-English copy or a
missing en-US listing before importing. No translation pipeline is installed yet.

## Validation

Run `ruby fastlane/tests/marketing_snapshot_test.rb` for public-field, exact-text,
and locale-path checks. Run `fastlane lanes` to check lane discovery, then the two
read-only commands above for integration verification. `make gate` remains the
repository build gate; fastlane does not alter it.

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
