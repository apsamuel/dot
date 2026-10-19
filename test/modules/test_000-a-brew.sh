# shellcheck shell=bash
# shellcheck source=/dev/null
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"
export DOT_DISABLE_BREW=0 OPERATING_SYSTEM=test CPU_ARCHITECTURE=arm64
dot::static::logging::loading() { :; }
source_module "000-a-brew.sh"
test_setup() { mock_reset_calls; }

test_brew_help() {
    local topic="" result=""
    for topic in version installed install update upgrade list resolve dump recipe load info bottle-files; do
        result="$(dot::brew help "${topic}")" || return 1
        assert_eq "${result}" "$(dot::brew "${topic}" --help)" 'help agrees' || return 1
    done
    assert_not_called brew 'help never invokes brew'
}

test_brew_options() {
    brew() { printf '<%s>\n' "$@"; }
    assert_eq "$(dot::brew list -t cask)" "$(dot::brew list --type cask)" 'long type agrees' || return 1
    dot::brew list -t formula >/dev/null || return 1
    assert_eq $'<list>\n<-1>\n<--cask>' "$(dot::brew list -tcask)" 'repeated calls reset parser' || return 1
    assert_exit_code 1 dot::brew list --type || return 1
    assert_exit_code 1 dot::brew install --arch unknown pkg || return 1
    assert_exit_code 1 dot::brew installed --type invalid pkg
}

test_brew_forwarding() {
    brew() { printf '<%s>\n' "$@"; return 24; }
    local result="" ret=0
    result="$(dot::brew info 'quoted package' --installed)" || ret=$?
    assert_eq 24 "${ret}" 'status survives' || return 1
    assert_eq $'<info>\n<--json>\n<quoted package>\n<--installed>' "${result}" 'argv survives' || return 1
    assert_exit_code 24 dot::brew upgrade
}

it 'contextual help bypasses brew' test_brew_help
it 'type and architecture options are validated' test_brew_options
it 'forwarded arguments and failures survive' test_brew_forwarding
tap_summary
