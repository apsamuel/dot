# shellcheck shell=bash
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"
export DOT_INTERACTIVE=0
tic() { _mock_record tic "$@"; return 99; }
infocmp() { _mock_record infocmp "$@"; return 99; }
source_module 999-a-terminal.sh

test_terminal_help() {
    assert_not_called tic 'sourcing does not compile' || return 1
    local topic=""
    for topic in compile-info configure-fzf; do
        assert_eq "$(dot::terminal help "${topic}")" "$(dot::terminal "${topic}" --help)" 'terminal help agrees' || return 1
    done
    assert_not_called infocmp 'help does not query terminal database' || return 1
    assert_exit_code 0 dot::terminal configure-fzf || return 1
    assert_not_called brew 'noninteractive setup skips backend'
}

test_terminal_failure() {
    dot::foundation::compile-terminfo() { return 24; }
    assert_exit_code 24 dot::terminal compile-info || return 1
    assert_exit_code 1 dot::terminal compile-info unexpected || return 1
    assert_exit_code 1 dot::terminal configure-fzf unexpected
}

describe 'terminal interface'
it 'source and help do not compile or configure' test_terminal_help
it 'validation and compiler failures propagate' test_terminal_failure
tap_summary
