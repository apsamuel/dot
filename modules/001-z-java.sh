# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

dot::loading "${library}" "${directory}"

if command -v jenv >/dev/null 2>&1; then
    eval "$(jenv init -)" >/dev/null 2>&1
    JAVA_HOME="$HOME/.jenv/versions/$(jenv version-name)"
    PATH="$JAVA_HOME/bin:$PATH"
    export JAVA_HOME
    alias jenv-set-java-home='export JAVA_HOME="$HOME/.jenv/versions/$(jenv version-name)"'
fi

# export PATH="$HOME/.jenv/bin:$PATH"
# eval "$(jenv init -)"
# add openjdk to path
# PATH="/usr/local/opt/openjdk/bin:$PATH"
