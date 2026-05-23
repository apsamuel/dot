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
    assert_called "jq"
}

test_load_secrets_function_exists() {
    typeset -f dot::secrets::load > /dev/null 2>&1
    local rc=$?
    assert_eq "0" "${rc}"
}

it "dot::secrets::load calls jq" test_load_secrets_calls_jq
it "dot::secrets::load function is defined" test_load_secrets_function_exists

describe "000-a-secrets.sh: dot::secrets::_load()"

test_private_load_secrets_exists() {
    typeset -f dot::secrets::_load > /dev/null 2>&1
    local rc=$?
    assert_eq "0" "${rc}"
}

it "dot::secrets::_load function is defined" test_private_load_secrets_exists

describe "000-a-secrets.sh: maskSecrets()"

test_mask_secrets_exists() {
    typeset -f maskSecrets > /dev/null 2>&1
    local rc=$?
    assert_eq "0" "${rc}"
}

it "maskSecrets function is defined" test_mask_secrets_exists

describe "000-a-secrets.sh: dot::secrets::reload-options()"

test_reload_options_exists() {
    typeset -f dot::secrets::reload-options > /dev/null 2>&1
    local rc=$?
    assert_eq "0" "${rc}"
}

test_reload_options_calls_yq() {
    mock_reset_calls
    dot::secrets::reload-options 2>/dev/null || true
    assert_called "yq"
}

it "dot::secrets::reload-options function is defined" test_reload_options_exists
it "dot::secrets::reload-options calls yq" test_reload_options_calls_yq

tap_summary
