# shellcheck source=/dev/null
# shellcheck shell=bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: secret-scanner.sh"
  echo "Run trufflehog in a container against the local dot repository."
  exit 0
fi

podman run --rm \
  -v "$HOME"/.dot:/src \
  trufflesecurity/trufflehog:latest \
  git file:///src \
  --fail \
  --exclude-paths /src/.trufflehog-exclude.txt