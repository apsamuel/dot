# shellcheck shell=bash
# Test: modules/000-a-config.sh — config access layer
source "${0:A:h}/../framework.sh"
source "${0:A:h}/../mocks/env.sh"
source "${0:A:h}/../mocks/tools.sh"

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

describe "000-a-config.sh: getConfig()"

test_get_config_calls_yq() {
    mock_reset_calls
    getConfig > /dev/null 2>&1
    assert_called "yq"
}

it "getConfig calls yq" test_get_config_calls_yq

describe "000-a-config.sh: getTheme()"

test_get_theme_returns_value() {
    local result=""
    result="$(getTheme 2>/dev/null)"
    assert_eq "powerlevel10k/powerlevel10k" "${result}"
}

test_get_theme_calls_yq() {
    mock_reset_calls
    getTheme > /dev/null 2>&1
    assert_called "yq"
}

it "getTheme returns the theme name" test_get_theme_returns_value
it "getTheme calls yq" test_get_theme_calls_yq

describe "000-a-config.sh: getCondition()"

test_get_condition_returns_value() {
    local result=""
    result="$(getCondition "network" "home" 2>/dev/null)"
    # Our mock returns "true" for .conditions.* queries
    assert_eq "true" "${result}"
}

test_get_condition_calls_yq() {
    mock_reset_calls
    getCondition "host" "home" > /dev/null 2>&1
    assert_called "yq"
}

it "getCondition returns a value" test_get_condition_returns_value
it "getCondition calls yq" test_get_condition_calls_yq

describe "000-a-config.sh: DOT_SHELL_DATA"

test_dot_shell_data_defined() {
    assert_defined "DOT_SHELL_DATA"
}

it "DOT_SHELL_DATA is defined" test_dot_shell_data_defined

tap_summary
