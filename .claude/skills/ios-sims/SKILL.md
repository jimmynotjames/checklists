---
name: ios-sims
description: iOS simulator setup, management commands, UI_WORKERS concurrency tuning, retries, and the warm-up for this repo's test runs. Invoke when setting up a fresh clone, debugging simulator failures, adjusting parallelism, or reading a retry-only pass.
---

# iOS Simulator reference

AGENTS.md §"Simulator sandbox" and §"Simulator slots" are canonical; this is the quick reference.

## Per-checkout sandbox

Each checkout gets its own simulator, `iPhone 17 [<hash of the checkout's physical path>]`, in the default CoreSimulator device set. `scripts/_sim_sandbox.sh` (sourced by `scripts/_destination.sh`, in turn sourced by the test scripts) creates, boots and reuses it; you don't manage it by hand for a normal run.

- `SIMULATOR_NAME` picks another base device; `SIMULATOR_UDID` pins one and skips sandbox management.
- Every test script and `make sim-*` target but `sim-status` holds the checkout's lock (`.build/sim.lock`, `scripts/_sim_common.sh`), so two runs in one checkout queue. For parallel runs, use a worktree.
- DerivedData and result bundles are per checkout: `.build/sim/DerivedData`, `.build/sim/results/`.

## Management commands

```bash
make initialize-sims  # create and boot this checkout's simulator without building
make sim-status       # the device, the lock holder, and the checkout path
make sim-shutdown     # shut down this checkout's devices (sandbox, Screenshots, clones)
make sim-clean        # delete them all and remove .build/sim/
```

`make sim-clean` runs `scripts/sim_clean.py`, which only touches devices whose name carries this checkout's hash. A parallel UI run also deletes clones an interrupted run left behind (`sim_clean.py --clones-only`) before it starts.

## UI pass concurrency: the simulator pool, UI_WORKERS and retries

`scripts/_sim_concurrency.sh` decides how many simulators a test run uses; it is identical in checklists and simple-recurring-budgets. Unit and focused runs are always serial on one simulator.

**Pool on** (the maintainer's machine, where `~/dev/simulator-slots` exists): each run builds first, then takes slots from a machine-wide pool. The UI pass asks for `UI_WORKERS` slots (default 2), gets what is free (at least 1), and runs that many clones. `SIMULATOR_SLOTS_FEWER=N` leaves N free slots unused; `SIMULATOR_SLOTS_TIMEOUT=S` gives up after S seconds (exit 75). `make simulator-slots-status` shows who holds what.

**Pool off** (everyone else): the run prints a `simulator-slots: no shared pool` notice, takes nothing, and uses `UI_WORKERS` (default 1, serial):

| `UI_WORKERS` | UI pass flags | When to use |
| --- | --- | --- |
| unset or `1` | `-parallel-testing-enabled NO` (serial, 1 sim) | Lightest; the default without the pool. |
| `2` | `-parallel-testing-enabled YES -parallel-testing-worker-count 2 -maximum-parallel-testing-workers 2` | ≈16 GB Apple silicon with little else running. |
| `3` | same, with `3` | Only with headroom; RAM-heavy. |

Values outside 1–3 are clamped with a warning. The old names `SRB_SIM_MAX` and `SIMULATOR_WORKERS_WITHOUT_POOL` stop the run with "renamed to UI_WORKERS". Each booted simulator uses about 2–3 GB.

**Retries:** `UI_RETRY_ON_FAILURE=auto|1|0`. `auto` (default) retries a failed UI test once when 2+ clones run; `1` always retries (CI's shards); `0` never. A test that passed only on retry prints `PASSED-ON-RETRY: <test> <file:line> <message>` (on CI, a "UI test passed only on retry" warning). That is a flake: log it in `checklists/checklistsUITests/FLAKY_TESTS.md`. A genuine failure fails both attempts and prints `TEST-FAILED:` lines.

## Warm-up

XCUITest's IPC socket is unreliable until the device has hosted one app lifecycle. `make unit-tests` leaves the `.build/sim/warmed` sentinel; every boot clears it. A serial UI run (or a UI-target `make focused-tests`) on an unwarmed device first runs one small unit suite (`warm_up_if_needed`). A parallel run skips that: its clones boot fresh.

## Reproducing a CI-only UI failure

CI runs UI tests with animations off. Prefix `TEST_RUNNER_FORCE_ANIMATIONS=off`:

```bash
TEST_RUNNER_FORCE_ANIMATIONS=off make focused-tests ONLY=checklistsUITests/<Class>/<test> ITERATIONS=3
```
