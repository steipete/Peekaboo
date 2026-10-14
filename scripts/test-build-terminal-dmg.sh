#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/terminal-artifact-env.sh
source "$ROOT_DIR/scripts/terminal-artifact-env.sh"
for secret_name in "${TERMINAL_ARTIFACT_SECRET_NAMES[@]}"; do unset "$secret_name"; done
TEST_DIR="$(mktemp -d /tmp/peekaboo-terminal-dmg-test.XXXXXX)"
FIXTURE_MOUNT=""
cleanup() {
  if [[ -n "$FIXTURE_MOUNT" && -d "$FIXTURE_MOUNT" ]]; then
    hdiutil detach "$FIXTURE_MOUNT" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT
APP="$TEST_DIR/Peekaboo.app"
mkdir -p "$APP/Contents/Resources"
printf 'icon\n' > "$APP/Contents/Resources/AppIcon.icns"

for tool in codesign xcrun verify-native hdiutil; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_DIR/$tool"
  chmod 755 "$TEST_DIR/$tool"
done
cat > "$TEST_DIR/sips" <<'EOF'
#!/usr/bin/env bash
case "$*" in *pixelWidth*) printf 'pixelWidth: 720\n' ;; *) printf 'pixelHeight: 460\n' ;; esac
EOF
cat > "$TEST_DIR/uv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "${ROOT_DIR:?}/scripts/terminal-artifact-env.sh"
terminal_artifact_assert_build_env_is_clean
printf 'dmg\n' > "${!#}"
EOF
chmod 755 "$TEST_DIR/sips" "$TEST_DIR/uv"
export ROOT_DIR

run_fixture() {
  PEEKABOO_TERMINAL_TEST_MODE=1 \
  TERMINAL_DMG_UV_BIN="$TEST_DIR/uv" \
  TERMINAL_DMG_CODESIGN_BIN="$TEST_DIR/codesign" \
  TERMINAL_DMG_XCRUN_BIN="$TEST_DIR/xcrun" \
  TERMINAL_DMG_VERIFY_NATIVE_BIN="$TEST_DIR/verify-native" \
  TERMINAL_DMG_SIPS_BIN="$TEST_DIR/sips" \
  TERMINAL_DMG_HDIUTIL_BIN="$TEST_DIR/hdiutil" \
    "$ROOT_DIR/scripts/build-terminal-dmg.sh" --app "$APP" --version 9.9.9 "$@"
}

run_fixture --output "$TEST_DIR/output.dmg" >/dev/null
[[ -f "$TEST_DIR/output.dmg" ]]
if APP_STORE_CONNECT_API_KEY_P8=secret run_fixture --output "$TEST_DIR/secret.dmg" >/dev/null 2>&1; then
  printf 'test-build-terminal-dmg: credentialed construction succeeded\n' >&2
  exit 1
fi
[[ ! -e "$TEST_DIR/secret.dmg" ]]
if TERMINAL_DMG_UV_BIN="$TEST_DIR/uv" "$ROOT_DIR/scripts/build-terminal-dmg.sh" --help >/dev/null 2>&1; then
  printf 'test-build-terminal-dmg: production accepted tool override\n' >&2
  exit 1
fi
python3 - "$ROOT_DIR/scripts/dmgbuild-settings.py" <<'PY'
import runpy
import sys

settings = runpy.run_path(
    sys.argv[1],
    init_globals={
        "defines": {
            "app_name": "Peekaboo",
            "app_path": "/tmp/Peekaboo.app",
            "background": "/tmp/background.png",
            "volume_icon": "/tmp/AppIcon.icns",
        }
    },
)

assert settings["files"] == [("/tmp/Peekaboo.app", "Peekaboo.app")]
assert settings["symlinks"] == {"Applications": "/Applications"}
assert settings["icon"] == "/tmp/AppIcon.icns"
assert settings["background"] == "/tmp/background.png"
assert settings["window_rect"] == ((200, 120), (720, 460))
assert settings["text_size"] == 13
assert settings["icon_size"] == 128
assert settings["icon_locations"] == {
    "Peekaboo.app": (180, 230),
    "Applications": (540, 230),
}
assert settings.get("hide_extensions", []) == []
assert settings["format"] == "UDZO"
assert settings["filesystem"] == "HFS+"
PY

rg -Fq '"dmgbuild==1.6.7"' "$ROOT_DIR/scripts/dmgbuild-runner.py"
rg -Fq '"ds-store==1.3.3"' "$ROOT_DIR/scripts/dmgbuild-runner.py"
rg -Fq '"mac-alias==2.2.3"' "$ROOT_DIR/scripts/dmgbuild-runner.py"
rg -Fq '"$UV_BIN" --no-config run --locked "$ROOT_DIR/scripts/dmgbuild-runner.py"' "$ROOT_DIR/scripts/build-terminal-dmg.sh"
[[ -f "$ROOT_DIR/scripts/dmgbuild-runner.py.lock" ]]

FIXTURE_DIR="$TEST_DIR/fixture"
FIXTURE_DMG="$TEST_DIR/Peekaboo-Fixture.dmg"
FIXTURE_MOUNT="$TEST_DIR/fixture-mount"
mkdir -p "$FIXTURE_DIR/Peekaboo.app/Contents/MacOS" "$FIXTURE_MOUNT"
printf 'fixture\n' >"$FIXTURE_DIR/Peekaboo.app/Contents/MacOS/Peekaboo"
chmod 755 "$FIXTURE_DIR/Peekaboo.app/Contents/MacOS/Peekaboo"

env \
  -u APP_STORE_CONNECT_API_KEY_P8 \
  -u APP_STORE_CONNECT_KEY_ID \
  -u APP_STORE_CONNECT_ISSUER_ID \
  -u NPM_TOKEN \
  -u OP_SERVICE_ACCOUNT_TOKEN \
  -u MOLTY_OP_SERVICE_ACCOUNT_TOKEN \
  uv --no-config run --locked "$ROOT_DIR/scripts/dmgbuild-runner.py" \
  --no-hidpi \
  --detach-retries 5 \
  --settings "$ROOT_DIR/scripts/dmgbuild-settings.py" \
  -D 'app_name=Peekaboo' \
  -D "app_path=$FIXTURE_DIR/Peekaboo.app" \
  -D "background=$ROOT_DIR/assets/dmg-background.png" \
  -D "volume_icon=$ROOT_DIR/assets/dmg-background.png" \
  'Peekaboo Fixture' \
  "$FIXTURE_DMG" >/dev/null

hdiutil attach -readonly -nobrowse -noautoopen \
  -mountpoint "$FIXTURE_MOUNT" "$FIXTURE_DMG" >/dev/null
[[ -L "$FIXTURE_MOUNT/Applications" ]]
[[ "$(readlink "$FIXTURE_MOUNT/Applications")" == "/Applications" ]]
cmp "$ROOT_DIR/assets/dmg-background.png" "$FIXTURE_MOUNT/.background.png"
[[ -f "$FIXTURE_MOUNT/.VolumeIcon.icns" ]]
[[ -f "$FIXTURE_MOUNT/.DS_Store" ]]

fixture_xattrs="$(xattr -r "$FIXTURE_MOUNT/Peekaboo.app")"
if printf '%s\n' "$fixture_xattrs" | rg -q ': com\.apple\.(FinderInfo|ResourceFork)$'; then
  printf 'Fixture app contains disallowed Finder metadata or a resource fork\n' >&2
  printf '%s\n' "$fixture_xattrs" >&2
  exit 1
fi

uv --no-config run \
  --with 'ds-store==1.3.3' \
  --with 'mac-alias==2.2.3' \
  python - "$FIXTURE_MOUNT/.DS_Store" <<'PY'
from ds_store import DSStore
import sys

records = {}
with DSStore.open(sys.argv[1], "r") as store:
    for entry in store:
        records[(entry.filename, entry.code)] = entry.value

assert records[(".", b"bwsp")]["WindowBounds"] == "{{200, 120}, {720, 460}}"
icon_view = records[(".", b"icvp")]
assert icon_view["backgroundType"] == 2
assert icon_view["iconSize"] == 128.0
assert icon_view["textSize"] == 13.0
assert records[("Peekaboo.app", b"Iloc")] == (180, 230)
assert records[("Applications", b"Iloc")] == (540, 230)
PY

hdiutil detach "$FIXTURE_MOUNT" -quiet
rmdir "$FIXTURE_MOUNT"
FIXTURE_MOUNT=""

printf 'test-build-terminal-dmg: ok\n'
