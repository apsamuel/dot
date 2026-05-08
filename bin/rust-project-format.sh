# shellcheck source=/dev/null
# shellcheck shell=bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: rust-project-format.sh"
    echo "Find and format Rust source files recursively with rustfmt."
    exit 0
fi

# Format Turtle source files
find . -name "*.rs" -print -exec rustfmt {} \;

mapfile -t rust_files < <(find . -name "*.rs" -print)

for file in "${rust_files[@]}"; do
    printf "Formatting %s\n" "$file"
    rustfmt "$file"
done