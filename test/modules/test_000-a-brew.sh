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

test_brew_dump() {
    local -x DOT_DIR="${TEST_TMPDIR}/dot root"
    brew() {
        local argument=""
        for argument in "$@"; do
            [[ "${argument}" != --describe ]] || return 1
        done
        printf '<%s>\n' "$@"
    }
    local result="" dump_type="" expected="" suffix=""
    result="$(dot::brew::dump)" || return 1
    expected="$(printf '<%s>\n' bundle dump --force --formula --taps "--file=${DOT_DIR}/data/Brewfile.arm64")"
    assert_eq "${expected}" "${result}" 'default dump omits disabled flag' || return 1
    for dump_type in formula cask mas all; do
        local -a type_flags=()
        suffix=".${dump_type}"
        case "${dump_type}" in
            formula) type_flags=(--formula --taps); suffix="" ;;
            cask) type_flags=(--cask) ;;
            mas) type_flags=(--mas) ;;
            all) type_flags=(--formula --taps --cask --mas) ;;
        esac
        result="$(dot::brew dump -t "${dump_type}")" || return 1
        expected="$(printf '<%s>\n' bundle dump --force "${type_flags[@]}" "--file=${DOT_DIR}/data/Brewfile${suffix}.arm64")"
        assert_eq "${expected}" "${result}" "${dump_type} dump preserves flags and default path" || return 1
    done
    result="$(dot::brew::dump -t cask -o "${TEST_TMPDIR}/quoted output/Brewfile")" || return 1
    expected="$(printf '<%s>\n' bundle dump --force --cask "--file=${TEST_TMPDIR}/quoted output/Brewfile")"
    assert_eq "${expected}" "${result}" 'custom output remains one argument' || return 1
    brew() { return 24; }
    assert_exit_code 24 dot::brew::dump || return 1
    assert_exit_code 24 dot::brew dump -t cask
}

test_brew_load() {
    local -x DOT_DIR="${TEST_TMPDIR}/dot root"
    local load_type="" suffix="" result="" expected=""
    mkdir -p "${DOT_DIR}/data" || return 1
    brew() { printf '<%s>\n' "$@"; }
    for load_type in formula cask mas all; do
        suffix=".${load_type}"
        [[ "${load_type}" != formula ]] || suffix=""
        : > "${DOT_DIR}/data/Brewfile${suffix}.arm64"
        result="$(dot::brew load -t "${load_type}")" || return 1
        expected="$(printf '<%s>\n' bundle install "--file=${DOT_DIR}/data/Brewfile${suffix}.arm64")"
        assert_eq "${expected}" "${result}" "${load_type} loads from dot root" || return 1
    done
    result="$(dot::brew::load)" || return 1
    expected="$(printf '<%s>\n' bundle install "--file=${DOT_DIR}/data/Brewfile.arm64")"
    assert_eq "${expected}" "${result}" 'default load uses formula file' || return 1
    : > "${TEST_TMPDIR}/custom Brewfile"
    result="$(dot::brew::load -i "${TEST_TMPDIR}/custom Brewfile")" || return 1
    expected="$(printf '<%s>\n' bundle install "--file=${TEST_TMPDIR}/custom Brewfile")"
    assert_eq "${expected}" "${result}" 'explicit input overrides default and preserves spaces' || return 1
    assert_exit_code 1 dot::brew::load -i "${TEST_TMPDIR}/missing Brewfile" || return 1
    brew() { return 24; }
    assert_exit_code 24 dot::brew::load
}

test_brew_root_fallbacks() {
    local -x DOT_DIR="" DOT_DIRECTORY="${TEST_TMPDIR}/dot directory" DOT_ROOT="${TEST_TMPDIR}/dot root"
    local -x HOME="${TEST_TMPDIR}/fallback home"
    local root_source="" root_dir="" result="" expected=""
    brew() { printf '<%s>\n' "$@"; }
    for root_source in directory root home; do
        case "${root_source}" in
            directory) root_dir="${DOT_DIRECTORY}" ;;
            root) DOT_DIRECTORY=""; root_dir="${DOT_ROOT}" ;;
            home) DOT_ROOT=""; root_dir="${HOME}/.dot" ;;
        esac
        mkdir -p "${root_dir}/data" || return 1
        : > "${root_dir}/data/Brewfile.arm64"
        result="$(dot::brew::dump)" || return 1
        expected="$(printf '<%s>\n' bundle dump --force --formula --taps "--file=${root_dir}/data/Brewfile.arm64")"
        assert_eq "${expected}" "${result}" "dump uses ${root_source} fallback" || return 1
        result="$(dot::brew::load)" || return 1
        expected="$(printf '<%s>\n' bundle install "--file=${root_dir}/data/Brewfile.arm64")"
        assert_eq "${expected}" "${result}" "load uses ${root_source} fallback" || return 1
    done
}

it 'contextual help bypasses brew' test_brew_help
it 'type and architecture options are validated' test_brew_options
it 'forwarded arguments and failures survive' test_brew_forwarding
it 'dump uses supported flags and preserves paths and failures' test_brew_dump
it 'load uses dot files and preserves explicit inputs and failures' test_brew_load
it 'dump and load resolve repository root fallbacks' test_brew_root_fallbacks
tap_summary
