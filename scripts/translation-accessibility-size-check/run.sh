#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Ad-hoc localized large-type screenshot capture; what it does and how to read it: README.md.
# Knobs (env):
#   WORKERS         parallel simulator clones (default 1, serial). Each clone is a full simulator
#                   (~1.5-2 GB) plus the app and runner; on 16 GB, 6-7 is the practical ceiling.
#   SIMULATOR_NAME  base device (default from _sim_sandbox.sh). A narrow device is the worst case
#                   for truncation — try SIMULATOR_NAME="iPhone 17e".
#   MAX_PX          downscale longest screenshot edge to this many px (default 1000).

WORKERS="${WORKERS:-1}"
MAX_PX="${MAX_PX:-1000}"
OUT="${ROOT}/tmp/loc-size-check"

if [[ "${1:-}" != "--yes" ]]; then
  cat <<USAGE
⚠  Localized large-type screenshot capture — RESOURCE WARNING
   This drives 13 locales through 7 screens each on the simulator and takes roughly
   20-30 minutes serially. Close other heavy apps first, then re-run to proceed:

       bash scripts/translation-accessibility-size-check/run.sh --yes

   (Override WORKERS / SIMULATOR_NAME / MAX_PX via env — see the header of this script.)
USAGE
  exit 2
fi

for tool in jq sips; do
  command -v "$tool" >/dev/null 2>&1 || { echo "✗ missing required tool: $tool" >&2; exit 1; }
done

source "${ROOT}/scripts/_destination.sh"   # sets DESTINATION, SIM_DERIVED, SIM_RESULTS_DIR

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RESULT="${SIM_RESULTS_DIR}/${TIMESTAMP}-$$-loc-size.xcresult"

PARALLEL_ARGS=(-parallel-testing-enabled NO)
if [[ "${WORKERS}" -gt 1 ]]; then
  PARALLEL_ARGS=(-parallel-testing-enabled YES -parallel-testing-worker-count "${WORKERS}")
  # Clones an interrupted run left behind; safe under the lock _destination.sh holds.
  python3 "${ROOT}/scripts/sim_clean.py" --clones-only
fi

echo "→ Capturing 13 locales @ xxxLarge (WORKERS=${WORKERS}) …"
# `|| RC=$?` so a failed run still names its bundle below.
RC=0
xcodebuild test \
  -project checklists/checklists.xcodeproj \
  -scheme checklists \
  -destination "${DESTINATION}" \
  -destination-timeout 300 \
  -derivedDataPath "${SIM_DERIVED}" \
  -resultBundlePath "${RESULT}" \
  "${PARALLEL_ARGS[@]}" \
  -collect-test-diagnostics never \
  -only-testing:checklistsUITests/LocalizationScreenshotCapture || RC=$?

echo "result-bundle: ${RESULT}"
[[ "${RC}" -eq 0 ]] || exit "${RC}"
echo "→ Exporting and downscaling screenshots into ${OUT} …"
rm -rf "${OUT}" && mkdir -p "${OUT}"
RAW="$(mktemp -d)"
xcrun xcresulttool export attachments --path "${RESULT}" --output-path "${RAW}" >/dev/null 2>&1

# Rename exported UUID files to <lang>__<screen>.png using the manifest, then downscale.
# The exporter appends `_<index>_<UUID>.png` to the attachment name we set (e.g.
# `de__01-list_0_<UUID>.png`); strip that suffix back to our `<lang>__<screen>` name.
jq -r '.[] | .attachments[]? | select((.suggestedHumanReadableName // "") | test("__"))
        | "\(.exportedFileName)\t\(.suggestedHumanReadableName | sub("_[0-9]+_[0-9A-Fa-f-]+\\.png$"; ""))"' \
        "${RAW}/manifest.json" \
| while IFS=$'\t' read -r file name; do
    [[ -f "${RAW}/${file}" ]] || continue
    cp "${RAW}/${file}" "${OUT}/${name}.png"
    sips -Z "${MAX_PX}" "${OUT}/${name}.png" >/dev/null 2>&1 || true
  done
rm -rf "${RAW}"

COUNT="$(find "${OUT}" -name '*.png' | wc -l | tr -d ' ')"
echo "✓ ${COUNT} screenshot(s) → ${OUT}/ (downscaled to ${MAX_PX}px max edge)"
echo "  Next: read them — the visual review IS the check — and record findings in"
echo "  scripts/translation-accessibility-size-check/AUDIT_LOG.md."
echo "  They are left in place; delete with: rm -rf ${OUT}"
