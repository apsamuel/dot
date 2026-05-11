#!/usr/bin/env zsh
# Test: modules/000-a-foundation.sh — baseline env + utility functions
source "${0:A:h}/../framework.sh"
source "${0:A:h}/../mocks/env.sh"
source "${0:A:h}/../mocks/tools.sh"

# Source the module under test
source_module "000-a-foundation.sh"

# ── Tests ─────────────────────────────────────────────────────────────────────

describe "000-a-foundation.sh: getShellName()"

test_get_shell_name_returns_string() {
    local result=""
    result="$(getShellName 2>/dev/null)"
    assert_defined "result"
}

test_get_shell_name_lowercase() {
    local result=""
    result="$(getShellName 2>/dev/null)"
    # Should be lowercase (no uppercase chars)
    local lower=""
    lower="$(echo "${result}" | tr '[:upper:]' '[:lower:]')"
    assert_eq "${lower}" "${result}"
}

it "getShellName returns a string" test_get_shell_name_returns_string
it "getShellName returns lowercase" test_get_shell_name_lowercase

describe "000-a-foundation.sh: getSecureString()"

test_get_secure_string_default_length() {
    local result=""
    result="$(getSecureString 2>/dev/null)"
    assert_defined "result"
}

test_get_secure_string_custom_length() {
    local result=""
    result="$(getSecureString 20 2>/dev/null)"
    assert_defined "result"
}

test_get_secure_string_calls_pwgen() {
    mock_reset_calls
    getSecureString 10 > /dev/null 2>&1
    assert_called "pwgen"
}

it "getSecureString returns a value" test_get_secure_string_default_length
it "getSecureString accepts a length arg" test_get_secure_string_custom_length
it "getSecureString calls pwgen" test_get_secure_string_calls_pwgen

describe "000-a-foundation.sh: sysctl mock (static/lib/mac.sh)"

test_get_processor_cores() {
    if typeset -f getProcessorCores > /dev/null 2>&1; then
        local result=""
        result="$(getProcessorCores 2>/dev/null)"
        assert_defined "result"
    else
        skip "getProcessorCores not defined (mac.sh not sourced)"
    fi
}

test_get_processor_brand() {
    if typeset -f getProcessorBrand > /dev/null 2>&1; then
        local result=""
        result="$(getProcessorBrand 2>/dev/null)"
        assert_defined "result"
    else
        skip "getProcessorBrand not defined (mac.sh not sourced)"
    fi
}

it "getProcessorCores returns a value" test_get_processor_cores
it "getProcessorBrand returns a value" test_get_processor_brand

tap_summary
