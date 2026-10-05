#!/usr/bin/env python3
"""Fail when a comment or doc points at something that no longer exists.

Four checks, all aimed at the drift the AGENTS.md "Writing style" rules exist to prevent:

1. Every `<doc>.md §Heading` pointer resolves to a real heading in that doc, including
   chained ones (`analytics-spec.md §Event catalog / §Property catalog`). Quote the heading
   (`AGENTS.md §"Lint policy"`) for an exact match; a bare one resolves to the longest run of
   following words that is a heading, so `§Consent` passes wherever a Consent heading exists.
2. No numbered pointer (a section sign followed by a digit). Section numbers change when a doc
   is restructured.
3. Every code symbol or file name written in backticks in `core-docs/` or AGENTS.md
   (`resize(in:)`, `ToastPresenter`, `Checklist.dragItems()`, `SettingsView.swift`) still exists
   in the code, scripts, or build config. Swift comments don't count as code: a name that survives
   only in another stale Swift comment still fails.
4. Lines this branch adds under `checklists/` or `core-docs/`, or to AGENTS.md, carry no history
   markers ("since #N", "once #N lands", "used to be", ...). Git is the record.

Checks 1–3 are repo-wide: a heading rename or a deleted method breaks pointers in files the
branch never touched. Check 4 looks only at the lines this branch adds, so existing text never
fails it; it needs the base branch (or `origin/<base>`) and warns when neither exists.

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
SELF = {"scripts/check_doc_pointers.py", "scripts/tests/test_check_doc_pointers.py"}

# Text files whose pointers are checked.
POINTER_SUFFIXES = {".swift", ".md", ".py", ".sh", ".yml", ".yaml", ".toml", ".template",
                    ".xcprivacy", ".txt"}
POINTER_NAMES = {"Makefile", ".swiftlint.yml", ".swiftformat", ".gitleaks.toml"}
EXCLUDED_PARTS = {"DesignExplorations"}
EXCLUDED_FILES = {"SnapshotHelper.swift", "TRADEMARK.md", "LICENSE", "NOTICE"}
# Generated listing copy, and test fixtures that are broken on purpose.
EXCLUDED_PREFIXES = ("fastlane/metadata/", "scripts/tests/")

# Docs whose backticked symbols must exist in the code.
SYMBOL_DOCS = ("AGENTS.md", "core-docs/")
# Where a symbol may legitimately live.
SYMBOL_CORPUS_SUFFIXES = {".swift", ".py", ".sh", ".rb", ".xcconfig", ".plist", ".pbxproj",
                          ".entitlements", ".xcprivacy", ".yml", ".template", ".xcscheme"}
SYMBOL_CORPUS_NAMES = {"Makefile", "Fastfile", "Snapfile", "Appfile", ".swiftlint.yml",
                       ".swiftformat"}
# Names the docs discuss that this repo's code never spells out. Add only a name that is
# genuinely external; a name of ours that fails the check is a stale doc, not a candidate here.
EXTERNAL_SYMBOLS = {
    # Accessibility APIs the spec records as not yet adopted.
    "isReduceTransparency", "isBoldTextEnabled", "shouldDifferentiateWithoutColor",
    "accessibilityViewIsModal", "adjustsFontForContentSizeCategory", "UIDragInteraction",
    # Mixpanel SDK internals and options the spec explains.
    "AutomaticProperties", "useUniqueDistinctId", "encryptionKey",
    # Info.plist keys, file-protection levels, and files the docs say are deliberately absent.
    "ITSEncryptionExportComplianceCode", "NSFileProtectionComplete",
    "NSFileProtectionCompleteUntilFirstUserAuthentication", "InfoPlist",
    # Apple's logging framework (the code imports `os`), and the next schema's name as an example.
    "OSLog", "SchemaV2",
    # Xcode MCP server tools and arguments AGENTS.md §"Xcode MCP" steers agents through.
    "workspaceIdentifier", "deviceIdentifier", "RunAllTests", "RunSomeTests", "RunProject",
    "XcodeSwitchRunDestination", "XcodeOpenWorkspace", "DeviceInteractionInstallAndRun",
    "DeviceInteractionSynthesize",
    # The XCUITest error AGENTS.md §"The software keyboard" says to escalate.
    "kAXErrorCannotComplete",
}
# `Name.ext` in backticks is a file reference: it must be a tracked file, not a symbol.
FILE_EXTENSIONS = {"swift", "md", "py", "sh", "xcstrings", "xcprivacy", "plist", "yml",
                   "json", "xcconfig", "entitlements", "txt", "rb"}

HISTORY_SCOPES = ("checklists/", "core-docs/", "AGENTS.md")
# Phrases that only ever narrate the past. Words with a current-state sense ("previously
# selected", "was tried and failed") are left to the reviewer's deletable-prose check.
HISTORY_PATTERNS = [
    (re.compile(r"\bformerly\b", re.I), '"formerly"'),
    (re.compile(r"\bused to be\b", re.I), '"used to be"'),
    (re.compile(r"\bwas tried first\b|\btried and reverted\b", re.I), '"was tried first"'),
    (re.compile(r"\bsince #\d+", re.I), '"since #N"'),
    (re.compile(r"\bonce #\d+ (?:lands|merges|ships)\b", re.I), '"once #N lands"'),
    (re.compile(r"\b(?:an )?earlier (?:version|draft)\b", re.I), '"an earlier version/draft"'),
]
# Naming the sibling repo is how AGENTS.md "Naming" introduces it; in code it is provenance.
SIBLING_PATTERN = (re.compile(r"simple-recurring-budgets"), "comparison to simple-recurring-budgets")

# `doc.md §`, `` `doc.md` § ``, `[doc.md](doc.md) §`.
POINTER = re.compile(r"(?P<doc>[\w./-]+\.md)[`)\]]*\s*§")
# A further `§Heading` in the same doc: `§Event catalog / §Property catalog`.
CHAINED = re.compile(r"\s*(?:/|,|and|or)\s*§")
NUMBERED = re.compile(r"§\s*\d")
# Joins a comment or blockquote that wraps mid-pointer: `§"What gates a` / `// merge"`.
CONTINUATION = re.compile(r"\n[ \t]*(?:///?|#|\*|>)?[ \t]*")
FOLLOWING_LINES = 3
BACKTICK = re.compile(r"`([^`\n]+)`")
# `Type`, `Type.member`, `member()`, `resize(in:)` — but not `snake_case`, paths, or values.
SYMBOL_SHAPE = re.compile(r"^([A-Za-z_]\w*)(?:\.([A-Za-z_]\w*))?(\([\w:]*\))?$")
SWIFT_LINE_COMMENT = re.compile(r"(^|\s)//.*$", re.M)
SWIFT_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)


def tracked_files() -> list[str]:
    out = subprocess.run(["git", "ls-files"], cwd=REPO_ROOT, capture_output=True, text=True,
                         check=True).stdout
    return [line for line in out.splitlines() if line]


def read(rel: str) -> str | None:
    try:
        return (REPO_ROOT / rel).read_text(encoding="utf-8")
    except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
        return None


def excluded(path: str) -> bool:
    parts = Path(path).parts
    return (any(p in EXCLUDED_PARTS for p in parts) or Path(path).name in EXCLUDED_FILES
            or path.startswith(EXCLUDED_PREFIXES) or path in SELF)


def normalize_heading(text: str) -> str:
    text = re.sub(r"[`*_]", "", text).strip().rstrip(":").strip()
    return re.sub(r"\s+", " ", text).lower()


def headings_of(rel: str) -> set[str]:
    found = set()
    in_fence = False
    for line in (read(rel) or "").splitlines():
        if line.startswith("```"):
            in_fence = not in_fence
        elif not in_fence and re.match(r"#{1,6} ", line):
            found.add(normalize_heading(line.lstrip("#")))
    return found


def resolve_doc(name: str, md_files: list[str]) -> str | None:
    name = re.sub(r"^(?:\.\.?/)+", "", name)
    matches = [f for f in md_files if f == name or f.endswith("/" + name)]
    if len(matches) == 1:
        return matches[0]
    # `analytics-spec.md` and `core-docs/analytics-spec.md` both mean the core doc.
    core = [f for f in matches if f.startswith("core-docs/")]
    return core[0] if len(core) == 1 else None


def match_heading(rest: str, headings: set[str]) -> tuple[bool, str, int]:
    """Whether `rest` (the text after a §) starts with a heading; the target; its length."""
    rest = rest.replace('\\"', '"')
    quoted = re.match(r'"([^"]+)"', rest)
    if quoted:
        target = quoted.group(1)
        return normalize_heading(target) in headings, target, quoted.end()
    words = list(re.finditer(r"\S+", rest))
    for n in range(min(len(words), 10), 0, -1):
        candidate = rest[:words[n - 1].end()].rstrip(".,;:)*`'\"")
        if normalize_heading(candidate) in headings:
            return True, candidate, len(candidate)
    return False, " ".join(w.group() for w in words[:4]), 0


def check_pointers(files: list[str]) -> list[dict]:
    md_files = [f for f in files if f.endswith(".md")]
    heading_cache: dict[str, set[str]] = {}
    errors = []
    for rel in files:
        path = Path(rel)
        if excluded(rel) or not (path.suffix in POINTER_SUFFIXES or path.name in POINTER_NAMES):
            continue
        text = read(rel)
        if text is None:
            continue
        lines = text.splitlines()
        for idx, line in enumerate(lines):
            if "§" not in line:
                continue
            lineno = idx + 1
            if NUMBERED.search(line):
                errors.append({"file": rel, "line": lineno, "check": "numbered-pointer",
                               "message": "numbered § pointer; point at the heading name instead"})
            following = "".join(CONTINUATION.sub(" ", "\n" + nxt)
                                for nxt in lines[idx + 1: idx + 1 + FOLLOWING_LINES])
            for m in POINTER.finditer(line):
                doc = resolve_doc(m.group("doc"), md_files)
                if doc is None:
                    errors.append({"file": rel, "line": lineno, "check": "unknown-doc",
                                   "message": f"`{m.group('doc')}` matches no single tracked doc"})
                    continue
                if doc not in heading_cache:
                    heading_cache[doc] = headings_of(doc)
                rest = line[m.end():] + following
                while True:
                    if re.match(r"\s*\d", rest):
                        break  # reported above
                    rest = rest.lstrip()
                    ok, target, used = match_heading(rest, heading_cache[doc])
                    if not ok:
                        errors.append({"file": rel, "line": lineno, "check": "dangling-pointer",
                                       "message": f"{doc} has no heading matching §{target!r}"})
                        break
                    chained = CHAINED.match(rest[used:])
                    if not chained:
                        break
                    rest = rest[used + chained.end():]
    return errors


def symbol_corpus(files: list[str]) -> set[str]:
    words: set[str] = set()
    for rel in files:
        path = Path(rel)
        if any(p in EXCLUDED_PARTS for p in path.parts) or rel in SELF:
            continue
        if not (path.suffix in SYMBOL_CORPUS_SUFFIXES or path.name in SYMBOL_CORPUS_NAMES):
            continue
        text = read(rel)
        if text is None:
            continue
        if path.suffix == ".swift":
            text = SWIFT_LINE_COMMENT.sub(" ", SWIFT_BLOCK_COMMENT.sub(" ", text))
        words.update(re.findall(r"\w+", text))
    # A Swift file's name counts: docs name a file-level concept (`Reordering`) by it.
    words.update(Path(f).stem for f in files if f.endswith(".swift"))
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
        for lineno, line in enumerate((read(rel) or "").splitlines(), 1):
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
                # A call like `resize(in:)` names a function even without camelCase.
                names = parts if m.group(3) else [p for p in parts if looks_like_code_symbol(p)]
                for name in names:
                    if name in EXTERNAL_SYMBOLS or name in corpus:
                        continue
                    errors.append({"file": rel, "line": lineno, "check": "missing-symbol",
                                   "message": f"`{raw}`: `{name}` appears nowhere in the code"})
    return errors


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=REPO_ROOT, capture_output=True, text=True).stdout


def added_lines(base: str) -> tuple[list[tuple[str, int, str]], str | None]:
    """Lines added on this branch and in the working tree, plus a warning if the base is missing."""
    diffs, warning = [], None
    ref = next((r for r in (base, f"origin/{base}")
                if git("rev-parse", "--verify", "--quiet", r).strip()), None)
    if ref:
        diffs.append(git("diff", "-U0", "--diff-filter=d", f"{ref}...HEAD"))
    else:
        warning = (f"check_doc_pointers: neither `{base}` nor `origin/{base}` exists, so the "
                   "history-marker check covers uncommitted changes only.")
    diffs.append(git("diff", "-U0", "--diff-filter=d", "HEAD"))
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
    for rel in git("ls-files", "--others", "--exclude-standard").splitlines():
        for lineno, line in enumerate((read(rel) or "").splitlines(), 1):
            result.append((rel, lineno, line))
    return result, warning


def check_history(base: str) -> tuple[list[dict], str | None]:
    errors = []
    seen = set()
    lines, warning = added_lines(base)
    for rel, lineno, text in lines:
        # The same added line appears in both diffs when it is committed and then edited nearby.
        if (rel, text) in seen or excluded(rel) or not rel.startswith(HISTORY_SCOPES):
            continue
        if not (rel.endswith(".swift") or rel.endswith(".md")):
            continue
        seen.add((rel, text))
        patterns = list(HISTORY_PATTERNS)
        if rel.endswith(".swift"):
            patterns.append(SIBLING_PATTERN)
        for pattern, label in patterns:
            if pattern.search(text):
                errors.append({"file": rel, "line": lineno, "check": "history-marker",
                               "message": f"{label} — describe the current state; git is the record"})
    return errors, warning


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--base", default="main", help="branch to diff against for check 4")
    args = parser.parse_args()

    files = tracked_files()
    history, warning = check_history(args.base)
    errors = check_pointers(files) + check_symbols(files) + history
    if warning:
        print(warning, file=sys.stderr)

    if args.json:
        print(json.dumps({"errors": errors}, indent=2))
    else:
        for e in errors:
            print(f"{e['file']}:{e['line']}: [{e['check']}] {e['message']}")
        if errors:
            print(f'\ncheck_doc_pointers: {len(errors)} problem(s). See AGENTS.md §"Writing style".',
                  file=sys.stderr)
        else:
            print("check_doc_pointers: ok")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
