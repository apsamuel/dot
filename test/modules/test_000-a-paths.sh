#!/usr/bin/env zsh
# Test: modules/000-a-paths.sh — PATH management
source "${0:A:h}/../framework.sh"
source "${0:A:h}/../mocks/env.sh"
source "${0:A:h}/../mocks/tools.sh"

# Provide stub implementations for splitString/joinList used by addPath/deletePath
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

describe "000-a-paths.sh: inPath()"

test_in_path_finds_existing() {
    # /usr/bin should always be in PATH
    inPath "/usr/bin"
    assert_eq "0" "$?"
}

test_in_path_rejects_missing() {
    inPath "/nonexistent/fake/path"
    local rc=$?
    assert_eq "1" "${rc}"
}

it "inPath finds /usr/bin" test_in_path_finds_existing
it "inPath rejects missing path" test_in_path_rejects_missing

describe "000-a-paths.sh: printPath()"

test_print_path_produces_output() {
    local result=""
    result="$(printPath 2>/dev/null)"
    assert_defined "result"
}

test_print_path_shows_entries() {
    local result=""
    result="$(printPath 2>/dev/null)"
    # Should contain at least one path entry
    assert_contains "${result}" "/"
}

it "printPath produces output" test_print_path_produces_output
it "printPath shows path entries" test_print_path_shows_entries

describe "000-a-paths.sh: addPath()"

test_add_path_no_args_fails() {
    addPath > /dev/null 2>&1
    local rc=$?
    assert_eq "1" "${rc}"
}

it "addPath with no args returns error" test_add_path_no_args_fails

describe "000-a-paths.sh: deletePath()"

test_delete_path_no_args_fails() {
    deletePath > /dev/null 2>&1
    local rc=$?
    assert_eq "1" "${rc}"
}

it "deletePath with no args returns error" test_delete_path_no_args_fails

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
