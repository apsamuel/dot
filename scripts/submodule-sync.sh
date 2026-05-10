#!/usr/bin/env bash
#% author: github.com/apsamuel
#% description: manage root-level and vendored (nested) git submodules
#% usage: ./submodule-sync.sh [OPTIONS] <command> [submodule]
#
# Commands:
#   status      Show checkout state for all submodules (root + nested)
#   init        Initialize + update all submodules recursively
#   update      Pull latest for all submodules recursively
#   list        Print all registered submodule paths and remote URLs
#
# Arguments:
#   submodule   Optional submodule path to target (e.g. vendor/oh-my-zsh).
#               When omitted, all submodules are processed.
#
# Options:
#   -n          Dry-run — print commands instead of running them
#   -v          Verbose — pass --verbose to git submodule calls
#   -j <N>      Parallel jobs for git submodule update (default: 4)
#   -h          Show this help

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

DRY_RUN=0
VERBOSE=0
JOBS=4

_log()  { printf '[submodule-sync] %s\n' "$*" >&2; }
_info() { printf '  ✔  %s\n'              "$*"; }
_warn() { printf '  ⚠  %s\n'              "$*" >&2; }
_err()  { printf '  ✖  %s\n'              "$*" >&2; }

run() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        printf '[dry-run] %s\n' "$*"
        return 0
    fi
    "$@"
}

verbose_flag() {
    [[ "${VERBOSE}" -eq 1 ]] && echo "--verbose" || echo ""
}

# ── resolve repo root ─────────────────────────────────────────────────────────

find_repo_root() {
    local dir="${PWD}"
    while [[ "${dir}" != "/" ]]; do
        [[ -f "${dir}/.git/config" || -f "${dir}/.gitmodules" ]] && { echo "${dir}"; return; }
        dir="$(dirname "${dir}")"
    done
    _err "Could not find git repository root from ${PWD}"
    exit 1
}

REPO_ROOT="$(find_repo_root)"

# ── usage ─────────────────────────────────────────────────────────────────────

usage() {
    grep '^#[%]' "$0" | sed 's/^#[%] \{0,1\}//'
    echo
    echo "Commands:"
    echo "  status   Show checkout state for all submodules (root + nested)"
    echo "  init     Initialize + update all submodules recursively"
    echo "  update   Pull latest for all submodules recursively"
    echo "  list     Print all registered submodule paths and remote URLs"
    echo
    echo "Arguments:"
    echo "  submodule  Optional submodule path (e.g. vendor/oh-my-zsh)."
    echo "             When omitted, all submodules are processed."
    echo
    echo "Options:"
    echo "  -n       Dry-run — print commands instead of running them"
    echo "  -v       Verbose — pass --verbose to git submodule calls"
    echo "  -j <N>   Parallel jobs for git submodule update (default: ${JOBS})"
    echo "  -h       Show this help"
}

# ── subcommand: status ────────────────────────────────────────────────────────
# Prints a human-readable table showing which submodules are:
#   ✔  checked out (commit hash shown)
#   -  not yet initialized / checked out
#   +  checked out but at a different commit than recorded in the index

cmd_status() {
    _log "submodule status (root + nested) in ${REPO_ROOT}${TARGET:+ [filter: ${TARGET}]}"
    echo
    printf '%-6s  %-55s  %s\n' "STATE" "PATH" "REF / COMMIT"
    printf '%-6s  %-55s  %s\n' "-----" "----" "------------"

    git -C "${REPO_ROOT}" submodule foreach --quiet --recursive \
        'echo "${displaypath} $(git -C "${toplevel}/${displaypath}" rev-parse --short HEAD 2>/dev/null || echo "(uninitialized)")"' \
        2>/dev/null | while read -r path ref; do
            if [[ -n "${TARGET}" && "${path}" != "${TARGET}" && "${path}" != "${TARGET}"/* ]]; then
                continue
            fi
            printf '%-6s  %-55s  %s\n' "✔" "${path}" "${ref}"
        done

    # Also surface uninitialized entries (shown with '-' by git submodule status)
    echo
    _log "uninitialized submodule entries:"
    git -C "${REPO_ROOT}" submodule status --recursive 2>/dev/null \
        | grep '^-' \
        | awk '{print "  -  " $2}' \
        | { [[ -n "${TARGET}" ]] && grep -F "${TARGET}" || cat; } \
        || _info "none"
}

# ── subcommand: list ──────────────────────────────────────────────────────────
cmd_list() {
    _log "registered submodules in ${REPO_ROOT}${TARGET:+ [filter: ${TARGET}]}"
    echo
    printf '%-55s  %s\n' "PATH" "URL"
    printf '%-55s  %s\n' "----" "---"

    # Root-level submodules
    git -C "${REPO_ROOT}" config --file "${REPO_ROOT}/.gitmodules" \
        --get-regexp 'submodule\..*\.path' \
        | awk '{print $2}' \
        | while read -r path; do
            # skip if a target is specified and this path doesn't match
            if [[ -n "${TARGET}" && "${path}" != "${TARGET}" && "${path}" != "${TARGET}"/* && "${TARGET}" != "${path}"/* ]]; then
                continue
            fi
            url="$(git -C "${REPO_ROOT}" config --file "${REPO_ROOT}/.gitmodules" \
                --get "submodule.${path}.url" 2>/dev/null || echo "(no url)")"
            # Strip the leading "submodule." prefix that git uses
            # the submodule name may differ from path; find by path
            name="$(git -C "${REPO_ROOT}" config --file "${REPO_ROOT}/.gitmodules" \
                --get-regexp 'submodule\..*\.path' \
                | awk -v p="${path}" '$2==p{sub(/submodule\./,""); sub(/\.path/,""); print $1}')"
            url="$(git -C "${REPO_ROOT}" config --file "${REPO_ROOT}/.gitmodules" \
                --get "submodule.${name}.url" 2>/dev/null || echo "(no url)")"
            printf '  %-53s  %s\n' "${path}" "${url}"

            # If this submodule has its own .gitmodules, list nested entries
            nested_gitmodules="${REPO_ROOT}/${path}/.gitmodules"
            if [[ -f "${nested_gitmodules}" ]]; then
                git config --file "${nested_gitmodules}" \
                    --get-regexp 'submodule\..*\.path' \
                    | awk '{print $2}' \
                    | while read -r npath; do
                        nname="$(git config --file "${nested_gitmodules}" \
                            --get-regexp 'submodule\..*\.path' \
                            | awk -v p="${npath}" '$2==p{sub(/submodule\./,""); sub(/\.path/,""); print $1}')"
                        nurl="$(git config --file "${nested_gitmodules}" \
                            --get "submodule.${nname}.url" 2>/dev/null || echo "(no url)")"
                        printf '  %-53s  %s\n' "  └─ ${path}/${npath}" "${nurl}"
                    done
            fi
        done
}

# ── subcommand: init ──────────────────────────────────────────────────────────
# Runs git submodule update --init --recursive with optional parallelism.
# For any submodule whose URL uses git+ssh (git@...) and ssh-agent has no
# identities loaded, the script warns and skips rather than hanging.

_ssh_available() {
    ssh-add -l &>/dev/null && return 0 || {
        local rc=$?
        # rc=1 → agent running but no keys; rc=2 → agent not running
        [[ $rc -eq 2 ]] && return 1
        return 1
    }
}

_rewrite_url_if_needed() {
    # If SSH is unavailable and URL is an SSH URL, rewrite to HTTPS (best-effort)
    local url="$1"
    if [[ "${url}" == git@github.com:* ]] && ! _ssh_available; then
        # git@github.com:owner/repo.git  →  https://github.com/owner/repo.git
        echo "${url/git@github.com:/https:\/\/github.com\/}"
        return
    fi
    echo "${url}"
}

cmd_init() {
    _log "initializing + updating all submodules in ${REPO_ROOT}${TARGET:+ [filter: ${TARGET}]}"

    local vflag
    vflag="$(verbose_flag)"

    # Step 1 — root-level submodules
    _log "step 1/2: root-level submodules"
    # shellcheck disable=SC2086
    run git -C "${REPO_ROOT}" submodule update \
        --init \
        ${vflag} \
        --jobs "${JOBS}" \
        ${TARGET:+-- "${TARGET}"} \
        2>&1 | sed 's/^/  /'

    # Step 2 — nested submodules inside each vendor path
    _log "step 2/2: nested submodules within vendor paths"

    while IFS= read -r vendor_path; do
        # when a target is specified, only process vendor paths that match or contain it
        if [[ -n "${TARGET}" && "${vendor_path}" != "${TARGET}" && "${TARGET}" != "${vendor_path}"/* ]]; then
            continue
        fi

        vendor_dir="${REPO_ROOT}/${vendor_path}"
        nested_gitmodules="${vendor_dir}/.gitmodules"

        [[ -f "${nested_gitmodules}" ]] || continue

        _info "processing nested submodules in ${vendor_path}"

        # Rewrite SSH URLs to HTTPS when no SSH key is available, so CI/CD
        # environments without an SSH agent can still clone.
        while IFS= read -r npath; do
            nname="$(git config --file "${nested_gitmodules}" \
                --get-regexp 'submodule\..*\.path' \
                | awk -v p="${npath}" '$2==p{sub(/submodule\./,""); sub(/\.path/,""); print $1}')"
            nurl="$(git config --file "${nested_gitmodules}" \
                --get "submodule.${nname}.url" 2>/dev/null || true)"

            if [[ -z "${nurl}" ]]; then
                _warn "no URL for nested submodule ${vendor_path}/${npath} — skipping"
                continue
            fi

            rewritten="$(_rewrite_url_if_needed "${nurl}")"
            if [[ "${rewritten}" != "${nurl}" ]]; then
                _warn "SSH unavailable; temporarily using HTTPS for ${vendor_path}/${npath}"
                run git -C "${vendor_dir}" config "submodule.${nname}.url" "${rewritten}"
            fi
        done < <(git config --file "${nested_gitmodules}" \
            --get-regexp 'submodule\..*\.path' | awk '{print $2}')

        # shellcheck disable=SC2086
        run git -C "${vendor_dir}" submodule update \
            --init \
            --recursive \
            ${vflag} \
            --jobs "${JOBS}" \
            2>&1 | sed 's/^/    /'

    done < <(git -C "${REPO_ROOT}" config --file "${REPO_ROOT}/.gitmodules" \
        --get-regexp 'submodule\..*\.path' | awk '{print $2}')

    _log "done — all submodules initialized"
}

# ── subcommand: update ────────────────────────────────────────────────────────
# Fetches latest remote commits and updates each submodule to HEAD of its
# tracked branch (or the commit pinned in the index if no branch is set).

cmd_update() {
    _log "updating all submodules to latest in ${REPO_ROOT}${TARGET:+ [filter: ${TARGET}]}"

    local vflag
    vflag="$(verbose_flag)"

    # Root-level
    _log "step 1/2: root-level submodules"
    # shellcheck disable=SC2086
    run git -C "${REPO_ROOT}" submodule update \
        --init \
        --remote \
        ${vflag} \
        --jobs "${JOBS}" \
        ${TARGET:+-- "${TARGET}"} \
        2>&1 | sed 's/^/  /'

    # Nested
    _log "step 2/2: nested submodules within vendor paths"
    while IFS= read -r vendor_path; do
        # when a target is specified, only process vendor paths that match or contain it
        if [[ -n "${TARGET}" && "${vendor_path}" != "${TARGET}" && "${TARGET}" != "${vendor_path}"/* ]]; then
            continue
        fi

        vendor_dir="${REPO_ROOT}/${vendor_path}"
        [[ -f "${vendor_dir}/.gitmodules" ]] || continue

        _info "updating nested submodules in ${vendor_path}"
        # shellcheck disable=SC2086
        run git -C "${vendor_dir}" submodule update \
            --init \
            --recursive \
            --remote \
            ${vflag} \
            --jobs "${JOBS}" \
            2>&1 | sed 's/^/    /'
    done < <(git -C "${REPO_ROOT}" config --file "${REPO_ROOT}/.gitmodules" \
        --get-regexp 'submodule\..*\.path' | awk '{print $2}')

    _log "done — all submodules updated"
}

# ── argument parsing ──────────────────────────────────────────────────────────

while getopts ":nvj:h" opt; do
    case "${opt}" in
        n) DRY_RUN=1 ;;
        v) VERBOSE=1 ;;
        j) JOBS="${OPTARG}" ;;
        h) usage; exit 0 ;;
        :) _err "-${OPTARG} requires an argument"; usage; exit 1 ;;
        \?) _err "unknown option: -${OPTARG}"; usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

COMMAND="${1:-status}"
TARGET="${2:-}"

case "${COMMAND}" in
    status) cmd_status ;;
    init)   cmd_init   ;;
    update) cmd_update ;;
    list)   cmd_list   ;;
    *)
        _err "unknown command: ${COMMAND}"
        usage
        exit 1
        ;;
esac
