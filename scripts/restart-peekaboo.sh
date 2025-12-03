#!/usr/bin/env bash
# Reset Peekaboo.app: kill running instances, rebuild, relaunch, verify.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$ROOT_DIR/Apps/Peekaboo.xcworkspace}"
SCHEME="${SCHEME:-Peekaboo}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build}"
APP_NAME="${APP_NAME:-Peekaboo}"
APP_BUNDLE="${APP_BUNDLE:-$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}/${APP_NAME}.app}"

APP_PROCESS_PATTERN="${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
HELPER_PATTERN="Peekaboo Helper"
XPC_PATTERN="boo.peekaboo.app.XPCService"

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
    pkill -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
    pkill -f "${HELPER_PATTERN}" 2>/dev/null || true
    pkill -f "${XPC_PATTERN}" 2>/dev/null || true
    pkill -x "${APP_NAME}" 2>/dev/null || true

    if ! pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1 \
       && ! pgrep -f "${HELPER_PATTERN}" >/dev/null 2>&1 \
       && ! pgrep -f "${XPC_PATTERN}" >/dev/null 2>&1 \
       && ! pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  fail "Could not stop running Peekaboo processes"
}

xc_pipe() {
  if command -v xcbeautify >/dev/null 2>&1; then
    xcbeautify "$@"
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

verify_bundle() {
  if [ ! -d "${APP_BUNDLE}" ]; then
    fail "App bundle not found at ${APP_BUNDLE}"
  fi
}

launch_app() {
  open "${APP_BUNDLE}"
  sleep 1
  if pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1 || pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    log "OK: ${APP_NAME} is running."
  else
    fail "App exited immediately. Check crash logs."
  fi
}

log "==> Killing existing Peekaboo instances"
kill_peekaboo
run_step "Build Peekaboo.app (${CONFIGURATION})" build_app
run_step "Locate app bundle" verify_bundle
run_step "Launch app" launch_app
