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
    assert_eq "0" "$?" "existing path is present"
}

test_in_path_rejects_missing() {
    local original_path="${PATH}" ret=0
    dot::paths::in /not-a-real-path || ret=$?
    assert_eq 1 "${ret}" "missing path is absent" || return 1
    assert_eq "${original_path}" "${PATH}" "membership does not change PATH"
}

it "dot::paths::in finds /usr/bin" test_in_path_finds_existing
it "dot::paths::in rejects missing path" test_in_path_rejects_missing

describe "000-a-paths.sh: dot::paths::print()"

test_print_path_produces_output() {
    local result=""
    result="$(dot::paths::print 2>/dev/null)"
    assert_defined "result" "print returns path entries"
}

test_print_path_shows_entries() {
    local result=""
    result="$(dot::paths::print 2>/dev/null)"
    # Should contain at least one path entry
    assert_contains "${result}" "/" "print includes path entries"
}

it "dot::paths::print produces output" test_print_path_produces_output
it "dot::paths::print shows path entries" test_print_path_shows_entries

describe "000-a-paths.sh: dot::paths::add()"

test_add_path_exists() {
    typeset -f dot::paths::add > /dev/null 2>&1
    assert_eq "0" "$?" "add is defined"
}

it "dot::paths::add function is defined" test_add_path_exists

describe "000-a-paths.sh: dot::paths::delete()"

test_delete_path_exists() {
    typeset -f dot::paths::delete > /dev/null 2>&1
    assert_eq "0" "$?" "delete is defined"
}

it "dot::paths::delete function is defined" test_delete_path_exists

describe "000-a-paths.sh: PATH augmentation on load"

test_dot_bin_in_path() {
    # After sourcing, $DOT_DIRECTORY/bin should be in PATH
    assert_contains "${PATH}" "${DOT_DIRECTORY}/bin" "module adds bin"
}

test_dot_scripts_in_path() {
    assert_contains "${PATH}" "${DOT_DIRECTORY}/scripts" "module adds scripts"
}

it "DOT_DIRECTORY/bin added to PATH" test_dot_bin_in_path
it "DOT_DIRECTORY/scripts added to PATH" test_dot_scripts_in_path

test_paths_help() {
    local topic="" result="" original_path="${PATH}"
    find() { _mock_record paths_help; return 99; }
    for topic in in add delete print; do
        result="$(dot::paths help "${topic}")" || return 1
        assert_contains "${result}" 'Usage:' "topic help exists" || return 1
    done
    for topic in add delete print; do
        dot::paths "${topic}" --help >/dev/null || return 1
    done
    assert_eq "${original_path}" "${PATH}" "help never changes PATH" || return 1
    assert_not_called paths_help "help never calls find"
}

test_paths_add_delete() {
    local target_path="${TEST_TMPDIR}/with spaces.[x]" original_path="${PATH}"
    mkdir -p "${target_path}" || return 1
    find() { printf '%s\n' executable; }
    dot::paths add "${target_path}" || return 1
    dot::paths add "${target_path}" || return 1
    assert_eq "${original_path}:${target_path}" "${PATH}" "quoted directory added exactly once" || return 1
    dot::paths delete "${target_path}" || return 1
    assert_eq "${original_path}" "${PATH}" "deletion updates PATH exactly"
}

test_paths_failures() {
    local ret=0 original_path="${PATH}"
    dot::paths add >/dev/null 2>&1 || ret=$?
    assert_eq 1 "${ret}" "missing operand returns safely" || return 1
    ret=0
    dot::paths delete --typo >/dev/null 2>&1 || ret=$?
    assert_eq 1 "${ret}" "invalid options fail before mutation" || return 1
    ret=0
    find() { return 31; }
    dot::paths add "${TEST_TMPDIR}" >/dev/null 2>&1 || ret=$?
    assert_eq 31 "${ret}" "discovery failure propagates" || return 1
    assert_eq "${original_path}" "${PATH}" "failure leaves PATH unchanged"
}

it "contextual help has no side effects" test_paths_help
it "add and delete preserve quoted directories" test_paths_add_delete
it "invalid input and backend errors preserve PATH" test_paths_failures

tap_summary
