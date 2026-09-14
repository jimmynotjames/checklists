# Claude Code agent instructions

Project-wide agent instructions live in [`AGENTS.md`](../AGENTS.md). Treat that file as
canonical for:

- Build and test procedure (`make gate`; tests are opt-in and not gated)
- The **`ARCHS=arm64` pin** in `build.sh`/CI — a build-speed choice, no longer a correctness
  constraint (it was one until the Flurry SDK was removed)
- **Lint policy**: changed files only; repo-wide `make format` / `make lint` are manual
  escape hatches, never hooks or gates
- **Bash command hygiene** (`/tmp/`, `sed`, pushing to main, `nohup`) — enforced by
  `scripts/hooks/guard_bash_hygiene.sh`, registered in `.claude/settings.json`
- **What NOT to do**, especially machine-wide simulator destruction
- Known issues (the old Flurry API key still in git history; test targets don't link)

Analytics go through the `AnalyticsClient` protocol in `checklists/checklists/Analytics/`. The
Mixpanel SDK is connected; `ConsoleAnalyticsClient` is the fallback for test runs and for a fresh
clone with no token.
[`core-docs/analytics-spec.md`](../core-docs/analytics-spec.md) is canonical for analytics: the
event and property catalogs, the privacy contract, and the consent model. `core-docs/` holds
design docs that outlive a single change; `docs/` is the published GitHub Pages site, not a place
for internal docs.

[`core-docs/accessibility-spec.md`](../core-docs/accessibility-spec.md) is canonical for
accessibility status and conventions. Read and update it only if a change involved accessibility
work.
