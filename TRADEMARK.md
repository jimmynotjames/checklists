# reChecklist Trademark and Branding Policy

> **This document is policy guidance, not legal counsel.** For trademark questions in a commercial or legal context, consult a qualified attorney.

The source code in this repository is licensed under the Apache License 2.0 (see [`LICENSE`](LICENSE)), which permits broad use, modification, and redistribution. However, Apache §6 explicitly withholds trademark rights. This file describes what the code license **does not** cover.

---

## Reserved marks

The following are trademarks and intellectual property of **Jimmy Ho**:

| Mark / Asset | Description | Location in repo |
|---|---|---|
| **reChecklist** (word mark) | App display name as used in the iOS App Store | `CFBundleDisplayName = reChecklist` in `checklists/checklists/Info.plist` |
| **reChecklist app icon** | The stylized icon artwork in all sizes | `checklists/checklists/Assets.xcassets/AppIcon.appiconset/` |
| **App Store metadata** | Name, subtitle, keywords, promotional text, description, release notes — all storefront locales | `fastlane/metadata/` |
| **Screenshot seed / demo content** | Locale-specific demo checklists used when capturing App Store screenshots | `checklists/checklistsUITests/ScreenshotSeeds/` |
| **Support URL** | `https://jimmynotjames.github.io/checklists/` | `fastlane/metadata/*/support_url.txt` |

---

## What this policy prohibits (without explicit written permission)

- Distributing an **iOS app or TestFlight build** under the name "reChecklist" or any confusingly similar name.
- Uploading an **App Store or TestFlight listing** that uses the reChecklist name, the reChecklist app icon, or any of the committed App Store metadata text.
- Implying **official affiliation or endorsement** by using "reChecklist" as your app's product name or as a prominent label in your UI.
- Republishing **captured App Store screenshots** in a store listing or promotional material for a fork.

---

## What this policy permits (nominative / fair reference)

You **may** use the name "reChecklist" factually and accurately to describe the origin of your code:

- In your repository's README: *"This is a fork of the [reChecklist open-source project](https://github.com/jimmynotjames/checklists)."*
- In documentation or commit messages: *"Based on reChecklist source code."*
- In source code comments: *"Derived from reChecklist's `ChecklistStore`."*

These uses do not employ "reChecklist" as the **distributed app's name or store title**.

---

## A note on look and feel

Hi! I'm glad you're here. Feel free to fork the code, learn from it, reuse what helps. As stated above, the name, icon, and store copy are what I reserve legally.

While it's hard for me to legally protect my color palette, layout, and general look and feel, if you ship **your own app**, I would prefer that you're not a jerk about this. In addition to swapping out the icon and name, please put your personal mark on the colors, UI, screen architecture, etc. Perhaps add some nifty new product features or UX enhancements.

---

## Tier A (Simulator-only development)

**Compiling and running on a local Simulator is permitted and encouraged**, even if reChecklist branding is visible on screen. Local development is not redistribution.

This policy applies when you **distribute** — defined as delivering a binary (via TestFlight, App Store, ad-hoc, enterprise distribution, or any other means) to users other than yourself.

---

## What to replace before distributing a fork

See [CONTRIBUTING.md § B — Configure secrets, ship, or fork for distribution](CONTRIBUTING.md#b--configure-secrets-ship-or-fork-for-distribution) for the full replacement checklist. Summary:

1. App icon (`checklists/checklists/Assets.xcassets/AppIcon.appiconset/`)
2. App display name (`CFBundleDisplayName` in `checklists/checklists/Info.plist`)
3. All `fastlane/metadata/*` storefront copy
4. Screenshot seed content (`checklists/checklistsUITests/ScreenshotSeeds/`)
5. Bundle ID (`com.jimmyho.checklists` in `project.pbxproj`)
6. CloudKit container (`iCloud.com.jimmyho.checklists` in `checklists.entitlements`)
7. Support and privacy URLs (`fastlane/metadata/*/support_url.txt`, `privacy_url.txt`)
8. Your own feedback address (`checklists/checklists/App/FeedbackMail.swift`) and privacy policy URL (`checklists/checklists/Screens/SettingsView.swift`)

---

## Contact

For trademark licensing inquiries, open an issue on this repository or reach out via the support URL above.
