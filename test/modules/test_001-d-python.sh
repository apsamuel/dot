# shellcheck shell=bash
# shellcheck source=/dev/null
# Test: modules/001-d-python.sh — venv pip requirement reconciliation
# Portable bootstrap — works under bash and zsh
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"

# Keep the startup reconcile from running at source time (interactive-only).
export DOT_INTERACTIVE=0
export DOT_PY_ENSURE_REQUIREMENTS=1

# Source the module under test
source_module "001-d-python.sh"

# Fresh fake venv + clean mock state before each test.
MOCK_VENV="${TEST_TMPDIR}/pyvenv"
test_setup() {
    command rm -rf "${MOCK_VENV}"
    mkdir -p "${MOCK_VENV}/bin"
    printf '#!/bin/sh\n' > "${MOCK_VENV}/bin/python"
    chmod +x "${MOCK_VENV}/bin/python"
    export MOCK_UV_INSTALLED=""
    mock_reset_calls
}

# ── Tests ─────────────────────────────────────────────────────────────────────

describe "001-d-python.sh: dot::python::requirements()"

test_requirements_reads_yaml() {
    local out=""
    out="$(dot::python::requirements 2>/dev/null)"
    assert_eq "requests==2.31.0" "${out}"
}
it "reads pip requirements from zsh.yaml" test_requirements_reads_yaml

describe "001-d-python.sh: dot::python::ensure-requirements()"

test_installs_missing() {
    dot::python::ensure-requirements "${MOCK_VENV}" >/dev/null 2>&1
    mock_call_args uv | grep -q "pip install" || { echo "expected 'uv pip install' to be called"; return 1; }
    return 0
}
it "installs a missing requirement" test_installs_missing

test_skips_when_present() {
    export MOCK_UV_INSTALLED="requests"
    dot::python::ensure-requirements "${MOCK_VENV}" >/dev/null 2>&1
    if mock_call_args uv | grep -q "pip install"; then
        echo "should not install a package that is already present"; return 1
    fi
    return 0
}
it "does not install when already present" test_skips_when_present

test_writes_stamp() {
    dot::python::ensure-requirements "${MOCK_VENV}" >/dev/null 2>&1
    [ -f "${MOCK_VENV}/.dot-requirements.sha" ] || { echo "stamp file not written"; return 1; }
    return 0
}
it "writes a stamp after a clean pass" test_writes_stamp

test_stamp_gating_skips_second_run() {
    dot::python::ensure-requirements "${MOCK_VENV}" >/dev/null 2>&1
    mock_reset_calls
    # Even if the package now looks missing, a matching stamp short-circuits.
    export MOCK_UV_INSTALLED=""
    dot::python::ensure-requirements "${MOCK_VENV}" >/dev/null 2>&1
    assert_not_called "uv"
}
it "skips uv entirely when the stamp matches" test_stamp_gating_skips_second_run

test_force_bypasses_stamp() {
    dot::python::ensure-requirements "${MOCK_VENV}" >/dev/null 2>&1
    mock_reset_calls
    export MOCK_UV_INSTALLED=""
    dot::python::ensure-requirements --force "${MOCK_VENV}" >/dev/null 2>&1
    mock_call_args uv | grep -q "pip install" || { echo "--force should reinstall a missing package"; return 1; }
    return 0
}
it "--force re-checks despite a matching stamp" test_force_bypasses_stamp

describe "001-d-python.sh: dot::python::env base requirements"

test_env_installs_base_by_default() {
    local d="${TEST_TMPDIR}/proj-default"
    mkdir -p "${d}"
    export MOCK_UV_INSTALLED=""
    dot::python::env -p "${d}" -n venv >/dev/null 2>&1
    mock_call_args uv | grep -q "pip install" || { echo "expected base requirements to be installed"; return 1; }
    return 0
}
it "installs base requirements into a new venv by default" test_env_installs_base_by_default

test_env_skips_base_with_flag() {
    local d="${TEST_TMPDIR}/proj-noreqs"
    mkdir -p "${d}"
    export MOCK_UV_INSTALLED=""
    dot::python::env -p "${d}" -n venv --no-base-requirements >/dev/null 2>&1
    if mock_call_args uv | grep -q "pip install"; then
        echo "--no-base-requirements should skip base requirement install"; return 1
    fi
    return 0
}
it "--no-base-requirements skips base requirement install" test_env_skips_base_with_flag

describe "001-d-python.sh: dot::python::sync()"

test_sync_reconciles_named_venv() {
    export MOCK_UV_INSTALLED=""
    dot::python::sync "${MOCK_VENV}" >/dev/null 2>&1
    mock_call_args uv | grep -q "pip install" || { echo "sync should reconcile the named venv"; return 1; }
    return 0
}
it "reconciles an explicitly named venv" test_sync_reconciles_named_venv

tap_summary
