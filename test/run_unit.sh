#!/usr/bin/env bash
# shellcheck shell=bash
# ──────────────────────────────────────────────────────────────────────────────
# dot unit-test runner — discovers and runs test_*.sh files in subshells,
# aggregates TAP output, and prints a summary.
#
# Portable across bash (>=4.0) and zsh (>=5.0).
#
# Usage:
#   ./test/run_unit.sh                    # run all module tests
#   ./test/run_unit.sh test_000-a-base    # run a single test file (name match)
#   ./test/run_unit.sh -v                 # verbose (show individual TAP lines)
#   DOT_TEST_SHELL=bash ./test/run_unit.sh  # override test shell (default: zsh)
#
# Exit: 0 if all suites pass, 1 if any fail
# ──────────────────────────────────────────────────────────────────────────────

set -o pipefail 2>/dev/null || true

# ── Resolve script directory portably ─────────────────────────────────────────
if [ -n "${ZSH_VERSION:-}" ]; then
    RUNNER_DIR="${0:A:h}"
else
    # shellcheck disable=SC3028,SC3054
    RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
fi
TEST_MODULES_DIR="${RUNNER_DIR}/modules"

# Shell used to execute each test file (default: zsh for zsh module tests)
DOT_TEST_SHELL="${DOT_TEST_SHELL:-zsh}"

# ── Options ───────────────────────────────────────────────────────────────────
VERBOSE=0
FILTER=""

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--verbose) VERBOSE=1; shift ;;
        -h|--help)
            printf 'Usage: %s [-v|--verbose] [filter]\n' "$(basename "$0")"
            printf '  filter   substring match against test file names\n'
            exit 0
            ;;
        *) FILTER="$1"; shift ;;
    esac
done

# ── Discover test files ───────────────────────────────────────────────────────
TEST_FILES=()
for f in "${TEST_MODULES_DIR}"/test_*.sh; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
        *"${FILTER}"*) TEST_FILES+=("$f") ;;
        *) [ -z "${FILTER}" ] && TEST_FILES+=("$f") ;;
    esac
done

if [ "${#TEST_FILES[@]}" -eq 0 ]; then
    printf 'No test files found'
    [ -n "${FILTER}" ] && printf " matching '%s'" "${FILTER}"
    printf '\n'
    exit 1
fi

# ── Run tests ─────────────────────────────────────────────────────────────────
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
TOTAL_SUITES=0
FAILED_SUITES=0
FAILED_NAMES=()

echo "# ══════════════════════════════════════════════════════════════════"
echo "# dot unit-test runner — ${#TEST_FILES[@]} suite(s)"
echo "# ══════════════════════════════════════════════════════════════════"
echo ""

for test_file in "${TEST_FILES[@]}"; do
    TOTAL_SUITES=$(( TOTAL_SUITES + 1 ))
    suite_name="$(basename "${test_file}" .sh)"
    suite_exit=0
    suite_output=""

    echo "# ── ${suite_name} ──"

    # Run in a subshell via the configured test shell
    suite_output="$("${DOT_TEST_SHELL}" "${test_file}" 2>&1)" || suite_exit=$?

    # Parse TAP summary from output
    pass=0; fail=0; skipped=0
    pass=$(printf '%s\n' "${suite_output}" | grep -c '^ok ' || true)
    fail=$(printf '%s\n' "${suite_output}" | grep -c '^not ok ' || true)
    skipped=$(printf '%s\n' "${suite_output}" | grep -c '# SKIP' || true)

    # Show full output in verbose mode
    if [ "${VERBOSE}" -eq 1 ]; then
        printf '%s\n' "${suite_output}" | sed 's/^/  /'
    else
        # Show only failures
        failures="$(printf '%s\n' "${suite_output}" | grep -A1 '^not ok ')" || true
        if [ -n "${failures}" ]; then
            printf '%s\n' "${failures}" | sed 's/^/  /'
        fi
    fi

    TOTAL_PASS=$(( TOTAL_PASS + pass ))
    TOTAL_FAIL=$(( TOTAL_FAIL + fail ))
    TOTAL_SKIP=$(( TOTAL_SKIP + skipped ))

    if [ "${suite_exit}" -ne 0 ] || [ "${fail}" -gt 0 ]; then
        FAILED_SUITES=$(( FAILED_SUITES + 1 ))
        FAILED_NAMES+=("${suite_name}")
        printf '  FAIL (%d pass, %d fail, %d skip)\n' "${pass}" "${fail}" "${skipped}"
    else
        printf '  PASS (%d pass, %d fail, %d skip)\n' "${pass}" "${fail}" "${skipped}"
    fi
    echo ""
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo "# ══════════════════════════════════════════════════════════════════"
echo "# Summary"
echo "# ══════════════════════════════════════════════════════════════════"
printf '#  Suites:  %d total, %d failed\n' "${TOTAL_SUITES}" "${FAILED_SUITES}"
printf '#  Tests:   %d total\n' "$(( TOTAL_PASS + TOTAL_FAIL + TOTAL_SKIP ))"
printf '#  Passed:  %d\n' "${TOTAL_PASS}"
printf '#  Failed:  %d\n' "${TOTAL_FAIL}"
printf '#  Skipped: %d\n' "${TOTAL_SKIP}"

if [ "${FAILED_SUITES}" -gt 0 ]; then
    echo "#"
    echo "#  Failed suites:"
    for name in "${FAILED_NAMES[@]}"; do
        printf '#    - %s\n' "${name}"
    done
    echo "# ══════════════════════════════════════════════════════════════════"
    exit 1
fi

echo "# ══════════════════════════════════════════════════════════════════"
exit 0
