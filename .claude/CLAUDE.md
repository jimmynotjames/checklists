# Claude Code agent instructions

Project-wide agent instructions live in [`AGENTS.md`](../AGENTS.md). Treat that file as
canonical for:

- Build and test procedure (`make gate`; tests are opt-in and not gated)
- The **`ARCHS=arm64` pin** — load-bearing, because the vendored Flurry static library's
  x86_64 slice is malformed and breaks the linker
- **Lint policy**: changed files only; repo-wide `make format` / `make lint` are manual
  escape hatches, never hooks or gates
- **Bash command hygiene** (`/tmp/`, `sed`, pushing to main, `nohup`) — enforced by
  `scripts/hooks/guard_bash_hygiene.sh`, registered in `.claude/settings.json`
- **What NOT to do**, especially machine-wide simulator destruction
- Known issues (hardcoded Flurry API key; Flurry x86_64 unbuildable)
