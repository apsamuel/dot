# shellcheck shell=bash
# shellcheck source=/dev/null
# Test: modules/000-a-config.sh — config access layer
# Portable bootstrap — works under bash and zsh
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"

# Source the module under test
source_module "000-a-config.sh"

# ── Tests ─────────────────────────────────────────────────────────────────────

describe "000-a-config.sh: pager exports"

test_less_exported() {
    assert_defined "LESS" "LESS is set"
}

test_bat_pager() {
    assert_defined "BAT_PAGER" "BAT_PAGER is set"
}

test_git_pager() {
    assert_defined "GIT_PAGER" "GIT_PAGER is set"
}

test_manpager() {
    assert_defined "MANPAGER" "MANPAGER is set"
}

it "LESS is exported" test_less_exported
it "BAT_PAGER is exported" test_bat_pager
it "GIT_PAGER is exported" test_git_pager
it "MANPAGER is exported" test_manpager

describe "000-a-config.sh: dot::config::get()"

test_get_config_calls_yq() {
    mock_reset_calls
    dot::config::get > /dev/null 2>&1
    assert_called "yq" "get queries configuration"
}

it "dot::config::get calls yq" test_get_config_calls_yq

describe "000-a-config.sh: dot::config::theme()"

test_get_theme_returns_value() {
    local result=""
    result="$(dot::config::theme 2>/dev/null)"
    assert_eq "powerlevel10k/powerlevel10k" "${result}" "theme value is unchanged"
}

test_get_theme_calls_yq() {
    mock_reset_calls
    dot::config::theme > /dev/null 2>&1
    assert_called "yq" "theme queries configuration"
}

it "dot::config::theme returns the theme name" test_get_theme_returns_value
it "dot::config::theme calls yq" test_get_theme_calls_yq

describe "000-a-config.sh: dot::config::condition()"

test_get_condition_returns_value() {
    local result=""
    result="$(dot::config::condition "network" "home" 2>/dev/null)"
    # Our mock returns "true" for .conditions.* queries
    assert_eq "true" "${result}" "condition result is unchanged"
}

test_get_condition_calls_yq() {
    mock_reset_calls
    dot::config::condition "host" "home" > /dev/null 2>&1
    assert_called "yq" "condition queries configuration"
}

it "dot::config::condition returns a value" test_get_condition_returns_value
it "dot::config::condition calls yq" test_get_condition_calls_yq

describe "000-a-config.sh: DOT_SHELL_DATA"

test_dot_shell_data_defined() {
    assert_defined "DOT_SHELL_DATA" "configuration path is set"
}

it "DOT_SHELL_DATA is defined" test_dot_shell_data_defined

test_config_help() {
    local topic="" result="" direct=""
    yq() { _mock_record config_help; return 99; }
    for topic in get theme condition; do
        result="$(dot::config help "${topic}")" || return 1
        direct="$(dot::config "${topic}" --help)" || return 1
        assert_eq "${result}" "${direct}" "topic and command help agree" || return 1
        assert_contains "${result}" 'Usage:' "help includes usage" || return 1
    done
    assert_not_called config_help "help never queries configuration"
}

test_config_invalid_arguments() {
    local action="" ret=0
    yq() { _mock_record config_invalid; return 99; }
    for action in get theme condition _query unknown; do
        ret=0
        dot::config "${action}" unexpected >/dev/null 2>"${TEST_TMPDIR}/config-errors" || ret=$?
        assert_eq 1 "${ret}" "invalid invocation fails without aborting shell" || return 1
        [[ -s "${TEST_TMPDIR}/config-errors" ]] || return 1
    done
    assert_not_called config_invalid "invalid invocation never queries configuration"
}

test_config_backend_failure() {
    local ret=0 result=""
    yq() { printf '%s\n' 'query failed' >&2; return 29; }
    result="$(dot::config theme 2>"${TEST_TMPDIR}/config-errors")" || ret=$?
    assert_eq 29 "${ret}" "query status propagates" || return 1
    assert_eq '' "${result}" "failure does not pollute stdout" || return 1
    assert_eq 'query failed' "$(<"${TEST_TMPDIR}/config-errors")" "query diagnostic remains visible"
}

it "help does not query configuration" test_config_help
it "invalid inputs fail before querying" test_config_invalid_arguments
it "backend status and diagnostics propagate" test_config_backend_failure

tap_summary
