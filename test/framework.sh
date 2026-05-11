# shellcheck shell=bash
# ──────────────────────────────────────────────────────────────────────────────
# dot unit-test framework — TAP-producing test harness for zsh modules
#
# Source this file at the top of every test_*.sh file:
#   source "${0:A:h}/../framework.sh"
#
# API:
#   describe "group name"                  — begin a test group (cosmetic)
#   it "test name" function_name           — run a single test
#   skip "reason"                          — mark the current test as skipped
#   assert_eq  expected actual [msg]       — strict string equality
#   assert_neq value1 value2 [msg]         — strings must differ
#   assert_match pattern actual [msg]      — extended-glob / regex match
#   assert_contains haystack needle [msg]  — substring check
#   assert_defined varname [msg]           — variable is set and non-empty
#   assert_undefined varname [msg]         — variable is unset or empty
#   assert_exit_code expected cmd...       — command exits with expected code
#   assert_output_contains cmd needle      — stdout of cmd contains needle
#   assert_called mock_name [msg]          — mock was invoked at least once
#   assert_not_called mock_name [msg]      — mock was never invoked
#
# Lifecycle hooks (define in your test file, optional):
#   test_setup()    — runs before EACH test
#   test_teardown() — runs after EACH test
#
# Output: TAP (Test Anything Protocol) on stdout
# Exit:   0 if all tests pass, 1 if any fail
# ──────────────────────────────────────────────────────────────────────────────

# Bail if not running under zsh
if [[ -z "${ZSH_VERSION:-}" ]]; then
    echo "FATAL: framework.sh requires zsh" >&2
    exit 1
fi

setopt LOCAL_OPTIONS NO_UNSET PIPE_FAIL 2>/dev/null

# ── State ─────────────────────────────────────────────────────────────────────
typeset -gi _TAP_TEST_NUM=0
typeset -gi _TAP_PASS=0
typeset -gi _TAP_FAIL=0
typeset -gi _TAP_SKIP=0
typeset -g  _TAP_CURRENT_GROUP=""
typeset -g  _TAP_SKIP_REASON=""
typeset -gi _TAP_PLAN_PRINTED=0

# Temp directory for this test run — cleaned on exit
export TEST_TMPDIR
TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/dot-test.XXXXXX")"

_tap_cleanup() {
    [[ -d "${TEST_TMPDIR}" ]] && rm -rf "${TEST_TMPDIR}"
}
trap _tap_cleanup EXIT INT TERM

# ── TAP helpers ───────────────────────────────────────────────────────────────

_tap_ok() {
    local description="$1"
    (( _TAP_TEST_NUM++ ))
    (( _TAP_PASS++ ))
    echo "ok ${_TAP_TEST_NUM} - ${description}"
}

_tap_not_ok() {
    local description="$1"
    local detail="${2:-}"
    (( _TAP_TEST_NUM++ ))
    (( _TAP_FAIL++ ))
    echo "not ok ${_TAP_TEST_NUM} - ${description}"
    [[ -n "${detail}" ]] && echo "#   ${detail}"
}

_tap_skip() {
    local description="$1"
    local reason="${2:-}"
    (( _TAP_TEST_NUM++ ))
    (( _TAP_SKIP++ ))
    echo "ok ${_TAP_TEST_NUM} - ${description} # SKIP ${reason}"
}

# ── Public API ────────────────────────────────────────────────────────────────

describe() {
    _TAP_CURRENT_GROUP="$1"
    echo "# ── ${1} ──"
}

skip() {
    _TAP_SKIP_REASON="$1"
}

it() {
    local name="$1"
    local fn="$2"
    local full_name=""

    if [[ -n "${_TAP_CURRENT_GROUP}" ]]; then
        full_name="${_TAP_CURRENT_GROUP}: ${name}"
    else
        full_name="${name}"
    fi

    # Reset skip flag
    _TAP_SKIP_REASON=""

    # Run setup hook if defined
    if typeset -f test_setup > /dev/null 2>&1; then
        test_setup
    fi

    # Check if test function wants to skip
    if [[ -n "${_TAP_SKIP_REASON}" ]]; then
        _tap_skip "${full_name}" "${_TAP_SKIP_REASON}"
        if typeset -f test_teardown > /dev/null 2>&1; then
            test_teardown
        fi
        return 0
    fi

    # Run the test function, capturing output and exit code
    local _test_output=""
    local _test_exit=0
    _test_output="$("${fn}" 2>&1)" || _test_exit=$?

    if [[ ${_test_exit} -eq 0 ]]; then
        _tap_ok "${full_name}"
    else
        _tap_not_ok "${full_name}" "${_test_output}"
    fi

    # Run teardown hook if defined
    if typeset -f test_teardown > /dev/null 2>&1; then
        test_teardown
    fi
}

# ── Assertions ────────────────────────────────────────────────────────────────

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-expected '${expected}', got '${actual}'}"
    if [[ "${expected}" != "${actual}" ]]; then
        echo "${msg}" >&2
        return 1
    fi
    return 0
}

assert_neq() {
    local val1="$1"
    local val2="$2"
    local msg="${3:-expected values to differ, both are '${val1}'}"
    if [[ "${val1}" == "${val2}" ]]; then
        echo "${msg}" >&2
        return 1
    fi
    return 0
}

assert_match() {
    local pattern="$1"
    local actual="$2"
    local msg="${3:-'${actual}' does not match pattern '${pattern}'}"
    if [[ ! "${actual}" =~ ${pattern} ]]; then
        echo "${msg}" >&2
        return 1
    fi
    return 0
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-'${haystack}' does not contain '${needle}'}"
    if [[ "${haystack}" != *"${needle}"* ]]; then
        echo "${msg}" >&2
        return 1
    fi
    return 0
}

assert_defined() {
    local varname="$1"
    local msg="${2:-variable '${varname}' is not defined}"
    if [[ -z "${(P)varname:-}" ]]; then
        echo "${msg}" >&2
        return 1
    fi
    return 0
}

assert_undefined() {
    local varname="$1"
    local msg="${2:-variable '${varname}' should not be defined}"
    if [[ -n "${(P)varname:-}" ]]; then
        echo "${msg}" >&2
        return 1
    fi
    return 0
}

assert_exit_code() {
    local expected="$1"
    shift
    local actual=0
    "$@" > /dev/null 2>&1 || actual=$?
    if [[ "${expected}" != "${actual}" ]]; then
        echo "expected exit code ${expected}, got ${actual}" >&2
        return 1
    fi
    return 0
}

assert_output_contains() {
    local needle="${1}"
    shift
    local output=""
    output="$("$@" 2>&1)" || true
    if [[ "${output}" != *"${needle}"* ]]; then
        echo "output does not contain '${needle}'" >&2
        echo "actual output: ${output}" >&2
        return 1
    fi
    return 0
}

assert_called() {
    local mock_name="$1"
    local msg="${2:-mock '${mock_name}' was never called}"
    local call_log="${TEST_TMPDIR}/.mock_calls_${mock_name}"
    if [[ ! -f "${call_log}" ]] || [[ ! -s "${call_log}" ]]; then
        echo "${msg}" >&2
        return 1
    fi
    return 0
}

assert_not_called() {
    local mock_name="$1"
    local msg="${2:-mock '${mock_name}' was unexpectedly called}"
    local call_log="${TEST_TMPDIR}/.mock_calls_${mock_name}"
    if [[ -f "${call_log}" ]] && [[ -s "${call_log}" ]]; then
        echo "${msg}" >&2
        return 1
    fi
    return 0
}

# Helper: get the args from a mock call log
mock_call_args() {
    local mock_name="$1"
    local call_log="${TEST_TMPDIR}/.mock_calls_${mock_name}"
    [[ -f "${call_log}" ]] && cat "${call_log}"
}

# Helper: reset call logs for all mocks
mock_reset_calls() {
    rm -f "${TEST_TMPDIR}"/.mock_calls_* 2>/dev/null
}

# ── Summary (call at end of test file) ────────────────────────────────────────

tap_summary() {
    echo "1..${_TAP_TEST_NUM}"
    echo "# passed: ${_TAP_PASS}"
    echo "# failed: ${_TAP_FAIL}"
    echo "# skipped: ${_TAP_SKIP}"
    echo "# total:  ${_TAP_TEST_NUM}"
    if (( _TAP_FAIL > 0 )); then
        return 1
    fi
    return 0
}
