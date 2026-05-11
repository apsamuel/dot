#!/usr/bin/env zsh
# ──────────────────────────────────────────────────────────────────────────────
# Mock environment — sets up an isolated sandbox so modules can be sourced
# without touching the real filesystem or user config.
#
# Source AFTER framework.sh:
#   source "${0:A:h}/../framework.sh"
#   source "${0:A:h}/../mocks/env.sh"
# ──────────────────────────────────────────────────────────────────────────────

# ── Resolve paths ─────────────────────────────────────────────────────────────
# TEST_TMPDIR is set by framework.sh
export MOCK_HOME="${TEST_TMPDIR}/home"
export MOCK_ICLOUD="${TEST_TMPDIR}/icloud"
export MOCK_DOT="${TEST_TMPDIR}/dot"

mkdir -p "${MOCK_HOME}" "${MOCK_ICLOUD}/dot" "${MOCK_DOT}/modules"

# ── Real repo root (read-only reference) ──────────────────────────────────────
# Resolve from this file's location: mocks/ -> test/ -> repo root
export DOT_REAL_ROOT="${0:A:h}/../../"

# ── Override env vars that modules read ───────────────────────────────────────
export HOME="${MOCK_HOME}"
export ICLOUD="${MOCK_ICLOUD}"
export ICLOUD_DIR="${MOCK_ICLOUD}"
export ICLOUD_DOCUMENTS="${MOCK_ICLOUD}/Documents"
export ICLOUD_DOWNLOADS="${MOCK_ICLOUD}/Downloads"
export ICLOUD_SCREENSHOTS="${MOCK_ICLOUD}/ScreenShots"

export DOT_DIR="${DOT_REAL_ROOT}"
export DOT_MODULES="${DOT_REAL_ROOT}/modules"
export DOT_DEBUG=0
export DOT_DRY_RUN=1
export TMPDIR="${TEST_TMPDIR}/tmp"
mkdir -p "${TMPDIR}"

# ── Disable module features that are not under test ───────────────────────────
export DOT_DISABLE_OUTPUTS=0
export DOT_DISABLE_GIT=0
export DOT_DISABLE_NETWORK=1
export DOT_DISABLE_SECRETS=1
export DOT_DISABLE_VENDOR=1

# ── Provide fixture paths ────────────────────────────────────────────────────
export DOT_TEST_FIXTURES="${0:A:h}/../fixtures"
export DOT_SHELL_DATA="${DOT_TEST_FIXTURES}/zsh.yaml"

# ── Minimal XDG dirs ──────────────────────────────────────────────────────────
export XDG_CACHE_HOME="${MOCK_HOME}/.cache"
export XDG_CONFIG_HOME="${MOCK_HOME}/.config"
export XDG_DATA_HOME="${MOCK_HOME}/.local/share"
mkdir -p "${XDG_CACHE_HOME}" "${XDG_CONFIG_HOME}" "${XDG_DATA_HOME}"

# ── Copy fixture data into mock iCloud ────────────────────────────────────────
if [[ -f "${DOT_TEST_FIXTURES}/secrets.json" ]]; then
    cp "${DOT_TEST_FIXTURES}/secrets.json" "${MOCK_ICLOUD}/dot/secrets.json"
fi
if [[ -f "${DOT_TEST_FIXTURES}/zsh.yaml" ]]; then
    mkdir -p "${MOCK_ICLOUD}/dot/shell/zsh"
    cp "${DOT_TEST_FIXTURES}/zsh.yaml" "${MOCK_ICLOUD}/dot/shell/zsh/zsh.yaml"
fi

# ── Utility: source a module from the real repo in the mock env ───────────────
source_module() {
    local module_name="$1"
    local module_path="${DOT_MODULES}/${module_name}"
    if [[ ! -f "${module_path}" ]]; then
        echo "ERROR: module not found: ${module_path}" >&2
        return 1
    fi
    source "${module_path}"
}
