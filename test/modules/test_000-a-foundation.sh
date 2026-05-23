# shellcheck shell=bash
# Test: modules/000-a-foundation.sh — baseline env + utility functions
# Portable bootstrap — works under bash and zsh
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"

# Source the module under test
source_module "000-a-foundation.sh"

# ── Tests ─────────────────────────────────────────────────────────────────────

describe "000-a-foundation.sh: dot::foundation::shell-name()"

test_get_shell_name_returns_string() {
    # dot::foundation::shell-name references $fish_pid which fails under NO_UNSET
    # Temporarily allow unset variables for this function
    local result=""
    if [ -n "${ZSH_VERSION:-}" ]; then setopt LOCAL_OPTIONS UNSET; else set +u; fi
    result="$(dot::foundation::shell-name 2>/dev/null)"
    [ -n "${result}" ] || { printf 'dot::foundation::shell-name returned empty\n' >&2; return 1; }
}

test_get_shell_name_lowercase() {
    if [ -n "${ZSH_VERSION:-}" ]; then setopt LOCAL_OPTIONS UNSET; else set +u; fi
    local result=""
    result="$(dot::foundation::shell-name 2>/dev/null)"
    local lower=""
    lower="$(echo "${result}" | tr '[:upper:]' '[:lower:]')"
    assert_eq "${lower}" "${result}"
}

it "dot::foundation::shell-name returns a string" test_get_shell_name_returns_string
it "dot::foundation::shell-name returns lowercase" test_get_shell_name_lowercase

describe "000-a-foundation.sh: dot::foundation::secure-string()"

test_get_secure_string_default_length() {
    local result=""
    result="$(dot::foundation::secure-string 2>/dev/null)"
    assert_defined "result"
}

test_get_secure_string_custom_length() {
    local result=""
    result="$(dot::foundation::secure-string 20 2>/dev/null)"
    assert_defined "result"
}

test_get_secure_string_calls_pwgen() {
    mock_reset_calls
    dot::foundation::secure-string 10 > /dev/null 2>&1
    assert_called "pwgen"
}

it "dot::foundation::secure-string returns a value" test_get_secure_string_default_length
it "dot::foundation::secure-string accepts a length arg" test_get_secure_string_custom_length
it "dot::foundation::secure-string calls pwgen" test_get_secure_string_calls_pwgen

describe "000-a-foundation.sh: sysctl mock (static/lib/mac.sh)"

test_get_processor_cores() {
    if typeset -f dot::mac::cpu-cores > /dev/null 2>&1; then
        local result=""
        result="$(dot::mac::cpu-cores 2>/dev/null)"
        assert_defined "result"
    else
        skip "dot::mac::cpu-cores not defined (mac.sh not sourced)"
    fi
}

test_get_processor_brand() {
    if typeset -f dot::mac::cpu-brand > /dev/null 2>&1; then
        local result=""
        result="$(dot::mac::cpu-brand 2>/dev/null)"
        assert_defined "result"
    else
        skip "dot::mac::cpu-brand not defined (mac.sh not sourced)"
    fi
}

it "dot::mac::cpu-cores returns a value" test_get_processor_cores
it "dot::mac::cpu-brand returns a value" test_get_processor_brand

tap_summary
