#!/usr/bin/env python3
"""Validate screenshot seed catalogs for explicitly enabled runtime locales."""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from config import ConfigError, SEEDS_DIR, load_config, parse_locale_args  # noqa: E402


def _string(value: object, location: str, issues: list[str], *, optional: bool = False) -> None:
    if optional and value is None:
        return
    if not isinstance(value, str) or not value.strip():
        issues.append(f"{location} must be a non-empty string")


def _check_source_parity(data: dict, source: dict, issues: list[str]) -> None:
    """Require this seed to have the same shape as the source-locale seed.

    Only the words are localized. If a locale gains a checklist, loses an item,
    reorders ids, or flips which items read as done, its screenshots stop being
    comparable with every other locale's and the reviewer cannot tell a
    translation problem from a seeding one.
    """
    source_lists = source.get("checklists", [])
    checklists = data.get("checklists", [])
    if len(checklists) != len(source_lists):
        issues.append(
            f"has {len(checklists)} checklist(s); the source locale has {len(source_lists)}"
        )
        return
    for index, (checklist, expected) in enumerate(zip(checklists, source_lists)):
        location = f"checklists[{index}]"
        if not isinstance(checklist, dict):
            continue
        if checklist.get("id") != expected.get("id"):
            issues.append(
                f"{location}.id is {checklist.get('id')!r}; the source locale has "
                f"{expected.get('id')!r} in this position"
            )
        items = checklist.get("items", [])
        expected_items = expected.get("items", [])
        if len(items) != len(expected_items):
            issues.append(
                f"{location} has {len(items)} item(s); the source locale has "
                f"{len(expected_items)}"
            )
            continue
        for offset, (item, expected_item) in enumerate(zip(items, expected_items)):
            item_location = f"{location}.items[{offset}]"
            if not isinstance(item, dict):
                continue
            if item.get("isChecked") != expected_item.get("isChecked"):
                issues.append(
                    f"{item_location}.isChecked is {item.get('isChecked')!r}; the source "
                    f"locale has {expected_item.get('isChecked')!r}"
                )
            if ("notes" in item) != ("notes" in expected_item):
                issues.append(
                    f"{item_location} notes presence differs from the source locale"
                )


def validate_seed(
    path: Path, runtime: str, primary_locale: str, source: dict | None = None
) -> list[str]:
    issues: list[str] = []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return [f"missing seed file: {path}"]
    except OSError as exc:
        return [f"cannot read {path}: {exc}"]
    except json.JSONDecodeError as exc:
        return [f"invalid JSON in {path}: {exc}"]

    if not isinstance(data, dict):
        return [f"{path} must contain a JSON object"]
    if data.get("schemaVersion") != 1:
        issues.append("schemaVersion must be 1")
    if data.get("locale") != runtime:
        issues.append(f"locale must be {runtime!r}")
    if data.get("primaryLocale") != primary_locale:
        issues.append(f"primaryLocale must be {primary_locale!r}")

    checklists = data.get("checklists")
    if not isinstance(checklists, list) or not checklists:
        issues.append("checklists must be a non-empty array")
        return [f"{path.name}: {issue}" for issue in issues]

    seen_ids: set[str] = set()
    for checklist_index, checklist in enumerate(checklists):
        location = f"checklists[{checklist_index}]"
        if not isinstance(checklist, dict):
            issues.append(f"{location} must be an object")
            continue
        checklist_id = checklist.get("id")
        _string(checklist_id, f"{location}.id", issues)
        if isinstance(checklist_id, str):
            try:
                uuid.UUID(checklist_id)
            except ValueError:
                issues.append(f"{location}.id must be a UUID")
            if checklist_id in seen_ids:
                issues.append(f"{location}.id duplicates another checklist")
            seen_ids.add(checklist_id)
        _string(checklist.get("name"), f"{location}.name", issues)
        _string(checklist.get("notes"), f"{location}.notes", issues, optional=True)

        items = checklist.get("items")
        if not isinstance(items, list) or not items:
            issues.append(f"{location}.items must be a non-empty array")
            continue
        for item_index, item in enumerate(items):
            item_location = f"{location}.items[{item_index}]"
            if not isinstance(item, dict):
                issues.append(f"{item_location} must be an object")
                continue
            _string(item.get("name"), f"{item_location}.name", issues)
            _string(item.get("notes"), f"{item_location}.notes", issues, optional=True)
            if not isinstance(item.get("isChecked"), bool):
                issues.append(f"{item_location}.isChecked must be a boolean")

    if source is not None and data.get("locale") != source.get("locale"):
        _check_source_parity(data, source, issues)

    return [f"{path.name}: {issue}" for issue in issues]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--locales",
        action="append",
        help="Runtime locale(s), repeatable or comma-separated; defaults to active_locales",
    )
    args = parser.parse_args(argv)

    try:
        config = load_config()
        runtimes = parse_locale_args(args.locales, config)
    except ConfigError as exc:
        print(f"check_content: {exc}", file=sys.stderr)
        return 2

    source_path = SEEDS_DIR / f"{config.source_locale}.json"
    try:
        source = json.loads(source_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        source = None  # validate_seed reports the source's own problems on its turn.

    issues: list[str] = []
    for runtime in runtimes:
        locale = config.locales_by_runtime[runtime]
        issues.extend(
            validate_seed(SEEDS_DIR / f"{runtime}.json", runtime, locale.apple_locale, source)
        )

    if issues:
        print(f"check_content: {len(issues)} issue(s)", file=sys.stderr)
        for issue in issues:
            print(f"  {issue}", file=sys.stderr)
        return 1

    print(f"check_content: {len(runtimes)} locale(s) valid: {' '.join(runtimes)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
