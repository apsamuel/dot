# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null


if command -v jenv >/dev/null 2>&1; then
    eval "$(jenv init -)" >/dev/null 2>&1
    JAVA_HOME="$HOME/.jenv/versions/$(jenv version-name)"
    export JAVA_HOME
    alias jenv-set-java-home='export JAVA_HOME="$HOME/.jenv/versions/$(jenv version-name)"'
fi