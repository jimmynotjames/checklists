"""Shared utility for writing Localizable.xcstrings in Xcode's canonical format."""
from __future__ import annotations

import json
import re
from pathlib import Path

_RUN = re.compile(r"\d+|[A-Za-z]+|.")
# ICU's root collation order for ASCII punctuation and symbols, which is not ASCII order.
_PUNCTUATION = "_-,;:!?.'\"()[]{}@*/\\&#%`^+<=>|~$"


def xcode_key_order(key: str) -> tuple:
    """Sort key matching Xcode 27's order for the `strings` object: `localizedStandardCompare`.

    Digit runs compare by value, letters ignore case, punctuation sorts before digits and digits
    before letters. Ties go to lowercase first, then fewer leading zeros. Exact for keys made of
    ASCII letters, digits, `.` and `_` with digit runs under ~15 long; non-ASCII letters would sort
    as punctuation here but among letters in Xcode.
    """
    primary, case, zeros = [], [], []
    for run in _RUN.findall(key):
        if run.isdigit():
            primary.append((1, int(run), ""))
            zeros.append(len(run))
        elif run.isalpha():
            primary.append((2, 0, run.lower()))
            case.extend(char.isupper() for char in run)
        else:
            rank = _PUNCTUATION.find(run)
            primary.append((0, rank if rank >= 0 else len(_PUNCTUATION) + ord(run), ""))
    return primary, case, zeros


def _sorted_keys(value):
    if isinstance(value, dict):
        return {key: _sorted_keys(value[key]) for key in sorted(value)}
    if isinstance(value, list):
        return [_sorted_keys(item) for item in value]
    return value


def write_xcstrings(catalog: dict, path: Path) -> None:
    # Xcode's string catalog editor orders the `strings` keys with `localizedStandardCompare`
    # (`item2` before `item10`); every other object is in plain sorted order.
    ordered = _sorted_keys(catalog)
    ordered["strings"] = dict(sorted(ordered["strings"].items(), key=lambda item: xcode_key_order(item[0])))
    # Xcode serializes xcstrings with a space before colons ("key" : "value"). Set it as the
    # separator rather than replacing '": ' afterwards, which also matched an escaped quote
    # followed by a colon inside a string value.
    out = json.dumps(ordered, ensure_ascii=False, indent=2, separators=(",", " : "))
    # Xcode writes no trailing newline.
    path.write_text(out, encoding="utf-8")
