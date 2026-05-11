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

describe "000-a-secrets.sh: loadSecrets()"

test_load_secrets_calls_jq() {
    mock_reset_calls
    loadSecrets 2>/dev/null || true
    assert_called "jq"
}

test_load_secrets_function_exists() {
    typeset -f loadSecrets > /dev/null 2>&1
    local rc=$?
    assert_eq "0" "${rc}"
}

it "loadSecrets calls jq" test_load_secrets_calls_jq
it "loadSecrets function is defined" test_load_secrets_function_exists

describe "000-a-secrets.sh: __load_secrets()"

test_private_load_secrets_exists() {
    typeset -f __load_secrets > /dev/null 2>&1
    local rc=$?
    assert_eq "0" "${rc}"
}

it "__load_secrets function is defined" test_private_load_secrets_exists

describe "000-a-secrets.sh: maskSecrets()"

test_mask_secrets_exists() {
    typeset -f maskSecrets > /dev/null 2>&1
    local rc=$?
    assert_eq "0" "${rc}"
}

it "maskSecrets function is defined" test_mask_secrets_exists

describe "000-a-secrets.sh: reloadOptions()"

test_reload_options_exists() {
    typeset -f reloadOptions > /dev/null 2>&1
    local rc=$?
    assert_eq "0" "${rc}"
}

test_reload_options_calls_yq() {
    mock_reset_calls
    reloadOptions 2>/dev/null || true
    assert_called "yq"
}

it "reloadOptions function is defined" test_reload_options_exists
it "reloadOptions calls yq" test_reload_options_calls_yq

tap_summary
