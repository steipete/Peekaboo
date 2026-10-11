#!/usr/bin/env bash
# No arguments. Build the prepared package version without signing credentials.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source "$ROOT/scripts/release-version.sh"
source "$ROOT/scripts/source-provenance.sh"
PACKAGE_VERSION="$(node -p 'require("./package.json").version')"
[[ "${VERSION:-$PACKAGE_VERSION}" == "$PACKAGE_VERSION" ]] || {
  echo 'VERSION must match the prepared package.json version' >&2
  exit 1
}
BUILD_NUMBER="$(peekaboo_release_build_number "$PACKAGE_VERSION")"
SOURCE_COMMIT="$(peekaboo_require_source_commit "$ROOT")"
OUTPUT="$ROOT/dist/sparkle-app/Peekaboo.app"
[[ ! -e "$OUTPUT" ]] || { echo "Output already exists: $OUTPUT" >&2; exit 1; }
mkdir -p "$ROOT/build" "$(dirname "$OUTPUT")"
DERIVED_DATA="$(mktemp -d "$ROOT/build/hosted-app.XXXXXX")"
trap 'rm -rf "$DERIVED_DATA"' EXIT

# Keep the release driver's destination, locked resolution, and version stamps.
python3 scripts/setup-swift-workspace.py run --release -- xcodebuild \
  ${PEEKABOO_BUILD_JOBS:+-jobs "$PEEKABOO_BUILD_JOBS"} \
  -workspace "$ROOT/Apps/Peekaboo.xcworkspace" \
  -scheme Peekaboo \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA" \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipPackageUpdates \
  -quiet \
  MARKETING_VERSION="$PACKAGE_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  PEEKABOO_SOURCE_COMMIT="$SOURCE_COMMIT" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$DERIVED_DATA/Build/Products/Release/Peekaboo.app"
scripts/verify-release-package-resolution.sh \
  --source-root "$ROOT" --derived-data "$DERIVED_DATA" --app "$APP"
peekaboo_verify_source_commit "$ROOT" "$SOURCE_COMMIT"
ditto "$APP" "$OUTPUT"
printf 'Unsigned app: %s\n' "$OUTPUT"
