# shellcheck shell=bash
# shellcheck source=/dev/null
# Test: modules/001-d-rust.sh — rustup helper wrappers
# Portable bootstrap — works under bash and zsh
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"

# Source the module under test
source_module "001-d-rust.sh"

test_setup() {
    mock_reset_calls
}

# ── Tests ─────────────────────────────────────────────────────────────────────

describe "001-d-rust.sh: dot::rust::toolchains()"

test_toolchains_lists() {
    assert_output_contains "stable" dot::rust::toolchains
}
it "lists installed toolchains" test_toolchains_lists

test_toolchains_calls_rustup() {
    dot::rust::toolchains > /dev/null 2>&1
    mock_call_args rustup | grep -q "toolchain list" || { echo "expected 'rustup toolchain list'"; return 1; }
    return 0
}
it "invokes 'rustup toolchain list'" test_toolchains_calls_rustup

describe "001-d-rust.sh: dot::rust::versions()"

test_versions_reports() {
    local out=""
    out="$(dot::rust::versions 2>/dev/null)"
    case "${out}" in
        *"1.27.1"*"1.79.0"*) return 0 ;;
        *) echo "unexpected versions output: ${out}"; return 1 ;;
    esac
}
it "reports rustup + toolchain versions" test_versions_reports

describe "001-d-rust.sh: dot::rust::use()"

test_use_sets_default() {
    dot::rust::use nightly > /dev/null 2>&1
    mock_call_args rustup | grep -q "default nightly" || { echo "expected 'rustup default nightly'"; return 1; }
    return 0
}
it "sets the default toolchain" test_use_sets_default

test_use_requires_arg() {
    assert_exit_code 1 dot::rust::use
}
it "errors without a toolchain argument" test_use_requires_arg

describe "001-d-rust.sh: dot::rust::add()"

test_add_target() {
    dot::rust::add target x86_64-unknown-linux-gnu > /dev/null 2>&1
    mock_call_args rustup | grep -q "target add x86_64-unknown-linux-gnu" || { echo "expected 'rustup target add ...'"; return 1; }
    return 0
}
it "adds a compilation target" test_add_target

test_add_component() {
    dot::rust::add component clippy > /dev/null 2>&1
    mock_call_args rustup | grep -q "component add clippy" || { echo "expected 'rustup component add clippy'"; return 1; }
    return 0
}
it "adds a component" test_add_component

test_add_rejects_unknown_kind() {
    assert_exit_code 1 dot::rust::add widgets foo
}
it "rejects an unknown add kind" test_add_rejects_unknown_kind

describe "001-d-rust.sh: dot::rust() dispatcher"

test_dispatch_list_toolchains() {
    dot::rust list toolchains > /dev/null 2>&1
    mock_call_args rustup | grep -q "toolchain list" || { echo "dispatcher did not route 'list toolchains'"; return 1; }
    return 0
}
it "routes 'list toolchains'" test_dispatch_list_toolchains

test_dispatch_unknown_errors() {
    assert_exit_code 1 dot::rust bogus-command
}
it "errors on an unknown command" test_dispatch_unknown_errors

test_dispatch_which() {
    assert_output_contains "/mock/.rustup" dot::rust which cargo
}
it "routes 'which' to rustup" test_dispatch_which

test_rust_help_without_backend() {
    local topic="" direct="" result=""
    dot::rust::_require() { _mock_record require; return 95; }
    for topic in toolchains targets components versions show use update install uninstall add which doctor; do
        result="$(dot::rust help "${topic}")" || return 1
        direct="$(dot::rust "${topic}" --help)" || return 1
        assert_eq "${result}" "${direct}" "${topic} help agrees" || return 1
    done
    assert_not_called require 'help bypasses prerequisite checks' || return 1
    assert_not_called rustup 'help never calls rustup'
}

test_rust_forwarding_failures() {
    rustup() { printf '<%s>\n' "$@"; return 24; }
    local result="" ret=0
    result="$(dot::rust install 'quoted toolchain' --profile minimal)" || ret=$?
    assert_eq 24 "${ret}" 'backend status survives' || return 1
    assert_eq $'<toolchain>\n<install>\n<quoted toolchain>\n<--profile>\n<minimal>' "${result}" 'backend argv survives' || return 1
    assert_exit_code 24 dot::rust list all
}

it 'help is contextual and backend-free' test_rust_help_without_backend
it 'forwarding and aggregate failures are preserved' test_rust_forwarding_failures
tap_summary
