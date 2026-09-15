#!/usr/bin/env bash
# scripts/verify_release_secrets.sh — release ship guard.
#
# Escape hatch (exceptional local Release archives ONLY — never for shipping):
#   SKIP_RELEASE_SECRETS_CHECK=1 bash scripts/verify_release_secrets.sh
#
# Exit codes:
#   0 — checks passed, safe to archive.
#   1 — a placeholder is still active; ship blocked.

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
# MixpanelTokenSource.isConfigured matches this: it validates only the token the active build
# configuration will actually use.
#
# Prefer the build-phase env value if present: without baseConfigurationReference the
# xcconfig still has a real token while Info.plist would get an empty one, hiding failure.
MIXPANEL_PROD="${MIXPANEL_PROD_TOKEN:-$(xcconfig_value MIXPANEL_PROD_TOKEN)}"

# A token is 32 lowercase hex; the shape check also rejects $(inherited), the template
# placeholder, and typos.
if [[ ! "$MIXPANEL_PROD" =~ ^[0-9a-f]{32}$ ]]; then
  if [[ -z "$MIXPANEL_PROD" ]]; then
    ERRORS="${ERRORS}  - MIXPANEL_PROD_TOKEN is empty\n"
  else
    ERRORS="${ERRORS}  - MIXPANEL_PROD_TOKEN is not a valid token (expected 32 lowercase hex characters)\n"
  fi
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
