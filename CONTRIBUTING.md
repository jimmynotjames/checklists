# Contributing to reChecklist

> Note from maintainer: I generated this file using AI and have not had a chance to test this end-to-end. If you try to reproduce this repo and run into issues, please post an Issue or post a PR to update this file with better instructions. Thanks!

---

> **Branding notice (read before you distribute):** The code is Apache 2.0–licensed, but the reChecklist name, app icon, and App Store marketing assets are not. See [§ Branding & trademarks](#branding--trademarks) and [TRADEMARK.md](TRADEMARK.md) for what forks must replace before distributing.

---

## Contributing Features and Bug Fixes

I'm not working on this repo regularly, so responses may take some time. That said, if you do not meet the requirements below, your issue or pull request will likely be ignored. Sorry if that feels strict. I'm doing my best to manage my time and ensure this stays a quality product. Remember that you can always fork this repo, add your own desired features, and deploy a debug version on your device for your own use.

Requirements:

- You must prove that you understand this product and have a genuine desire to improve it. Explain your product thinking clearly and concisely. I recommend you hand-write this part and have AI review it. Be prepared to have a conversation.
- For bug fixes, clearly and concisely explain the bug, including detailed reproduction steps. Explain your bug fix and discuss any architectural issue. No "band-aid" fixes will be accepted unless it's a high-severity issue, and it would be a crazy endeavor to refactor appropriately.

Obviously, given that this code is agentically written, I have no issues if you use AI to contribute to this repo. That said, if I sense that you did not put effort into ensuring that your agent was producing quality work, I will likely ignore or reject your pull request or issue.

Pull requests follow [`.github/pull_request_template.md`](.github/pull_request_template.md), including its cross-cutting concerns checklist.

## Two-tier setup

How much work each goal requires:

| Goal                                     | Gitignored files needed?                                        | Apple account                                        | Quick start                                                    |
| ---------------------------------------- | --------------------------------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------- |
| **A. Simulator dev**                     | None                                                            | Apple ID in Xcode (only if a signing prompt appears) | `make system` → `make build` → `make sim-run`                  |
| **B. Ship / configure for distribution** | `Secrets.local.xcconfig` + `fastlane/.env` + `.p8` outside repo | Apple Developer Program + App Store Connect          | See [§ B](#b--configure-secrets-ship-or-fork-for-distribution) |

```
Tier A — zero secrets               Tier B — ship / full config
────────────────────────            ──────────────────────────────
git clone                           Secrets.local.xcconfig
     ↓                              fastlane/.env + .p8
make system                         Replace branding if distributing
     ↓                                    ↓
make build                          verify_release_secrets.sh (auto)
     ↓                                    ↓
make sim-run              ────────▶  fastlane beta
(Xcode signing only
 if prompted)
```

To build and run on Simulator only, stop after [§ A](#a--compile-and-run-on-simulator-no-secrets-files).

---

## A — Compile and run on Simulator (no secrets files)

Audience: contributors exploring the code, running tests, iterating on UI.

You don't need `config/Secrets.local.xcconfig`, `fastlane/.env`, an App Store Connect API key, or Apple Developer Program enrollment.

### Minimal steps

1. Clone the repo.
2. One-time machine setup (needs [Homebrew](https://brew.sh)):
   ```bash
   make system
   ```
   Installs Lefthook hooks, SwiftLint, SwiftFormat, gitleaks; verifies Xcode and Python. The lint and hook tools must match the exact versions pinned in `config/lint-tools.env`; if Homebrew installs a different version, `make system` and `make gate` stop and name the mismatch, so install the pinned release of that tool.
3. Compile:
   ```bash
   make build
   ```
   Reads committed placeholder values from `config/Secrets.xcconfig`, so no local secrets file is needed. It never boots a simulator.
4. Run on Simulator:
   - From terminal: `make sim-run` (builds, installs, and launches on this checkout's own simulator), or
   - From Xcode: open `checklists/checklists.xcodeproj`, select an iPhone Simulator → Run (⌘R).
5. Before opening a PR: `make gate` (format, lint, i18n, doc, and tooling checks, then a build).

The unit and UI suites (`make test-unit`, `make test-ui`) are opt-in and not part of the gate. See [AGENTS.md](AGENTS.md) §"Build and test".

### Simulator concurrency

The test scripts can draw on a shared simulator pool at `~/dev/simulator-slots`. That pool exists only on the maintainer's machine, where it caps how many simulators all of their repos run at once (`scripts/simulator-slots/` is that tool's vendored copy). You don't need it, and you shouldn't create its directories. Without the pool, test runs go serially on this checkout's own simulator.

To run UI tests on parallel simulator clones instead, set `SIMULATOR_WORKERS_WITHOUT_POOL`:

- Unset (default) runs serially on one simulator, the lightest option.
- `SIMULATOR_WORKERS_WITHOUT_POOL=2 make test-ui` runs up to that many clones, also capped by `UI_WORKERS` (default 2). Each booted simulator takes about 2–3 GB of RAM.

Details: [AGENTS.md](AGENTS.md) §"Simulator slots".

### Signing

`make build` on a fresh clone should succeed without changing the team, even though the project references maintainer team ID `EDMB3Z5KAY`. Don't work around a signing error with `CODE_SIGNING_ALLOWED=NO`: the app then launches without its simulated entitlements and crashes in CloudKit setup (see `scripts/build.sh`).

Only if a build or run fails on signing or provisioning: open `checklists/checklists.xcodeproj` → `checklists` app target → Signing & Capabilities → choose your Personal Team (the Apple ID registered in Xcode). Simulator-only dev doesn't require changing the bundle ID or CloudKit container.

### What works with placeholders

- App launches; checklists, items, settings, and SwiftData work against the local store. iCloud may show as unavailable on Simulator, which is expected.
- Unit and UI tests (`make test-unit`, `make test-ui`).
- Analytics: console only (`ConsoleAnalyticsClient`); no Mixpanel network traffic.
- Send Feedback and Privacy Policy still point at the maintainer's address and site. They're hardcoded, not secrets; see [§ Branding](#branding-required-if-you-distribute).

---

## B — Configure secrets, ship, or fork for distribution

Audience: shipping to TestFlight/App Store, using real analytics locally, or publishing a fork as your own app.

Prerequisites to ship: Apple Developer Program enrollment and an App Store Connect app record.

The full inventory of local secrets, with where each comes from, is [core-docs/secrets-list.md](core-docs/secrets-list.md).

### Step 1 — App secrets (required for Release / Fastlane ship)

```bash
cp config/Secrets.local.xcconfig.template config/Secrets.local.xcconfig
```

Open the file and fill in:

| Key                   | What                                      | Notes                               |
| --------------------- | ----------------------------------------- | ----------------------------------- |
| `MIXPANEL_DEV_TOKEN`  | Mixpanel project token for Debug builds   | From your Mixpanel project settings |
| `MIXPANEL_PROD_TOKEN` | Mixpanel project token for Release builds | Usually a separate Mixpanel project |

`config/Secrets.local.xcconfig` is gitignored and must never be committed. `make verify-secrets` checks it without printing the tokens.

### Step 2 — App Store Connect API

```bash
cp fastlane/.env.template fastlane/.env
```

Store your `.p8` key file **outside the repo** (e.g. `~/.appstoreconnect/`) and set its path in `fastlane/.env`. Details in [fastlane/SETUP.md](fastlane/SETUP.md).

### Step 3 — Verify auth

```bash
fastlane ios verify_auth
```

### Step 4 — Ship

```bash
fastlane ios beta   # TestFlight
```

The lane runs `scripts/verify_release_secrets.sh` before building. If any placeholder sentinel remains, it exits with instructions before archive, sign, or upload; shipping lanes refuse `SKIP_RELEASE_SECRETS_CHECK=1`. App Store submission is done by hand in App Store Connect.

### What never gets committed

| File                            | Why                                                                                                  |
| ------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `config/Secrets.local.xcconfig` | Contains your real Mixpanel tokens                                                                   |
| `fastlane/.env`                 | Contains ASC API key ID and issuer ID                                                                |
| `*.p8`                          | App Store Connect private key. Keep outside the repo entirely. Filepath recorded in `fastlane/.env`. |

### Branding (required if you distribute)

See [§ Branding & trademarks](#branding--trademarks) and [TRADEMARK.md](TRADEMARK.md) for the full policy. Short version: before you upload to TestFlight, submit to the App Store, or distribute a binary to users, you must replace:

- App icon (`checklists/checklists/Assets.xcassets/AppIcon.appiconset/`)
- App display name (`CFBundleDisplayName = reChecklist` in `checklists/checklists/Info.plist`)
- All `fastlane/metadata/*` storefront copy (name, subtitle, keywords, description, promotional text, release notes)
- Screenshot seed content in `checklists/checklistsUITests/ScreenshotSeeds/` (if you generate store screenshots)
- Bundle ID (`com.jimmyho.checklists`) and team ID (`EDMB3Z5KAY`) in `project.pbxproj`, `fastlane/Appfile`, and `fastlane/lib/release_build.rb`
- CloudKit container (`iCloud.com.jimmyho.checklists` in `checklists/checklists/checklists.entitlements`)
- Support and privacy URLs in `fastlane/metadata/*/support_url.txt` and `privacy_url.txt`
- The feedback address in `checklists/checklists/App/FeedbackMail.swift`, and the privacy policy URL and App Store review link (`id1475724536`) in `checklists/checklists/Screens/SettingsView.swift`

Tier A (Simulator-only) builds may show reChecklist branding locally; that is development, not distribution.

---

## Branding & trademarks

The source code is licensed under the Apache License 2.0 (see [LICENSE](LICENSE)), which permits modification and redistribution but explicitly withholds trademark and product-name rights (section 6 of the Apache License).

The reChecklist name and these assets are not covered by the code license:

| Asset                               | Location                                                                         |
| ----------------------------------- | -------------------------------------------------------------------------------- |
| Word mark / app name **reChecklist** | `CFBundleDisplayName` in `checklists/checklists/Info.plist`; all in-app branding strings |
| App icon                            | `checklists/checklists/Assets.xcassets/AppIcon.appiconset/`                      |
| App Store metadata (all storefronts) | `fastlane/metadata/` — name, subtitle, keywords, description, promo text, release notes, URLs |
| Screenshot seed demo data           | `checklists/checklistsUITests/ScreenshotSeeds/`                                  |

Forks that only compile and run on a Simulator locally are fine. The trademark rules apply when you distribute: TestFlight, App Store, or any binary delivered to users.

Full policy, permitted uses, and what to replace: [TRADEMARK.md](TRADEMARK.md).

---

## Analytics fork hygiene

If you ship a fork with analytics, use your own Mixpanel project: set `MIXPANEL_DEV_TOKEN` and `MIXPANEL_PROD_TOKEN` in `config/Secrets.local.xcconfig` to your project's tokens. Never point a fork at reChecklist's projects. Keep the consent and no-PII rules in [core-docs/analytics-spec.md](core-docs/analytics-spec.md); your App Privacy label must match what you collect.

---

## What never belongs in the repo

Besides the files in [§ What never gets committed](#what-never-gets-committed): any other secret, credential, or personal identifier. The pre-commit hook (`gitleaks git --pre-commit --staged`) blocks them; CI's full-history secret scan runs when CI is triggered.

---

## Agent / AI tool reminder

If you are an AI agent working in this codebase:

- **Read [AGENTS.md](AGENTS.md) first.** It is canonical; the design docs in `core-docs/` are canonical for their areas.
- **Local secrets:** `config/Secrets.local.xcconfig` and `fastlane/.env` (gitignored), and the `.p8` key (outside the repo). Never read, print, or commit them; [core-docs/secrets-list.md](core-docs/secrets-list.md) names the keys.
- **Ship guard:** `scripts/verify_release_secrets.sh`. Don't bypass it.
- **Build & test:** `make gate` before a PR; app test suites are opt-in. See AGENTS.md §"Build and test".
- **Simulators:** the simulator-slots pool is off outside the maintainer's machine. Run normally and don't create the pool's directories; choose concurrency with `SIMULATOR_WORKERS_WITHOUT_POOL`. See AGENTS.md §"Simulator slots".
- **Translations:** new user-facing strings require the `translate-new-strings` skill. See [core-docs/localization-spec.md](core-docs/localization-spec.md).
- **Branding:** unless you are deriving your own app with its own branding, do not alter the app icon, reChecklist name, or store metadata as part of code changes. See [TRADEMARK.md](TRADEMARK.md).
