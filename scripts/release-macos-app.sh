#!/usr/bin/env bash
# Build, sign, notarize, staple, zip, Sparkle-sign, and optionally upload Peekaboo.app.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$ROOT_DIR/Apps/Peekaboo.xcworkspace}"
SCHEME="${SCHEME:-Peekaboo}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/peekaboo-macos-app-release}"
RELEASE_DIR="${RELEASE_DIR:-$ROOT_DIR/release}"
APP_NAME="${APP_NAME:-Peekaboo}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Peter Steinberger (Y5PE65HELJ)}"
SPARKLE_PRIVATE_KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-$HOME/Library/CloudStorage/Dropbox/Backup/Sparkle/sparkle-private-key-KEEP-SECURE.txt}"
APPCAST_PATH="${APPCAST_PATH:-$ROOT_DIR/appcast.xml}"
MINIMUM_SYSTEM_VERSION="${MINIMUM_SYSTEM_VERSION:-15.0}"
REPOSITORY_SLUG="${REPOSITORY_SLUG:-openclaw/Peekaboo}"

VERSION="$(node -p "require('$ROOT_DIR/package.json').version")"
TAG="v${VERSION}"
UPDATE_APPCAST=true
UPLOAD=false
UPLOAD_CHECKSUMS=false
NOTARIZE=true
KEEP_DERIVED_DATA=false
DRY_RUN=false
SKIP_BUILD=false
VERIFY_ONLY_ZIP=""

usage() {
  cat <<EOF
Usage: scripts/release-macos-app.sh [options]

Options:
  --version <version>            Override package.json version.
  --tag <tag>                    Override GitHub release tag (default: v<version>).
  --sparkle-key <path>           Sparkle EdDSA private key file.
  --sign-identity <identity>     Developer ID signing identity.
  --notary-profile <profile>     notarytool keychain profile.
  --dry-run                      Build/sign/zip/verify in /tmp; no notarization, appcast, or upload.
  --skip-build                   Reuse the app already in DerivedData.
  --verify-only <zip>            Verify an existing zip's extracted app, then exit.
  --no-notarize                  Build/sign/zip without Apple notarization.
  --no-appcast                   Do not update appcast.xml.
  --upload                       Upload the app zip to the GitHub release.
  --upload-checksums             Also upload checksums.txt; requires an existing checksum file.
  --keep-derived-data            Keep Xcode DerivedData after completion.
  --help                         Show this help.

Notarization uses NOTARYTOOL_PROFILE when set, otherwise APP_STORE_CONNECT_KEY_ID,
APP_STORE_CONNECT_ISSUER_ID, and APP_STORE_CONNECT_API_KEY_P8.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --)
      shift
      ;;
    --version)
      VERSION="$2"
      TAG="v${VERSION}"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --sparkle-key)
      SPARKLE_PRIVATE_KEY_FILE="$2"
      shift 2
      ;;
    --sign-identity)
      SIGN_IDENTITY="$2"
      shift 2
      ;;
    --notary-profile)
      NOTARYTOOL_PROFILE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      NOTARIZE=false
      UPDATE_APPCAST=false
      UPLOAD=false
      shift
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --verify-only)
      VERIFY_ONLY_ZIP="$2"
      SKIP_BUILD=true
      NOTARIZE=false
      UPDATE_APPCAST=false
      UPLOAD=false
      shift 2
      ;;
    --no-notarize)
      NOTARIZE=false
      shift
      ;;
    --no-appcast)
      UPDATE_APPCAST=false
      shift
      ;;
    --upload)
      UPLOAD=true
      shift
      ;;
    --upload-checksums)
      UPLOAD_CHECKSUMS=true
      shift
      ;;
    --keep-derived-data)
      KEEP_DERIVED_DATA=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$DRY_RUN" == true ]]; then
  NOTARIZE=false
  UPDATE_APPCAST=false
  UPLOAD=false
  UPLOAD_CHECKSUMS=false
  RELEASE_DIR="$(mktemp -d /tmp/peekaboo-macos-app-dry-run.XXXXXX)"
fi

if [[ "$UPLOAD_CHECKSUMS" == true && "$UPLOAD" != true ]]; then
  echo "ERROR: --upload-checksums requires --upload" >&2
  exit 1
fi

APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
ZIP_NAME="$APP_NAME-${VERSION}.app.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"
RELEASE_URL="https://github.com/$REPOSITORY_SLUG/releases/tag/$TAG"
ASSET_URL="https://github.com/$REPOSITORY_SLUG/releases/download/$TAG/$ZIP_NAME"
NOTARY_DIR="$(mktemp -d /tmp/peekaboo-notary.XXXXXX)"
VERIFY_DIR="$(mktemp -d /tmp/peekaboo-zip-verify.XXXXXX)"

cleanup() {
  rm -rf "$NOTARY_DIR" "$VERIFY_DIR"
  if [[ "$DRY_RUN" == true ]]; then
    rm -rf "$RELEASE_DIR"
  fi
  if [[ "$KEEP_DERIVED_DATA" != true ]]; then
    rm -rf "$DERIVED_DATA_PATH"
  fi
}
trap cleanup EXIT

log() { printf '==> %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "$1 not found"; }

require_command codesign
require_command ditto
if [[ -z "$VERIFY_ONLY_ZIP" ]]; then
  require_command node
  require_command xcodebuild
  require_command shasum
  require_command sign_update
fi
if [[ "$NOTARIZE" == true ]]; then
  require_command xcrun
  require_command spctl
fi

if [[ -z "$VERIFY_ONLY_ZIP" ]]; then
  [[ -d "$WORKSPACE" ]] || fail "Workspace not found: $WORKSPACE"
  [[ -f "$SPARKLE_PRIVATE_KEY_FILE" ]] || fail "Sparkle private key not found: $SPARKLE_PRIVATE_KEY_FILE"
  mkdir -p "$RELEASE_DIR"
fi

verify_zip() {
  local zip_path="$1"
  local verify_dir="$2"

  [[ -f "$zip_path" ]] || fail "Zip not found: $zip_path"
  rm -rf "$verify_dir"
  mkdir -p "$verify_dir"
  ditto -x -k "$zip_path" "$verify_dir"
  local extracted_app="$verify_dir/$APP_NAME.app"
  [[ -d "$extracted_app" ]] || fail "Extracted app not found: $extracted_app"
  codesign --verify --deep --strict --verbose=2 "$extracted_app"
  if [[ "$NOTARIZE" == true ]]; then
    xcrun stapler validate "$extracted_app"
    spctl --assess --type execute --verbose=4 "$extracted_app"
  fi
}

if [[ -n "$VERIFY_ONLY_ZIP" ]]; then
  log "Verifying existing zip"
  verify_zip "$VERIFY_ONLY_ZIP" "$VERIFY_DIR"
  log "Done"
  exit 0
fi

if [[ "$SKIP_BUILD" == true ]]; then
  log "Skipping build; reusing $APP_BUNDLE"
else
  log "Building $APP_NAME.app $VERSION"
  xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -quiet \
    build
fi

[[ -d "$APP_BUNDLE" ]] || fail "App bundle not found: $APP_BUNDLE"

log "Developer ID signing"
codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ "$NOTARIZE" == true ]]; then
  log "Submitting to Apple notarization"
  NOTARY_ZIP="$NOTARY_DIR/$APP_NAME-notary.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"

  if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
  else
    [[ -n "${APP_STORE_CONNECT_KEY_ID:-}" ]] || fail "APP_STORE_CONNECT_KEY_ID missing"
    [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]] || fail "APP_STORE_CONNECT_ISSUER_ID missing"
    [[ -n "${APP_STORE_CONNECT_API_KEY_P8:-}" ]] || fail "APP_STORE_CONNECT_API_KEY_P8 missing"

    KEY_FILE="$NOTARY_DIR/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
    APP_STORE_CONNECT_API_KEY_P8="$APP_STORE_CONNECT_API_KEY_P8" node > "$KEY_FILE" <<'EOF'
const raw = process.env.APP_STORE_CONNECT_API_KEY_P8 ?? "";
let pem = raw.replace(/\\n/g, "\n").trim();
if (!pem.includes("\n")) {
  const match = pem.match(/^(-----BEGIN [^-]+-----)\s*(.+?)\s*(-----END [^-]+-----)$/);
  if (match) {
    const body = match[2].replace(/\s+/g, "");
    const wrapped = body.match(/.{1,64}/g)?.join("\n") ?? body;
    pem = `${match[1]}\n${wrapped}\n${match[3]}`;
  }
}
process.stdout.write(`${pem}\n`);
EOF
    chmod 600 "$KEY_FILE"
    xcrun notarytool submit "$NOTARY_ZIP" \
      --key "$KEY_FILE" \
      --key-id "$APP_STORE_CONNECT_KEY_ID" \
      --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
      --wait
    rm -f "$KEY_FILE"
  fi

  log "Stapling notarization ticket"
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
  spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
fi

log "Creating Sparkle zip"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
ZIP_LENGTH="$(stat -f%z "$ZIP_PATH")"
ZIP_SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

log "Signing Sparkle update"
SIGN_OUTPUT="$(sign_update --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" "$ZIP_PATH" 2>&1)"
printf '%s\n' "$SIGN_OUTPUT"
ED_SIGNATURE="$(printf '%s\n' "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' | tail -1)"
[[ -n "$ED_SIGNATURE" ]] || fail "Could not parse sparkle:edSignature from sign_update output"

log "Verifying zipped app"
verify_zip "$ZIP_PATH" "$VERIFY_DIR"

CHECKSUMS_PATH="$RELEASE_DIR/checksums.txt"
HAD_CHECKSUMS=false
if [[ -f "$CHECKSUMS_PATH" ]]; then
  HAD_CHECKSUMS=true
  grep -F -v "  $ZIP_NAME" "$CHECKSUMS_PATH" > "$CHECKSUMS_PATH.tmp" || true
  mv "$CHECKSUMS_PATH.tmp" "$CHECKSUMS_PATH"
fi
printf '%s  %s\n' "$ZIP_SHA256" "$ZIP_NAME" >> "$CHECKSUMS_PATH"

if [[ "$UPDATE_APPCAST" == true ]]; then
  log "Updating appcast.xml"
  VERSION="$VERSION" \
  RELEASE_URL="$RELEASE_URL" \
  ASSET_URL="$ASSET_URL" \
  ZIP_LENGTH="$ZIP_LENGTH" \
  ED_SIGNATURE="$ED_SIGNATURE" \
  MINIMUM_SYSTEM_VERSION="$MINIMUM_SYSTEM_VERSION" \
  APPCAST_PATH="$APPCAST_PATH" \
  node <<'EOF'
const fs = require("node:fs");

const appcastPath = process.env.APPCAST_PATH;
const version = process.env.VERSION;
const item = `    <item>
      <title>Peekaboo ${version}</title>
      <link>${process.env.RELEASE_URL}</link>
      <sparkle:releaseNotesLink>${process.env.RELEASE_URL}</sparkle:releaseNotesLink>
      <pubDate>${new Date().toUTCString().replace("GMT", "+0000")}</pubDate>
      <enclosure
        url="${process.env.ASSET_URL}"
        sparkle:version="1"
        sparkle:shortVersionString="${version}"
        sparkle:minimumSystemVersion="${process.env.MINIMUM_SYSTEM_VERSION}"
        length="${process.env.ZIP_LENGTH}"
        type="application/octet-stream"
        sparkle:edSignature="${process.env.ED_SIGNATURE}" />
    </item>`;

let xml = fs.readFileSync(appcastPath, "utf8");
const existingItems = xml.match(/    <item>[\s\S]*?    <\/item>/g) ?? [];
const nextItems = [
  item,
  ...existingItems.filter((entry) => !entry.includes(`sparkle:shortVersionString="${version}"`)),
];

if (existingItems.length > 0) {
  xml = xml.replace(existingItems.join("\n"), nextItems.join("\n"));
} else {
  xml = xml.replace(/(\s*<language>en<\/language>\n)/, `$1\n${item}\n`);
}

fs.writeFileSync(appcastPath, xml);
EOF
  if command -v xmllint >/dev/null 2>&1; then
    xmllint --noout "$APPCAST_PATH"
  fi
fi

if [[ "$UPLOAD" == true ]]; then
  require_command gh
  log "Uploading release assets"
  gh release upload "$TAG" "$ZIP_PATH" --clobber
  if [[ "$UPLOAD_CHECKSUMS" == true ]]; then
    [[ "$HAD_CHECKSUMS" == true ]] || fail "--upload-checksums requires an existing $CHECKSUMS_PATH from release-binaries.sh"
    gh release upload "$TAG" "$CHECKSUMS_PATH" --clobber
  fi
fi

log "Done"
if [[ "$DRY_RUN" == true ]]; then
  printf 'Dry run: no notarization, appcast update, or upload performed.\n'
fi
printf 'Zip: %s\n' "$ZIP_PATH"
printf 'SHA256: %s\n' "$ZIP_SHA256"
printf 'Length: %s\n' "$ZIP_LENGTH"
printf 'Appcast asset URL: %s\n' "$ASSET_URL"
