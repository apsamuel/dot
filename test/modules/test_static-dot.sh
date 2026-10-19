# shellcheck shell=bash
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"
export TMUX=''
source "${_test_dir}/../../modules/static/dot.sh"
export ICLOUD="${MOCK_ICLOUD}"
export DOT_DIRECTORY="${MOCK_DOT}"

test_root_help() {
    mock_reset_calls
    local topic=""
    for topic in version update reload changelog printenv secrets refresh-modules load-options add-plugin add-theme vendor; do
        assert_eq "$(dot::static::shell help "${topic}")" "$(dot::static::shell "${topic}" --help)" 'topic help agrees' || return 1
    done
    assert_not_called git 'help performs no git work' || return 1
    assert_not_called jq 'help reads no secrets'
}

test_root_invalid() {
    mock_reset_calls
    assert_exit_code 1 dot::static::shell secrets --set --key || return 1
    assert_exit_code 1 dot::static::shell secrets --get --list || return 1
    assert_exit_code 1 dot::static::shell reload --invalid || return 1
    assert_exit_code 1 dot::static::shell changelog --invalid || return 1
    assert_not_called git 'invalid input performs no git work' || return 1
    assert_not_called jq 'invalid input reads no secrets'
}

test_root_failures() {
    git() { return 24; }
    omz() { _mock_record omz "$@"; return 25; }
    assert_exit_code 24 dot::static::shell update || return 1
    assert_not_called omz 'failed pull prevents second update' || return 1
    assert_exit_code 25 dot::static::shell reload --debug || return 1
    jq() { return 26; }
    assert_exit_code 26 dot::static::shell secrets --set --key TEST --value fixture
}

test_root_default() {
    assert_eq "$(dot::static::shell version)" "$(dot::static::shell)" 'default remains version'
}

describe 'root shell interface'
it 'topic help is backend-free' test_root_help
it 'malformed input is rejected before work' test_root_invalid
it 'mutating failures are not masked' test_root_failures
it 'default action remains version' test_root_default
tap_summary
