# Secrets needed after a fresh clone

This document inventories the local, uncommitted secrets needed to fully restore development and
release workflows after cloning the repository. It records locations and setup steps only—never
paste secret values or private-key contents into this file, source control, command output, or logs.

Do not ask an agent to read or print any file listed below. The tracked templates and validation
commands are sufficient to configure and check them without exposing their contents.

## Reconstruction checklist

### Mixpanel project tokens

- Local file: `config/Secrets.local.xcconfig` (gitignored)
- Starting point: `config/Secrets.local.xcconfig.template` (tracked)
- Required values: `MIXPANEL_DEV_TOKEN` and `MIXPANEL_PROD_TOKEN`
- Source: Mixpanel → Settings → Project Settings → Project Token for the
  `reChecklist App - Dev` and `reChecklist App - Prod` projects

Create the local override from the repository root:

```bash
cp config/Secrets.local.xcconfig.template config/Secrets.local.xcconfig
```

Fill in both tokens locally. `make verify-secrets` safely confirms that the file exists and that
the production token has the shape required for a release; it does not print the token. Debug
analytics also requires the development token, even though the release check intentionally does
not validate it.

### App Store Connect API credentials

- Local file: `fastlane/.env` (gitignored)
- Starting point: `fastlane/.env.template` (tracked)
- Required values: `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID`, and `ASC_API_KEY_FILEPATH`

Create the local environment file from the repository root:

```bash
cp fastlane/.env.template fastlane/.env
```

The configured key path should point to the private key described below. Run
`fastlane ios verify_auth` to validate App Store Connect access without uploading or changing app
data. Fastlane consumes the credentials internally; do not print or inspect `.env` while
troubleshooting.

### App Store Connect private key

- External file: `/Users/jimmynotjames/.appstoreconnect/AuthKey_UN4N2PXFKN.p8`
- Referenced by: `ASC_API_KEY_FILEPATH` in `fastlane/.env`

Restore this file from secure storage. It deliberately lives outside the repository, and the
repository also ignores any `*.p8` file accidentally placed inside it. The key must exist and be
readable for Fastlane authentication. Never copy its contents into `.env`, documentation, source
control, or logs.

## Why there are two tracked xcconfig files

`config/Secrets.xcconfig` and `config/Secrets.local.xcconfig.template` are not interchangeable:

- `Secrets.xcconfig` is the tracked base configuration referenced by the app target's Debug and
  Release build configurations. Its safe placeholder values let a fresh clone build and launch,
  and its final optional include loads `Secrets.local.xcconfig` when present.
- `Secrets.local.xcconfig.template` is a tracked human-facing scaffold. Copy it to the ignored
  `Secrets.local.xcconfig`, then replace its instructional values locally. Xcode never consumes the
  template directly.

The base file must remain tracked so a fresh clone has a valid Xcode configuration. The populated
local override must remain ignored so real tokens cannot be committed.

## Other machine-local release prerequisites

These are not gitignored repository files, but a fresh machine also needs a valid Apple
Distribution identity in the login keychain, a matching App Store provisioning profile, and an
Xcode account signed into the app's development team. See [`fastlane/SETUP.md`](../fastlane/SETUP.md)
for the complete release workflow and signing requirements.
