# shellcheck shell=bash
# shellcheck source=/dev/null
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"
dot::static::logging::loading() { :; }
source_module "000-c-mac.sh"

describe "000-c-mac.sh: CPU query interface"

test_mac_help() {
    local topic="" direct="" result=""
    sysctl() { _mock_record mac_help; return 99; }
    for topic in cpu-cores cpu-brand; do
        result="$(dot::mac help "${topic}")" || return 1
        direct="$("dot::mac::${topic}" --help)" || return 1
        assert_eq "${result}" "${direct}" "${topic} help agrees" || return 1
        assert_exit_code 1 dot::mac "${topic}" extra || return 1
    done
    assert_not_called mac_help "help and invalid input do not query sysctl"
}

test_mac_queries() {
    local result="" ret=0
    sysctl() { printf '<%s>\n' "$@"; return 0; }
    result="$(dot::mac cpu-cores)" || return 1
    assert_eq $'<-n>\n<machdep.cpu.core_count>' "${result}" "core query unchanged" || return 1
    sysctl() { printf '<%s>\n' "$@"; return 19; }
    result="$(dot::mac cpu-brand)" || ret=$?
    assert_eq $'<-n>\n<machdep.cpu.brand_string>' "${result}" "brand query unchanged" || return 1
    assert_eq 19 "${ret}" "backend error propagates"
}

test_mac_missing_dependency() {
    local ret=0
    unset -f sysctl 2>/dev/null || true
    # shellcheck disable=SC2123
    PATH="${TEST_TMPDIR}/no-tools"
    dot::mac cpu-cores >/dev/null 2>"${TEST_TMPDIR}/mac-errors" || ret=$?
    assert_eq 1 "${ret}" "missing sysctl fails" || return 1
    assert_contains "$(<"${TEST_TMPDIR}/mac-errors")" 'sysctl is required' "dependency is named"
}

it "help and invalid input avoid host queries" test_mac_help
it "queries preserve arguments and status" test_mac_queries
it "missing dependencies fail clearly" test_mac_missing_dependency
tap_summary
