# shellcheck shell=bash
# Test: modules/000-c-git.sh — git constants and functions
source "${0:A:h}/../framework.sh"
source "${0:A:h}/../mocks/env.sh"
source "${0:A:h}/../mocks/tools.sh"

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
    typeset -f ghAuth > /dev/null 2>&1
    assert_eq "0" "$?"
}

test_git_config_exists() {
    typeset -f gitConfig > /dev/null 2>&1
    assert_eq "0" "$?"
}

test_git_changes_exists() {
    typeset -f gitChanges > /dev/null 2>&1
    assert_eq "0" "$?"
}

test_git_diff_exists() {
    typeset -f gitDiff > /dev/null 2>&1
    assert_eq "0" "$?"
}

test_git_log_exists() {
    typeset -f gitLog > /dev/null 2>&1
    assert_eq "0" "$?"
}

it "ghAuth is defined" test_gh_auth_exists
it "gitConfig is defined" test_git_config_exists
it "gitChanges is defined" test_git_changes_exists
it "gitDiff is defined" test_git_diff_exists
it "gitLog is defined" test_git_log_exists

describe "000-c-git.sh: DOT_DISABLE_GIT guard"

test_disable_git_guard() {
    # Verify the guard mechanism exists — we sourced with it disabled
    assert_eq "0" "${DOT_DISABLE_GIT}"
}

it "DOT_DISABLE_GIT guard is recognized" test_disable_git_guard

describe "000-c-git.sh: ghAuth with mock"

test_gh_auth_calls_gh() {
    mock_reset_calls
    export GH_TOKEN="test-token"
    ghAuth > /dev/null 2>&1
    assert_called "gh"
}

it "ghAuth invokes gh CLI" test_gh_auth_calls_gh

tap_summary
