# shellcheck shell=bash
#% note: configure rust environment via rustup (brew) + dot::rust helpers
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"

if [[ "${DOT_DISABLE_RUST:-0}" -eq 1 ]]; then
    dot::static::logging::skip "rust" "disabled"
    return
fi

# Add rustup's cargo/rustc shims to PATH (brew-managed, deduped).
if command -v brew >/dev/null 2>&1; then
    _rustup_bin="$(brew --prefix rustup 2>/dev/null)/bin"
    if [[ -d "${_rustup_bin}" && ":${PATH}:" != *":${_rustup_bin}:"* ]]; then
        export PATH="${PATH}:${_rustup_bin}"
    fi
    unset _rustup_bin
fi

# Put cargo-installed binaries (~/.cargo/bin) ahead of the shims.
_cargo_bin="${CARGO_HOME:-${HOME}/.cargo}/bin"
if [[ -d "${_cargo_bin}" && ":${PATH}:" != *":${_cargo_bin}:"* ]]; then
    export PATH="${_cargo_bin}:${PATH}"
fi
unset _cargo_bin

# ---------------------------------------------------------------------------
# dot::rust — thin, friendlier wrappers around rustup for listing toolchains,
# targets, components, versions, and managing the underlying rustup utilities.
# ---------------------------------------------------------------------------

# dot::rust::_require — ensure rustup is available before running a subcommand.
dot::rust::_require() {
    if ! command -v rustup >/dev/null 2>&1; then
        dot::static::logging::error "rustup not found — install with: brew install rustup-init && rustup-init"
        return 1
    fi
    return 0
}

# dot::rust::toolchains — list installed toolchains (default is marked by rustup).
dot::rust::toolchains() {
    case "${1:-}" in -h|--help) dot::rust::help toolchains; return ;; esac
    dot::rust::_require || return 1
    rustup toolchain list "$@"
}

# dot::rust::targets [toolchain] — list installed compilation targets.
dot::rust::targets() {
    case "${1:-}" in -h|--help) dot::rust::help targets; return ;; esac
    [[ $# -le 1 ]] || { dot::rust::help targets >&2; return 1; }
    dot::rust::_require || return 1
    if [[ -n "${1:-}" ]]; then
        rustup target list --installed --toolchain "$1"
    else
        rustup target list --installed
    fi
}

# dot::rust::components [toolchain] — list installed components.
dot::rust::components() {
    case "${1:-}" in -h|--help) dot::rust::help components; return ;; esac
    [[ $# -le 1 ]] || { dot::rust::help components >&2; return 1; }
    dot::rust::_require || return 1
    if [[ -n "${1:-}" ]]; then
        rustup component list --installed --toolchain "$1"
    else
        rustup component list --installed
    fi
}

# dot::rust::versions — summarize rustup / rustc / cargo versions + default toolchain.
dot::rust::versions() {
    case "${1:-}" in -h|--help) dot::rust::help versions; return ;; esac
    [[ $# -eq 0 ]] || { dot::rust::help versions >&2; return 1; }
    dot::rust::_require || return 1
    local rustup_v rustc_v cargo_v default_tc
    rustup_v="$(rustup --version 2>/dev/null | awk '{print $2}')"
    rustc_v="$(rustc --version 2>/dev/null | awk '{print $2}')"
    cargo_v="$(cargo --version 2>/dev/null | awk '{print $2}')"
    default_tc="$(rustup default 2>/dev/null | awk '{print $1}')"
    printf 'rustup\t%s\n' "${rustup_v:-not found}"
    printf 'rustc\t%s\n' "${rustc_v:-not found}"
    printf 'cargo\t%s\n' "${cargo_v:-not found}"
    printf 'default\t%s\n' "${default_tc:-none}"
}

# dot::rust::show — active toolchain summary (rustup show).
dot::rust::show() {
    case "${1:-}" in -h|--help) dot::rust::help show; return ;; esac
    dot::rust::_require || return 1
    rustup show "$@"
}

# dot::rust::use <toolchain> — set the default toolchain.
dot::rust::use() {
    case "${1:-}" in -h|--help) dot::rust::help use; return ;; esac
    [[ $# -eq 1 && -n "$1" ]] || { dot::rust::help use >&2; return 1; }
    dot::rust::_require || return 1
    [[ -n "${1:-}" ]] || { echo "dot::rust::use: usage: dot::rust use <toolchain>" >&2; return 1; }
    rustup default "$1"
}

# dot::rust::update [toolchain...] — update rustup itself and installed toolchains.
dot::rust::update() {
    case "${1:-}" in -h|--help) dot::rust::help update; return ;; esac
    dot::rust::_require || return 1
    rustup update "$@"
}

# dot::rust::install <toolchain...> — install one or more toolchains.
dot::rust::install() {
    case "${1:-}" in -h|--help) dot::rust::help install; return ;; esac
    dot::rust::_require || return 1
    [[ -n "${1:-}" ]] || { echo "dot::rust::install: usage: dot::rust install <toolchain>" >&2; return 1; }
    rustup toolchain install "$@"
}

# dot::rust::uninstall <toolchain...> — remove one or more toolchains.
dot::rust::uninstall() {
    case "${1:-}" in -h|--help) dot::rust::help uninstall; return ;; esac
    dot::rust::_require || return 1
    [[ -n "${1:-}" ]] || { echo "dot::rust::uninstall: usage: dot::rust uninstall <toolchain>" >&2; return 1; }
    rustup toolchain uninstall "$@"
}

# dot::rust::add <target|component> <name...> — add a target or component.
dot::rust::add() {
    case "${1:-}" in -h|--help) dot::rust::help add; return ;; esac
    dot::rust::_require || return 1
    local kind="${1:-}"
    [[ $# -gt 0 ]] && shift
    case "${kind}" in
        target)
            [[ $# -gt 0 ]] || { echo "dot::rust::add: usage: dot::rust add target <name...>" >&2; return 1; }
            rustup target add "$@" ;;
        component)
            [[ $# -gt 0 ]] || { echo "dot::rust::add: usage: dot::rust add component <name...>" >&2; return 1; }
            rustup component add "$@" ;;
        *)
            echo "dot::rust::add: expected 'target' or 'component'" >&2; return 1 ;;
    esac
}

# dot::rust::which <command> — resolve a binary within the active toolchain.
dot::rust::which() {
    case "${1:-}" in -h|--help) dot::rust::help which; return ;; esac
    dot::rust::_require || return 1
    [[ -n "${1:-}" ]] || { echo "dot::rust::which: usage: dot::rust which <command>" >&2; return 1; }
    rustup which "$@"
}

# dot::rust::doctor — report the rust toolchain environment health.
dot::rust::doctor() {
    case "${1:-}" in -h|--help) dot::rust::help doctor; return ;; esac
    [[ $# -eq 0 ]] || { dot::rust::help doctor >&2; return 1; }
    local ret=0 _tool=""
    for _tool in rustup cargo rustc; do
        if command -v "${_tool}" >/dev/null 2>&1; then
            printf '%s\t%s\n' "${_tool}" "$(command -v "${_tool}")"
        else
            printf '%s\t%s\n' "${_tool}" "MISSING"
            ret=1
        fi
    done
    printf 'CARGO_HOME\t%s\n' "${CARGO_HOME:-${HOME}/.cargo}"
    printf 'RUSTUP_HOME\t%s\n' "${RUSTUP_HOME:-${HOME}/.rustup}"
    return "${ret}"
}

# dot::rust::help — usage for the dispatcher.
dot::rust::help() {
    local usage="" purpose=""
    case "${1:-}" in
        ''|help|-h|--help) ;;
        list) usage='[toolchains|targets|components|versions|all]'; purpose='List installed items; defaults to all.' ;;
        toolchains) usage='[rustup-options...]'; purpose='List installed toolchains.' ;;
        targets|components) usage='[toolchain]'; purpose='List installed items for the optional toolchain.' ;;
        versions) purpose='Summarize tool versions; unavailable optional tools display not found.' ;;
        show) usage='[rustup-options...]'; purpose='Show the active toolchain.' ;;
        use) usage='<toolchain>'; purpose='Change the default toolchain.' ;;
        update) usage='[toolchain...]'; purpose='Update installed toolchains.' ;;
        install|uninstall) usage='<toolchain...> [rustup-options...]'; purpose='Modify installed toolchains; no automatic retries.' ;;
        add) usage='<target|component> <name...>'; purpose='Install targets or components; no automatic retries.' ;;
        which) usage='<command> [rustup-options...]'; purpose='Resolve an active toolchain executable.' ;;
        doctor) purpose='Read-only tool and environment health report; returns 1 if a tool is absent.' ;;
        *) printf 'dot::rust: unknown help topic: %s\n' "$1" >&2; return 1 ;;
    esac
    case "${1:-}" in
        ''|help|-h|--help) ;;
        *) printf '%s\n' "${purpose}"
           printf 'Usage: dot::rust %s %s\n' "$1" "${usage}"
           [[ "$1" == list ]] || printf '       dot::rust::%s %s\n' "$1" "${usage}"
           printf '%s\n' 'Options: -h, --help. Backend operations require rustup; help does not.' 'Delegated options and backend status are preserved. Invalid wrapper input returns 1.'
           printf 'Example: dot::rust %s --help\n' "$1"
           return ;;
    esac
    cat <<'EOF'
dot::rust — manage the rust toolchain via rustup

Usage: dot::rust <command> [args]

Commands:
  list [toolchains|targets|components|versions|all]
                          List installed items (default: all)
  show                    Active toolchain summary (rustup show)
  versions                rustup / rustc / cargo versions + default toolchain
  use <toolchain>         Set the default toolchain
  update [toolchain...]   Update rustup and installed toolchains
  install <toolchain...>  Install one or more toolchains
  uninstall <toolchain...>Remove one or more toolchains
  add target <name...>    Add a compilation target
  add component <name...> Add a component (clippy, rustfmt, ...)
  which <command>         Resolve a binary in the active toolchain
  doctor                  Report toolchain environment health
  help                    Show this help
EOF
}

# dot::rust — subcommand dispatcher.
dot::rust() {
    local cmd="${1:-help}"
    [[ $# -gt 0 ]] && shift
    case "${cmd}" in
        list)
            local what="${1:-all}"
            [[ $# -gt 0 ]] && shift
            case "${what}" in
                -h|--help) dot::rust::help list ;;
                toolchains) dot::rust::toolchains "$@" ;;
                targets)    dot::rust::targets "$@" ;;
                components) dot::rust::components "$@" ;;
                versions)   dot::rust::versions "$@" ;;
                all)
                    echo "── toolchains ──";            dot::rust::toolchains || return $?
                    echo "── targets (installed) ──";   dot::rust::targets || return $?
                    echo "── components (installed) ──"; dot::rust::components || return $?
                    echo "── versions ──";              dot::rust::versions
                    ;;
                *) echo "dot::rust list: expected toolchains|targets|components|versions|all" >&2; return 1 ;;
            esac
            ;;
        show)      dot::rust::show "$@" ;;
        toolchains) dot::rust::toolchains "$@" ;;
        targets) dot::rust::targets "$@" ;;
        components) dot::rust::components "$@" ;;
        versions)  dot::rust::versions "$@" ;;
        use)       dot::rust::use "$@" ;;
        update)    dot::rust::update "$@" ;;
        install)   dot::rust::install "$@" ;;
        uninstall) dot::rust::uninstall "$@" ;;
        add)       dot::rust::add "$@" ;;
        which)     dot::rust::which "$@" ;;
        doctor)    dot::rust::doctor "$@" ;;
        help|-h|--help) dot::rust::help "$@" ;;
        *) echo "dot::rust: unknown command: ${cmd}" >&2; dot::rust::help; return 1 ;;
    esac
}
