# Fastlane setup

This repo uses Homebrew fastlane, verified with 2.236.1. Run commands from the
repository root. Install on a new machine with
`brew install fastlane`. There is no Gemfile or plugin dependency. Supply a UTF-8
locale per command if your shell does not already have one:
`LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 fastlane lanes`.

## Credentials

See [`core-docs/secrets-list.md`](../core-docs/secrets-list.md) for the complete fresh-clone secret
inventory and safe reconstruction checklist. `fastlane ios verify_auth` confirms read-only access to
the app configured in Appfile and prints its App Store Connect ID, with no upload, build, version
change, or availability change.

Binary archives also require a valid Apple Distribution identity in the login
keychain and automatic signing for team `EDMB3Z5KAY`. `archive_validation` does
not request provisioning updates, so a matching App Store provisioning profile
must already be installed for its export to pass. The real beta lane allows Xcode
to update provisioning through an existing signed-in Xcode account. It also
requires the Release values checked by `scripts/verify_release_secrets.sh`.

## Initial marketing copy

`metadata/` is the source of truth; `metadata-source.json` records the one-time 1.1 import's
provenance. There is no download lane. Marketing URL and promotional text were absent from the
source listing.

## English fallback and future overrides

`metadata/en-US/` is the American English source copy. The locale manifest records
the 50 metadata locales supported by the installed Fastlane version. Preparation
resolves each field for all of them from an explicit locale override when present,
or from English otherwise. Preserve App Store Connect locale codes in sibling
directories when translated overrides are eventually introduced.

The app is English-only; do not create duplicate locale directories or generate translations yet.

## Workflow routing and validation

Routing: AGENTS.md §"Commit and PR style". `make gate` remains the build gate; never use an upload
lane as an infrastructure test.

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

`fastlane/screenshot-config.json` records the 50 runtime/storefront locale
mappings independently of the translation pipeline. Only runtime `en-US` is
active, with regional locale `en_US`. This list is separate from the metadata
pipeline's all-locale English fallback. Enable additional screenshot locales
only after supplying their catalogs and translated app strings. The remaining
translation integration is tracked in [issue #161](https://github.com/jimmynotjames/checklists/issues/161).

The English catalog under `checklists/checklistsUITests/ScreenshotSeeds/` mirrors
the shipped sample data, except it checks the first three Pre-Trip items. Thus the
home screen shows completion counts 5/6, 4/12, and 3/11. Normal first-launch data
is unchanged. Screenshot launches use Debug-only, disposable in-memory model and settings stores;
they never import or sync user data. The settings store begins with an explicit analytics opt-out
so strict-region captures cannot be covered by first-run consent, while the catalog's regional
locale still controls the rendered UI. It captures two screens,
`01_checklists` and `02_pre_trip`, and is excluded from normal UI-test runs.

Device/locale config: `fastlane/screenshot-config.json`. Captures the real UI; no frames or
generated artwork.

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
seeds, or configuration require a new run. Direct `fastlane snapshot` is rejected —
`Snapfile` enforces the required isolation.

## Screenshot publication

`fastlane ios inspect_screenshots` is read-only: it reports the primary locale
and screenshot sets on the editable version, falling back to the live version
when none is editable.

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
sizes. Other locales remain untouched.

There is no binary upload, text-metadata update, localization/version creation,
availability change, or submission in this path. No screenshot upload is needed
to validate the infrastructure; use mocked publishing tests and local captures.
