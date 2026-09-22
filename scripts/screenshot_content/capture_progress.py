#!/usr/bin/env python3
"""Start or inspect a screenshot run using verified PNG files as progress."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import struct
import sys
import time
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from check_content import validate_seed  # noqa: E402
from config import (  # noqa: E402
    CONFIG_PATH,
    REPO_ROOT,
    RUNS_DIR,
    SEEDS_DIR,
    ConfigError,
    ScreenshotConfig,
    config_sha256,
    file_sha256,
    load_config,
    parse_locale_args,
    repo_device_name,
    validate_run_id,
)

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
MANIFEST_NAME = "capture-run.json"


class CaptureError(ValueError):
    """Raised when a run or captured image cannot be trusted."""


def read_png(path: Path) -> tuple[int, int]:
    """Return dimensions for a well-formed, opaque PNG; reject any alpha channel."""
    try:
        with path.open("rb") as handle:
            if handle.read(8) != PNG_SIGNATURE:
                raise CaptureError("not a PNG")
            width = height = color_type = None
            has_transparency = False
            saw_end = False
            while True:
                length_bytes = handle.read(4)
                if not length_bytes:
                    break
                if len(length_bytes) != 4:
                    raise CaptureError("truncated PNG chunk length")
                length = struct.unpack(">I", length_bytes)[0]
                chunk_type = handle.read(4)
                payload = handle.read(length)
                crc_bytes = handle.read(4)
                if len(chunk_type) != 4 or len(payload) != length or len(crc_bytes) != 4:
                    raise CaptureError("truncated PNG chunk")
                expected_crc = struct.unpack(">I", crc_bytes)[0]
                actual_crc = zlib.crc32(chunk_type + payload) & 0xFFFFFFFF
                if actual_crc != expected_crc:
                    raise CaptureError(f"bad CRC in {chunk_type.decode('ascii', 'replace')} chunk")
                if chunk_type == b"IHDR":
                    if length != 13 or width is not None:
                        raise CaptureError("invalid IHDR chunk")
                    width, height, _depth, color_type, _compression, _filter, _interlace = struct.unpack(
                        ">IIBBBBB", payload
                    )
                elif chunk_type == b"tRNS":
                    has_transparency = True
                elif chunk_type == b"IEND":
                    saw_end = True
                    break
    except OSError as exc:
        raise CaptureError(str(exc)) from exc

    if width is None or height is None or color_type is None or not saw_end:
        raise CaptureError("missing required PNG chunks")
    if color_type in {4, 6} or has_transparency:
        raise CaptureError("PNG contains an alpha channel or transparency chunk")
    return width, height


def run_root(run_id: str) -> Path:
    return RUNS_DIR / validate_run_id(run_id)


def manifest_path(run_id: str) -> Path:
    return run_root(run_id) / MANIFEST_NAME


def capture_source_files() -> list[Path]:
    """Files whose behavior can affect pixels or capture integrity.

    Publication helpers and documentation are intentionally excluded: changing an
    upload implementation cannot make already-captured pixels stale.
    """
    fixed = [
        CONFIG_PATH,
        REPO_ROOT / "checklists" / "checklists.xcodeproj" / "project.pbxproj",
        REPO_ROOT / "fastlane" / "Snapfile",
        REPO_ROOT / "fastlane" / "lib" / "screenshot_capture.rb",
        REPO_ROOT / "scripts" / "_sim_sandbox.sh",
        REPO_ROOT / "scripts" / "resolve_booted_sim_udid.py",
        REPO_ROOT / "scripts" / "resolve_sim_spec.py",
        REPO_ROOT / "scripts" / "sim_retire_stale.py",
        Path(__file__).resolve(),
        Path(__file__).with_name("check_content.py"),
        Path(__file__).with_name("config.py"),
        Path(__file__).with_name("prepare_simulator.sh"),
    ]
    source_suffixes = {".swift", ".plist", ".json", ".png", ".jpg", ".storyboard", ".strings", ".xcstrings"}
    app_sources = sorted(
        path
        for path in (REPO_ROOT / "checklists" / "checklists").rglob("*")
        if path.is_file() and path.suffix in source_suffixes
    )
    ui_sources = [
        REPO_ROOT / "checklists" / "checklistsUITests" / "AppStoreScreenshots.swift",
        REPO_ROOT / "checklists" / "checklistsUITests" / "Info.plist",
        REPO_ROOT / "checklists" / "checklistsUITests" / "SnapshotHelper.swift",
        REPO_ROOT / "checklists" / "checklists.xcodeproj" / "xcshareddata" / "xcschemes" / "checklists.xcscheme",
    ]
    return [path for path in fixed + app_sources + ui_sources if path.is_file()]


def capture_source_hashes() -> dict[str, str]:
    return {
        str(path.relative_to(REPO_ROOT)): file_sha256(path)
        for path in capture_source_files()
    }


def aggregate_hash(hashes: dict[str, str]) -> str:
    digest = hashlib.sha256()
    for path, value in sorted(hashes.items()):
        digest.update(path.encode("utf-8"))
        digest.update(b"\0")
        digest.update(value.encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def _manifest_payload(run_id: str, locales: tuple[str, ...], config: ScreenshotConfig) -> dict[str, object]:
    seed_hashes = {runtime: file_sha256(SEEDS_DIR / f"{runtime}.json") for runtime in locales}
    source_hashes = capture_source_hashes()
    devices = [
        {
            "name": device.name,
            "capture_name": repo_device_name(device.name),
            "width": device.width,
            "height": device.height,
            "orientation": device.orientation,
        }
        for device in config.devices
    ]
    return {
        "schema_version": 1,
        "run_id": run_id,
        "started_at_ns": time.time_ns(),
        "config_path": str(CONFIG_PATH.relative_to(CONFIG_PATH.parents[1])),
        "config_sha256": config_sha256(),
        "locales": list(locales),
        "seed_sha256": seed_hashes,
        "capture_source_sha256": aggregate_hash(source_hashes),
        "capture_source_files": source_hashes,
        "devices": devices,
        "shots": list(config.shots),
    }


def begin_run(run_id: str, locales: tuple[str, ...], config: ScreenshotConfig) -> tuple[Path, bool]:
    root = run_root(run_id)
    manifest_file = root / MANIFEST_NAME
    if manifest_file.exists():
        manifest = load_manifest(run_id)
        requested = set(locales)
        recorded = set(manifest["locales"])
        if not requested.issubset(recorded):
            raise CaptureError("resume locales must be a subset of the run manifest")
        _validate_provenance(manifest, locales)
        return root, True

    issues: list[str] = []
    for runtime in locales:
        locale = config.locales_by_runtime[runtime]
        issues.extend(validate_seed(SEEDS_DIR / f"{runtime}.json", runtime, locale.apple_locale))
    if issues:
        raise CaptureError("invalid screenshot content:\n  " + "\n  ".join(issues))

    root.mkdir(parents=True, exist_ok=False)
    (root / "raw").mkdir()
    (root / "logs").mkdir()
    (root / "DerivedData").mkdir()
    payload = _manifest_payload(run_id, locales, config)
    manifest_file.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return root, False


def load_manifest(run_id: str) -> dict[str, object]:
    path = manifest_path(run_id)
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise CaptureError(f"run {run_id!r} does not exist") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise CaptureError(f"cannot read run manifest {path}: {exc}") from exc
    if not isinstance(manifest, dict) or manifest.get("schema_version") != 1:
        raise CaptureError(f"invalid run manifest: {path}")
    if manifest.get("run_id") != run_id:
        raise CaptureError(f"run manifest id does not match directory: {path}")
    return manifest


def _validate_provenance(manifest: dict[str, object], locales: tuple[str, ...]) -> None:
    if manifest.get("config_sha256") != config_sha256():
        raise CaptureError("screenshot config changed after this run began; captures are stale")
    current_sources = capture_source_hashes()
    if manifest.get("capture_source_sha256") != aggregate_hash(current_sources):
        raise CaptureError("app or capture source changed after this run began; captures are stale")
    seed_hashes = manifest.get("seed_sha256")
    if not isinstance(seed_hashes, dict):
        raise CaptureError("run manifest has no seed provenance")
    for runtime in locales:
        path = SEEDS_DIR / f"{runtime}.json"
        if seed_hashes.get(runtime) != file_sha256(path):
            raise CaptureError(f"{runtime} seed changed after this run began; captures are stale")


def _receipt_path(run_id: str, runtime: str, device_name: str) -> Path:
    device_key = hashlib.sha256(device_name.encode("utf-8")).hexdigest()[:16]
    return run_root(run_id) / "success" / runtime / f"{device_key}.json"


def capture_status(
    run_id: str,
    locales: tuple[str, ...],
    config: ScreenshotConfig,
    *,
    require_success: bool = True,
) -> dict[str, object]:
    manifest = load_manifest(run_id)
    recorded = set(manifest.get("locales", []))
    if not set(locales).issubset(recorded):
        raise CaptureError("status locales must be a subset of the run manifest")
    _validate_provenance(manifest, locales)

    started_at_ns = manifest.get("started_at_ns")
    if not isinstance(started_at_ns, int):
        raise CaptureError("run manifest has no valid started_at_ns")
    manifest_devices = manifest.get("devices")
    shots = manifest.get("shots")
    if not isinstance(manifest_devices, list) or not isinstance(shots, list):
        raise CaptureError("run manifest has invalid devices or shots")

    results: dict[str, dict[str, object]] = {}
    run_dir = run_root(run_id)
    for runtime in locales:
        files: list[dict[str, object]] = []
        for device in manifest_devices:
            if not isinstance(device, dict):
                raise CaptureError("run manifest has an invalid device")
            capture_name = str(device.get("capture_name", ""))
            receipt_file = _receipt_path(run_id, runtime, str(device.get("name", "")))
            receipt: dict[str, object] | None = None
            if receipt_file.is_file():
                try:
                    candidate = json.loads(receipt_file.read_text(encoding="utf-8"))
                    if isinstance(candidate, dict):
                        receipt = candidate
                except (OSError, json.JSONDecodeError):
                    receipt = None
            for shot in shots:
                filename = f"{capture_name}-{shot}.png"
                path = run_dir / "raw" / runtime / filename
                record: dict[str, object] = {
                    "path": str(path),
                    "device": device.get("name"),
                    "capture_device": capture_name,
                    "shot": shot,
                    "valid": False,
                }
                if not path.is_file():
                    record["issue"] = "missing"
                elif path.stat().st_mtime_ns < started_at_ns:
                    record["issue"] = "older than run manifest"
                else:
                    try:
                        dimensions = read_png(path)
                        expected = (device.get("width"), device.get("height"))
                        if dimensions != expected:
                            record["issue"] = f"dimensions {dimensions[0]}x{dimensions[1]}, expected {expected[0]}x{expected[1]}"
                        elif require_success and not receipt:
                            record["issue"] = "no successful XCTest receipt"
                        elif require_success and receipt.get("files", {}).get(filename) != file_sha256(path):
                            record["issue"] = "changed after successful XCTest receipt"
                        else:
                            record.update(
                                valid=True,
                                width=dimensions[0],
                                height=dimensions[1],
                                sha256=file_sha256(path),
                            )
                    except CaptureError as exc:
                        record["issue"] = str(exc)
                files.append(record)
        results[runtime] = {"complete": all(bool(record["valid"]) for record in files), "files": files}

    complete = [runtime for runtime, result in results.items() if result["complete"]]
    pending = [runtime for runtime, result in results.items() if not result["complete"]]
    return {
        "run_id": run_id,
        "capture_root": str(run_dir / "raw"),
        "locales": list(locales),
        "complete": complete,
        "pending": pending,
        "results": results,
    }


def mark_success(run_id: str, runtime: str, device_name: str, config: ScreenshotConfig) -> Path:
    manifest = load_manifest(run_id)
    if runtime not in manifest.get("locales", []):
        raise CaptureError(f"locale {runtime!r} is not part of run {run_id!r}")
    device = next(
        (
            row
            for row in manifest.get("devices", [])
            if isinstance(row, dict) and row.get("name") == device_name
        ),
        None,
    )
    if device is None:
        raise CaptureError(f"device {device_name!r} is not part of run {run_id!r}")
    status = capture_status(run_id, (runtime,), config, require_success=False)
    matching = [
        record
        for record in status["results"][runtime]["files"]
        if Path(record["path"]).name.startswith(f"{device['capture_name']}-")
    ]
    if not matching or not all(record["valid"] for record in matching):
        raise CaptureError(f"cannot mark {runtime}/{device_name} successful: capture files are invalid")
    receipt_path = _receipt_path(run_id, runtime, device_name)
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    receipt_path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "run_id": run_id,
                "runtime": runtime,
                "device": device_name,
                "completed_at_ns": time.time_ns(),
                "files": {Path(record["path"]).name: record["sha256"] for record in matching},
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    return receipt_path


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("begin", "status", "pending", "pending-targets"):
        subparser = subparsers.add_parser(command)
        subparser.add_argument("--run-id", required=True)
        subparser.add_argument("--locales", action="append", help="Repeatable or comma-separated active runtime locales")
        if command == "status":
            subparser.add_argument("--json", action="store_true")
    mark = subparsers.add_parser("mark-success")
    mark.add_argument("--run-id", required=True)
    mark.add_argument("--locale", required=True)
    mark.add_argument("--device", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        config = load_config()
        if args.command == "mark-success":
            locales = parse_locale_args([args.locale], config)
            receipt = mark_success(args.run_id, locales[0], args.device, config)
            print(receipt)
            return 0
        locales = parse_locale_args(args.locales, config)
        if args.command == "begin":
            root, resumed = begin_run(args.run_id, locales, config)
            print(json.dumps({"run_id": args.run_id, "run_root": str(root), "resumed": resumed}))
            return 0

        status = capture_status(args.run_id, locales, config)
        if args.command == "pending":
            print("\n".join(status["pending"]))
            return 0
        if args.command == "pending-targets":
            for runtime in locales:
                records = status["results"][runtime]["files"]
                for device in dict.fromkeys(record["device"] for record in records):
                    device_records = [record for record in records if record["device"] == device]
                    if not all(record["valid"] for record in device_records):
                        print(json.dumps({"runtime": runtime, "device": device}))
            return 0
        if args.json:
            print(json.dumps(status, indent=2, sort_keys=True))
        else:
            print(
                f"Screenshot capture {args.run_id}: {len(status['complete'])}/{len(locales)} "
                "locale(s) complete"
            )
            print(f"  complete: {' '.join(status['complete']) or '—'}")
            print(f"  pending:  {' '.join(status['pending']) or '—'}")
            for runtime in status["pending"]:
                for record in status["results"][runtime]["files"]:
                    if not record["valid"]:
                        print(f"  {runtime}: {record['path']}: {record['issue']}")
        return 0 if not status["pending"] else 1
    except (ConfigError, CaptureError, OSError) as exc:
        print(f"capture_progress: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
