#!/usr/bin/env python3
"""A machine-wide pool of simulator slots shared by every repo that opts in.

A slot is one simulator actively running tests. The pool size lives in the state directory's
`max` file (default 4); booted-but-idle simulators don't take a slot. Repos opt in by vendoring
this directory and wrapping each test run in `hold`; repos that don't are invisible to the pool.

`hold` runs in the background next to the test run. It may first show a dialog offering to shut
down idle simulators, then flocks free slots and prints one line, `<granted> <run-id>`, and keeps
the locks until the process it watches exits or it is sent SIGTERM. The kernel releases a flock
when its holder dies, so a crashed run never leaves a slot taken.

Usage:
  simulator_slots.py hold --watch-pid PID --want N [--fewer N] [--label L] [--root R]
                         [--udid U] [--owns TEXT]
  simulator_slots.py result --run ID --rc RC   # record a run's exit code in runs.log
  simulator_slots.py status                    # pool, holders, booted simulators, recent runs
  simulator_slots.py preflight [--force]       # the idle-simulator dialog alone
  simulator_slots.py sync --into DIR [--master M]        # copy the master over a vendored copy
  simulator_slots.py sync-check --into DIR [--master M]  # exit 1 when the copy differs

Environment:
  SIMULATOR_SLOTS_FEWER      leave this many slots unused for this run (default 0)
  SIMULATOR_SLOTS_TIMEOUT    seconds `hold` waits for a slot before exiting 75 (0 = forever)
  SIMULATOR_SLOTS_PROMPT     0 skips the dialog
  SIMULATOR_SLOTS_STATE_DIR  state directory (default ~/.local/state/simulator-slots)
  SIMULATOR_SLOTS_MASTER     master copy (default ~/dev/simulator-slots)
"""

from __future__ import annotations

import argparse
import datetime
import fcntl
import filecmp
import json
import os
import plistlib
import re
import select
import shutil
import signal
import subprocess
import sys
import time
import uuid
from pathlib import Path

# Bump when the state directory's layout or locking changes. A copy speaking another protocol
# refuses to run rather than share a pool it would miscount.
PROTOCOL = 1
DEFAULT_MAX = 4
POLL_SEC = 2.0
REPORT_EVERY_SEC = 60.0
PROMPT_EVERY_SEC = 30 * 60
PROMPT_TIMEOUT_SEC = 60
EXIT_TIMEOUT = 75
EXIT_CONFIG = 78
SYNC_IGNORE = {".git", "__pycache__", ".DS_Store"}
CLONE_SET_NAME = "XCTestDevices"
BOOTSTRAP_RE = re.compile(r"(/\S.*?)/([0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12})/data/var/run/launchd_bootstrap\.plist")


class ConfigError(Exception):
    pass


def state_dir() -> Path:
    override = os.environ.get("SIMULATOR_SLOTS_STATE_DIR")
    return Path(override) if override else Path.home() / ".local" / "state" / "simulator-slots"


def master_dir() -> Path:
    override = os.environ.get("SIMULATOR_SLOTS_MASTER")
    return Path(override) if override else Path.home() / "dev" / "simulator-slots"


def now_iso() -> str:
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


# -- State directory ----------------------------------------------------------------------------


def prepare_state(directory: Path) -> int:
    """Create the state directory on first use, check its protocol, and return the pool size."""
    directory.mkdir(parents=True, exist_ok=True)
    protocol_file = directory / "protocol"
    if not protocol_file.exists():
        protocol_file.write_text(f"{PROTOCOL}\n", encoding="utf-8")
    found = protocol_file.read_text(encoding="utf-8").strip()
    if found != str(PROTOCOL):
        raise ConfigError(
            f"{protocol_file} says protocol {found}, this copy speaks {PROTOCOL}; "
            "sync this repo's copy from the master (make simulator-slots-sync)"
        )
    max_file = directory / "max"
    if not max_file.exists():
        max_file.write_text(f"{DEFAULT_MAX}\n", encoding="utf-8")
    raw = max_file.read_text(encoding="utf-8").strip()
    if not raw.isdigit() or int(raw) < 1:
        raise ConfigError(f"{max_file} must hold a positive integer, found {raw!r}")
    return int(raw)


def slot_path(directory: Path, index: int) -> Path:
    return directory / f"slot-{index}.lock"


# -- Holder records -----------------------------------------------------------------------------


def format_holder(fields: dict[str, str]) -> str:
    return "".join(f"{key}={value}\n" for key, value in fields.items())


def parse_holder(text: str) -> dict[str, str]:
    fields = {}
    for line in text.splitlines():
        key, sep, value = line.partition("=")
        if sep:
            fields[key] = value
    return fields


def describe(fields: dict[str, str]) -> str:
    if not fields.get("pid"):
        return "holder unknown"
    where = Path(fields.get("root", "?")).name
    return f"{fields.get('label', '?')} in {where} (pid {fields['pid']}, since {fields.get('started', '?')})"


def slot_holder(path: Path) -> dict[str, str] | None:
    """None when the slot is free, else its holder record (possibly empty)."""
    try:
        fd = os.open(path, os.O_RDONLY)
    except FileNotFoundError:
        return None
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_SH | fcntl.LOCK_NB)
        except BlockingIOError:
            return parse_holder(path.read_text(encoding="utf-8", errors="replace"))
        fcntl.flock(fd, fcntl.LOCK_UN)
        return None
    finally:
        os.close(fd)


def holders(directory: Path, size: int) -> list[dict[str, str] | None]:
    return [slot_holder(slot_path(directory, i)) for i in range(1, size + 1)]


# -- Acquisition --------------------------------------------------------------------------------


def grant_size(want: int, free: int, fewer: int) -> int:
    """Slots to take: as many as wanted, leaving `fewer` of the free ones unused; 0 means wait."""
    return max(0, min(want, free - fewer))


def try_take(directory: Path, size: int, want: int, fewer: int) -> list[int]:
    """Lock every free slot, keep the ones this run gets, release the rest. Returns kept fds."""
    with open(directory / "acquire.lock", "a") as gate:
        fcntl.flock(gate, fcntl.LOCK_EX)  # one acquirer counts at a time
        taken = []
        for index in range(1, size + 1):
            fd = os.open(slot_path(directory, index), os.O_RDWR | os.O_CREAT, 0o644)
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                os.close(fd)
                continue
            taken.append(fd)
        keep = grant_size(want, len(taken), fewer)
        for fd in taken[keep:]:
            os.close(fd)  # closing the only descriptor releases its flock
        return taken[:keep]


def record(fds: list[int], fields: dict[str, str]) -> None:
    text = format_holder(fields).encode("utf-8")
    for fd in fds:
        os.ftruncate(fd, 0)
        os.pwrite(fd, text, 0)


def waiting_message(directory: Path, size: int, fewer: int) -> str:
    lines = [f"simulator-slots: waiting for a slot (pool {size}, leaving {fewer} unused)"]
    for index, fields in enumerate(holders(directory, size), start=1):
        if fields is not None:
            lines.append(f"  slot {index}: {describe(fields)}")
    return "\n".join(lines)


def acquire(directory: Path, size: int, want: int, fewer: int, timeout: float) -> list[int] | None:
    start = time.monotonic()
    last_report = None
    while True:
        fds = try_take(directory, size, want, fewer)
        if fds:
            if last_report is not None:
                print(f"simulator-slots: got {len(fds)} after {time.monotonic() - start:.0f}s", file=sys.stderr)
            return fds
        now = time.monotonic()
        if timeout and now - start >= timeout:
            print(waiting_message(directory, size, fewer), file=sys.stderr)
            print(f"simulator-slots: gave up after {timeout:g}s (SIMULATOR_SLOTS_TIMEOUT)", file=sys.stderr)
            return None
        if last_report is None or now - last_report >= REPORT_EVERY_SEC:
            print(waiting_message(directory, size, fewer), file=sys.stderr)
            last_report = now
        time.sleep(POLL_SEC)


def wait_for_exit(pid: int) -> None:
    """Block until `pid` exits; returns at once if it is already gone."""
    queue = select.kqueue()
    event = select.kevent(pid, filter=select.KQ_FILTER_PROC, flags=select.KQ_EV_ADD, fflags=select.KQ_NOTE_EXIT)
    try:
        queue.control([event], 1, None)
    except ProcessLookupError:
        return
    finally:
        queue.close()


# -- Machine state ------------------------------------------------------------------------------


def swap_used_mb() -> float | None:
    out = subprocess.run(["sysctl", "-n", "vm.swapusage"], capture_output=True, text=True).stdout
    match = re.search(r"used = ([\d.]+)M", out)
    return float(match.group(1)) if match else None


def memory_free_percent() -> int | None:
    out = subprocess.run(["memory_pressure", "-Q"], capture_output=True, text=True).stdout
    match = re.search(r"free percentage: (\d+)%", out)
    return int(match.group(1)) if match else None


def process_table() -> list[tuple[int, int, str]]:
    out = subprocess.run(["ps", "-axo", "pid=,ppid=,command="], capture_output=True, text=True).stdout
    rows = []
    for line in out.splitlines():
        parts = line.split(None, 2)
        if len(parts) == 3 and parts[0].isdigit() and parts[1].isdigit():
            rows.append((int(parts[0]), int(parts[1]), parts[2]))
    return rows


def booted_simulators(rows: list[tuple[int, int, str]] | None = None) -> list[dict]:
    """Every booted simulator in any device set, found by its launchd_sim process."""
    rows = process_table() if rows is None else rows
    found = []
    for pid, _ppid, command in rows:
        if not command.split(" ", 1)[0].endswith("launchd_sim"):
            continue
        match = BOOTSTRAP_RE.search(command)
        if not match:
            continue
        device_set, udid = match.group(1), match.group(2)
        found.append({"pid": pid, "udid": udid, "set": device_set, "name": device_name(device_set, udid)})
    return found


def device_name(device_set: str, udid: str) -> str:
    try:
        with open(Path(device_set) / udid / "device.plist", "rb") as f:
            return plistlib.load(f).get("name", udid)
    except (OSError, plistlib.InvalidFileException):
        return udid


def set_label(device_set: str) -> str:
    if device_set.endswith(CLONE_SET_NAME):
        return "parallel-testing clone"
    if "Previews" in device_set:
        return "Xcode Previews"
    return ""


def tree_footprint_mb(root_pid: int, rows: list[tuple[int, int, str]]) -> float | None:
    children: dict[int, list[int]] = {}
    for pid, ppid, _command in rows:
        children.setdefault(ppid, []).append(pid)
    pids, stack = [], [root_pid]
    while stack:
        pid = stack.pop()
        pids.append(pid)
        stack.extend(children.get(pid, []))
    args = [arg for pid in pids for arg in ("-p", str(pid))]
    out = subprocess.run(["footprint", *args], capture_output=True, text=True).stdout
    match = re.search(r"Summary Footprint: ([\d.]+) (KB|MB|GB)", out)
    if not match:
        return None
    value = float(match.group(1))
    return value / 1024 if match.group(2) == "KB" else value * 1024 if match.group(2) == "GB" else value


def idle_simulators(
    booted: list[dict], held: list[dict[str, str] | None], mine: dict[str, str] | None = None
) -> list[dict]:
    """Booted simulators no run holds, and none of `mine` (the asking run's own devices).

    A run owns its --udid and every device whose name contains its --owns text. Unnamed clones
    count as held while any slot is, since some running run made them.
    """
    active = [fields for fields in held if fields is not None]
    owners = active + ([mine] if mine else [])
    udids = {fields.get("udid") for fields in owners if fields.get("udid")}
    tags = [fields["owns"] for fields in owners if fields.get("owns")]
    return [
        sim
        for sim in booted
        if sim["udid"] not in udids
        and not any(tag in sim["name"] for tag in tags)
        and not (active and sim["set"].endswith(CLONE_SET_NAME))
    ]


# -- The idle-simulator dialog ------------------------------------------------------------------


def applescript_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def gb(mb: float | None) -> str:
    return "?" if mb is None else f"{mb / 1024:.1f} GB"


def dialog_text(label: str, idle: list[dict], swap: float | None, free_pct: int | None) -> str:
    lines = [f"Before {label}: please close other memory-heavy apps.", "", "Idle simulators:"]
    for sim in idle:
        kind = set_label(sim["set"])
        lines.append(f"• {sim['name']}{f' ({kind})' if kind else ''}: {gb(sim.get('footprint_mb'))}")
    lines += ["", f"Swap used: {gb(swap)}; memory free: {free_pct if free_pct is not None else '?'}%", ""]
    lines.append(f"Shut the idle simulators down? This closes in {PROMPT_TIMEOUT_SEC} s and leaves them running.")
    return "\n".join(lines)


def ask(text: str) -> bool | None:
    """True to shut down, False to leave them, None when no dialog could be shown or it timed out."""
    script = (
        "display dialog " + applescript_string(text) + ' with title "Simulator slots"'
        ' buttons {"Leave them", "Shut down idle"} default button "Leave them"'
        f" giving up after {PROMPT_TIMEOUT_SEC}"
    )
    try:
        result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=PROMPT_TIMEOUT_SEC + 15)
    except subprocess.TimeoutExpired:
        return None
    if result.returncode != 0 or "gave up:true" in result.stdout:
        return None
    return "button returned:Shut down idle" in result.stdout


def shut_down(sim: dict) -> bool:
    result = subprocess.run(
        ["xcrun", "simctl", "--set", sim["set"], "shutdown", sim["udid"]], capture_output=True, text=True, timeout=60
    )
    return result.returncode == 0


def preflight(directory: Path, size: int, label: str, mine: dict[str, str] | None = None, force: bool = False) -> None:
    """Offer to shut down idle simulators, at most once per PROMPT_EVERY_SEC across all runs."""
    if os.environ.get("SIMULATOR_SLOTS_PROMPT") == "0":
        return
    stamp = directory / "prompt.stamp"
    with open(directory / "prompt.lock", "a") as gate:
        fcntl.flock(gate, fcntl.LOCK_EX)  # concurrent runs show one dialog, not several
        if not force and stamp.exists() and time.time() - stamp.stat().st_mtime < PROMPT_EVERY_SEC:
            return
        rows = process_table()
        idle = idle_simulators(booted_simulators(rows), holders(directory, size), mine)
        if not idle:
            return
        for sim in idle:
            sim["footprint_mb"] = tree_footprint_mb(sim["pid"], rows)
        print(f"simulator-slots: {len(idle)} idle simulator(s); asking in a dialog ({PROMPT_TIMEOUT_SEC} s)", file=sys.stderr)
        answer = ask(dialog_text(label, idle, swap_used_mb(), memory_free_percent()))
        stamp.touch()  # a timed-out dialog counts too: an away user shouldn't cost every run a minute
        if answer is None:
            print("simulator-slots: no answer; leaving the idle simulators running", file=sys.stderr)
        elif not answer:
            print("simulator-slots: leaving the idle simulators running", file=sys.stderr)
        else:
            for sim in idle:
                outcome = "shut down" if shut_down(sim) else "could not shut down"
                print(f"simulator-slots: {outcome} {sim['name']} ({sim['udid']})", file=sys.stderr)
        log_event(directory, {"event": "prompt", "idle": len(idle), "answer": answer})


# -- Run log ------------------------------------------------------------------------------------


def log_event(directory: Path, fields: dict) -> None:
    line = json.dumps({"time": now_iso(), **fields}, sort_keys=True)
    with open(directory / "runs.log", "a", encoding="utf-8") as f:
        f.write(line + "\n")


def recent_runs(directory: Path, count: int) -> list[dict]:
    try:
        lines = (directory / "runs.log").read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return []
    runs: dict[str, dict] = {}
    for line in lines:
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "run" in event:
            runs.setdefault(event["run"], {}).update({k: v for k, v in event.items() if k not in ("event", "time")})
            runs[event["run"]].setdefault("time", event["time"])
    return list(runs.values())[-count:]


# -- Commands -----------------------------------------------------------------------------------


def cmd_hold(args: argparse.Namespace) -> int:
    directory = state_dir()
    size = prepare_state(directory)
    fewer = args.fewer if args.fewer is not None else int(os.environ.get("SIMULATOR_SLOTS_FEWER") or 0)
    if args.want < 1 or fewer < 0:
        raise ConfigError("--want must be at least 1 and SIMULATOR_SLOTS_FEWER at least 0")
    if fewer >= size:
        raise ConfigError(f"SIMULATOR_SLOTS_FEWER={fewer} leaves nothing of a pool of {size}")
    preflight(directory, size, args.label, {"udid": args.udid, "owns": args.owns})

    for signum in (signal.SIGTERM, signal.SIGINT):
        signal.signal(signum, lambda *_: sys.exit(0))
    timeout = float(os.environ.get("SIMULATOR_SLOTS_TIMEOUT") or 0)
    swap_before = swap_used_mb()
    waited_from = time.monotonic()
    fds = acquire(directory, size, args.want, fewer, timeout)
    if fds is None:
        return EXIT_TIMEOUT
    run_id = uuid.uuid4().hex[:12]
    record(fds, {"pid": str(args.watch_pid), "started": now_iso(), "label": args.label, "root": args.root,
                 "udid": args.udid, "owns": args.owns, "run": run_id})
    log_event(directory, {"event": "start", "run": run_id, "label": args.label, "root": args.root, "want": args.want,
                          "fewer": fewer, "granted": len(fds), "pool": size,
                          "waited_sec": round(time.monotonic() - waited_from), "swap_before_mb": swap_before})
    print(f"{len(fds)} {run_id}", flush=True)
    # The caller has its line; let go of its pipe so a reader waiting for EOF isn't held up.
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 1)
    os.close(devnull)
    held_from = time.monotonic()
    try:
        wait_for_exit(args.watch_pid)
    finally:
        log_event(directory, {"event": "release", "run": run_id, "held_sec": round(time.monotonic() - held_from),
                              "swap_after_mb": swap_used_mb()})
    return 0


def cmd_result(args: argparse.Namespace) -> int:
    log_event(state_dir(), {"event": "result", "run": args.run, "rc": args.rc})
    return 0


def cmd_status(_args: argparse.Namespace) -> int:
    directory = state_dir()
    size = prepare_state(directory)
    held = holders(directory, size)
    print(f"state: {directory} (protocol {PROTOCOL}, pool {size})")
    for index, fields in enumerate(held, start=1):
        print(f"slot {index}: {'free' if fields is None else 'held by ' + describe(fields)}")
    booted = booted_simulators()
    idle = {sim["udid"] for sim in idle_simulators(booted, held)}
    print(f"booted simulators: {len(booted)}")
    for sim in booted:
        kind = set_label(sim["set"])
        print(f"  {sim['name']}{f' ({kind})' if kind else ''} {sim['udid']} {'idle' if sim['udid'] in idle else 'in use'}")
    print(f"swap used: {gb(swap_used_mb())}; memory free: {memory_free_percent()}%")
    print("recent runs:")
    for run in recent_runs(directory, 10):
        print(
            f"  {run.get('time', '?')} {run.get('label', '?')} in {Path(run.get('root', '?')).name}: "
            f"want {run.get('want', '?')} got {run.get('granted', '?')}, waited {run.get('waited_sec', '?')}s, "
            f"held {run.get('held_sec', '?')}s, rc {run.get('rc', '?')}, "
            f"swap {gb(run.get('swap_before_mb'))} -> {gb(run.get('swap_after_mb'))}"
        )
    return 0


def cmd_preflight(args: argparse.Namespace) -> int:
    directory = state_dir()
    preflight(directory, prepare_state(directory), "a simulator run", force=args.force)
    return 0


def synced_files(directory: Path) -> set[Path]:
    if not directory.is_dir():
        return set()
    return {
        path.relative_to(directory)
        for path in directory.rglob("*")
        if path.is_file() and not SYNC_IGNORE.intersection(path.relative_to(directory).parts)
    }


def tree_differences(master: Path, copy: Path) -> list[str]:
    ours, theirs = synced_files(master), synced_files(copy)
    differences = [f"only in master: {rel}" for rel in sorted(ours - theirs)]
    differences += [f"only in copy: {rel}" for rel in sorted(theirs - ours)]
    differences += [
        f"differs: {rel}" for rel in sorted(ours & theirs) if not filecmp.cmp(master / rel, copy / rel, shallow=False)
    ]
    return differences


def cmd_sync(args: argparse.Namespace) -> int:
    master, copy = Path(args.master or master_dir()), Path(args.into)
    if not master.is_dir():
        print(f"simulator-slots: no master at {master}", file=sys.stderr)
        return 1
    if copy.exists():
        shutil.rmtree(copy)
    shutil.copytree(master, copy, ignore=shutil.ignore_patterns(*SYNC_IGNORE))
    print(f"simulator-slots: synced {copy} from {master} (VERSION {(copy / 'VERSION').read_text().strip()})")
    return 0


def cmd_sync_check(args: argparse.Namespace) -> int:
    master, copy = Path(args.master or master_dir()), Path(args.into)
    if not master.is_dir():
        print(f"simulator-slots: sync-check skipped: no master at {master}")
        return 0
    differences = tree_differences(master, copy)
    if not differences:
        print(f"simulator-slots: {copy} matches {master}")
        return 0
    print(f"simulator-slots: {copy} is out of sync with {master}:", file=sys.stderr)
    for line in differences:
        print(f"  {line}", file=sys.stderr)
    print("  Fix: make simulator-slots-sync (copies the master over this repo's copy), then commit.", file=sys.stderr)
    return 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    hold = commands.add_parser("hold")
    hold.add_argument("--watch-pid", type=int, required=True, help="release the slots when this process exits")
    hold.add_argument("--want", type=int, required=True)
    hold.add_argument("--fewer", type=int, help="overrides SIMULATOR_SLOTS_FEWER")
    hold.add_argument("--label", default="a simulator run")
    hold.add_argument("--root", default=os.getcwd())
    hold.add_argument("--udid", default="", help="a device this run uses, so it never counts as idle")
    hold.add_argument("--owns", default="", help="devices whose name contains this text are this run's")
    hold.set_defaults(func=cmd_hold)

    result = commands.add_parser("result")
    result.add_argument("--run", required=True)
    result.add_argument("--rc", type=int, required=True)
    result.set_defaults(func=cmd_result)

    commands.add_parser("status").set_defaults(func=cmd_status)

    pre = commands.add_parser("preflight")
    pre.add_argument("--force", action="store_true", help="ignore the once-per-30-minutes window")
    pre.set_defaults(func=cmd_preflight)

    for name, func in (("sync", cmd_sync), ("sync-check", cmd_sync_check)):
        sub = commands.add_parser(name)
        sub.add_argument("--into", required=True, help="the vendored copy")
        sub.add_argument("--master")
        sub.set_defaults(func=func)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except ConfigError as error:
        print(f"simulator-slots: {error}", file=sys.stderr)
        return EXIT_CONFIG


if __name__ == "__main__":
    sys.exit(main())
