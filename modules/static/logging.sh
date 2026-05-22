#!/bin/sh
#% author: Aaron Samuel
#% description: dot:: structured logging helpers (loaded before dynamic modules)
# shellcheck shell=bash

# --- emoji palette (shown only when DOT_DEBUG=1) ---
_DOT_EMOJI_DEBUG="🔧"
_DOT_EMOJI_INFO="📦"
_DOT_EMOJI_WARN="⚠️ "
_DOT_EMOJI_ERROR="🚨"
_DOT_EMOJI_SUCCESS="✅"
_DOT_EMOJI_LOADING="📂"
_DOT_EMOJI_SKIP="⏭️ "

# --- lightweight structured logging helpers (dot:: namespace) ---

# dot::debug <message> — only prints when DOT_DEBUG=1
function dot::debug() {
    [[ "${DOT_DEBUG:-0}" -eq 1 ]] || return 0
    local prefix="${_DOT_EMOJI_DEBUG} [DEBUG]"
    printf '%s %s\n' "${prefix}" "$*" >&2
}

# dot::info <message> — informational, always prints
function dot::info() {
    if [[ "${DOT_DEBUG:-0}" -eq 1 ]]; then
        printf '%s %s\n' "${_DOT_EMOJI_INFO} [INFO]" "$*"
    else
        printf '[INFO] %s\n' "$*"
    fi
}

# dot::warn <message> — warning, always prints to stderr
function dot::warn() {
    if [[ "${DOT_DEBUG:-0}" -eq 1 ]]; then
        printf '%s %s\n' "${_DOT_EMOJI_WARN}[WARN]" "$*" >&2
    else
        printf '[WARN] %s\n' "$*" >&2
    fi
}

# dot::error <message> — error, always prints to stderr
function dot::error() {
    if [[ "${DOT_DEBUG:-0}" -eq 1 ]]; then
        printf '%s %s\n' "${_DOT_EMOJI_ERROR} [ERROR]" "$*" >&2
    else
        printf '[ERROR] %s\n' "$*" >&2
    fi
}

# dot::success <message> — success confirmation
function dot::success() {
    if [[ "${DOT_DEBUG:-0}" -eq 1 ]]; then
        printf '%s %s\n' "${_DOT_EMOJI_SUCCESS} [OK]" "$*"
    else
        printf '[OK] %s\n' "$*"
    fi
}

# dot::loading <library> <directory> — module load announcement (debug only)
function dot::loading() {
    [[ "${DOT_DEBUG:-0}" -eq 1 ]] || return 0
    local _lib="${1:-unknown}"
    local _dir="${2:-}"
    if [[ -n "${_dir}" ]]; then
        printf '%s loading: %s (%s)\n' "${_DOT_EMOJI_LOADING}" "${_lib}" "${_dir}"
    else
        printf '%s loading: %s\n' "${_DOT_EMOJI_LOADING}" "${_lib}"
    fi
}

# dot::skip <feature> [reason] — skipped feature (debug only)
function dot::skip() {
    [[ "${DOT_DEBUG:-0}" -eq 1 ]] || return 0
    local _feat="${1:-unknown}"
    local _reason="${2:-disabled}"
    printf '%s skip: %s (%s)\n' "${_DOT_EMOJI_SKIP}" "${_feat}" "${_reason}"
}
