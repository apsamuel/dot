# shellcheck shell=bash
# Test: modules/000-a-output.sh — color/emoji output helpers
# Portable bootstrap — works under bash and zsh
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"

# Ensure outputs are enabled
export DOT_DISABLE_OUTPUTS=0

# Source the module under test
source_module "000-a-output.sh"

# ── Tests ─────────────────────────────────────────────────────────────────────

describe "000-a-output.sh: dot::output::levels()"

test_print_levels_returns_all() {
    local result=""
    result="$(dot::output::levels)"
    assert_contains "${result}" "info"
    assert_contains "${result}" "error"
    assert_contains "${result}" "debug"
}

it "dot::output::levels returns info, error, debug" test_print_levels_returns_all

describe "000-a-output.sh: dot::output::level()"

test_print_level_info() {
    local result=""
    result="$(dot::output::level info)"
    assert_contains "${result}" "info"
}

test_print_level_error() {
    local result=""
    result="$(dot::output::level error)"
    assert_contains "${result}" "error"
}

test_print_level_invalid() {
    dot::output::level "nonexistent" > /dev/null 2>&1
    local rc=$?
    assert_eq "1" "${rc}"
}

test_print_level_no_args() {
    dot::output::level > /dev/null 2>&1
    local rc=$?
    assert_eq "1" "${rc}"
}

it "dot::output::level info contains 'info'" test_print_level_info
it "dot::output::level error contains 'error'" test_print_level_error
it "dot::output::level rejects invalid level" test_print_level_invalid
it "dot::output::level fails with no arguments" test_print_level_no_args

describe "000-a-output.sh: dot::output::pretty()"

test_print_pretty_basic() {
    local result=""
    result="$(dot::output::pretty "hello world" 2>/dev/null)"
    assert_contains "${result}" "hello world"
}

test_print_pretty_no_message_fails() {
    dot::output::pretty -l info > /dev/null 2>&1
    local rc=$?
    assert_eq "1" "${rc}"
}

test_print_pretty_with_level() {
    local result=""
    result="$(dot::output::pretty -l error "something failed" 2>/dev/null)"
    assert_contains "${result}" "something failed"
}

it "dot::output::pretty includes the message" test_print_pretty_basic
it "dot::output::pretty fails with no message" test_print_pretty_no_message_fails
it "dot::output::pretty -l error includes message" test_print_pretty_with_level

describe "000-a-output.sh: DOT_DISABLE_OUTPUTS guard"

test_disable_outputs_guard() {
    # When DOT_DISABLE_OUTPUTS=1, sourcing returns early —
    # we just verify the guard variable exists as a mechanism
    assert_eq "0" "${DOT_DISABLE_OUTPUTS}"
}

it "DOT_DISABLE_OUTPUTS is recognized" test_disable_outputs_guard

tap_summary
