# shellcheck shell=bash
# shellcheck source=/dev/null
# shellcheck disable=SC2123
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"
source_module "000-a-tools.sh"

describe "000-a-tools.sh: preview interface"

test_tools_help() {
    local result="" direct=""
    fzf() { _mock_record tools_help; return 99; }
    result="$(dot::tools help preview)" || return 1
    direct="$(dot::tools::preview --help)" || return 1
    assert_eq "${result}" "${direct}" "direct and topic help agree" || return 1
    assert_contains "${result}" 'FZF_OPTIONS' "forwarding is documented" || return 1
    assert_not_called tools_help "help does not invoke fzf"
}

test_tools_forwarding() {
    local result="" ret=0
    bat() { return 0; }
    fzf() { printf '<%s>\n' "$@"; return 23; }
    result="$(dot::tools preview -- --filter 'file name')" || ret=$?
    assert_eq 23 "${ret}" "fzf status propagates" || return 1
    assert_eq $'<--preview>\n<bat --color=always -- {-1}>\n<--filter>\n<file name>' "${result}" "fzf arguments stay separate"
}

test_tools_plain_fallback() {
    local result=""
    unset -f bat 2>/dev/null || true
    cat() { return 0; }
    fzf() { printf '%s\n' "$2"; }
    PATH="${TEST_TMPDIR}/no-tools"
    result="$(dot::tools preview)" || return 1
    assert_eq 'cat -- {-1}' "${result}" "cat previews replace missing bat"
}

test_tools_missing_dependency() {
    local ret=0
    unset -f fzf 2>/dev/null || true
    PATH="${TEST_TMPDIR}/no-tools"
    dot::tools preview >/dev/null 2>"${TEST_TMPDIR}/tools-errors" || ret=$?
    assert_eq 1 "${ret}" "missing fzf fails" || return 1
    assert_contains "$(<"${TEST_TMPDIR}/tools-errors")" 'fzf is required' "diagnostic names dependency"
}

it "help runs no tools" test_tools_help
it "arguments and statuses are preserved" test_tools_forwarding
it "missing bat uses a plain preview" test_tools_plain_fallback
it "missing fzf is reported" test_tools_missing_dependency
tap_summary
