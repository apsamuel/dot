# shellcheck shell=bash
# ──────────────────────────────────────────────────────────────────────────────
# dot unit-test framework — TAP-producing test harness (bash / zsh / POSIX-lean)
#
# Portable across bash (>=4.0) and zsh (>=5.0).  Prefers POSIX constructs
# where practical; falls back to bash/zsh extensions only when necessary
# (glob matching, regex).
#
# Source this file at the top of every test_*.sh file.  Use the portable
# bootstrap block (see below) so the same test can be invoked by either shell:
#
#   if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
#   else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
#   source "${_test_dir}/../framework.sh"
#
# API:
#   describe "group name"                  — begin a test group (cosmetic)
#   it "test name" function_name           — run a single test
#   skip "reason"                          — mark the current test as skipped
#   assert_eq  expected actual [msg]       — strict string equality
#   assert_neq value1 value2 [msg]         — strings must differ
#   assert_match pattern actual [msg]      — ERE regex match (via grep -qE)
#   assert_contains haystack needle [msg]  — substring check (POSIX case)
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

# ── Shell detection ───────────────────────────────────────────────────────────
_FRAMEWORK_SHELL=""
if [ -n "${ZSH_VERSION:-}" ]; then
    _FRAMEWORK_SHELL="zsh"
elif [ -n "${BASH_VERSION:-}" ]; then
    _FRAMEWORK_SHELL="bash"
else
    printf 'FATAL: framework.sh requires bash (>=4.0) or zsh (>=5.0)\n' >&2
    return 1 2>/dev/null
fi
export _FRAMEWORK_SHELL

# ── Script directory (exported for downstream files) ─────────────────────────
if [ "${_FRAMEWORK_SHELL}" = "zsh" ]; then
    FRAMEWORK_DIR="${0:A:h}"
else
    # shellcheck disable=SC3028,SC3054
    FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
fi
export FRAMEWORK_DIR

# ── Strict mode ───────────────────────────────────────────────────────────────
if [ "${_FRAMEWORK_SHELL}" = "zsh" ]; then
    setopt LOCAL_OPTIONS NO_UNSET PIPE_FAIL 2>/dev/null
else
    set -uo pipefail 2>/dev/null || true
fi

# ── State ─────────────────────────────────────────────────────────────────────
_TAP_TEST_NUM=0
_TAP_PASS=0
_TAP_FAIL=0
_TAP_SKIP=0
_TAP_CURRENT_GROUP=""
_TAP_SKIP_REASON=""
_TAP_PLAN_PRINTED=0

# Temp directory for this test run — cleaned on exit
export TEST_TMPDIR
TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/dot-test.XXXXXX")"

_tap_cleanup() {
    [ -d "${TEST_TMPDIR}" ] && command rm -rf "${TEST_TMPDIR}"
}
trap _tap_cleanup EXIT INT TERM

# ── Internal helpers ──────────────────────────────────────────────────────────

# Portable indirect variable dereference: _deref VARNAME
# Returns the value of the variable whose name is passed as $1.
# Uses eval — safe here because callers only pass known variable names.
_deref() {
    eval printf '%s' "\"\${${1}:-}\""
}

# Check whether a shell function is defined (works in bash + zsh)
_fn_exists() {
    typeset -f "$1" > /dev/null 2>&1
}

# ── TAP helpers ───────────────────────────────────────────────────────────────

_tap_ok() {
    local description="$1"
    _TAP_TEST_NUM=$(( _TAP_TEST_NUM + 1 ))
    _TAP_PASS=$(( _TAP_PASS + 1 ))
    printf 'ok %d - %s\n' "${_TAP_TEST_NUM}" "${description}"
}

_tap_not_ok() {
    local description="$1"
    local detail="${2:-}"
    _TAP_TEST_NUM=$(( _TAP_TEST_NUM + 1 ))
    _TAP_FAIL=$(( _TAP_FAIL + 1 ))
    printf 'not ok %d - %s\n' "${_TAP_TEST_NUM}" "${description}"
    [ -n "${detail}" ] && printf '#   %s\n' "${detail}"
}

_tap_skip() {
    local description="$1"
    local reason="${2:-}"
    _TAP_TEST_NUM=$(( _TAP_TEST_NUM + 1 ))
    _TAP_SKIP=$(( _TAP_SKIP + 1 ))
    printf 'ok %d - %s # SKIP %s\n' "${_TAP_TEST_NUM}" "${description}" "${reason}"
}

# ── Public API ────────────────────────────────────────────────────────────────

describe() {
    _TAP_CURRENT_GROUP="$1"
    printf '# ── %s ──\n' "$1"
}

skip() {
    _TAP_SKIP_REASON="$1"
}

it() {
    local name="$1"
    local fn="$2"
    local full_name=""

    if [ -n "${_TAP_CURRENT_GROUP}" ]; then
        full_name="${_TAP_CURRENT_GROUP}: ${name}"
    else
        full_name="${name}"
    fi

    # Reset skip flag
    _TAP_SKIP_REASON=""

    # Run setup hook if defined
    if _fn_exists test_setup; then
        test_setup
    fi

    # Check if test function wants to skip
    if [ -n "${_TAP_SKIP_REASON}" ]; then
        _tap_skip "${full_name}" "${_TAP_SKIP_REASON}"
        if _fn_exists test_teardown; then
            test_teardown
        fi
        return 0
    fi

    # Run the test function, capturing output and exit code
    local _test_output=""
    local _test_exit=0
    _test_output="$("${fn}" 2>&1)" || _test_exit=$?

    if [ "${_test_exit}" -eq 0 ]; then
        _tap_ok "${full_name}"
    else
        _tap_not_ok "${full_name}" "${_test_output}"
    fi

    # Run teardown hook if defined
    if _fn_exists test_teardown; then
        test_teardown
    fi
}

# ── Assertions ────────────────────────────────────────────────────────────────

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    [ -z "${msg}" ] && msg="expected '${expected}', got '${actual}'"
    if [ "${expected}" != "${actual}" ]; then
        printf '%s\n' "${msg}" >&2
        return 1
    fi
    return 0
}

assert_neq() {
    local val1="$1"
    local val2="$2"
    local msg="$3"
    [ -z "${msg}" ] && msg="expected values to differ, both are '${val1}'"
    if [ "${val1}" = "${val2}" ]; then
        printf '%s\n' "${msg}" >&2
        return 1
    fi
    return 0
}

assert_match() {
    local pattern="$1"
    local actual="$2"
    local msg="$3"
    [ -z "${msg}" ] && msg="'${actual}' does not match pattern '${pattern}'"
    if ! printf '%s' "${actual}" | command grep -qE "${pattern}"; then
        printf '%s\n' "${msg}" >&2
        return 1
    fi
    return 0
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="$3"
    [ -z "${msg}" ] && msg="'${haystack}' does not contain '${needle}'"
    case "${haystack}" in
        *"${needle}"*) return 0 ;;
    esac
    printf '%s\n' "${msg}" >&2
    return 1
}

assert_defined() {
    local varname="$1"
    local msg="$2"
    [ -z "${msg}" ] && msg="variable '${varname}' is not defined"
    local _val=""
    _val="$(_deref "${varname}")"
    if [ -z "${_val}" ]; then
        printf '%s\n' "${msg}" >&2
        return 1
    fi
    return 0
}

assert_undefined() {
    local varname="$1"
    local msg="$2"
    [ -z "${msg}" ] && msg="variable '${varname}' should not be defined"
    local _val=""
    _val="$(_deref "${varname}")"
    if [ -n "${_val}" ]; then
        printf '%s\n' "${msg}" >&2
        return 1
    fi
    return 0
}

assert_exit_code() {
    local expected="$1"
    shift
    local actual=0
    "$@" > /dev/null 2>&1 || actual=$?
    if [ "${expected}" != "${actual}" ]; then
        printf 'expected exit code %s, got %s\n' "${expected}" "${actual}" >&2
        return 1
    fi
    return 0
}

assert_output_contains() {
    local needle="${1}"
    shift
    local output=""
    output="$("$@" 2>&1)" || true
    case "${output}" in
        *"${needle}"*) return 0 ;;
    esac
    printf "output does not contain '%s'\n" "${needle}" >&2
    printf 'actual output: %s\n' "${output}" >&2
    return 1
}

assert_called() {
    local mock_name="$1"
    local msg="$2"
    [ -z "${msg}" ] && msg="mock '${mock_name}' was never called"
    local call_log="${TEST_TMPDIR}/.mock_calls_${mock_name}"
    if [ ! -f "${call_log}" ] || [ ! -s "${call_log}" ]; then
        printf '%s\n' "${msg}" >&2
        return 1
    fi
    return 0
}

assert_not_called() {
    local mock_name="$1"
    local msg="$2"
    [ -z "${msg}" ] && msg="mock '${mock_name}' was unexpectedly called"
    local call_log="${TEST_TMPDIR}/.mock_calls_${mock_name}"
    if [ -f "${call_log}" ] && [ -s "${call_log}" ]; then
        printf '%s\n' "${msg}" >&2
        return 1
    fi
    return 0
}

# Helper: get the args from a mock call log
mock_call_args() {
    local mock_name="$1"
    local call_log="${TEST_TMPDIR}/.mock_calls_${mock_name}"
    [ -f "${call_log}" ] && cat "${call_log}"
}

# Helper: reset call logs for all mocks
mock_reset_calls() {
    command rm -f "${TEST_TMPDIR}"/.mock_calls_* 2>/dev/null
    return 0
}

# ── Summary (call at end of test file) ────────────────────────────────────────

tap_summary() {
    printf '1..%d\n' "${_TAP_TEST_NUM}"
    printf '# passed: %d\n' "${_TAP_PASS}"
    printf '# failed: %d\n' "${_TAP_FAIL}"
    printf '# skipped: %d\n' "${_TAP_SKIP}"
    printf '# total:  %d\n' "${_TAP_TEST_NUM}"
    if [ "${_TAP_FAIL}" -gt 0 ]; then
        return 1
    fi
    return 0
}
