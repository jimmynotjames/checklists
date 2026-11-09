"""Parse a `/ci ...` PR comment into ci.yml's workflow_dispatch inputs.

Run by .github/workflows/ci-command.yml with the comment in $COMMENT_BODY. Writes to
$GITHUB_OUTPUT (or stdout without it):
  action=run|help|error|ignore
  only=<comma list of ci.yml selections, empty for the default gates + build>
  tests=none|unit|ui
  error=<the unknown words, for the usage reply>
`--usage` prints the usage reply instead.
"""

from __future__ import annotations

import os
import re
import sys
from dataclasses import dataclass

GATES = ("lint", "secrets", "large-files", "i18n")
SELECTIONS = (*GATES, "build")  # ci.yml's `only` vocabulary, in job order
TEST_LEVELS = ("none", "unit", "ui")  # each level includes the ones before it

USAGE = """\
**`/ci` usage** — the words after `/ci` on the first line combine:

| Word | Runs |
|---|---|
| *(none)* | all four gates + build, no tests |
| `lint` `secrets` `large-files` `i18n` | that gate |
| `gates` | all four gates |
| `build` | macOS compile check |
| `unit` | build with unit tests |
| `ui` | build with unit then UI tests |
| `all` | all gates + build with unit then UI tests |
| `help` | this message |

Named tests run only the build job unless gates are named too, e.g. `/ci gates unit`.
Only the repo owner's comments start runs."""

_COMMAND = re.compile(r"^/ci(?:\s+(?P<args>.*))?$", re.IGNORECASE)


@dataclass(frozen=True)
class Command:
    action: str  # run | help | error | ignore
    only: str = ""
    tests: str = "none"
    error: str = ""


def parse(body: str) -> Command:
    first_line = body.strip().splitlines()[0].strip() if body.strip() else ""
    match = _COMMAND.match(first_line)
    if not match:
        return Command("ignore")
    words = [w for w in re.split(r"[\s,]+", (match.group("args") or "").lower()) if w]
    if not words:
        return Command("run")  # empty `only` is ci.yml's default: gates + build

    selected: set[str] = set()
    tests = "none"
    unknown: list[str] = []
    wants_help = False
    for word in words:
        if word == "help":
            wants_help = True
        elif word in SELECTIONS:
            selected.add(word)
        elif word == "gates":
            selected.update(GATES)
        elif word in ("unit", "ui"):
            selected.add("build")
            tests = max(tests, word, key=TEST_LEVELS.index)
        elif word == "all":
            selected.update(SELECTIONS)
            tests = "ui"
        else:
            unknown.append(word)

    if unknown:
        return Command("error", error=" ".join(unknown))
    if wants_help:
        return Command("help")
    return Command("run", only=",".join(s for s in SELECTIONS if s in selected), tests=tests)


def main(argv: list[str]) -> int:
    if argv[1:] == ["--usage"]:
        print(USAGE)
        return 0
    command = parse(os.environ.get("COMMENT_BODY", ""))
    lines = [f"{key}={getattr(command, key)}" for key in ("action", "only", "tests", "error")]
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
    else:
        print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
