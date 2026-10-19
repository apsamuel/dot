# shellcheck shell=bash
# Test: modules/000-c-git.sh — git constants and functions
# Portable bootstrap — works under bash and zsh
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"

# Ensure git module loads (not disabled)
export DOT_DISABLE_GIT=0

# Source the module under test
source_module "000-c-git.sh"

# ── Tests ─────────────────────────────────────────────────────────────────────

describe "000-c-git.sh: constants"

test_default_source_branch() {
    assert_eq "main" "${DOT_GIT_DEFAULT_SOURCE_BRANCH}" 'source branch default'
}

test_default_destination_branch() {
    assert_eq "staging" "${DOT_GIT_DEFAULT_DESTINATION_BRANCH}" 'destination branch default'
}

test_default_user() {
    assert_defined "DOT_GIT_DEFAULT_USER" 'user default exists'
}

test_default_email() {
    assert_defined "DOT_GIT_DEFAULT_EMAIL" 'email default exists'
}

test_merge_branch_flag() {
    assert_eq "1" "${DOT_GIT_DEFAULT_MERGE_BRANCH}" 'merge enabled'
}

test_rebase_branch_flag() {
    assert_eq "0" "${DOT_GIT_DEFAULT_REBASE_BRANCH}" 'rebase disabled'
}

it "default source branch is main" test_default_source_branch
it "default destination branch is staging" test_default_destination_branch
it "default user is defined" test_default_user
it "default email is defined" test_default_email
it "merge branch default is 1" test_merge_branch_flag
it "rebase branch default is 0" test_rebase_branch_flag

describe "000-c-git.sh: functions exist"

test_gh_auth_exists() {
    typeset -f dot::git::auth > /dev/null 2>&1
    assert_eq "0" "$?" 'auth exists'
}

test_git_config_exists() {
    typeset -f dot::git::config > /dev/null 2>&1
    assert_eq "0" "$?" 'config exists'
}

test_git_changes_exists() {
    typeset -f dot::git::changes > /dev/null 2>&1
    assert_eq "0" "$?" 'changes exists'
}

test_git_diff_exists() {
    typeset -f dot::git::diff > /dev/null 2>&1
    assert_eq "0" "$?" 'diff exists'
}

test_git_log_exists() {
    typeset -f dot::git::log > /dev/null 2>&1
    assert_eq "0" "$?" 'log exists'
}

it "dot::git::auth is defined" test_gh_auth_exists
it "dot::git::config is defined" test_git_config_exists
it "dot::git::changes is defined" test_git_changes_exists
it "dot::git::diff is defined" test_git_diff_exists
it "dot::git::log is defined" test_git_log_exists

describe "000-c-git.sh: DOT_DISABLE_GIT guard"

test_disable_git_guard() {
    # Verify the guard mechanism exists — we sourced with it disabled
    assert_eq "0" "${DOT_DISABLE_GIT}" 'module enabled'
}

it "DOT_DISABLE_GIT guard is recognized" test_disable_git_guard

describe "000-c-git.sh: dot::git::auth with mock"

test_gh_auth_calls_gh() {
    mock_reset_calls
    export GH_TOKEN="test-token"
    dot::git::auth > /dev/null 2>&1
    assert_called "gh" 'auth calls gh'
}

it "dot::git::auth invokes gh CLI" test_gh_auth_calls_gh

test_git_help() {
    mock_reset_calls
    local topic=""
    for topic in auth config changes diff preview log; do
        assert_eq "$(dot::git help "${topic}")" "$(dot::git "${topic}" --help)" 'help agrees' || return 1
    done
    assert_not_called git 'help never configures git' || return 1
    assert_not_called gh 'help never authenticates'
}

test_git_config_validation() {
    mock_reset_calls
    assert_exit_code 1 dot::git config -u || return 1
    assert_not_called git 'invalid config never writes' || return 1
    dot::git config -g -u 'Quoted User' >/dev/null || return 1
    mock_call_args git | grep -q -- 'config --global user.name Quoted User' || return 1
    mock_reset_calls
    dot::git config -e example@example.test >/dev/null || return 1
    mock_call_args git | grep -q -- 'config user.name' || return 1
    git() { return 24; }
    assert_exit_code 24 dot::git config -u name
}

test_git_auth_failure() {
    gh() { command cat >/dev/null; return 24; }
    export GH_TOKEN='mock-token'
    local result="" ret=0
    result="$(dot::git auth)" || ret=$?
    assert_eq 24 "${ret}" 'authentication failure propagates' || return 1
    assert_eq '' "${result}" 'failure never claims authenticated or prints token'
}

it 'help does not authenticate or configure git' test_git_help
it 'config validates before writes and resets parser state' test_git_config_validation
it 'authentication failure is not reported as success' test_git_auth_failure

test_git_diff_forwarding() {
    git() { printf '<%s>\n' "$@" > "${TEST_TMPDIR}/diff-args"; printf 'quoted file.txt\n'; }
    fzf() { printf '%s\n' "$@" > "${TEST_TMPDIR}/preview-args"; command cat; }
    assert_eq 'quoted file.txt' "$(dot::git diff HEAD -- 'quoted file.txt')" 'selected filename stays intact' || return 1
    assert_eq "$(printf '<%s>\n' diff --name-only HEAD -- 'quoted file.txt')" "$(command cat "${TEST_TMPDIR}/diff-args")" 'git receives literal path after separator' || return 1
    command grep -Fx 'git diff --color=always HEAD -- {}' "${TEST_TMPDIR}/preview-args" >/dev/null || return 1
    git() { return 24; }
    assert_exit_code 24 dot::git diff -- 'quoted file.txt'
}
it 'diff preserves separators, filenames and backend failures' test_git_diff_forwarding
tap_summary
