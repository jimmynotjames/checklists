#!/usr/bin/env python3
"""Copy verified captures into an exact storefront-coded upload staging tree."""

from __future__ import annotations

import argparse
import html
import json
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from capture_progress import CaptureError, capture_status, load_manifest, run_root  # noqa: E402
from config import ConfigError, REPO_ROOT, load_config, parse_locale_args  # noqa: E402

MARKER = ".screenshot-staging.json"
# A non-default output (an upload subset) carries its own report, so staging it never
# replaces the run's full review set.
STAGING_REPORT = "staging-report.json"


def _safe_output_path(path: Path, run_id: str) -> Path:
    resolved = path.resolve()
    allowed_roots = [(run_root(run_id)).resolve(), (REPO_ROOT / "tmp").resolve()]
    if not any(resolved != root and resolved.is_relative_to(root) for root in allowed_roots):
        raise CaptureError("output must be below this run directory or the repository tmp directory")
    return resolved


def _replaceable_output(path: Path, run_id: str) -> None:
    if not path.exists():
        return
    marker = path / MARKER
    try:
        data = json.loads(marker.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise CaptureError(f"refusing to replace unowned staging directory: {path}") from exc
    if data.get("run_id") != run_id:
        raise CaptureError(f"refusing to replace staging directory owned by another run: {path}")


def prepare_output(
    run_id: str,
    locales: tuple[str, ...],
    output: Path | None = None,
) -> tuple[Path, Path, Path | None]:
    config = load_config()
    status = capture_status(run_id, locales, config)
    if status["pending"]:
        raise CaptureError(f"cannot stage incomplete locale(s): {', '.join(status['pending'])}")

    default_target = (run_root(run_id) / "storefront").resolve()
    target = _safe_output_path(output or default_target, run_id)
    is_review_set = target == default_target
    _replaceable_output(target, run_id)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix=f".{target.name}-", dir=target.parent))
    report_files: list[dict[str, object]] = []
    try:
        manifest = load_manifest(run_id)
        devices = manifest["devices"]
        shots = manifest["shots"]
        raw_root = run_root(run_id) / "raw"
        for runtime in locales:
            locale = config.locales_by_runtime[runtime]
            destination_dir = temporary / locale.storefront
            destination_dir.mkdir()
            for device in devices:
                for shot in shots:
                    source_name = f"{device['capture_name']}-{shot}.png"
                    destination_name = f"{device['name']}-{shot}.png"
                    source = raw_root / runtime / source_name
                    destination = destination_dir / destination_name
                    shutil.copy2(source, destination)
                    result = next(
                        record
                        for record in status["results"][runtime]["files"]
                        if record["path"] == str(source)
                    )
                    report_files.append(
                        {
                            "runtime": runtime,
                            "storefront": locale.storefront,
                            "shot": shot,
                            "device": device["name"],
                            "width": result["width"],
                            "height": result["height"],
                            "sha256": result["sha256"],
                            "source": str(source),
                            "staged": str(target / locale.storefront / destination_name),
                        }
                    )
        (temporary / MARKER).write_text(
            json.dumps({"schema_version": 1, "run_id": run_id, "locales": list(locales)}, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        if target.exists():
            shutil.rmtree(target)
        os.replace(temporary, target)
    except BaseException:
        shutil.rmtree(temporary, ignore_errors=True)
        raise

    storefronts = [config.locales_by_runtime[runtime].storefront for runtime in locales]
    report = {
        "schema_version": 1,
        "run_id": run_id,
        "generated_at_ns": time.time_ns(),
        "locales": storefronts,
        "runtime_locales": list(locales),
        "storefront_locales": storefronts,
        "screenshots_path": str(target),
        "files": report_files,
    }
    if not is_review_set:
        report_path = target / STAGING_REPORT
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return target, report_path, None

    report_path = run_root(run_id) / "capture-report.json"
    review_path = run_root(run_id) / "review.html"
    sections = []
    for device in devices:
        cards = []
        for record in report_files:
            if record["device"] != device["name"]:
                continue
            image_url = Path(str(record["staged"])).resolve().as_uri()
            title = f"{record['storefront']} · {record['device']} · {record['shot']}"
            cards.append(
                "<figure><img src=\"{}\" alt=\"{}\"><figcaption>{}</figcaption></figure>".format(
                    html.escape(image_url, quote=True),
                    html.escape(title, quote=True),
                    html.escape(title),
                )
            )
        heading = f"{device['name']} · {device['width']}×{device['height']}"
        sections.append(f"<h2>{html.escape(heading)}</h2><main>{''.join(cards)}</main>")
    review_path.write_text(
        "<!doctype html><meta charset=\"utf-8\"><title>Screenshot review</title>"
        "<style>body{font:16px system-ui;margin:24px;background:#eee;color:#111}"
        "main{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:24px}"
        "figure{margin:0;background:white;padding:12px;border-radius:12px}"
        "img{display:block;width:100%;height:auto}figcaption{padding-top:10px}</style>"
        f"<h1>Screenshot run {html.escape(run_id)}</h1>{''.join(sections)}\n",
        encoding="utf-8",
    )
    report["review_page"] = str(review_path)
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return target, report_path, review_path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--locales", action="append", help="Repeatable or comma-separated active runtime locales")
    target = parser.add_mutually_exclusive_group()
    target.add_argument("--output", type=Path)
    target.add_argument("--upload", action="store_true", help="Stage into the run's upload/ folder")
    args = parser.parse_args(argv)
    try:
        config = load_config()
        locales = parse_locale_args(args.locales, config)
        destination = run_root(args.run_id) / "upload" if args.upload else args.output
        output, report, review = prepare_output(args.run_id, locales, destination)
        print(
            json.dumps(
                {
                    "output": str(output),
                    "screenshots_path": str(output),
                    "report": str(report),
                    "review_page": str(review) if review else None,
                    "locales": [config.locales_by_runtime[value].storefront for value in locales],
                }
            )
        )
        return 0
    except (ConfigError, CaptureError, OSError) as exc:
        print(f"prepare_output: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
