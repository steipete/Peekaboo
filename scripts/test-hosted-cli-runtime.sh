#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/peekaboo-hosted-runtime.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
printf 'int runtime_fixture(void) { return 42; }\n' > "$TEST_DIR/fixture.c"
for arch in arm64 arm64e x86_64; do
  xcrun clang -arch "$arch" -mmacosx-version-min=15.0 -dynamiclib "$TEST_DIR/fixture.c" \
    -Wl,-install_name,@rpath/libswiftCompatibilityFixture.dylib -o "$TEST_DIR/$arch.dylib"
done
mkdir "$TEST_DIR/empty"
bash "$ROOT/scripts/hosted-release/normalize-cli-runtime.sh" "$TEST_DIR/empty"
mkdir "$TEST_DIR/payload"
library="$TEST_DIR/payload/libswiftCompatibilityFixture.dylib"
lipo -create "$TEST_DIR/arm64.dylib" "$TEST_DIR/arm64e.dylib" "$TEST_DIR/x86_64.dylib" -output "$library"
chmod 755 "$library"

bash "$ROOT/scripts/hosted-release/normalize-cli-runtime.sh" "$TEST_DIR/payload"
case "$(lipo -archs "$library")" in
  "arm64 x86_64"|"x86_64 arm64") ;;
  *) echo 'Runtime payload retained the wrong slices' >&2; exit 1 ;;
esac
/usr/bin/codesign --verify --strict "$library"
/usr/bin/codesign -dv "$library" 2>&1 | grep -q 'Signature=adhoc'
[[ "$(stat -f '%Lp' "$library")" == 755 ]]
for arch in arm64 x86_64; do
  otool -arch "$arch" -D "$library" | grep -q '@rpath/libswiftCompatibilityFixture.dylib'
  nm -arch "$arch" -g "$library" | grep -q '_runtime_fixture'
done
# Already-normalized payloads remain valid on a repeated preparation.
bash "$ROOT/scripts/hosted-release/normalize-cli-runtime.sh" "$TEST_DIR/payload"

mkdir "$TEST_DIR/missing-slice" "$TEST_DIR/symlink"
cp "$TEST_DIR/arm64.dylib" "$TEST_DIR/missing-slice/libswiftCompatibilityFixture.dylib"
before="$(shasum -a 256 "$TEST_DIR/missing-slice/libswiftCompatibilityFixture.dylib")"
if bash "$ROOT/scripts/hosted-release/normalize-cli-runtime.sh" "$TEST_DIR/missing-slice" > "$TEST_DIR/refusal" 2>&1; then
  echo 'Accepted a runtime missing the Intel slice' >&2; exit 1
fi
grep -q 'must contain arm64 and x86_64' "$TEST_DIR/refusal"
[[ "$(shasum -a 256 "$TEST_DIR/missing-slice/libswiftCompatibilityFixture.dylib")" == "$before" ]]
ln -s "$TEST_DIR/arm64.dylib" "$TEST_DIR/symlink/libswiftCompatibilityFixture.dylib"
if bash "$ROOT/scripts/hosted-release/normalize-cli-runtime.sh" "$TEST_DIR/symlink" > "$TEST_DIR/refusal" 2>&1; then
  echo 'Accepted a symlink runtime payload' >&2; exit 1
fi
grep -q 'Invalid runtime library' "$TEST_DIR/refusal"
echo 'test-hosted-cli-runtime: ok'
