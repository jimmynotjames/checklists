from __future__ import annotations

import json
import os
import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCREENSHOT_SCRIPTS = ROOT / "scripts" / "screenshot_content"
sys.path.insert(0, str(SCREENSHOT_SCRIPTS))

import capture_progress  # noqa: E402
import prepare_output  # noqa: E402
from config import (  # noqa: E402
    ConfigError,
    DeviceConfig,
    LocaleConfig,
    ScreenshotConfig,
    load_config,
    parse_locale_args,
)


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, *, alpha: bool = False) -> None:
    color_type = 6 if alpha else 2
    channels = 4 if alpha else 3
    pixel = b"\0" * channels
    raw = b"".join(b"\0" + pixel * width for _ in range(height))
    payload = (
        capture_progress.PNG_SIGNATURE
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(raw))
        + png_chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)


def seed(runtime: str, apple_locale: str) -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "locale": runtime,
        "primaryLocale": apple_locale,
        "checklists": [
            {
                "id": "C4EC1157-0000-4000-A000-000000000001",
                "name": "List",
                "items": [{"name": "Item", "isChecked": False}],
            }
        ],
    }


class ConfigTests(unittest.TestCase):
    def test_all_locale_mappings_are_self_contained(self) -> None:
        config = load_config()
        self.assertEqual(len(config.locales), 50)
        self.assertEqual(config.active_locales, ("en-US",))
        mappings = config.locales_by_runtime
        self.assertEqual((mappings["de"].storefront, mappings["de"].region, mappings["de"].apple_locale), ("de-DE", "DE", "de_DE"))
        self.assertEqual((mappings["nb"].storefront, mappings["nb"].apple_locale), ("no", "nb_NO"))
        self.assertEqual((mappings["zh-Hans"].storefront, mappings["zh-Hans"].apple_locale), ("zh-Hans", "zh_Hans_CN"))

    def test_explicit_inactive_locale_is_rejected(self) -> None:
        with self.assertRaisesRegex(ConfigError, "inactive runtime locale"):
            parse_locale_args(["de"], load_config())


class CaptureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.old_values = {
            "RUNS_DIR": capture_progress.RUNS_DIR,
            "SEEDS_DIR": capture_progress.SEEDS_DIR,
            "config_sha256": capture_progress.config_sha256,
            "capture_source_hashes": capture_progress.capture_source_hashes,
        }
        capture_progress.RUNS_DIR = self.root / "runs"
        capture_progress.SEEDS_DIR = self.root / "seeds"
        capture_progress.config_sha256 = lambda: "config-hash"
        capture_progress.capture_source_hashes = lambda: {"source": "source-hash"}
        prepare_output.REPO_ROOT = self.root

        self.config = ScreenshotConfig(
            source_locale="en-US",
            active_locales=("en-US", "de"),
            locales=(LocaleConfig("en-US", "en-US", "US"), LocaleConfig("de", "de-DE", "DE")),
            devices=(DeviceConfig("Test Phone", 2, 3, "portrait"),),
            shots=("01_checklists", "02_pre_trip"),
        )
        for locale in self.config.locales:
            path = capture_progress.SEEDS_DIR / f"{locale.runtime}.json"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(seed(locale.runtime, locale.apple_locale)), encoding="utf-8")

    def tearDown(self) -> None:
        for name, value in self.old_values.items():
            setattr(capture_progress, name, value)
        self.temporary.cleanup()

    def _write_capture(self, run_id: str, runtime: str, *, alpha: bool = False) -> None:
        manifest = capture_progress.load_manifest(run_id)
        device = manifest["devices"][0]
        for shot in manifest["shots"]:
            path = capture_progress.run_root(run_id) / "raw" / runtime / f"{device['capture_name']}-{shot}.png"
            write_png(path, 2, 3, alpha=alpha)

    def test_missing_files_and_xctest_receipt_are_both_required(self) -> None:
        capture_progress.begin_run("run-one", ("en-US",), self.config)
        status = capture_progress.capture_status("run-one", ("en-US",), self.config)
        self.assertEqual(status["pending"], ["en-US"])
        self.assertTrue(all(record["issue"] == "missing" for record in status["results"]["en-US"]["files"]))

        self._write_capture("run-one", "en-US")
        status = capture_progress.capture_status("run-one", ("en-US",), self.config)
        self.assertTrue(all(record["issue"] == "no successful XCTest receipt" for record in status["results"]["en-US"]["files"]))

        capture_progress.mark_success("run-one", "en-US", "Test Phone", self.config)
        self.assertEqual(capture_progress.capture_status("run-one", ("en-US",), self.config)["complete"], ["en-US"])

    def test_stale_and_alpha_pngs_are_rejected(self) -> None:
        capture_progress.begin_run("run-two", ("en-US",), self.config)
        self._write_capture("run-two", "en-US", alpha=True)
        status = capture_progress.capture_status("run-two", ("en-US",), self.config, require_success=False)
        self.assertTrue(all("alpha" in record["issue"] for record in status["results"]["en-US"]["files"]))

        self._write_capture("run-two", "en-US")
        started = capture_progress.load_manifest("run-two")["started_at_ns"]
        for path in (capture_progress.run_root("run-two") / "raw" / "en-US").glob("*.png"):
            os.utime(path, ns=(started - 1, started - 1))
        status = capture_progress.capture_status("run-two", ("en-US",), self.config, require_success=False)
        self.assertTrue(all(record["issue"] == "older than run manifest" for record in status["results"]["en-US"]["files"]))

    def test_subset_staging_preserves_other_good_raw_captures(self) -> None:
        capture_progress.begin_run("run-three", ("en-US", "de"), self.config)
        for runtime in ("en-US", "de"):
            self._write_capture("run-three", runtime)
            capture_progress.mark_success("run-three", runtime, "Test Phone", self.config)

        prepare_output.load_config = lambda: self.config
        output, report, review = prepare_output.prepare_output("run-three", ("en-US",))
        self.assertTrue((output / "en-US" / "Test Phone-01_checklists.png").is_file())
        self.assertFalse((output / "de-DE").exists())
        self.assertTrue((capture_progress.run_root("run-three") / "raw" / "de").is_dir())
        self.assertTrue(report.is_file())
        self.assertTrue(review.is_file())


if __name__ == "__main__":
    unittest.main()
