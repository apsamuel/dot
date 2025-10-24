#! /usr/bin/env bash

# Format Turtle source files
find . -name "*.rs" -print -exec rustfmt {} \;

mapfile -t rust_files < <(find . -name "*.rs" -print)

for file in "${rust_files[@]}"; do
    printf "Formatting %s\n" "$file"
    rustfmt "$file"
done