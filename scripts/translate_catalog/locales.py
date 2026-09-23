"""
Single source of truth for the localization locale set, derived from the registry in
fastlane/screenshot-config.json (`locales[]`: runtime, storefront, region, name).

Runtime codes are the app's BCP 47 codes (`de`, `nb`, `zh-Hans`) — the keys used in
Localizable.xcstrings and ScreenshotSeeds/. Storefront codes are what App Store Connect
and `deliver` expect for fastlane/metadata/<storefront>/ folders (`de-DE`, `no`).

Import from this module in every pipeline script; never restate the list.

    python3 scripts/translate_catalog/locales.py   # prints the target runtime locales
"""

from __future__ import annotations

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = REPO_ROOT / "fastlane" / "screenshot-config.json"

SOURCE_RUNTIME = "en-US"


def _load_rows() -> list[dict]:
    try:
        raw = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    except OSError as exc:
        raise RuntimeError(f"locale registry unreadable at {REGISTRY_PATH}: {exc}") from exc
    rows = raw.get("locales")
    if not isinstance(rows, list) or not rows:
        raise RuntimeError(f"{REGISTRY_PATH}: locales must be a non-empty array")
    for row in rows:
        for field in ("runtime", "storefront", "region", "name"):
            value = row.get(field) if isinstance(row, dict) else None
            if not isinstance(value, str) or not value.strip():
                raise RuntimeError(f"{REGISTRY_PATH}: every locales entry needs a non-empty {field!r}")
    runtimes = [row["runtime"] for row in rows]
    storefronts = [row["storefront"] for row in rows]
    if len(set(runtimes)) != len(runtimes) or len(set(storefronts)) != len(storefronts):
        raise RuntimeError(f"{REGISTRY_PATH}: runtime and storefront codes must be unique")
    if SOURCE_RUNTIME not in runtimes:
        raise RuntimeError(f"{REGISTRY_PATH}: source locale {SOURCE_RUNTIME!r} has no entry")
    return rows


_ROWS = _load_rows()

# Translation targets, in registry order, excluding the English source.
LOCALES: list[str] = [row["runtime"] for row in _ROWS if row["runtime"] != SOURCE_RUNTIME]

# English display name per runtime code (includes the source).
LOCALE_NAMES: dict[str, str] = {row["runtime"]: row["name"] for row in _ROWS}

RUNTIME_TO_STOREFRONT: dict[str, str] = {row["runtime"]: row["storefront"] for row in _ROWS}
STOREFRONT_TO_RUNTIME: dict[str, str] = {row["storefront"]: row["runtime"] for row in _ROWS}


if __name__ == "__main__":
    for locale in LOCALES:
        print(f"{locale:<8} {RUNTIME_TO_STOREFRONT[locale]:<8} {LOCALE_NAMES[locale]}")
    print(f"\n{len(LOCALES)} target locale(s) + source {SOURCE_RUNTIME}")
