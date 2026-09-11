# Fastlane setup

This repo uses Homebrew fastlane, verified with 2.236.1. Run commands from the
repository root. Install on a new machine with
`brew install fastlane`. There is no Gemfile or plugin dependency. Supply a UTF-8
locale per command if your shell does not already have one:
`LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 fastlane lanes`.

## Credentials

See [`core-docs/secrets-list.md`](../core-docs/secrets-list.md) for the complete fresh-clone secret
inventory and safe reconstruction checklist.

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

Translation generation and automatic submission remain out of scope. The user
manually attaches the tested TestFlight build and submits the release in App Store Connect.

## Screenshot content and capture

Use `appstore-generate-screenshot-seeding` for fixture changes and
`appstore-generate-push-screenshots` for capture, review, inspection, and explicitly
requested publication. A request to refresh screenshots reuses the committed
catalog; it does not regenerate content or authorize uploading.

`fastlane/screenshot-config.json` records the 50 runtime/storefront locale
mappings independently of the translation pipeline. Only runtime `en-US` is
active, with regional locale `en_US`. This list is separate from the metadata
pipeline's all-locale English fallback. Enable additional screenshot locales
only after supplying their catalogs and translated app strings. The remaining
translation integration is tracked in [issue #161](https://github.com/jimmynotjames/checklists/issues/161).

The English catalog under `checklists/checklistsUITests/ScreenshotSeeds/` mirrors
the shipped sample data, except it checks the first three Pre-Trip items. Thus the
home screen shows completion counts 5/6, 4/12, and 3/11. Normal first-launch data
is unchanged. Screenshot launches use a Debug-only, disposable in-memory store;
they never import or sync user data. The marketing UI test captures two screens,
`01_checklists` and `02_pre_trip`, and is excluded from normal UI-test runs.

The app target is iPhone-only. The configured device is an iPhone 17 Pro Max
(1320 × 2868, portrait), using light appearance, default text size, and a clean
status bar. Capture uses a repository-owned simulator and runs serially. The
pipeline is structured for additional locales/devices without generating them
now. It captures the actual app UI without frames or generated artwork.

Validate content with `python3 scripts/screenshot_content/check_content.py` and
capture with `fastlane ios screenshots`. Local capture does not authenticate
with App Store Connect. Preserve its run ID and review both generated PNGs before
publication; the run's validation rejects missing, malformed, or stale images.

Runs live under `.build/screenshots/runs/RUN_ID/`: `raw/` retains runtime-coded
captures, `storefront/` contains validated upload files, `review.html` displays
the images, and `capture-report.json` records their hashes and dimensions.
Build logs and the private Snapshot cache also stay in the run directory.
The reusable build cache lives in `.build/screenshots/DerivedData`; a per-checkout
lock permits one capture at a time so runs cannot compete for its simulator or cache.

```bash
python3 scripts/screenshot_content/capture_progress.py status --run-id RUN_ID
fastlane ios screenshots run_id:RUN_ID locales:en-US
```

The second command resumes only pending targets from that run, preserving successful
captures. To refresh everything, omit `run_id` to create a new run. Changed source,
seeds, or configuration require a new run. Direct `fastlane snapshot` is rejected:
the lane supplies simulator/cache isolation and the explicit UI-test environment.
The private Snapshot integration is verified with Fastlane 2.236.1 and fails on
other versions until its isolation behavior is revalidated.

## Screenshot publication

`fastlane ios inspect_screenshots` is read-only: it reports the primary locale
and screenshot sets on the editable version, falling back to the live version
when none is editable. The initial check found primary locale en-US and only
English screenshots on live version 1.1; no editable version existed.

Apple defaults new localizations to primary-language screenshots. Existing
explicit sets can take precedence, so inspect before relying on fallback.
See [Apple's localization guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information/)
and [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

Screenshot publication requires a reviewed run and an explicit existing editable
version:

```bash
fastlane ios push_screenshots app_version:X.Y.Z run_id:REVIEWED_RUN
# Optional subset retry: add locales:en-US (runtime codes; enabled locales only).
```

It replaces screenshot sets in selected active locales, including their
old display-size sets, allowing the new large iPhone screenshots to serve smaller
sizes. Other locales remain untouched. The implementation scopes Deliver's
deletion, processing retries, and sorting to selected localizations; it does not
invoke the general metadata/version publishing runner. Each operation has bounded
deletion/upload retries, followed by checksum, processing, and order verification.
Preserve logs and inspect remote state after a partial failure before
retrying the affected locale subset.

There is no binary upload, text-metadata update, localization/version creation,
availability change, or submission in this path. No screenshot upload is needed
to validate the infrastructure; use mocked publishing tests and local captures.
