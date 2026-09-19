"""Repo paths shared by the localization pipelines. Import; never restate."""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# The app target's String Catalog (auto-included via the synchronized folder).
CATALOG_PATH = REPO_ROOT / "checklists" / "checklists" / "Localizable.xcstrings"

# Production Swift sources scanned for unkeyed copy.
SOURCE_DIR = REPO_ROOT / "checklists" / "checklists"

# Per-locale screenshot seed catalogs (UI-test target only; never ships).
SEEDS_DIR = REPO_ROOT / "checklists" / "checklistsUITests" / "ScreenshotSeeds"
