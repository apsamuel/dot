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
    assert_defined "LESS"
}

test_bat_pager() {
    assert_defined "BAT_PAGER"
}

test_git_pager() {
    assert_defined "GIT_PAGER"
}

test_manpager() {
    assert_defined "MANPAGER"
}

it "LESS is exported" test_less_exported
it "BAT_PAGER is exported" test_bat_pager
it "GIT_PAGER is exported" test_git_pager
it "MANPAGER is exported" test_manpager

describe "000-a-config.sh: dot::config::get()"

test_get_config_calls_yq() {
    mock_reset_calls
    dot::config::get > /dev/null 2>&1
    assert_called "yq"
}

it "dot::config::get calls yq" test_get_config_calls_yq

describe "000-a-config.sh: dot::config::theme()"

test_get_theme_returns_value() {
    local result=""
    result="$(dot::config::theme 2>/dev/null)"
    assert_eq "powerlevel10k/powerlevel10k" "${result}"
}

test_get_theme_calls_yq() {
    mock_reset_calls
    dot::config::theme > /dev/null 2>&1
    assert_called "yq"
}

it "dot::config::theme returns the theme name" test_get_theme_returns_value
it "dot::config::theme calls yq" test_get_theme_calls_yq

describe "000-a-config.sh: dot::config::condition()"

test_get_condition_returns_value() {
    local result=""
    result="$(dot::config::condition "network" "home" 2>/dev/null)"
    # Our mock returns "true" for .conditions.* queries
    assert_eq "true" "${result}"
}

test_get_condition_calls_yq() {
    mock_reset_calls
    dot::config::condition "host" "home" > /dev/null 2>&1
    assert_called "yq"
}

it "dot::config::condition returns a value" test_get_condition_returns_value
it "dot::config::condition calls yq" test_get_condition_calls_yq

describe "000-a-config.sh: DOT_SHELL_DATA"

test_dot_shell_data_defined() {
    assert_defined "DOT_SHELL_DATA"
}

it "DOT_SHELL_DATA is defined" test_dot_shell_data_defined

tap_summary
