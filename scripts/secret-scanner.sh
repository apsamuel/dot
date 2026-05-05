# shellcheck source=/dev/null
# shellcheck shell=bash

podman run --rm \
  -v "$HOME"/.dot:/src \
  trufflesecurity/trufflehog:latest \
  git file:///src \
  --results=verified,unknown \
  --fail \
  --exclude-paths /src/.trufflehog-exclude.txt