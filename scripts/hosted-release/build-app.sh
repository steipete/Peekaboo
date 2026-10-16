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

# Build both release architectures even when the runner has an active architecture.
python3 scripts/setup-swift-workspace.py run --release -- xcodebuild \
  ${PEEKABOO_BUILD_JOBS:+-jobs "$PEEKABOO_BUILD_JOBS"} \
  -workspace "$ROOT/Apps/Peekaboo.xcworkspace" \
  -scheme Peekaboo \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipPackageUpdates \
  -quiet \
  MARKETING_VERSION="$PACKAGE_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  PEEKABOO_SOURCE_COMMIT="$SOURCE_COMMIT" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$DERIVED_DATA/Build/Products/Release/Peekaboo.app"
case "$(lipo -archs "$APP/Contents/MacOS/Peekaboo")" in
  "arm64 x86_64"|"x86_64 arm64") ;;
  *) echo 'App must contain arm64 and x86_64 slices' >&2; exit 1 ;;
esac
# Toolchain compatibility dylibs also carry arm64e; the archetype's Swift runtime audit accepts only arm64+x86_64.
while IFS= read -r -d '' library; do
  if lipo -archs "$library" | tr ' ' '\n' | grep -qx arm64e; then
    lipo "$library" -remove arm64e -output "$library.thin"
    chmod 755 "$library.thin"
    mv -f "$library.thin" "$library"
  fi
done < <(find "$APP/Contents/Frameworks" -maxdepth 1 -type f -name 'libswiftCompatibility*.dylib' -print0)
while IFS= read -r -d '' candidate; do
  file -b "$candidate" | grep -q 'Mach-O' || continue
  scripts/verify-swift-runtime-libraries.sh --rpaths-only "$candidate"
  [[ "$(lipo -archs "$candidate" | tr ' ' '\n' | sort | xargs)" == 'arm64 x86_64' ]] || {
    echo "Peekaboo.app code must be exactly arm64+x86_64: $candidate" >&2
    exit 1
  }
done < <(find "$APP/Contents" -type f -print0)
scripts/verify-release-package-resolution.sh \
  --source-root "$ROOT" --derived-data "$DERIVED_DATA" --app "$APP"
peekaboo_verify_source_commit "$ROOT" "$SOURCE_COMMIT"
ditto "$APP" "$OUTPUT"
printf 'Unsigned app: %s\n' "$OUTPUT"
