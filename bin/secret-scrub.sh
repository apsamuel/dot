#!/usr/bin/env bash
#% description: safely scrub secrets from git history, index, and cache
#% usage:   bin/secret-scrub.sh [options]
#%
#% options:
#%   -s <secret>       literal secret string to remove (repeatable)
#%   -f <file>         file of replacement rules (one per line)
#%                     each line: literal:<value>==>REPLACEMENT
#%                            or: regex:<pattern>==>REPLACEMENT
#%   -r <replacement>  replacement token written in place of the secret
#%                     (default: ***REMOVED***)
#%   -m                also scrub all registered git submodules
#%   -n                dry run — grep history for matches, no rewrites
#%   --push            force-push all branches + tags to origin after scrubbing
#%                     (requires re-added remote; filter-repo removes it)
#%   -h                print this help
#%
#% examples:
#%   bin/secret-scrub.sh -s "ghp_MyToken123"
#%   bin/secret-scrub.sh -s "API_KEY=abc123" -s "ANOTHER_SECRET" -m
#%   bin/secret-scrub.sh -f my-replacements.txt --push
#%   bin/secret-scrub.sh -s "ghp_MyToken123" -n      # dry run first
#%
#% ⚠️  BEFORE running this script:
#%   1. Rotate / revoke the exposed secret immediately — cleaning history
#%      does NOT un-expose a secret that has already been pushed.
#%   2. Notify any collaborators: their local clones will diverge after
#%      the rewrite and must be re-cloned or hard-reset.
#%   3. This rewrites commit SHAs across all branches. CI/CD pipelines,
#%      open PRs, and protected-branch rules may all be affected.

set -euo pipefail

# ── colours & helpers ────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}ℹ️  $*${RESET}"; }
ok()      { echo -e "${GREEN}✅  $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠️  $*${RESET}"; }
fail()    { echo -e "${RED}❌  $*${RESET}" >&2; exit 1; }
heading() { echo -e "\n${BOLD}── $* ──${RESET}"; }

# ── usage ────────────────────────────────────────────────────────────────────
usage() {
    grep '^#%' "$0" | sed 's/^#% \{0,1\}//'
    exit 0
}

# ── prerequisites ────────────────────────────────────────────────────────────
check_prerequisites() {
    if ! command -v git-filter-repo &>/dev/null; then
        fail "git-filter-repo is required but not found.\n   Install: brew install git-filter-repo"
    fi

    if ! git rev-parse --git-dir &>/dev/null; then
        fail "Not inside a git repository."
    fi

    # Warn if there are uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        warn "You have uncommitted changes. Consider stashing or committing first."
        read -r -p "Continue anyway? [y/N] " confirm
        [[ "${confirm,,}" == "y" ]] || { info "Aborted."; exit 0; }
    fi
}

# ── build replacements file ───────────────────────────────────────────────────
# git filter-repo --replace-text format:
#   literal:<value>==>REPLACEMENT
#   regex:<pattern>==>REPLACEMENT
#   glob:<pattern>==>REPLACEMENT
build_replacements_file() {
    local outfile="$1"; shift
    local replacement="$1"; shift
    local secrets=("$@")

    # Start fresh
    : > "${outfile}"

    for secret in "${secrets[@]}"; do
        printf 'literal:%s==>%s\n' "${secret}" "${replacement}" >> "${outfile}"
    done
}

# ── dry run: grep history for matches ────────────────────────────────────────
dry_run() {
    local secrets=("$@")
    heading "Dry Run — searching history for secrets"

    local found=0
    for secret in "${secrets[@]}"; do
        info "Scanning for: ${secret:0:4}$(printf '*%.0s' {1..8})${secret: -2} ..."
        # Search commit diffs
        if git log --all -p --diff-filter=ACMR -- | grep -qF "${secret}" 2>/dev/null; then
            warn "Found in commit history (diffs/blobs)"
            found=1
        fi
        # Search all trees (filenames and content via git grep)
        if git grep -l --all-targets "${secret}" 2>/dev/null | grep -q .; then
            warn "Found in tracked files:"
            git grep -l --all-targets "${secret}" 2>/dev/null | sed 's/^/    /'
            found=1
        fi
        # Search commit messages
        if git log --all --grep="${secret}" --oneline | grep -q .; then
            warn "Found in commit messages:"
            git log --all --grep="${secret}" --oneline | sed 's/^/    /'
            found=1
        fi
    done

    if [[ $found -eq 0 ]]; then
        ok "No matches found. Nothing to scrub."
    else
        warn "Matches found. Re-run without -n to rewrite history."
    fi
}

# ── scrub a single repo ───────────────────────────────────────────────────────
scrub_repo() {
    local repo_path="$1"
    local replacements_file="$2"
    local do_push="${3:-false}"

    heading "Scrubbing: ${repo_path}"
    pushd "${repo_path}" > /dev/null

    # Capture remote URL before filter-repo removes it
    local remote_url=""
    if git remote get-url origin &>/dev/null; then
        remote_url="$(git remote get-url origin)"
        info "Captured remote URL: ${remote_url}"
    fi

    # Snapshot all current commit SHAs so we can verify something actually changed
    local pre_head
    pre_head="$(git rev-parse HEAD)"

    info "Rewriting history with git-filter-repo..."
    # --force is required when the repo has an origin (it's a safety guard)
    git filter-repo \
        --replace-text "${replacements_file}" \
        --force \
        2>&1 | sed 's/^/  /'

    # ── verify the rewrite actually changed something ────────────────────────
    local post_head
    post_head="$(git rev-parse HEAD)"
    if [[ "${pre_head}" == "${post_head}" ]]; then
        warn "HEAD SHA is unchanged after filter-repo — the replacement pattern"
        warn "likely did not match any blobs. Double-check the secret value."
        warn "No history was modified in: ${repo_path}"
    else
        ok "History rewritten. HEAD changed: ${pre_head:0:12} → ${post_head:0:12}"
    fi

    # ── post-rewrite cleanup ─────────────────────────────────────────────────
    heading "Post-rewrite cleanup: ${repo_path}"

    info "Expiring reflog..."
    git reflog expire --expire=now --all

    info "Running aggressive gc to prune orphaned objects..."
    git gc --prune=now --aggressive 2>&1 | sed 's/^/  /'

    # Clean up the backup refs that filter-repo may leave
    if git show-ref | grep -q 'refs/filter-repo'; then
        info "Removing filter-repo backup refs..."
        git for-each-ref --format='delete %(refname)' refs/filter-repo | \
            git update-ref --stdin
    fi

    ok "Cleanup complete."

    # ── restore remote & optionally push ────────────────────────────────────
    if [[ -n "${remote_url}" ]]; then
        info "Re-adding remote origin: ${remote_url}"
        git remote add origin "${remote_url}"

        if [[ "${do_push}" == "true" ]]; then
            heading "Force-pushing to origin"
            warn "This is irreversible. All collaborators MUST re-clone."
            read -r -p "Force-push ${repo_path} to origin? [y/N] " confirm
            if [[ "${confirm,,}" == "y" ]]; then
                git push origin --force --all
                git push origin --force --tags
                ok "Force-pushed all branches and tags."
            else
                info "Skipped push. When ready, run:"
                echo "  cd ${repo_path} && git push origin --force --all && git push origin --force --tags"
            fi
        else
            info "Remote restored. When ready to publish the rewrite, run:"
            echo "  cd ${repo_path} && git push origin --force --all && git push origin --force --tags"
            warn "⚠️  Do NOT run 'git pull' before force-pushing — it will re-introduce"
            warn "   the old commits from the remote, undoing the rewrite."
        fi
    fi

    popd > /dev/null
}

# ── submodule handling ────────────────────────────────────────────────────────
scrub_submodules() {
    local repo_root="$1"
    local replacements_file="$2"
    local do_push="$3"

    heading "Scrubbing submodules"

    local submodule_paths=()
    while IFS= read -r line; do
        # git submodule foreach outputs: Entering 'vendor/ohmyzsh'
        local sm_path
        sm_path="$(echo "${line}" | sed "s/Entering '//;s/'//")"
        submodule_paths+=("${repo_root}/${sm_path}")
    done < <(git -C "${repo_root}" submodule foreach --quiet 'echo "Entering '"'"'$displaypath'"'"'"')

    if [[ ${#submodule_paths[@]} -eq 0 ]]; then
        info "No submodules found."
        return
    fi

    for sm_path in "${submodule_paths[@]}"; do
        info "Processing submodule: ${sm_path}"
        if [[ -d "${sm_path}/.git" || -f "${sm_path}/.git" ]]; then
            # Submodules always prompt for push — leaving a submodule unpushed
            # is the most common failure mode (secret stays on remote).
            scrub_repo "${sm_path}" "${replacements_file}" "true"
        else
            warn "Skipping ${sm_path} — not a git repo (may not be initialized)"
        fi
    done
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
    local secrets=()
    local rules_file=""
    local replacement="***REMOVED***"
    local do_submodules=false
    local dry=false
    local do_push=false

    # parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s)       [[ -n "${2:-}" ]] || fail "-s requires a value"; secrets+=("$2"); shift 2 ;;
            -f)       [[ -n "${2:-}" ]] || fail "-f requires a file path"; rules_file="$2"; shift 2 ;;
            -r)       [[ -n "${2:-}" ]] || fail "-r requires a value"; replacement="$2"; shift 2 ;;
            -m)       do_submodules=true; shift ;;
            -n)       dry=true; shift ;;
            --push)   do_push=true; shift ;;
            -h|--help) usage ;;
            *)        fail "Unknown option: $1\nRun with -h for help." ;;
        esac
    done

    # must have at least one source of secrets
    if [[ ${#secrets[@]} -eq 0 && -z "${rules_file}" ]]; then
        fail "Provide at least one secret via -s or a rules file via -f.\nRun with -h for help."
    fi

    check_prerequisites

    local repo_root
    repo_root="$(git rev-parse --show-toplevel)"

    # ── build the replacements file ──────────────────────────────────────────
    local tmp_replacements
    tmp_replacements="$(mktemp /tmp/secret-scrub-rules.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -f '${tmp_replacements}'" EXIT

    if [[ ${#secrets[@]} -gt 0 ]]; then
        build_replacements_file "${tmp_replacements}" "${replacement}" "${secrets[@]}"
    fi

    # append any user-supplied rules file
    if [[ -n "${rules_file}" ]]; then
        if [[ ! -f "${rules_file}" ]]; then
            fail "Rules file not found: ${rules_file}"
        fi
        cat "${rules_file}" >> "${tmp_replacements}"
    fi

    info "Replacement rules:"
    # Print rules but mask any secret values in output
    sed 's/\(literal:\|regex:\|glob:\)\(.\{4\}\).*/\1\2***/' "${tmp_replacements}" | sed 's/^/  /'

    # ── dry run mode ─────────────────────────────────────────────────────────
    if [[ "${dry}" == "true" ]]; then
        dry_run "${secrets[@]}"
        exit 0
    fi

    # ── confirm before rewriting ─────────────────────────────────────────────
    heading "Pre-flight confirmation"
    warn "This will permanently rewrite git history in: ${repo_root}"
    [[ "${do_submodules}" == "true" ]] && warn "…and all submodules."
    warn "Commit SHAs will change. Collaborators must re-clone after you force-push."
    echo ""
    read -r -p "Proceed with rewriting history? [y/N] " confirm
    [[ "${confirm,,}" == "y" ]] || { info "Aborted. No changes made."; exit 0; }

    # ── scrub main repo ───────────────────────────────────────────────────────
    scrub_repo "${repo_root}" "${tmp_replacements}" "${do_push}"

    # ── optionally scrub submodules ───────────────────────────────────────────
    if [[ "${do_submodules}" == "true" ]]; then
        scrub_submodules "${repo_root}" "${tmp_replacements}" "${do_push}"
    fi

    # ── final reminders ───────────────────────────────────────────────────────
    heading "Done — next steps"
    echo -e "${YELLOW}1. Rotate the exposed secret immediately if you haven't already.${RESET}"
    echo -e "${YELLOW}2. Force-push to origin (if not done above):${RESET}"
    echo    "     git push origin --force --all"
    echo    "     git push origin --force --tags"
    echo -e "${YELLOW}3. Ask all collaborators to re-clone the repository.${RESET}"
    echo -e "${YELLOW}4. Check GitHub/GitLab secret scanning alerts and mark them resolved.${RESET}"
    echo -e "${YELLOW}5. Review dependent CI/CD pipelines for cached secrets or credentials.${RESET}"
    echo ""
    ok "Secret scrub complete."
}

main "$@"
