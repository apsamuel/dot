# shellcheck shell=bash
# ──────────────────────────────────────────────────────────────────────────────
# Mock external tools — shell-function stubs that shadow real binaries.
#
# Portable across bash (>=4.0) and zsh (>=5.0).
# Each stub:
#   1. Records the invocation in TEST_TMPDIR/.mock_calls_<name>
#   2. Returns canned data appropriate for the module under test
#
# Source AFTER env.sh:
#   source "${FRAMEWORK_DIR}/mocks/tools.sh"
# ──────────────────────────────────────────────────────────────────────────────

# ── Helper: record a mock call ────────────────────────────────────────────────
_mock_record() {
    local name="$1"
    shift
    echo "$*" >> "${TEST_TMPDIR}/.mock_calls_${name}"
}

# ── jq ────────────────────────────────────────────────────────────────────────
# Returns canned JSON key/value data; supports '. | keys | .[]' and --arg
jq() {
    _mock_record "jq" "$@"
    local query=""
    local file=""
    local arg_name=""
    local arg_val=""
    local raw=0
    local _pat_secret="\$secret_key"
    local _pat_dollar="\$"

    # Parse args (simplified)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r) raw=1; shift ;;
            --arg)
                arg_name="$2"
                arg_val="$3"
                shift 3
                ;;
            -*)
                shift ;;
            *)
                if [[ -z "${query}" ]]; then
                    query="$1"
                else
                    file="$1"
                fi
                shift
                ;;
        esac
    done

    # If we have a file and it exists, delegate to the real jq if available
    # Otherwise return canned responses
    case "${query}" in
        *'keys'*)
            # Return keys from fixture secrets.json
            if [[ -f "${file}" ]]; then
                echo "API_KEY"
                echo "GH_TOKEN"
                echo "SECRET_VALUE"
            fi
            ;;
        *"${_pat_secret}"*|*"${_pat_dollar}"*)
            # Return a canned secret value for the requested key
            case "${arg_val}" in
                API_KEY)       echo "test-api-key-12345" ;;
                GH_TOKEN)      echo "ghp_test_token_abc" ;;
                SECRET_VALUE)  echo "s3cr3t_v4lu3" ;;
                *)             echo "mock-value-${arg_val}" ;;
            esac
            ;;
        *)
            echo "{}"
            ;;
    esac
}

# ── yq ────────────────────────────────────────────────────────────────────────
yq() {
    _mock_record "yq" "$@"
    local query=""
    local file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*) shift ;;
            *)
                if [[ -z "${query}" ]]; then
                    query="$1"
                else
                    file="$1"
                fi
                shift
                ;;
        esac
    done

    case "${query}" in
        '.theme')
            echo "powerlevel10k/powerlevel10k"
            ;;
        '.conditions.'*)
            echo "true"
            ;;
        '.options[]'|'.options')
            echo "autopushd"
            echo "extendedglob"
            echo "share_history"
            ;;
        '.')
            echo "theme: powerlevel10k/powerlevel10k"
            echo "options:"
            echo "  - autopushd"
            echo "  - extendedglob"
            ;;
        *)
            echo "null"
            ;;
    esac
}

# ── brew ──────────────────────────────────────────────────────────────────────
brew() {
    _mock_record "brew" "$@"
    case "$1" in
        --prefix) echo "/opt/homebrew" ;;
        list)     echo "coreutils" ; echo "jq" ; echo "yq" ;;
        info)     echo "mock-formula: stable 1.0.0" ;;
        *)        return 0 ;;
    esac
}

# ── git ───────────────────────────────────────────────────────────────────────
git() {
    _mock_record "git" "$@"
    case "$1" in
        config)
            # Silently accept config commands
            return 0
            ;;
        log)
            echo "abc1234  2025-01-01 (1 day ago)  Test User: initial commit"
            ;;
        --version)
            echo "git version 2.44.0"
            ;;
        status)
            echo "nothing to commit, working tree clean"
            ;;
        diff)
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

# ── gh (GitHub CLI) ───────────────────────────────────────────────────────────
gh() {
    _mock_record "gh" "$@"
    case "$1" in
        auth)
            echo "gh: already authenticated"
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

# ── fzf ───────────────────────────────────────────────────────────────────────
# fzf is interactive — stub always returns the first line of input
fzf() {
    _mock_record "fzf" "$@"
    head -1
}

# ── pwgen ─────────────────────────────────────────────────────────────────────
pwgen() {
    _mock_record "pwgen" "$@"
    echo "xK9!mP3q#rL5sT7"
}

# ── dscl ──────────────────────────────────────────────────────────────────────
dscl() {
    _mock_record "dscl" "$@"
    echo "admin"
}

# ── sysctl ────────────────────────────────────────────────────────────────────
sysctl() {
    _mock_record "sysctl" "$@"
    case "$2" in
        machdep.cpu.brand_string) echo "Apple M1 Pro" ;;
        machdep.cpu.features)     echo "FPU VME SSE SSE2 SSE3" ;;
        machdep.cpu.core_count)   echo "10" ;;
        *)                        echo "mock-sysctl" ;;
    esac
}

# ── tput ──────────────────────────────────────────────────────────────────────
tput() {
    _mock_record "tput" "$@"
    case "$1" in
        setab|setaf) echo "" ;;   # empty escape — no color
        sgr0)        echo "" ;;
        cols)        echo "120" ;;
        lines)       echo "40" ;;
        *)           echo "" ;;
    esac
}

# ── infocmp / tic ─────────────────────────────────────────────────────────────
infocmp() {
    _mock_record "infocmp" "$@"
    echo "xterm-256color|mock terminfo"
}

tic() {
    _mock_record "tic" "$@"
    return 0
}

# ── figlet ────────────────────────────────────────────────────────────────────
figlet() {
    _mock_record "figlet" "$@"
    echo "FIGLET: $*"
}

# ── bc ────────────────────────────────────────────────────────────────────────
bc() {
    _mock_record "bc" "$@"
    # Simple: read expression from stdin and try to evaluate with zsh
    local expr=""
    read -r expr
    echo $(( expr )) 2>/dev/null || echo "0"
}

# ── setopt (zsh builtin — wrap to prevent errors on invalid options) ──────────
# Not overriding setopt since it's a builtin, but modules use it safely
