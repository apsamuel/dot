# shellcheck shell=bash
# shellcheck source=/dev/null
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"
export DOT_DISABLE_NODE=0 NODE_VERSION=24.15.0 CPU_ARCHITECTURE=arm64 LDFLAGS='' CPPFLAGS=''
n() { _mock_record n "$@"; }
node() { printf '%s\n' v24.15.0; }
brew() { return 1; }
dot::static::logging::loading() { :; }
source_module "001-d-node.sh"
test_setup() { mock_reset_calls; }

test_node_help() {
    mkdir() { _mock_record mkdir; return 91; }
    curl() { _mock_record curl; return 92; }
    tar() { _mock_record tar; return 93; }
    assert_eq "$(dot::node help get)" "$(dot::node get --help)" 'help agrees' || return 1
    assert_exit_code 1 dot::node get --unknown || return 1
    assert_not_called mkdir 'help and invalid input never write' || return 1
    assert_not_called curl 'help never downloads' || return 1
    assert_not_called tar 'help never extracts'
}

test_node_download_failure() {
    mkdir() { :; }
    curl() { return 24; }
    tar() { return 0; }
    assert_exit_code 1 dot::node get
}

it 'help and validation precede download work' test_node_help
it 'download failure survives successful extraction' test_node_download_failure
tap_summary
