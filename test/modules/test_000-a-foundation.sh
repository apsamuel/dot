# shellcheck shell=bash
# Test: modules/000-a-foundation.sh — baseline env + utility functions
# Portable bootstrap — works under bash and zsh
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"

# Source the module under test
tic() { _mock_record tic; return 97; }
infocmp() { _mock_record infocmp; return 96; }
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
    assert_eq "${lower}" "${result}" "shell name is lowercase"
}

it "dot::foundation::shell-name returns a string" test_get_shell_name_returns_string
it "dot::foundation::shell-name returns lowercase" test_get_shell_name_lowercase

describe "000-a-foundation.sh: dot::foundation::secure-string()"

test_get_secure_string_default_length() {
    local result=""
    result="$(dot::foundation::secure-string 2>/dev/null)"
    assert_defined "result" "default password is nonempty"
}

test_get_secure_string_custom_length() {
    local result=""
    result="$(dot::foundation::secure-string 20 2>/dev/null)"
    assert_defined "result" "custom password is nonempty"
}

test_get_secure_string_calls_pwgen() {
    mock_reset_calls
    dot::foundation::secure-string 10 > /dev/null 2>&1
    assert_called "pwgen" "password generator is invoked"
}

it "dot::foundation::secure-string returns a value" test_get_secure_string_default_length
it "dot::foundation::secure-string accepts a length arg" test_get_secure_string_custom_length
it "dot::foundation::secure-string calls pwgen" test_get_secure_string_calls_pwgen

describe "000-a-foundation.sh: sysctl mock (static/lib/mac.sh)"

test_get_processor_cores() {
    if typeset -f dot::mac::cpu-cores > /dev/null 2>&1; then
        local result=""
        result="$(dot::mac::cpu-cores 2>/dev/null)"
        assert_defined "result" "core count is nonempty"
    else
        skip "dot::mac::cpu-cores not defined (mac.sh not sourced)"
    fi
}

test_get_processor_brand() {
    if typeset -f dot::mac::cpu-brand > /dev/null 2>&1; then
        local result=""
        result="$(dot::mac::cpu-brand 2>/dev/null)"
        assert_defined "result" "brand is nonempty"
    else
        skip "dot::mac::cpu-brand not defined (mac.sh not sourced)"
    fi
}

it "dot::mac::cpu-cores returns a value" test_get_processor_cores
it "dot::mac::cpu-brand returns a value" test_get_processor_brand

test_foundation_help() {
    local topic="" result=""
    for topic in compile-terminfo shell-name secure-string; do
        result="$(dot::foundation help "${topic}")" || return 1
        assert_contains "${result}" "dot::foundation::${topic}" 'leaf usage is documented' || return 1
        dot::foundation "${topic}" --help >/dev/null || return 1
    done
    assert_not_called tic 'source and help do not compile' || return 1
    assert_not_called infocmp 'source and help do not inspect terminfo'
}

test_foundation_failures() {
    assert_exit_code 96 dot::foundation compile-terminfo || return 1
    assert_not_called tic 'failed infocmp prevents compilation' || return 1
    assert_exit_code 1 dot::foundation secure-string invalid || return 1
    assert_exit_code 1 dot::foundation secure-string 0 || return 1
    pwgen() { return 23; }
    assert_exit_code 23 dot::foundation secure-string 12
}

it 'foundation help and sourcing avoid tools' test_foundation_help
it 'foundation rejects bad inputs and propagates failures' test_foundation_failures
tap_summary
