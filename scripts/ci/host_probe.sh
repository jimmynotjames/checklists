#!/bin/bash
# Diagnostic for issue #430: records what the CI macOS runner actually is and how loaded it gets,
# so a slow run can be told apart as "slow host at idle" (pool or neighbour) versus "host fine
# until our own simulators load it" (memory or CPU oversubscription). Not a test; never fails.
#
#   host_probe.sh snapshot <label>   hardware, OS and a short CPU and disk benchmark
#   host_probe.sh sample <seconds>   load, memory pressure, swap and top processes, every N seconds,
#                                    to a file and stdout, until killed (start it in the background)
#   host_probe.sh summary            prints the snapshots and a one-line-per-sample table
#
# Output goes to PROBE_DIR (default .build/host-probe). Runs on the runner's /bin/bash 3.2.
set -u
PROBE_DIR="${PROBE_DIR:-.build/host-probe}"
mkdir -p "$PROBE_DIR"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Seconds a fixed single-thread workload takes; lower is faster.
cpu_bench() {
    python3 -c '
import hashlib, time
t = time.time()
h = b"x"
for _ in range(10_000_000):
    h = hashlib.sha256(h).digest()
print(f"{time.time() - t:.2f}")'
}

snapshot() {
    local label="$1" out="$PROBE_DIR/snapshot-$1.txt" ncpu i start
    ncpu="$(sysctl -n hw.ncpu)"
    {
        echo "== snapshot ${label} at $(now)"
        sw_vers
        sysctl hw.model machdep.cpu.brand_string hw.ncpu hw.physicalcpu \
            hw.perflevel0.physicalcpu hw.perflevel1.physicalcpu hw.memsize 2>/dev/null
        system_profiler SPHardwareDataType 2>/dev/null | grep -E 'Model|Chip|Cores|Memory'
        echo "loadavg: $(sysctl -n vm.loadavg)"
        sysctl vm.swapusage
        memory_pressure -Q 2>/dev/null
        df -h / | tail -1
        echo "cpu_bench_single_s: $(cpu_bench)"
        # The same workload on every core at once; near the single figure means the cores are real.
        start=$(python3 -c 'import time; print(time.time())')
        for ((i = 0; i < ncpu; i++)); do cpu_bench >/dev/null & done
        wait
        python3 -c "import time; print(f'cpu_bench_all_${ncpu}_cores_s: {time.time() - ${start}:.2f}')"
        # 1 GiB written and fsynced, so it measures the disk rather than the page cache.
        dd if=/dev/zero of="$PROBE_DIR/dd.tmp" bs=1m count=1024 conv=fsync 2>&1 | tail -1
        rm -f "$PROBE_DIR/dd.tmp"
        echo "simulators booted: $(xcrun simctl list devices booted 2>/dev/null | grep -c Booted)"
    } >"$out" 2>&1
    cat "$out"
}

sample() {
    local every="$1" out="$PROBE_DIR/samples.tsv"
    printf 'time\tload1\tload5\tfree_pct\tswap_used\tpageouts\tswapouts\tbooted_sims\ttop3\n' >"$out"
    while true; do
        local load free swap vm top sims line
        load="$(sysctl -n vm.loadavg | tr -d '{}' | awk '{print $1 "\t" $2}')"
        free="$(memory_pressure -Q 2>/dev/null | awk -F': ' '/free percentage/ {print $2}')"
        swap="$(sysctl -n vm.swapusage | awk '{print $6}')"
        vm="$(vm_stat | awk '/Pageouts/ {p=$2} /Swapouts/ {s=$2} END {print p "\t" s}' | tr -d '.')"
        sims="$(xcrun simctl list devices booted 2>/dev/null | grep -c Booted)"
        top="$(ps -Ao pcpu=,rss=,comm= -r | head -3 \
            | awk '{c=$3; for (i=4; i<=NF; i++) c=c " " $i; n=split(c, a, "/"); printf "%s %s%% %dMB; ", a[n], $1, $2 / 1024}')"
        line="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s' "$(now)" "$load" "$free" "$swap" "$vm" "$sims" "$top")"
        echo "$line" >>"$out"
        # Also to stdout, live: a VM that wedges never runs the steps that upload the file.
        echo "host-probe: $line"
        sleep "$every"
    done
}

summary() {
    cat "$PROBE_DIR"/snapshot-*.txt 2>/dev/null
    echo "== samples"
    column -t -s $'\t' "$PROBE_DIR/samples.tsv" 2>/dev/null || cat "$PROBE_DIR/samples.tsv"
}

case "${1:-}" in
    snapshot) snapshot "${2:?label}" ;;
    sample) sample "${2:-30}" ;;
    summary) summary ;;
    *) echo "usage: $0 snapshot <label> | sample <seconds> | summary" >&2 ;;
esac
exit 0
