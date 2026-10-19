# shellcheck shell=bash
# shellcheck source=/dev/null
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"
[[ -z "${ZSH_VERSION:-}" ]] || zmodload zsh/zutil
dot::static::logging::loading() { :; }
# shellcheck disable=SC2034
SSH_KEYS=()
bindkey() { :; }
zle() { :; }
source_module "000-b-zsh.sh"

describe "000-b-zsh.sh: style interface"

test_zstyle_help() {
    [[ -n "${ZSH_VERSION:-}" ]] || { skip 'ZSH-only builtin'; return; }
    local topic="" direct="" result=""
    zstyle() { _mock_record styles_help; return 99; }
    for topic in list show dump; do
        result="$(dot::zstyle help "${topic}")" || return 1
        direct="$("dot::zstyle::${topic}" --help)" || return 1
        assert_eq "${result}" "${direct}" "${topic} help agrees" || return 1
    done
    assert_not_called styles_help "help does not invoke zstyle"
}

test_zstyle_queries() {
    [[ -n "${ZSH_VERSION:-}" ]] || { skip 'ZSH-only builtin'; return; }
    local result="" ret=0
    zstyle ':dot:test' sample 'two words'
    result="$(dot::zstyle show ':dot:test' sample)" || return 1
    assert_eq ':dot:test sample = two words' "${result}" "show preserves value" || return 1
    dot::zstyle show ':dot:test' missing >/dev/null || ret=$?
    assert_eq 1 "${ret}" "unset style is false" || return 1
    result="$(dot::zstyle list ':dot:test')" || return 1
    assert_contains "${result}" 'two words' "list retains re-sourceable values"
}

test_zstyle_dump() {
    [[ -n "${ZSH_VERSION:-}" ]] || { skip 'ZSH-only builtin'; return; }
    local ret=0
    printf '%s' original >"${TEST_TMPDIR}/styles"
    dot::zstyle dump "${TEST_TMPDIR}/styles" extra >/dev/null 2>&1 || ret=$?
    assert_eq 2 "${ret}" "extra operands rejected" || return 1
    assert_eq original "$(<"${TEST_TMPDIR}/styles")" "invalid dump does not truncate" || return 1
    dot::zstyle dump "${TEST_TMPDIR}/styles" || return 1
    assert_contains "$(<"${TEST_TMPDIR}/styles")" 'frequency' "dump writes styles"
}

test_zstyle_failure() {
    [[ -n "${ZSH_VERSION:-}" ]] || { skip 'ZSH-only builtin'; return; }
    local ret=0
    zstyle() { return 17; }
    dot::zstyle list >/dev/null || ret=$?
    assert_eq 17 "${ret}" "list propagates builtin failure"
}

it "help avoids queries" test_zstyle_help
it "queries preserve values and unset status" test_zstyle_queries
it "dump validates before opening its file" test_zstyle_dump
it "list preserves failures" test_zstyle_failure
tap_summary
