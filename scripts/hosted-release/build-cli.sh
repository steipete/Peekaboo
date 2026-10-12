#!/usr/bin/env bash
# No arguments. Emit the ad-hoc universal CLI and its runtime companions.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
PACKAGE_VERSION="$(node -p 'require("./package.json").version')"
CLI_VERSION="$(node -p 'require("./version.json").version')"
[[ "${VERSION:-$PACKAGE_VERSION}" == "$PACKAGE_VERSION" && "$CLI_VERSION" == "$PACKAGE_VERSION" ]] || {
  echo 'VERSION, package.json, and version.json must agree' >&2
  exit 1
}
OUTPUT="$ROOT/dist/sparkle-cli"
[[ ! -e "$OUTPUT" ]] || { echo "Output already exists: $OUTPUT" >&2; exit 1; }

python3 scripts/setup-swift-workspace.py setup --release
# Force the CI ad-hoc path even when a local shell has release signing settings.
env -u MAC_RELEASE_CODESIGN_IDENTITY -u MAC_RELEASE_CODESIGN_KEYCHAIN \
  -u CODESIGN_KEYCHAIN -u MAC_RELEASE_CODESIGN_BIN \
  SIGN_IDENTITY=- CODESIGN_TIMESTAMP=off \
  scripts/build-swift-universal.sh

mkdir -p "$OUTPUT"
cp "$ROOT/peekaboo" "$OUTPUT/"
for library in "$ROOT"/libswiftCompatibility*.dylib; do
  [[ -e "$library" ]] || continue
  # Toolchain compatibility dylibs also carry arm64e; the archetype requires exactly arm64+x86_64 payloads.
  if lipo -archs "$library" | tr ' ' '\n' | grep -qx arm64e; then
    lipo "$library" -remove arm64e -output "$OUTPUT/$(basename "$library")"
    chmod 755 "$OUTPUT/$(basename "$library")"
  else
    cp "$library" "$OUTPUT/"
  fi
done
for payload in "$OUTPUT"/*; do
  [[ "$(lipo -archs "$payload" | tr ' ' '\n' | sort | xargs)" == 'arm64 x86_64' ]] || {
    echo "CLI payload must be exactly arm64+x86_64: $payload" >&2
    exit 1
  }
done
printf 'Ad-hoc universal CLI: %s/peekaboo\n' "$OUTPUT"
