# shellcheck shell=bash
# shellcheck disable=SC2317
DOT_DEBUG="${DOT_DEBUG:-0}"


directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"

# Usage: dot::emulation::run [--spawn] [--arch arm64|x86_64] [--shell sh|bash|csh|ksh|zsh] [--login] [code...]
#   --spawn   Launch a real shell process instead of using zsh emulation mode
#   --arch    Run under a specific architecture (macOS only, implies --spawn --login)
#   --shell   Target shell (default: zsh)
#   --login   Start a login shell (no code execution)
#   code      Code to execute (default: echo "Hello World")
function dot::emulation::run() {
    local mode="emulate" shell="zsh" architecture="" login=0
    local args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --spawn)  mode="spawn"; shift ;;
            --arch)   architecture="${2:?architecture required (arm64|x86_64)}"; mode="spawn"; login=1; shift 2 ;;
            --shell)  shell="${2:?shell name required}"; shift 2 ;;
            --login)  login=1; shift ;;
            --)       shift; args+=("$@"); break ;;
            *)        args+=("$1"); shift ;;
        esac
    done

    local code="${args[*]:-echo \"Hello World\"}"

    # Architecture-specific login shell
    if [[ -n "$architecture" ]]; then
        local shell_path
        case "$architecture" in
            arm64)  shell_path="/opt/homebrew/bin/${shell}" ;;
            x86_64) shell_path="/usr/local/bin/${shell}" ;;
            *)      echo "dot::emulation::run: unsupported arch '${architecture}'" >&2; return 1 ;;
        esac
        exec arch "-${architecture}" "$shell_path" -l
    fi

    # Login shell (no code)
    if [[ $login -eq 1 ]]; then
        command "$shell" -l
        return $?
    fi

    # Spawn a real shell process
    if [[ "$mode" == "spawn" ]]; then
        command "$shell" -c "$code"
        return $?
    fi

    # Default: zsh emulation mode
    command zsh -c "emulate ${shell}; ${code}"
}
