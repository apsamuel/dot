#shellcheck shell=bash
# shellcheck source=/dev/null

function compile::terminfo() {
    infocmp -x xterm-256color
    printf '\t%s\n' 'ncv@,'
} >/tmp/t && tic -x /tmp/t
