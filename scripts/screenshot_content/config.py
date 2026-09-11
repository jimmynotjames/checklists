"""Configuration shared by screenshot capture, validation, and upload staging."""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = REPO_ROOT / "fastlane" / "screenshot-config.json"
SEEDS_DIR = REPO_ROOT / "checklists" / "checklistsUITests" / "ScreenshotSeeds"
RUNS_DIR = REPO_ROOT / ".build" / "screenshots" / "runs"

RUN_ID_PATTERN = re.compile(r"\A[A-Za-z0-9][A-Za-z0-9._-]{0,79}\Z")


class ConfigError(ValueError):
    """Raised when screenshot configuration or a locale selection is invalid."""


@dataclass(frozen=True)
class LocaleConfig:
    runtime: str
    storefront: str
    region: str

    @property
    def apple_locale(self) -> str:
        base = self.runtime.replace("-", "_")
        suffix = f"_{self.region}"
        return base if base.endswith(suffix) else f"{base}{suffix}"


@dataclass(frozen=True)
class DeviceConfig:
    name: str
    width: int
    height: int
    orientation: str


@dataclass(frozen=True)
class ScreenshotConfig:
    source_locale: str
    active_locales: tuple[str, ...]
    locales: tuple[LocaleConfig, ...]
    devices: tuple[DeviceConfig, ...]
    shots: tuple[str, ...]

    @property
    def locales_by_runtime(self) -> dict[str, LocaleConfig]:
        return {locale.runtime: locale for locale in self.locales}


def _nonempty_string(value: object, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ConfigError(f"{field} must be a non-empty string")
    return value


def load_config(path: Path = CONFIG_PATH) -> ScreenshotConfig:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise ConfigError(f"cannot read screenshot config at {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ConfigError(f"invalid JSON in {path}: {exc}") from exc

    if raw.get("schema_version") != 1:
        raise ConfigError("screenshot config schema_version must be 1")

    locale_rows = raw.get("locales")
    if not isinstance(locale_rows, list) or not locale_rows:
        raise ConfigError("locales must be a non-empty array")
    locales = tuple(
        LocaleConfig(
            runtime=_nonempty_string(row.get("runtime"), "locale.runtime"),
            storefront=_nonempty_string(row.get("storefront"), "locale.storefront"),
            region=_nonempty_string(row.get("region"), "locale.region"),
        )
        for row in locale_rows
        if isinstance(row, dict)
    )
    if len(locales) != len(locale_rows):
        raise ConfigError("every locales entry must be an object")

    runtimes = [locale.runtime for locale in locales]
    storefronts = [locale.storefront for locale in locales]
    if len(set(runtimes)) != len(runtimes):
        raise ConfigError("runtime locale codes must be unique")
    if len(set(storefronts)) != len(storefronts):
        raise ConfigError("storefront locale codes must be unique")
    for locale in locales:
        if not re.fullmatch(r"[A-Za-z]{2,3}(?:-[A-Za-z]{2,4})?", locale.runtime):
            raise ConfigError(f"invalid runtime locale code: {locale.runtime}")
        if not re.fullmatch(r"[A-Za-z]{2,3}(?:-[A-Za-z]{2,4})?", locale.storefront):
            raise ConfigError(f"invalid storefront locale code: {locale.storefront}")
        if not re.fullmatch(r"[A-Z]{2}", locale.region):
            raise ConfigError(f"invalid region code for {locale.runtime}: {locale.region}")

    active_raw = raw.get("active_locales")
    if not isinstance(active_raw, list) or not active_raw:
        raise ConfigError("active_locales must be a non-empty array")
    active = tuple(_nonempty_string(value, "active_locales[]") for value in active_raw)
    if len(set(active)) != len(active):
        raise ConfigError("active_locales must not contain duplicates")
    unknown_active = [locale for locale in active if locale not in runtimes]
    if unknown_active:
        raise ConfigError(f"active_locales contains unknown runtime code(s): {', '.join(unknown_active)}")

    device_rows = raw.get("devices")
    if not isinstance(device_rows, list) or not device_rows:
        raise ConfigError("devices must be a non-empty array")
    devices: list[DeviceConfig] = []
    for row in device_rows:
        if not isinstance(row, dict):
            raise ConfigError("every devices entry must be an object")
        width, height = row.get("width"), row.get("height")
        if not isinstance(width, int) or not isinstance(height, int) or width <= 0 or height <= 0:
            raise ConfigError("device width and height must be positive integers")
        orientation = _nonempty_string(row.get("orientation"), "device.orientation")
        if orientation not in {"portrait", "landscape"}:
            raise ConfigError("device.orientation must be portrait or landscape")
        if orientation == "portrait" and width >= height:
            raise ConfigError("portrait device dimensions must have width < height")
        if orientation == "landscape" and width <= height:
            raise ConfigError("landscape device dimensions must have width > height")
        devices.append(DeviceConfig(_nonempty_string(row.get("name"), "device.name"), width, height, orientation))

    shots_raw = raw.get("shots")
    if not isinstance(shots_raw, list) or not shots_raw:
        raise ConfigError("shots must be a non-empty array")
    shots = tuple(_nonempty_string(value, "shots[]") for value in shots_raw)
    if len(set(shots)) != len(shots):
        raise ConfigError("shots must not contain duplicates")
    if any(not re.fullmatch(r"[0-9]{2}_[a-z0-9_]+", shot) for shot in shots):
        raise ConfigError("shot names must look like 01_checklists")

    source = _nonempty_string(raw.get("source_locale"), "source_locale")
    if source not in runtimes:
        raise ConfigError("source_locale must have a locales entry")

    return ScreenshotConfig(source, active, locales, tuple(devices), shots)


def parse_locale_args(values: Iterable[str] | None, config: ScreenshotConfig) -> tuple[str, ...]:
    """Resolve repeatable/comma-separated runtime locales, defaulting to active_locales."""
    requested = []
    for value in values or []:
        requested.extend(part.strip() for part in value.split(",") if part.strip())
    if not requested:
        return config.active_locales
    deduped = tuple(dict.fromkeys(requested))
    unknown = [locale for locale in deduped if locale not in config.locales_by_runtime]
    if unknown:
        raise ConfigError(f"unknown runtime locale(s): {', '.join(unknown)}")
    inactive = [locale for locale in deduped if locale not in config.active_locales]
    if inactive:
        raise ConfigError(
            "inactive runtime locale(s): "
            f"{', '.join(inactive)}; enable them in screenshot-config.json first"
        )
    return deduped


def validate_run_id(run_id: str) -> str:
    if not RUN_ID_PATTERN.fullmatch(run_id):
        raise ConfigError("run id must use 1-80 ASCII letters, numbers, dot, underscore, or hyphen")
    return run_id


def repo_device_name(base_name: str, repo_root: Path = REPO_ROOT) -> str:
    digest = hashlib.sha1(str(repo_root.resolve()).encode("utf-8")).hexdigest()[:8]
    return f"{base_name} Screenshots [{digest}]"


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def config_sha256(path: Path = CONFIG_PATH) -> str:
    return file_sha256(path)
