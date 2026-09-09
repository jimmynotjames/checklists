#!/usr/bin/env bash
# scripts/verify_release_secrets.sh — release ship guard.
#
# Blocks TestFlight / App Store builds that still carry the committed placeholder token.
# Run by:
#   • Xcode — a "Verify release secrets" Run Script phase on the app target, restricted to
#     install/archive builds via runOnlyForDeploymentPostprocessing. A normal `make build`
#     does not trigger it.
#   • `make verify-secrets` — the manual pre-archive check. There is no Fastlane in this repo
#     and CI is disabled, so this target is the human-facing entry point.
#
# Deliberately NOT wired into `make gate` or lefthook: a fresh clone has no
# config/Secrets.local.xcconfig, and failing the everyday gate on that would be wrong.
#
# Escape hatch (exceptional local Release archives ONLY — never for shipping):
#   SKIP_RELEASE_SECRETS_CHECK=1 bash scripts/verify_release_secrets.sh
#
# Exit codes:
#   0 — checks passed, safe to archive.
#   1 — a placeholder is still active; ship blocked.
#
# Sentinels must stay in sync with config/Secrets.xcconfig and AppConfig.Placeholder in Swift.
# AppConfigSentinelTests guards the Swift half. See core-docs/analytics-spec.md §10.

set -euo pipefail

if [[ "${SKIP_RELEASE_SECRETS_CHECK:-}" == "1" ]]; then
  echo "warning: SKIP_RELEASE_SECRETS_CHECK=1 — release secrets check bypassed."
  echo "         Exceptional local Release archives only, NOT TestFlight or App Store uploads."
  exit 0
fi

# This script lives in scripts/, so SCRIPT_DIR/.. is the repo root regardless of the caller's
# working directory. Note Xcode's SRCROOT is checklists/, one level below the repo root, which
# is why the build phase passes $(SRCROOT)/../scripts/…
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BASE_XCCONFIG="${REPO_ROOT}/config/Secrets.xcconfig"
LOCAL_XCCONFIG="${REPO_ROOT}/config/Secrets.local.xcconfig"

# Read the effective value of an xcconfig key, mirroring how the committed file ends with
# `#include? "Secrets.local.xcconfig"`: base first, then local, last one wins.
xcconfig_value() {
  local key="$1"
  local value=""
  for file in "$BASE_XCCONFIG" "$LOCAL_XCCONFIG"; do
    [[ -f "$file" ]] || continue
    local match
    match=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" | tail -1 || true)
    if [[ -n "$match" ]]; then
      value="${match#*=}"
      value="${value%%//*}" # strip an inline // comment
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"
    fi
  done
  echo "$value"
}

ERRORS=""

# Only the prod token is ship-critical. MIXPANEL_DEV_TOKEN is irrelevant to a Release archive
# and is deliberately not checked — a maintainer archiving without a dev token is fine.
MIXPANEL_PROD="$(xcconfig_value MIXPANEL_PROD_TOKEN)"

if [[ "$MIXPANEL_PROD" == "PLACEHOLDER_MIXPANEL_PROD_TOKEN" ]] || [[ -z "$MIXPANEL_PROD" ]]; then
  ERRORS="${ERRORS}  - MIXPANEL_PROD_TOKEN is still the clone default\n"
fi

if [[ ! -f "$LOCAL_XCCONFIG" ]]; then
  ERRORS="${ERRORS}  - config/Secrets.local.xcconfig is missing\n"
fi

if [[ -n "$ERRORS" ]]; then
  echo ""
  echo "error: Release ship check failed — placeholder secrets still active."
  printf "%b" "$ERRORS"
  echo ""
  echo "Copy config/Secrets.local.xcconfig.template to config/Secrets.local.xcconfig and fill in"
  echo "the real project tokens from Mixpanel > Settings > Project Settings."
  echo ""
  exit 1
fi

echo "verify_release_secrets: all checks passed."
