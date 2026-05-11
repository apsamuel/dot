# shellcheck shell=bash
# Test: modules/000-b-aliases.sh — alias definitions
source "${0:A:h}/../framework.sh"
source "${0:A:h}/../mocks/env.sh"
source "${0:A:h}/../mocks/tools.sh"

# Source the module under test
source_module "000-b-aliases.sh"

# ── Tests ─────────────────────────────────────────────────────────────────────

describe "000-b-aliases.sh: ls alias"

test_ls_alias_defined() {
    local result=""
    result="$(alias ls 2>/dev/null)" || true
    assert_contains "${result}" "color"
}

it "ls alias includes --color" test_ls_alias_defined

describe "000-b-aliases.sh: bat aliases"

test_ccat_alias_defined() {
    local result=""
    result="$(alias ccat 2>/dev/null)" || true
    assert_contains "${result}" "bat"
}

test_cless_alias_defined() {
    local result=""
    result="$(alias cless 2>/dev/null)" || true
    assert_contains "${result}" "bat"
}

test_ccat_no_paging() {
    local result=""
    result="$(alias ccat 2>/dev/null)" || true
    assert_contains "${result}" "never"
}

test_cless_paging() {
    local result=""
    result="$(alias cless 2>/dev/null)" || true
    assert_contains "${result}" "always"
}

it "ccat alias uses bat" test_ccat_alias_defined
it "cless alias uses bat" test_cless_alias_defined
it "ccat disables paging" test_ccat_no_paging
it "cless enables paging" test_cless_paging

tap_summary
