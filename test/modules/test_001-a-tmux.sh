# shellcheck shell=bash
# shellcheck source=/dev/null
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"
export DOT_DISABLE_TMUX=0 DOT_INTERACTIVE=0 DOT_ROOT="${MOCK_DOT}" TMUX=''
tmux() { _mock_record tmux "$@"; return 91; }
source_module "001-a-tmux.sh"
test_setup() { _mock_reset; }

test_tmux_help() {
    local topic=""
    for topic in kill-unattached safe-session-name has-session create-session-from-cwd; do
        dot::tmux help "${topic}" >/dev/null || return 1
    done
    dot::tmux kill-unattached --help >/dev/null || return 1
    dot::tmux create-session-from-cwd --help >/dev/null || return 1
    assert_not_called tmux 'help does not touch sessions'
}

test_tmux_failure() {
    assert_exit_code 91 dot::tmux kill-unattached || return 1
    assert_exit_code 1 dot::tmux has-session absent
}

test_tmux_kill() {
    tmux() {
        _mock_record tmux "$@"
        case "$1" in
            list-sessions) printf '%s\n' 'attached 1' 'space name 0' 'later 0' ;;
            kill-session) [[ "$3" == 'space name' ]] || return 93; return 24 ;;
        esac
    }
    assert_exit_code 24 dot::tmux kill-unattached
}

it 'help never invokes tmux' test_tmux_help
it 'listing failures and predicate status survive' test_tmux_failure
it 'quoted session names and first kill failure survive' test_tmux_kill
tap_summary
