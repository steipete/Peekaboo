#!/usr/bin/env bash
# Reset Peekaboo.app: kill running instances, rebuild, repackage to a stable bundle, relaunch, verify.
#
# IMPORTANT: We intentionally build with code signing enabled and launch from a stable app bundle path
# (dist/Peekaboo.app by default). This keeps macOS TCC permissions (Screen Recording, Accessibility, etc.)
# tied to a single app identity/location, instead of bouncing between ephemeral DerivedData outputs.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$ROOT_DIR/Apps/Peekaboo.xcworkspace}"
SCHEME="${SCHEME:-Peekaboo}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build/DerivedData}"
APP_NAME="${APP_NAME:-Peekaboo}"
BUILT_APP_BUNDLE="${BUILT_APP_BUNDLE:-$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}/${APP_NAME}.app}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
DIST_APP_BUNDLE="${DIST_APP_BUNDLE:-$DIST_DIR/${APP_NAME}.app}"
APP_BUNDLE="${PEEKABOO_APP_BUNDLE:-}"

APP_PROCESS_PATTERN="${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
DERIVED_PROCESS_PATTERN="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

log()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

run_step() {
  local label="$1"; shift
  log "==> ${label}"
  if ! "$@"; then
    fail "${label} failed"
  fi
}

kill_peekaboo() {
  for _ in {1..15}; do
    pkill -f "${DERIVED_PROCESS_PATTERN}" 2>/dev/null || true
    pkill -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
    pkill -x "${APP_NAME}" 2>/dev/null || true

    if ! pgrep -f "${DERIVED_PROCESS_PATTERN}" >/dev/null 2>&1 \
       && ! pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1 \
       && ! pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  fail "Could not stop running Peekaboo processes"
}

xc_pipe() {
  if command -v xcbeautify >/dev/null 2>&1; then
    xcbeautify
  else
    cat
  fi
}

build_app() {
  xcodebuild \
    -workspace "${WORKSPACE}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -destination "platform=macOS" \
    build \
    | xc_pipe
}

choose_app_bundle() {
  if [[ -n "${APP_BUNDLE}" && -d "${APP_BUNDLE}" ]]; then
    return 0
  fi

  if [[ -d "/Applications/${APP_NAME}.app" ]]; then
    APP_BUNDLE="/Applications/${APP_NAME}.app"
    return 0
  fi

  if [[ -d "${DIST_APP_BUNDLE}" ]]; then
    APP_BUNDLE="${DIST_APP_BUNDLE}"
    return 0
  fi

  # If no stable bundle exists yet, we'll create dist/ and copy from the build output.
  APP_BUNDLE="${DIST_APP_BUNDLE}"
}

verify_built_bundle() {
  if [ ! -d "${BUILT_APP_BUNDLE}" ]; then
    fail "Built app bundle not found at ${BUILT_APP_BUNDLE}"
  fi
}

package_to_dist() {
  mkdir -p "${DIST_DIR}"
  rm -rf "${DIST_APP_BUNDLE}"
  ditto "${BUILT_APP_BUNDLE}" "${DIST_APP_BUNDLE}"
}

verify_launch_bundle() {
  if [ ! -d "${APP_BUNDLE}" ]; then
    fail "App bundle not found at ${APP_BUNDLE}"
  fi
}

launch_app() {
  # LaunchServices can inherit a huge environment from this shell; keep it minimal.
  env -i \
    HOME="${HOME}" \
    USER="${USER:-$(id -un)}" \
    LOGNAME="${LOGNAME:-$(id -un)}" \
    TMPDIR="${TMPDIR:-/tmp}" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    LANG="${LANG:-en_US.UTF-8}" \
    /usr/bin/open "${APP_BUNDLE}"
  sleep 1
  if pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1 || pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    log "OK: ${APP_NAME} is running."
  else
    fail "App exited immediately. Check crash logs."
  fi
}

log "==> Killing existing Peekaboo instances"
kill_peekaboo
run_step "Build ${APP_NAME}.app (${CONFIGURATION})" build_app
run_step "Locate build output" verify_built_bundle
run_step "Choose app bundle" choose_app_bundle
if [[ "${APP_BUNDLE}" == "${DIST_APP_BUNDLE}" ]]; then
  run_step "Package app to dist" package_to_dist
fi
run_step "Locate app bundle" verify_launch_bundle
run_step "Launch app" launch_app
