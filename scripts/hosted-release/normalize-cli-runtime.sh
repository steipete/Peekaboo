#!/usr/bin/env bash
# Keep the staged Swift runtime payload aligned with the universal CLI.
set -euo pipefail

[[ "$#" -eq 1 && -d "${1:-}" && ! -L "${1:-}" ]] || {
  echo "Usage: $0 <staged-cli-directory>" >&2
  exit 2
}
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
shopt -s nullglob
libraries=("$1"/libswiftCompatibility*.dylib)

# Validate the full inventory before replacing any staged library.
for library in ${libraries[@]+"${libraries[@]}"}; do
  [[ -f "$library" && ! -L "$library" ]] || { echo "Invalid runtime library: $library" >&2; exit 1; }
  arches=" $(lipo -archs "$library") "
  [[ "$arches" == *" arm64 "* && "$arches" == *" x86_64 "* ]] || {
    echo "Runtime library must contain arm64 and x86_64: $library" >&2
    exit 1
  }
done

temporary=""
trap '[[ -z "$temporary" ]] || rm -f -- "$temporary"' EXIT
for library in ${libraries[@]+"${libraries[@]}"}; do
  temporary="$(mktemp "${library}.XXXXXX")"
  lipo "$library" -extract arm64 -extract x86_64 -output "$temporary"
  chmod "$(stat -f '%Lp' "$library")" "$temporary"
  mv -f -- "$temporary" "$library"
  temporary=""
  # lipo changes signed bytes; the approved signing job applies Developer ID later.
  MAC_RELEASE_CODESIGN_BIN=/usr/bin/codesign "$ROOT/scripts/codesign-with-retry.sh" \
    --force --sign - --options runtime --timestamp=none "$library"
  /usr/bin/codesign --verify --strict "$library"
done
