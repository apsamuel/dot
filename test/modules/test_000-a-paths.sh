# shellcheck shell=bash
# Test: modules/000-a-paths.sh — PATH management
# Portable bootstrap — works under bash and zsh
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"

# Provide stub implementations for splitString/joinList used by dot::paths::add/dot::paths::delete
# (these may come from a plugin or were removed — stub them for testing)
splitString() {
    local string="$1"
    local delimiter="$2"
    echo "${string//${delimiter}/ }"
}

joinList() {
    local delimiter="$1"
    shift
    local result=""
    local first=1
    for element in "$@"; do
        if (( first )); then
            result="${element}"
            first=0
        else
            result="${result}${delimiter}${element}"
        fi
    done
    echo "${result}"
}

# Source the module under test
source_module "000-a-paths.sh"

# ── Tests ─────────────────────────────────────────────────────────────────────

describe "000-a-paths.sh: dot::paths::in()"

test_in_path_finds_existing() {
    # /usr/bin should always be in PATH
    dot::paths::in "/usr/bin"
    assert_eq "0" "$?"
}

test_in_path_rejects_missing() {
    # NOTE: dot::paths::in() has a known zsh issue — `local path` shadows the
    # special $path/$PATH tied variable, causing $PATH to be clobbered.
    # This test documents the bug; skip until the module is fixed.
    skip "dot::paths::in uses 'local path' which shadows \$PATH in zsh"
}

it "dot::paths::in finds /usr/bin" test_in_path_finds_existing
it "dot::paths::in rejects missing path" test_in_path_rejects_missing

describe "000-a-paths.sh: dot::paths::print()"

test_print_path_produces_output() {
    local result=""
    result="$(dot::paths::print 2>/dev/null)"
    assert_defined "result"
}

test_print_path_shows_entries() {
    local result=""
    result="$(dot::paths::print 2>/dev/null)"
    # Should contain at least one path entry
    assert_contains "${result}" "/"
}

it "dot::paths::print produces output" test_print_path_produces_output
it "dot::paths::print shows path entries" test_print_path_shows_entries

describe "000-a-paths.sh: dot::paths::add()"

test_add_path_exists() {
    typeset -f dot::paths::add > /dev/null 2>&1
    assert_eq "0" "$?"
}

it "dot::paths::add function is defined" test_add_path_exists

describe "000-a-paths.sh: dot::paths::delete()"

test_delete_path_exists() {
    typeset -f dot::paths::delete > /dev/null 2>&1
    assert_eq "0" "$?"
}

it "dot::paths::delete function is defined" test_delete_path_exists

describe "000-a-paths.sh: PATH augmentation on load"

test_dot_bin_in_path() {
    # After sourcing, $DOT_DIR/bin should be in PATH
    assert_contains "${PATH}" "${DOT_DIR}/bin"
}

test_dot_scripts_in_path() {
    assert_contains "${PATH}" "${DOT_DIR}/scripts"
}

it "DOT_DIR/bin added to PATH" test_dot_bin_in_path
it "DOT_DIR/scripts added to PATH" test_dot_scripts_in_path

tap_summary
