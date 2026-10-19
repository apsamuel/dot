# shellcheck shell=bash
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"
source "${_test_dir}/../../modules/static/foundation.sh"

test_static_help() {
    mock_reset_calls
    local topic=""
    for topic in shell-name secure-string cpu-cores cpu-brand load-user-secrets ssh-identities; do
        assert_eq "$(dot::static::foundation help "${topic}")" "$(dot::static::foundation "${topic}" --help)" 'static help agrees' || return 1
    done
    assert_eq "$(dot::history help rotate)" "$(dot::history rotate --help)" 'history help agrees' || return 1
    assert_not_called jq 'help reads no secrets' || return 1
    assert_exit_code 2 dot::static::foundation ssh-identities --dir || return 1
    assert_exit_code 2 dot::static::foundation ssh-identities --var 'invalid;name' || return 1
    assert_exit_code 1 dot::history rotate --invalid
}

test_history_failures() {
    local HISTFILE="${TEST_TMPDIR}/history-fixture"
    local DOT_HIST_ARCHIVE_DIR="${TEST_TMPDIR}/history-archives"
    local DOT_HIST_ARCHIVE_ENABLE=true DOT_HIST_ARCHIVE_INTERVAL=86400
    printf ': 1:0;fixture\n' > "${HISTFILE}"
    gzip() { return 24; }
    assert_exit_code 24 dot::history rotate --force || return 1
    assert_exit_code 1 test -e "${DOT_HIST_ARCHIVE_DIR}/.last-archive" || return 1
    DOT_HIST_ARCHIVE_INTERVAL='invalid'
    assert_exit_code 1 dot::history rotate --force
}

test_agent_failure() {
    ssh-add() { return 24; }
    assert_exit_code 24 dot::static::foundation ssh-identities --list-loaded || return 1
    ssh-add() { return 1; }
    assert_exit_code 0 dot::static::foundation ssh-identities --list-loaded
}

describe 'public static foundation and history'
it 'help and malformed options do not call backends' test_static_help
it 'history failures stay failures without a success stamp' test_history_failures
it 'agent errors differ from an empty agent' test_agent_failure

test_history_success() {
    local HISTFILE="${TEST_TMPDIR}/history-success"
    local DOT_HIST_ARCHIVE_DIR="${TEST_TMPDIR}/history-success-archives"
    local -x DOT_HIST_ARCHIVE_ENABLE=true DOT_HIST_ARCHIVE_INTERVAL=09 DOT_HIST_ARCHIVE_MAX=08 DOT_HIST_ROTATE_KEEP_LINES=00
    printf ': 1:0;fixture\n' > "${HISTFILE}"
    gzip() { command gzip "$@"; }
    dot::history rotate --force || return 1
    [[ -f "${DOT_HIST_ARCHIVE_DIR}/.last-archive" ]] || return 1
    assert_eq ': 1:0;fixture' "$(command gzip -dc "${DOT_HIST_ARCHIVE_DIR}"/*.gz)" 'archive preserves fixture content' || return 1
    dot::history rotate --force || return 1
    local count=""
    count="$(find "${DOT_HIST_ARCHIVE_DIR}" -name '*.gz' | wc -l | tr -d ' ')" || return $?
    assert_eq 2 "${count}" 'repeated archives do not overwrite each other'
}
it 'decimal settings and successful repeated snapshots preserve history' test_history_success

test_static_secret_loading() {
    local ICLOUD="${TEST_TMPDIR}/static-secrets"
    mkdir -p "${ICLOUD}/dot"
    jq() { command jq "$@"; }
    printf '%s\n' '{"DOT_STATIC_TEST":"$(false); literal", "secrets_file":"value"}' > "${ICLOUD}/dot/secrets.json"
    dot::static::foundation load-user-secrets || return 1
    assert_eq '$(false); literal' "${DOT_STATIC_TEST:-}" 'loaded values are literal' || return 1
    assert_eq value "${secrets_file:-}" 'loader names do not swallow assignments' || return 1
    assert_eq 'DOT_STATIC_TEST
secrets_file' "$(dot::static::foundation load-user-secrets --list-loaded)" 'loaded keys remain exported' || return 1
    assert_exit_code 1 test -e "${TMPDIR}/.secrets" || return 1
    printf '%s\n' '{"bad-name":"value"}' > "${ICLOUD}/dot/secrets.json"
    assert_exit_code 1 dot::static::foundation load-user-secrets
}
it 'static secret loading validates and exports literal values without temporary scripts' test_static_secret_loading
tap_summary
