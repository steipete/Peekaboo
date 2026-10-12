#!/usr/bin/env bash
# No arguments. The package job stages the signed payload in dist/sparkle-cli/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
PACKAGE_VERSION="$(node -p 'require("./package.json").version')"
[[ "${VERSION:-$PACKAGE_VERSION}" == "$PACKAGE_VERSION" ]] || {
  echo 'VERSION must match the prepared package.json version' >&2
  exit 1
}
SIGNED_CLI="$ROOT/dist/sparkle-cli"
OUTPUT="$ROOT/dist/sparkle-npm"
[[ -x "$SIGNED_CLI/peekaboo" ]] || { echo "Missing staged CLI: $SIGNED_CLI/peekaboo" >&2; exit 1; }
[[ ! -e "$OUTPUT" ]] || { echo "Output already exists: $OUTPUT" >&2; exit 1; }

# package.json's files list expects the binary and companions at the repo root.
cp "$SIGNED_CLI/peekaboo" "$ROOT/peekaboo"
for library in "$ROOT"/libswiftCompatibility*.dylib; do
  [[ -e "$library" ]] || continue
  rm -f "$library"
done
for library in "$SIGNED_CLI"/libswiftCompatibility*.dylib; do
  [[ -e "$library" ]] || continue
  cp "$library" "$ROOT/"
done
# Hosted runner images ship Node but not pnpm; Corepack runs the packageManager-pinned, integrity-checked pnpm.
if command -v pnpm >/dev/null 2>&1; then
  PNPM=(pnpm)
elif command -v corepack >/dev/null 2>&1; then
  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
  PNPM=(corepack pnpm)
else
  echo 'pnpm or corepack is required to pack the npm package' >&2
  exit 1
fi
mkdir -p "$OUTPUT"
"${PNPM[@]}" pack --pack-destination "$OUTPUT"

shopt -s nullglob
TARBALLS=("$OUTPUT"/*.tgz)
[[ ${#TARBALLS[@]} -eq 1 ]] || { echo 'Expected exactly one npm tarball' >&2; exit 1; }
VERIFY_DIR="$(mktemp -d "$OUTPUT/verify.XXXXXX")"
trap 'rm -rf "$VERIFY_DIR"' EXIT
tar -xzf "${TARBALLS[0]}" -C "$VERIFY_DIR"
cmp "$SIGNED_CLI/peekaboo" "$VERIFY_DIR/package/peekaboo"
for library in "$SIGNED_CLI"/libswiftCompatibility*.dylib; do
  cmp "$library" "$VERIFY_DIR/package/$(basename "$library")"
done
printf 'npm tarball (signed payload preserved): %s\n' "${TARBALLS[0]}"
