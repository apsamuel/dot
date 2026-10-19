# shellcheck shell=bash
# shellcheck source=/dev/null
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"
dot::static::logging::loading() { :; }
source_module "000-a-emulation.sh"

test_emulation_help() {
    local result=""
    result="$(dot::emulation help run)" || return 1
    assert_eq "${result}" "$(dot::emulation::run --help)" 'help agrees' || return 1
    assert_exit_code 1 dot::emulation help unknown
}

test_emulation_validation() {
    local option=""
    for option in --shell --arch --unknown; do
        assert_exit_code 1 dot::emulation run "${option}" || return 1
    done
    assert_exit_code 1 dot::emulation run --shell 'zsh; false' || return 1
    assert_exit_code 1 dot::emulation run --arch invalid
}

it 'emulation contextual help succeeds' test_emulation_help
it 'invalid options return without launching or aborting' test_emulation_validation
tap_summary
