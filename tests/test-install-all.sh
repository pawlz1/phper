#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHPER="$SCRIPT_DIR/../phper"
LOG_DIR="$SCRIPT_DIR/../test-logs"
SUMMARY_LOG="$LOG_DIR/summary.log"
PHPER_DIR="${PHPER_DIR:-$HOME/.phper}"
MIN_BRANCH="${1:-7.0}"  # Minimum branch to test (default: 7.0), e.g. ./test-install-all.sh 8.0

mkdir -p "$LOG_DIR"

# Fetch every X.Y.Z patch version from 7.1+ dynamically from GitHub
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
passed=0
failed=0
failed_versions=()

echo ""
echo "=============================================="
echo " phper install test — every patch version"
echo " PHP ${MIN_BRANCH}+ ($total versions)"
echo "=============================================="
echo ""
echo "Logs directory: $LOG_DIR"
echo "Started: $(date)"
echo ""

# Write summary header
{
    echo "phper install test — $(date)"
    echo "PHP ${MIN_BRANCH}+ ($total versions)"
    echo "=============================="
    echo ""
} > "$SUMMARY_LOG"

current=0
for ver in "${VERSIONS[@]}"; do
    current=$((current + 1))
    branch=$(echo "$ver" | grep -oP '^[0-9]+\.[0-9]+')
    log_file="$LOG_DIR/php-${ver}.log"
    printf "[%3d/%d] PHP %-10s ... " "$current" "$total" "$ver"

    # Remove previous install of this branch to force fresh build
    rm -rf "$PHPER_DIR/versions/$branch"

    # phper expects X.Y and auto-selects latest with -y.
    # To install a specific X.Y.Z, we pipe the version into the prompt.
    start_time=$(date +%s)
    echo "$ver" | "$PHPER" "$branch" > "$log_file" 2>&1
    exit_code=$?
    end_time=$(date +%s)
    duration=$(( end_time - start_time ))

    # Check if php binary was actually installed and reports the right version
    php_bin="$PHPER_DIR/versions/$branch/bin/php"
    if [[ $exit_code -eq 0 && -x "$php_bin" ]]; then
        actual_ver=$("$php_bin" -r "echo PHP_VERSION;" 2>/dev/null)
        if [[ "$actual_ver" == "$ver" ]]; then
            echo "OK (${duration}s)"
            echo "[PASS] PHP $ver — ${duration}s" >> "$SUMMARY_LOG"
            passed=$((passed + 1))
        else
            echo "WRONG VERSION (${duration}s) — got $actual_ver"
            echo "[FAIL] PHP $ver — ${duration}s — wrong version: $actual_ver" >> "$SUMMARY_LOG"
            failed=$((failed + 1))
            failed_versions+=("$ver")
        fi
    else
        echo "FAILED (${duration}s) — exit code $exit_code"
        echo "[FAIL] PHP $ver — ${duration}s — exit code $exit_code" >> "$SUMMARY_LOG"
        echo "       Last lines of $log_file:" >> "$SUMMARY_LOG"
        tail -20 "$log_file" | sed 's/^/         /' >> "$SUMMARY_LOG"
        echo "" >> "$SUMMARY_LOG"
        failed=$((failed + 1))
        failed_versions+=("$ver")
    fi
done

echo ""
echo "=============================================="
echo " Results: $passed passed, $failed failed (of $total)"
echo "=============================================="

if [[ $failed -gt 0 ]]; then
    echo ""
    echo "Failed versions ($failed):"
    for v in "${failed_versions[@]}"; do
        echo "  - PHP $v (see $LOG_DIR/php-${v}.log)"
    done
fi

echo ""
echo "Full summary: $SUMMARY_LOG"
echo "Finished: $(date)"

# Append totals to summary
{
    echo ""
    echo "=============================="
    echo "Total: $passed passed, $failed failed (of $total)"
    if [[ $failed -gt 0 ]]; then
        echo ""
        echo "Failed versions:"
        for v in "${failed_versions[@]}"; do
            echo "  - $v"
        done
    fi
    echo ""
    echo "Finished: $(date)"
} >> "$SUMMARY_LOG"

# Exit with failure if any version failed
[[ $failed -eq 0 ]]
