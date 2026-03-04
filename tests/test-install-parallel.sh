#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHPER="$SCRIPT_DIR/../phper"
LOG_DIR="$SCRIPT_DIR/../test-logs"
RESULTS_FILE="$LOG_DIR/results.txt"
SUMMARY_LOG="$LOG_DIR/summary.log"
WORK_ROOT="/tmp/phper-test"
MIN_BRANCH="${1:-7.0}"

# Auto-detect concurrency: min(cores/2, ram_gb/2, 8), minimum 1
detect_max_jobs() {
    local cores ram_kb ram_gb by_cores by_ram
    cores=$(nproc 2>/dev/null || echo 2)
    ram_kb=$(grep -i memtotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    ram_gb=$(( ${ram_kb:-4000000} / 1024 / 1024 ))
    by_cores=$(( cores / 2 ))
    by_ram=$(( ram_gb / 2 ))
    local max=$by_cores
    [[ $by_ram -lt $max ]] && max=$by_ram
    [[ $max -gt 8 ]] && max=8
    [[ $max -lt 1 ]] && max=1
    echo "$max"
}

MAX_JOBS="${PHPER_TEST_JOBS:-$(detect_max_jobs)}"
export PHPER_MAKE_JOBS="${PHPER_MAKE_JOBS:-2}"

mkdir -p "$LOG_DIR"
rm -f "$RESULTS_FILE"
touch "$RESULTS_FILE"

# Fetch all versions
echo "Fetching all available PHP versions from GitHub..."
mapfile -t ALL_VERSIONS < <(
    git ls-remote --tags https://github.com/php/php-src.git "php-5.*" "php-7.*" "php-8.*" 2>/dev/null \
    | grep -oP 'refs/tags/php-\K[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V
)

if [[ ${#ALL_VERSIONS[@]} -eq 0 ]]; then
    echo "Error: Failed to fetch version list from GitHub." >&2
    exit 1
fi

# Filter to versions >= MIN_BRANCH
min_major=$(echo "$MIN_BRANCH" | cut -d. -f1)
min_minor=$(echo "$MIN_BRANCH" | cut -d. -f2)

VERSIONS=()
for v in "${ALL_VERSIONS[@]}"; do
    major=$(echo "$v" | cut -d. -f1)
    minor=$(echo "$v" | cut -d. -f2)
    if [[ $major -gt $min_major ]] || [[ $major -eq $min_major && $minor -ge $min_minor ]]; then
        VERSIONS+=("$v")
    fi
done

total=${#VERSIONS[@]}

echo ""
echo "=============================================="
echo " phper parallel install test"
echo " PHP ${MIN_BRANCH}+ ($total versions)"
echo " Workers: $MAX_JOBS | make -j$PHPER_MAKE_JOBS"
echo "=============================================="
echo ""
echo "Logs: $LOG_DIR"
echo "Started: $(date)"
echo ""

# Worker function — runs in a subshell
build_one() {
    local ver="$1"
    local idx="$2"
    local total="$3"
    local branch
    branch=$(echo "$ver" | grep -oP '^[0-9]+\.[0-9]+')
    local work_dir="$WORK_ROOT/$ver"
    local log_file="$LOG_DIR/php-${ver}.log"

    export PHPER_DIR="$work_dir/.phper"
    mkdir -p "$PHPER_DIR/versions" "$PHPER_DIR/bin"

    # Install by piping the specific version into the prompt
    local start_time end_time duration
    start_time=$(date +%s)
    echo "$ver" | "$PHPER" "$branch" > "$log_file" 2>&1
    local rc=$?
    end_time=$(date +%s)
    duration=$(( end_time - start_time ))

    # Verify
    local php_bin="$PHPER_DIR/versions/$branch/bin/php"
    local status="FAIL"
    local detail=""

    if [[ $rc -eq 0 && -x "$php_bin" ]]; then
        local actual
        actual=$("$php_bin" -r "echo PHP_VERSION;" 2>/dev/null)
        if [[ "$actual" == "$ver" ]]; then
            status="PASS"
        else
            detail="wrong version: $actual"
        fi
    else
        detail="exit code $rc"
    fi

    # Cleanup build artifacts to save disk
    rm -rf "$work_dir"

    # Write result (atomic-ish via single echo)
    if [[ "$status" == "PASS" ]]; then
        echo "PASS $ver ${duration}s" >> "$RESULTS_FILE"
        printf "[%3d/%d] ✓ PHP %-10s (%ds)\n" "$idx" "$total" "$ver" "$duration"
    else
        echo "FAIL $ver ${duration}s $detail" >> "$RESULTS_FILE"
        printf "[%3d/%d] ✗ PHP %-10s (%ds) — %s\n" "$idx" "$total" "$ver" "$duration" "$detail"
    fi
}

# Run builds with controlled parallelism (bash semaphore via wait -n)
job_count=0
idx=0

for ver in "${VERSIONS[@]}"; do
    idx=$((idx + 1))
    build_one "$ver" "$idx" "$total" &
    job_count=$((job_count + 1))

    if [[ $job_count -ge $MAX_JOBS ]]; then
        wait -n 2>/dev/null || wait  # wait -n needs bash 4.3+, fallback to wait
        job_count=$((job_count - 1))
    fi
done

# Wait for remaining jobs
wait

# Aggregate results
pass_count=$(grep -c "^PASS" "$RESULTS_FILE" 2>/dev/null || echo 0)
fail_count=$(grep -c "^FAIL" "$RESULTS_FILE" 2>/dev/null || echo 0)

echo ""
echo "=============================================="
echo " Results: $pass_count passed, $fail_count failed (of $total)"
echo "=============================================="

# Write summary
{
    echo "phper parallel install test — $(date)"
    echo "PHP ${MIN_BRANCH}+ ($total versions)"
    echo "Workers: $MAX_JOBS | make -j$PHPER_MAKE_JOBS"
    echo "=============================="
    echo ""
    echo "PASSED ($pass_count):"
    grep "^PASS" "$RESULTS_FILE" | sort -V -k2 | while read -r _ ver dur _rest; do
        echo "  PHP $ver ($dur)"
    done
    echo ""
} > "$SUMMARY_LOG"

if [[ $fail_count -gt 0 ]]; then
    echo ""
    echo "Failed versions ($fail_count):"
    grep "^FAIL" "$RESULTS_FILE" | sort -V -k2 | while read -r _ ver dur rest; do
        echo "  - PHP $ver ($dur) — $rest"
        echo "    Log: $LOG_DIR/php-${ver}.log"
    done

    {
        echo "FAILED ($fail_count):"
        grep "^FAIL" "$RESULTS_FILE" | sort -V -k2 | while read -r _ ver dur rest; do
            echo ""
            echo "  PHP $ver ($dur) — $rest"
            echo "  Last 20 lines of log:"
            tail -20 "$LOG_DIR/php-${ver}.log" 2>/dev/null | sed 's/^/    /'
        done
    } >> "$SUMMARY_LOG"
fi

{
    echo ""
    echo "=============================="
    echo "Total: $pass_count passed, $fail_count failed (of $total)"
    echo "Finished: $(date)"
} >> "$SUMMARY_LOG"

echo ""
echo "Full summary: $SUMMARY_LOG"
echo "Finished: $(date)"

# Cleanup work root
rm -rf "$WORK_ROOT"

[[ $fail_count -eq 0 ]]
