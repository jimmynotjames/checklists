#!/usr/bin/env python3
"""Fail when a comment or doc points at something that no longer exists.

Four checks, all aimed at the drift the AGENTS.md "Writing style" rules exist to prevent:

1. Every `<doc>.md §Heading` pointer resolves to a real heading in that doc. The heading
   can be quoted (`AGENTS.md §"Lint policy"`) or bare (`analytics-spec.md §Consent`); a bare
   one resolves to the longest run of following words that matches a heading.
2. No numbered pointer (`§4.2`). Section numbers change when a doc is restructured.
3. Every code symbol written in backticks in `core-docs/` or AGENTS.md
   (`resize(in:)`, `ToastPresenter`, `Checklist.dragItems()`) still appears somewhere in the
   code, scripts, or build config.
4. Lines this branch adds to Swift, `core-docs/`, or AGENTS.md carry no history markers
   ("previously", "since #N", "once #N lands", ...). Git is the record.

Checks 1–3 are repo-wide: a heading rename or a deleted method breaks pointers in files the
branch never touched. Check 4 looks only at added lines, like the lint policy.

Usage:
  python3 scripts/check_doc_pointers.py          # exit 1 on any hit
  python3 scripts/check_doc_pointers.py --json   # machine-readable
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

# Text files whose pointers are checked.
POINTER_SUFFIXES = {".swift", ".md", ".py", ".sh", ".yml", ".yaml", ".toml", ".template",
                    ".xcprivacy", ".txt"}
POINTER_NAMES = {"Makefile", ".swiftlint.yml", ".swiftformat", ".gitleaks.toml"}
EXCLUDED_PARTS = {"DesignExplorations"}
EXCLUDED_FILES = {"SnapshotHelper.swift", "TRADEMARK.md", "LICENSE", "NOTICE"}
# Generated or third-party text that quotes other people's section numbers.
EXCLUDED_PREFIXES = ("fastlane/metadata/", "scripts/tests/")

# Docs whose backticked symbols must exist in the code.
SYMBOL_DOCS = ("AGENTS.md", "core-docs/")
# Where a symbol may legitimately live.
SYMBOL_CORPUS_SUFFIXES = {".swift", ".py", ".sh", ".rb", ".xcconfig", ".plist", ".pbxproj",
                          ".entitlements", ".xcprivacy", ".yml", ".template", ".xcscheme"}
SYMBOL_CORPUS_NAMES = {"Makefile", "Fastfile", "Snapfile", "Appfile", ".swiftlint.yml",
                       ".swiftformat"}
# Platform and framework names that docs discuss but this repo never spells out in code.
# Add here only a name that is genuinely external; a name of ours that fails the check is
# a stale doc, not a candidate for this list.
EXTERNAL_SYMBOLS = {
    "UIApplicationDelegate", "SceneDelegate", "UIApplicationDelegateAdaptor",
    "NSUbiquitousKeyValueStore", "CKContainer", "CKException", "UITableViewController",
    "NSPersistentCloudKitContainer", "ATTrackingManager", "IDFV", "IDFA",
    "OSLog", "XCUIApplication", "XCTestCase", "NavigationStack", "LocalizedStringKey",
    "LocalizedStringResource", "UIDragItem", "NSItemProvider", "ModelConfiguration",
    "SwiftData", "CloudKit", "RealmSwift", "SwiftUI", "UIKit", "XCTest",
    # Accessibility APIs the spec records as not yet adopted.
    "isReduceTransparency", "isBoldTextEnabled", "shouldDifferentiateWithoutColor",
    "accessibilityViewIsModal", "adjustsFontForContentSizeCategory", "UIDragInteraction",
    # Mixpanel SDK internals and options the spec explains.
    "AutomaticProperties", "useUniqueDistinctId", "encryptionKey",
    # Info.plist keys and file-protection levels the docs say are deliberately absent.
    "ITSEncryptionExportComplianceCode", "NSFileProtectionComplete",
    "NSFileProtectionCompleteUntilFirstUserAuthentication", "InfoPlist",
}
# `Name.ext` in backticks is a file reference: it must be a tracked file, not a symbol.
FILE_EXTENSIONS = {"swift", "md", "py", "sh", "xcstrings", "xcprivacy", "plist", "yml",
                   "json", "xcconfig", "entitlements", "txt", "rb"}

HISTORY_SCOPES = ("checklists/", "core-docs/", "AGENTS.md")
HISTORY_PATTERNS = [
    (re.compile(r"\bpreviously\b", re.I), '"previously"'),
    (re.compile(r"\bformerly\b", re.I), '"formerly"'),
    (re.compile(r"\bused to be\b", re.I), '"used to be"'),
    (re.compile(r"\bwas tried\b", re.I), '"was tried"'),
    (re.compile(r"\bsince #\d+", re.I), '"since #N"'),
    (re.compile(r"\bonce #\d+ (?:lands|merges|ships)\b", re.I), '"once #N lands"'),
    (re.compile(r"\b(?:an )?earlier (?:version|draft)\b", re.I), '"an earlier version/draft"'),
]
# Naming the sibling repo is how AGENTS.md "Naming" introduces it; in code it is provenance.
SIBLING_PATTERN = (re.compile(r"simple-recurring-budgets"), "comparison to simple-recurring-budgets")

POINTER = re.compile(r"(?P<doc>[\w./-]+\.md)`?\s*§")
NUMBERED = re.compile(r"§\s*\d")
# Joins a comment or blockquote that wraps mid-pointer: `§"What gates a` / `// merge"`.
CONTINUATION = re.compile(r"\n[ \t]*(?:///?|#|\*|>)?[ \t]*")
BACKTICK = re.compile(r"`([^`\n]+)`")
# `Type`, `Type.member`, `member()`, `resize(in:)` — but not `snake_case`, paths, or values.
SYMBOL_SHAPE = re.compile(r"^([A-Za-z_]\w*)(?:\.([A-Za-z_]\w*))?(\([\w:]*\))?$")


def tracked_files() -> list[str]:
    out = subprocess.run(["git", "ls-files"], cwd=REPO_ROOT, capture_output=True, text=True,
                         check=True).stdout
    return [line for line in out.splitlines() if line]


def excluded(path: str) -> bool:
    parts = Path(path).parts
    return (any(p in EXCLUDED_PARTS for p in parts) or Path(path).name in EXCLUDED_FILES
            or path.startswith(EXCLUDED_PREFIXES))


def normalize_heading(text: str) -> str:
    text = re.sub(r"[`*_]", "", text).strip().rstrip(":").strip()
    return re.sub(r"\s+", " ", text).lower()


def headings_of(path: Path) -> set[str]:
    found = set()
    in_fence = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("```"):
            in_fence = not in_fence
        elif not in_fence and re.match(r"#{1,6} ", line):
            found.add(normalize_heading(line.lstrip("#")))
    return found


def resolve_doc(name: str, md_files: list[str]) -> str | None:
    matches = [f for f in md_files if f == name or f.endswith("/" + name)]
    if len(matches) == 1:
        return matches[0]
    # `analytics-spec.md` and `core-docs/analytics-spec.md` both mean the core doc.
    core = [f for f in matches if f.startswith("core-docs/")]
    return core[0] if len(core) == 1 else None


def match_heading(rest: str, headings: set[str]) -> tuple[bool, str]:
    quoted = re.match(r'"([^"]+)"', rest)
    if quoted:
        target = quoted.group(1)
        return normalize_heading(target) in headings, target
    words = rest.split()
    for n in range(min(len(words), 10), 0, -1):
        candidate = " ".join(words[:n]).rstrip(".,;:)*`'\"")
        if normalize_heading(candidate) in headings:
            return True, candidate
    return False, " ".join(words[:4])


def check_pointers(files: list[str]) -> list[dict]:
    md_files = [f for f in files if f.endswith(".md")]
    heading_cache: dict[str, set[str]] = {}
    errors = []
    for rel in files:
        path = Path(rel)
        if excluded(rel) or not (path.suffix in POINTER_SUFFIXES or path.name in POINTER_NAMES):
            continue
        try:
            lines = (REPO_ROOT / rel).read_text(encoding="utf-8").splitlines()
        except (UnicodeDecodeError, FileNotFoundError):
            continue
        for idx, line in enumerate(lines):
            if "§" not in line:
                continue
            lineno = idx + 1
            if NUMBERED.search(line):
                errors.append({"file": rel, "line": lineno, "check": "numbered-pointer",
                               "message": "numbered § pointer; point at the heading name instead"})
            # A pointer can wrap onto the next comment line: `§"What gates a` / `// merge"`.
            following = CONTINUATION.sub(" ", "\n" + lines[idx + 1]) if idx + 1 < len(lines) else ""
            for m in POINTER.finditer(line):
                rest = line[m.end():] + following
                if re.match(r"\s*\d", rest):
                    continue  # reported above
                doc = resolve_doc(m.group("doc"), md_files)
                if doc is None:
                    errors.append({"file": rel, "line": lineno, "check": "unknown-doc",
                                   "message": f"`{m.group('doc')}` matches no single tracked doc"})
                    continue
                if doc not in heading_cache:
                    heading_cache[doc] = headings_of(REPO_ROOT / doc)
                ok, target = match_heading(rest.lstrip(), heading_cache[doc])
                if not ok:
                    errors.append({"file": rel, "line": lineno, "check": "dangling-pointer",
                                   "message": f"{doc} has no heading matching §{target!r}"})
    return errors


def symbol_corpus(files: list[str]) -> set[str]:
    words: set[str] = set()
    for rel in files:
        path = Path(rel)
        if any(p in EXCLUDED_PARTS for p in path.parts):
            continue
        if path.suffix in SYMBOL_CORPUS_SUFFIXES or path.name in SYMBOL_CORPUS_NAMES:
            try:
                words.update(re.findall(r"\w+", (REPO_ROOT / rel).read_text(encoding="utf-8")))
            except (UnicodeDecodeError, FileNotFoundError):
                continue
    return words


def looks_like_code_symbol(name: str) -> bool:
    # camelCase or PascalCase with at least one lowercase letter; excludes CONSTANTS,
    # snake_case event names, and plain words.
    return bool(re.search(r"[a-z]", name) and re.search(r"[A-Z]", name) and "_" not in name)


def check_symbols(files: list[str]) -> list[dict]:
    corpus = symbol_corpus(files)
    basenames = {Path(f).name for f in files}
    errors = []
    for rel in files:
        if not (rel.endswith(".md") and rel.startswith(SYMBOL_DOCS)):
            continue
        in_fence = False
        for lineno, line in enumerate((REPO_ROOT / rel).read_text(encoding="utf-8").splitlines(), 1):
            if line.startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for raw in BACKTICK.findall(line):
                m = SYMBOL_SHAPE.match(raw.strip())
                if not m:
                    continue
                if m.group(2) in FILE_EXTENSIONS and not m.group(3):
                    if raw.strip() not in basenames and m.group(1) not in EXTERNAL_SYMBOLS:
                        errors.append({"file": rel, "line": lineno, "check": "missing-file",
                                       "message": f"`{raw}` is not a tracked file"})
                    continue
                parts = [p for p in (m.group(1), m.group(2)) if p]
                if m.group(3):
                    # A call like `resize(in:)` names a function even without camelCase.
                    names = parts
                else:
                    names = [p for p in parts if looks_like_code_symbol(p)]
                for name in names:
                    if name in EXTERNAL_SYMBOLS or name in corpus:
                        continue
                    errors.append({"file": rel, "line": lineno, "check": "missing-symbol",
                                   "message": f"`{raw}`: `{name}` appears nowhere in the code"})
    return errors


def added_lines(base: str) -> list[tuple[str, int, str]]:
    def run(*args: str) -> str:
        return subprocess.run(["git", *args], cwd=REPO_ROOT, capture_output=True,
                              text=True).stdout

    diffs = []
    if run("rev-parse", "--verify", "--quiet", base).strip():
        diffs.append(run("diff", "-U0", "--diff-filter=d", f"{base}...HEAD"))
    diffs.append(run("diff", "-U0", "--diff-filter=d", "HEAD"))
    result = []
    for diff in diffs:
        current, lineno = None, 0
        for line in diff.splitlines():
            if line.startswith("+++ "):
                current = line[6:] if line.startswith("+++ b/") else None
            elif line.startswith("@@"):
                lineno = int(re.search(r"\+(\d+)", line).group(1))
            elif line.startswith("+") and current:
                result.append((current, lineno, line[1:]))
                lineno += 1
    for rel in run("ls-files", "--others", "--exclude-standard").splitlines():
        try:
            for lineno, line in enumerate((REPO_ROOT / rel).read_text(encoding="utf-8").splitlines(), 1):
                result.append((rel, lineno, line))
        except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
            continue
    return result


def check_history(base: str) -> list[dict]:
    errors = []
    seen = set()
    for rel, lineno, text in added_lines(base):
        if (rel, lineno) in seen or excluded(rel) or not rel.startswith(HISTORY_SCOPES):
            continue
        if not (rel.endswith(".swift") or rel.endswith(".md")):
            continue
        seen.add((rel, lineno))
        patterns = list(HISTORY_PATTERNS)
        if rel.endswith(".swift"):
            patterns.append(SIBLING_PATTERN)
        for pattern, label in patterns:
            if pattern.search(text):
                errors.append({"file": rel, "line": lineno, "check": "history-marker",
                               "message": f"{label} — describe the current state; git is the record"})
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--base", default="main", help="branch to diff against for check 4")
    args = parser.parse_args()

    files = tracked_files()
    errors = check_pointers(files) + check_symbols(files) + check_history(args.base)

    if args.json:
        print(json.dumps({"errors": errors}, indent=2))
    else:
        for e in errors:
            print(f"{e['file']}:{e['line']}: [{e['check']}] {e['message']}")
        if errors:
            print(f"\ncheck_doc_pointers: {len(errors)} problem(s). See AGENTS.md §\"Writing style\".",
                  file=sys.stderr)
        else:
            print("check_doc_pointers: ok")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
