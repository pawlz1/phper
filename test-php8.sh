#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHPER="$SCRIPT_DIR/phper"
LOG_DIR="$SCRIPT_DIR/test-logs"
RESULTS_FILE="$LOG_DIR/results-php8.txt"
WORK_ROOT="/tmp/phper-test-php8"

export PHPER_MAKE_JOBS="${PHPER_MAKE_JOBS:-2}"

mkdir -p "$LOG_DIR"
rm -f "$RESULTS_FILE"
touch "$RESULTS_FILE"

# PHP 8 minor versions — one parallel job each
BRANCHES=(8.0 8.1 8.2 8.3 8.4)

echo "=============================================="
echo " phper test — PHP 8.x (latest of each minor)"
echo " Parallel: ${#BRANCHES[@]} branches"
echo " make -j$PHPER_MAKE_JOBS per build"
echo "=============================================="
echo ""
echo "Started: $(date)"
echo ""

build_branch() {
    local branch="$1"
    local work_dir="$WORK_ROOT/$branch"
    local log_file="$LOG_DIR/php-${branch}.log"

    export PHPER_DIR="$work_dir/.phper"
    mkdir -p "$PHPER_DIR/versions" "$PHPER_DIR/bin"

    local start_time end_time duration
    start_time=$(date +%s)
    "$PHPER" "$branch" -y > "$log_file" 2>&1
    local rc=$?
    end_time=$(date +%s)
    duration=$(( end_time - start_time ))

    local php_bin="$PHPER_DIR/versions/$branch/bin/php"
    if [[ $rc -eq 0 && -x "$php_bin" ]]; then
        local actual
        actual=$("$php_bin" -r "echo PHP_VERSION;" 2>/dev/null)
        echo "PASS $branch ${duration}s $actual" >> "$RESULTS_FILE"
        printf "  ✓ PHP %-6s OK  (%3ds) — %s\n" "$branch" "$duration" "$actual"
    else
        echo "FAIL $branch ${duration}s exit=$rc" >> "$RESULTS_FILE"
        printf "  ✗ PHP %-6s FAIL (%3ds) — see %s\n" "$branch" "$duration" "$log_file"
    fi

    rm -rf "$work_dir"
}

# Launch all branches in parallel
for branch in "${BRANCHES[@]}"; do
    build_branch "$branch" &
done

wait

# Results
pass_count=$(grep -c "^PASS" "$RESULTS_FILE" 2>/dev/null || echo 0)
fail_count=$(grep -c "^FAIL" "$RESULTS_FILE" 2>/dev/null || echo 0)

echo ""
echo "=============================================="
echo " Results: $pass_count passed, $fail_count failed"
echo "=============================================="

if [[ $fail_count -gt 0 ]]; then
    echo ""
    echo "Failed:"
    grep "^FAIL" "$RESULTS_FILE" | sort -V -k2 | while read -r _ branch rest; do
        echo "  - PHP $branch ($rest)"
        echo "    Last 20 lines:"
        tail -20 "$LOG_DIR/php-${branch}.log" 2>/dev/null | sed 's/^/      /'
    done
fi

echo ""
echo "Finished: $(date)"
rm -rf "$WORK_ROOT"

[[ $fail_count -eq 0 ]]
