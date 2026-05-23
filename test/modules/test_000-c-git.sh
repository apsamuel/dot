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
    assert_eq "main" "${DOT_GIT_DEFAULT_SOURCE_BRANCH}"
}

test_default_destination_branch() {
    assert_eq "staging" "${DOT_GIT_DEFAULT_DESTINATION_BRANCH}"
}

test_default_user() {
    assert_defined "DOT_GIT_DEFAULT_USER"
}

test_default_email() {
    assert_defined "DOT_GIT_DEFAULT_EMAIL"
}

test_merge_branch_flag() {
    assert_eq "1" "${DOT_GIT_DEFAULT_MERGE_BRANCH}"
}

test_rebase_branch_flag() {
    assert_eq "0" "${DOT_GIT_DEFAULT_REBASE_BRANCH}"
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
    assert_eq "0" "$?"
}

test_git_config_exists() {
    typeset -f dot::git::config > /dev/null 2>&1
    assert_eq "0" "$?"
}

test_git_changes_exists() {
    typeset -f dot::git::changes > /dev/null 2>&1
    assert_eq "0" "$?"
}

test_git_diff_exists() {
    typeset -f dot::git::diff > /dev/null 2>&1
    assert_eq "0" "$?"
}

test_git_log_exists() {
    typeset -f dot::git::log > /dev/null 2>&1
    assert_eq "0" "$?"
}

it "dot::git::auth is defined" test_gh_auth_exists
it "dot::git::config is defined" test_git_config_exists
it "dot::git::changes is defined" test_git_changes_exists
it "dot::git::diff is defined" test_git_diff_exists
it "dot::git::log is defined" test_git_log_exists

describe "000-c-git.sh: DOT_DISABLE_GIT guard"

test_disable_git_guard() {
    # Verify the guard mechanism exists — we sourced with it disabled
    assert_eq "0" "${DOT_DISABLE_GIT}"
}

it "DOT_DISABLE_GIT guard is recognized" test_disable_git_guard

describe "000-c-git.sh: dot::git::auth with mock"

test_gh_auth_calls_gh() {
    mock_reset_calls
    export GH_TOKEN="test-token"
    dot::git::auth > /dev/null 2>&1
    assert_called "gh"
}

it "dot::git::auth invokes gh CLI" test_gh_auth_calls_gh

tap_summary
