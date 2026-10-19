# shellcheck shell=bash
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"
source "${_test_dir}/../../modules/static/ssh.sh"

test_ssh_help() {
    ssh-keygen() { return 99; }
    ssh-add() { return 99; }
    local topic=""
    for topic in list-keys create-key key-fingerprint key-type public-key remove-key add-key-to-agent; do
        assert_eq "$(dot::static::ssh help "${topic}")" "$(dot::static::ssh "${topic}" --help)" 'help agrees' || return 1
        assert_exit_code 2 dot::static::ssh "${topic}" --dir || return 1
    done
}

test_ssh_create_validation() {
    ssh-keygen() { return 99; }
    mkdir() { return 98; }
    assert_exit_code 2 dot::static::ssh create-key --name ../escape || return 1
    assert_exit_code 2 dot::static::ssh create-key --name fixture --type invalid || return 1
    assert_exit_code 2 dot::static::ssh create-key --passphrase || return 1
    assert_exit_code 98 dot::static::ssh create-key --name fixture --dir "${MOCK_DOT}/absent"
}

test_ssh_remove_failure() {
    local keyfile="${MOCK_DOT}/fixture-key"
    printf '%s\n' fixture > "${keyfile}"
    rm() { return 24; }
    assert_exit_code 24 dot::static::ssh remove-key --name "${keyfile}" --force
}

describe 'static SSH interface'
it 'help and missing option values never call SSH tools' test_ssh_help
it 'key creation validates before mutation and preserves mkdir failure' test_ssh_create_validation
it 'key removal preserves filesystem failure' test_ssh_remove_failure
tap_summary
