#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
policy_files=("$ROOT_DIR/.mac-release.env" "$ROOT_DIR/scripts/hosted-release/build-app.sh" "$ROOT_DIR/scripts/hosted-release/build-cli.sh" "$ROOT_DIR/scripts/create-release-dmg.sh")
if rg -n 'Y5PE65HELJ|Developer ID Application: Peter Steinberger' "${policy_files[@]}"; then
  echo 'Personal signing identity remains in an active release surface' >&2
  exit 1
fi
rg -Fq 'require-signed-tag: true' "$ROOT_DIR/.github/workflows/release.yml"
rg -Fq 'scripts/hosted-release/build-app.sh' "$ROOT_DIR/.github/workflows/release.yml"
rg -Fq 'scripts/hosted-release/build-cli.sh' "$ROOT_DIR/.github/workflows/release.yml"
test ! -e "$ROOT_DIR/scripts/release-binaries.sh"
test ! -e "$ROOT_DIR/scripts/release-macos-app.sh"
echo 'Hosted release signing policy passed'
