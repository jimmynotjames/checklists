#!/usr/bin/env python3
"""Generate the per-locale screenshot seed catalogs from the string catalog.

The seeds are derived, never authored. `ScreenshotSeeds/en-US.json` supplies the
structure — which checklists exist, their ids and order, how many items each has,
which read as done, and which carry notes — and `Localizable.xcstrings` supplies
the words, from the `sample.*` namespace the app itself uses on first launch.
That is the whole point: a screenshot shows exactly what a new user sees.

The mapping runs English value -> `sample.*` key -> that locale's translation.
It never matches localized text, because the `sample.*` namespace is
transcreated rather than translated: a locale's morning routine may start with a
tea kettle where English starts with a coffee maker, so the localized strings are
deliberately not parallel to the English and only the key is a reliable join.

Usage:
  python3 scripts/screenshot_content/generate_seeds.py [--locales a,b] [--check]

  --check  regenerate into memory, compare against what is on disk, and exit 1
           on any drift. This is what `make i18n-check` runs, so a catalog edit
           that leaves the seeds stale fails the gate instead of shipping.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]
sys.path.insert(0, str(SCRIPT_DIR))
sys.path.insert(0, str(REPO_ROOT / "scripts" / "translate_catalog"))

from config import ConfigError, SEEDS_DIR, load_config  # noqa: E402
from paths import CATALOG_PATH  # noqa: E402

SOURCE_RUNTIME = "en-US"
SOURCE_LANGUAGE = "en"
NAMESPACE = "sample."


class SeedError(Exception):
    """A seed could not be derived; the message says which key or value failed."""


def _canonical_json(document: dict) -> str:
    """Serialize a seed the one way this repo writes them, so runs are byte-stable.

    Key order follows the source document rather than sorting: it is already the
    order a reader wants, and sorting would rewrite the hand-authored en-US file
    for no gain.
    """
    return json.dumps(document, ensure_ascii=False, indent=2) + "\n"


def load_english_index(catalog: dict) -> dict[str, str]:
    """Map each `sample.*` key's English value to its key.

    Raises on a duplicate value: two keys sharing one English string would make
    the join ambiguous, and silently picking one would mistranslate a seed.
    """
    index: dict[str, str] = {}
    for key, entry in catalog["strings"].items():
        if not key.startswith(NAMESPACE):
            continue
        unit = entry.get("localizations", {}).get(SOURCE_LANGUAGE, {}).get("stringUnit", {})
        value = unit.get("value")
        if not value:
            raise SeedError(f"{key}: no English value in the catalog")
        if value in index:
            raise SeedError(
                f"ambiguous English value {value!r} shared by {index[value]} and {key}; "
                "seed generation joins on the English value and cannot choose between them"
            )
        index[value] = key
    if not index:
        raise SeedError(f"no {NAMESPACE}* keys in {CATALOG_PATH}")
    return index


def translate(catalog: dict, key: str, language: str) -> str:
    """Return `key`'s value in `language`, failing loud rather than falling back.

    A silent fallback to English would put English words in a localized
    screenshot, which is exactly the defect these seeds exist to prevent.
    """
    localizations = catalog["strings"][key].get("localizations", {})
    unit = localizations.get(language, {}).get("stringUnit", {})
    value = unit.get("value")
    if not value:
        raise SeedError(f"{key}: no translation for {language}")
    return value


def _localize(value: str, index: dict[str, str], catalog: dict, language: str, where: str) -> str:
    key = index.get(value)
    if key is None:
        raise SeedError(
            f"{where}: {value!r} is not in the catalog's {NAMESPACE}* namespace. "
            f"The seed and the app's sample data have drifted apart — add the string "
            f"to {CATALOG_PATH.name} under a {NAMESPACE}* key, or correct the seed."
        )
    return translate(catalog, key, language)


def build_seed(source: dict, index: dict[str, str], catalog: dict, runtime: str,
               language: str, primary_locale: str) -> dict:
    """Derive one locale's seed from the English source document."""
    checklists = []
    for position, checklist in enumerate(source["checklists"]):
        where = f"checklist {position + 1}"
        items = []
        for offset, item in enumerate(checklist["items"]):
            item_where = f"{where} item {offset + 1}"
            built = {
                "name": _localize(item["name"], index, catalog, language, item_where),
            }
            if "notes" in item:
                built["notes"] = _localize(
                    item["notes"], index, catalog, language, f"{item_where} notes"
                )
            built["isChecked"] = item["isChecked"]
            items.append(built)
        checklists.append({
            "id": checklist["id"],
            "name": _localize(checklist["name"], index, catalog, language, where),
            "items": items,
        })
    return {
        "schemaVersion": source["schemaVersion"],
        "locale": runtime,
        "primaryLocale": primary_locale,
        "checklists": checklists,
    }


def catalog_language(runtime: str) -> str:
    """The catalog's language code for a runtime locale.

    The registry's runtime codes are already the catalog's codes (`de`, `nb`,
    `zh-Hans`); only the source differs, where the registry says `en-US` and the
    catalog says `en`.
    """
    return SOURCE_LANGUAGE if runtime == SOURCE_RUNTIME else runtime


def _requested_runtimes(raw: str | None, by_runtime: dict) -> list[str]:
    if not raw:
        return list(by_runtime)
    requested = [part.strip() for part in raw.split(",") if part.strip()]
    unknown = [runtime for runtime in requested if runtime not in by_runtime]
    if unknown:
        raise SeedError(f"unknown runtime locale(s): {', '.join(unknown)}")
    return list(dict.fromkeys(requested))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--locales", help="Comma-separated runtime codes (default: every locale).")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Do not write; exit 1 if any seed on disk differs from the generated one.",
    )
    args = parser.parse_args(argv)

    try:
        config = load_config()
        catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
        index = load_english_index(catalog)
        source = json.loads((SEEDS_DIR / f"{SOURCE_RUNTIME}.json").read_text(encoding="utf-8"))
        by_runtime = config.locales_by_runtime
        # Deliberately not config.active_locales: a seed exists for every locale
        # in the registry, whether or not screenshots are currently captured for
        # it, so the set stays complete while capture is enabled a few at a time.
        runtimes = _requested_runtimes(args.locales, by_runtime)

        drifted: list[str] = []
        written = 0
        for runtime in runtimes:
            locale = by_runtime[runtime]
            seed = build_seed(
                source, index, catalog, runtime, catalog_language(runtime), locale.apple_locale
            )
            rendered = _canonical_json(seed)
            path = SEEDS_DIR / f"{runtime}.json"
            if args.check:
                on_disk = path.read_text(encoding="utf-8") if path.exists() else None
                if on_disk != rendered:
                    drifted.append(runtime if on_disk is not None else f"{runtime} (missing)")
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(rendered, encoding="utf-8")
            written += 1
    except (ConfigError, SeedError, KeyError, OSError) as error:
        print(f"generate_seeds: {error}", file=sys.stderr)
        return 1

    if args.check:
        if drifted:
            print(
                f"generate_seeds: {len(drifted)} seed(s) differ from the catalog: "
                f"{', '.join(drifted)}",
                file=sys.stderr,
            )
            print(
                "Run: python3 scripts/screenshot_content/generate_seeds.py",
                file=sys.stderr,
            )
            return 1
        print(f"generate_seeds: {len(runtimes)} seed(s) match the catalog.")
        return 0

    print(f"generate_seeds: wrote {written} seed(s) to {SEEDS_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
