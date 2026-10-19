# shellcheck shell=bash
# Test: modules/000-a-secrets.sh — secrets loading & masking
# Portable bootstrap — works under bash and zsh
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"

# Source the module under test
source_module "000-a-secrets.sh"

# ── Tests ─────────────────────────────────────────────────────────────────────

describe "000-a-secrets.sh: dot::secrets::load()"

test_load_secrets_calls_jq() {
    mock_reset_calls
    dot::secrets::load 2>/dev/null || true
    assert_called "jq" 'load queries jq'
}

test_load_secrets_function_exists() {
    typeset -f dot::secrets::load > /dev/null 2>&1
    local rc=$?
    assert_eq "0" "${rc}" 'load exists'
}

it "dot::secrets::load calls jq" test_load_secrets_calls_jq
it "dot::secrets::load function is defined" test_load_secrets_function_exists

describe "000-a-secrets.sh: dot::secrets::_load()"

test_private_load_secrets_exists() {
    typeset -f dot::secrets::_load > /dev/null 2>&1
    local rc=$?
    assert_eq "0" "${rc}" 'private load exists'
}

it "dot::secrets::_load function is defined" test_private_load_secrets_exists

describe "000-a-secrets.sh: dot::secrets::mask()"

test_mask_secrets_exists() {
    typeset -f dot::secrets::mask > /dev/null 2>&1
    local rc=$?
    assert_eq "0" "${rc}" 'mask exists'
}

it "dot::secrets::mask function is defined" test_mask_secrets_exists

describe "000-a-secrets.sh: dot::secrets::reload-options()"

test_reload_options_exists() {
    typeset -f dot::secrets::reload-options > /dev/null 2>&1
    local rc=$?
    assert_eq "0" "${rc}" 'reload exists'
}

test_reload_options_calls_yq() {
    setopt() { return 0; }
    mock_reset_calls
    dot::secrets::reload-options 2>/dev/null || true
    assert_called "yq" 'reload queries yq'
}

it "dot::secrets::reload-options function is defined" test_reload_options_exists
it "dot::secrets::reload-options calls yq" test_reload_options_calls_yq

test_secrets_help() {
    mock_reset_calls
    local topic=""
    for topic in load mask reload-options; do
        assert_eq "$(dot::secrets help "${topic}")" "$(dot::secrets "${topic}" --help)" 'help agrees' || return 1
    done
    assert_not_called jq 'help never reads secrets' || return 1
    assert_not_called yq 'help never reads config'
}

test_secrets_literal_values() {
    jq() { command jq "$@"; }
    local ICLOUD="${TEST_TMPDIR}/literal-secrets"
    mkdir -p "${ICLOUD}/dot"
    printf '%s\n' '{"DOT_TEST_SECRET":"$(false); space [.*]"}' > "${ICLOUD}/dot/secrets.json"
    dot::secrets load || return 1
    assert_eq '$(false); space [.*]' "${DOT_TEST_SECRET}" 'values remain literal' || return 1
    assert_eq '************** --help' "$(dot::secrets::mask '$(false); space [.*] --help')" 'masking is literal' || return 1
    printf '%s\n' '{"secret_value":"literal value","DOT_TEST_UNEXPORTED":"private"}' > "${ICLOUD}/dot/secrets.json"
    dot::secrets load || return 1
    assert_eq 'literal value' "${secret_value:-}" 'loader local names do not swallow assignments' || return 1
    assert_eq 'private' "${DOT_TEST_UNEXPORTED:-}" 'new variable is available in shell' || return 1
    if command env | command grep -q '^DOT_TEST_UNEXPORTED='; then return 1; fi
    printf '%s\n' '{"_dot_secrets_value":"reserved"}' > "${ICLOUD}/dot/secrets.json"
    assert_exit_code 1 dot::secrets load || return 1
    printf '%s\n' '{"bad-name":"value"}' > "${ICLOUD}/dot/secrets.json"
    assert_exit_code 1 dot::secrets load
}

test_secrets_failures() {
    jq() { return 24; }
    assert_exit_code 1 dot::secrets load || return 1
    assert_exit_code 1 dot::secrets mask text || return 1
    setopt() { return 0; }
    yq() { return 24; }
    assert_exit_code 24 dot::secrets reload-options
}

it 'help reads no secret or option data' test_secrets_help
it 'load and mask preserve literal punctuation without shell evaluation' test_secrets_literal_values
it 'secret and option backend failures stay failures' test_secrets_failures
tap_summary
