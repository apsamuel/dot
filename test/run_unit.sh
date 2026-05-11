#!/usr/bin/env zsh
# ──────────────────────────────────────────────────────────────────────────────
# dot unit-test runner — discovers and runs test_*.sh files in subshells,
# aggregates TAP output, and prints a summary.
#
# Usage:
#   ./test/run_unit.sh                    # run all module tests
#   ./test/run_unit.sh test_000-a-base    # run a single test file (name match)
#   ./test/run_unit.sh -v                 # verbose (show individual TAP lines)
#
# Exit: 0 if all suites pass, 1 if any fail
# ──────────────────────────────────────────────────────────────────────────────

set -o pipefail

RUNNER_DIR="${0:A:h}"
TEST_MODULES_DIR="${RUNNER_DIR}/modules"

# ── Options ───────────────────────────────────────────────────────────────────
typeset -gi VERBOSE=0
typeset -g  FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose) VERBOSE=1; shift ;;
        -h|--help)
            echo "Usage: ${0:t} [-v|--verbose] [filter]"
            echo "  filter   substring match against test file names"
            return 0 2>/dev/null || exit 0
            ;;
        *) FILTER="$1"; shift ;;
    esac
done

# ── Discover test files ──────────────────────────────────────────────────────
typeset -a TEST_FILES=()
for f in "${TEST_MODULES_DIR}"/test_*.sh; do
    [[ -f "$f" ]] || continue
    if [[ -n "${FILTER}" ]] && [[ "${f:t}" != *"${FILTER}"* ]]; then
        continue
    fi
    TEST_FILES+=("$f")
done

if (( ${#TEST_FILES[@]} == 0 )); then
    echo "No test files found${FILTER:+ matching '${FILTER}'}"
    return 1 2>/dev/null || exit 1
fi

# ── Run tests ─────────────────────────────────────────────────────────────────
typeset -gi TOTAL_PASS=0
typeset -gi TOTAL_FAIL=0
typeset -gi TOTAL_SKIP=0
typeset -gi TOTAL_SUITES=0
typeset -gi FAILED_SUITES=0
typeset -a  FAILED_NAMES=()

echo "# ══════════════════════════════════════════════════════════════════"
echo "# dot unit-test runner — ${#TEST_FILES[@]} suite(s)"
echo "# ══════════════════════════════════════════════════════════════════"
echo ""

for test_file in "${TEST_FILES[@]}"; do
    (( TOTAL_SUITES++ ))
    local suite_name="${test_file:t:r}"  # filename without extension
    local suite_exit=0
    local suite_output=""

    echo "# ── ${suite_name} ──"

    # Run in a subshell to isolate each test file
    suite_output="$(zsh "${test_file}" 2>&1)" || suite_exit=$?

    # Parse TAP summary from output
    local pass=0 fail=0 skipped=0
    pass=$(echo "${suite_output}" | grep -c '^ok ' || true)
    fail=$(echo "${suite_output}" | grep -c '^not ok ' || true)
    skipped=$(echo "${suite_output}" | grep -c '# SKIP' || true)

    # Show full output in verbose mode
    if (( VERBOSE )); then
        echo "${suite_output}" | sed 's/^/  /'
    else
        # Show only failures
        local failures=""
        failures="$(echo "${suite_output}" | grep -A1 '^not ok ')" || true
        if [[ -n "${failures}" ]]; then
            echo "${failures}" | sed 's/^/  /'
        fi
    fi

    (( TOTAL_PASS += pass ))
    (( TOTAL_FAIL += fail ))
    (( TOTAL_SKIP += skipped ))

    if (( suite_exit != 0 )) || (( fail > 0 )); then
        (( FAILED_SUITES++ ))
        FAILED_NAMES+=("${suite_name}")
        echo "  FAIL (${pass} pass, ${fail} fail, ${skipped} skip)"
    else
        echo "  PASS (${pass} pass, ${fail} fail, ${skipped} skip)"
    fi
    echo ""
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo "# ══════════════════════════════════════════════════════════════════"
echo "# Summary"
echo "# ══════════════════════════════════════════════════════════════════"
echo "#  Suites:  ${TOTAL_SUITES} total, ${FAILED_SUITES} failed"
echo "#  Tests:   $(( TOTAL_PASS + TOTAL_FAIL + TOTAL_SKIP )) total"
echo "#  Passed:  ${TOTAL_PASS}"
echo "#  Failed:  ${TOTAL_FAIL}"
echo "#  Skipped: ${TOTAL_SKIP}"

if (( FAILED_SUITES > 0 )); then
    echo "#"
    echo "#  Failed suites:"
    for name in "${FAILED_NAMES[@]}"; do
        echo "#    - ${name}"
    done
    echo "# ══════════════════════════════════════════════════════════════════"
    return 1 2>/dev/null || exit 1
fi

echo "# ══════════════════════════════════════════════════════════════════"
return 0 2>/dev/null || exit 0
