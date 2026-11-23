# App Store release v2.0

Status: in-flight
Started: 2026-10-24
Source commit: ce58445
Record PR: #342
Record merged: yes

## Listing

- [x] English source reviewed
- [x] Resolved metadata validated and reviewed
- [x] Editable App Store version 2.0 confirmed
- [x] Metadata uploaded or deliberately unchanged

Metadata note: Uploaded 2026-10-24, all locales, no errors.
Screenshots: Reviewed run `20261104T153913Z-34f31b45` (source 4ca0bc8) uploaded to 2.0 on 2026-11-04, replacing the 2026-10-26 run; all 50 locales now hold an APP_IPHONE_67 set of 2 and an APP_IPHONE_DUO set of 2, with processing, checksums and order verified. The 49-locale push stopped before sorting, with 4 assets still processing; sorting those locales and a subset retry of en-AU, es-ES, ur-PK completed it.

## Candidate

- [x] Spec drift sweep clean or fixed
- [x] Release candidate uploaded to TestFlight
- [ ] Version/build PR opened
- [ ] Version/build PR reviewed and merged
- [ ] Exact candidate installed and tested

Spec sweep: 2026-11-23, no drift affecting the binary; doc fixes and the App Privacy label step in #422
Version: 2.0
Build: 1
Binary source commit: 223edff
Fastlane recovery record: `tmp/releases/20261123T234649-12138/release.json` (status `committed`; local to this clone)
Upload result/date: uploaded 2026-11-23, build-number bump committed as fcbde2a. Exported `.ipa` entitlements verified: application-identifier `EDMB3Z5KAY.com.jimmyho.checklists`, iCloud container `iCloud.com.jimmyho.checklists`, CloudKit, `aps-environment` production, icloud-container-environment Production.
Version/build PR: —
Test result/date: —

## Submission

- [ ] App Privacy label in App Store Connect matches `core-docs/analytics-spec.md` §Published disclosures
- [ ] Exact tested build attached in App Store Connect
- [ ] Submitted manually
- [ ] Approved and released

Submitted: —
Released: —
Review/status note: —
