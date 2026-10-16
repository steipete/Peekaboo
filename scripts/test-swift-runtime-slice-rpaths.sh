#!/usr/bin/env bash
set -euo pipefail
unset MAC_RELEASE_CODESIGN_IDENTITY MAC_RELEASE_CODESIGN_TEAM_ID
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFIER="${PEEKABOO_RUNTIME_VERIFIER:-$ROOT_DIR/scripts/verify-swift-runtime-libraries.sh}"
STRIPPER="$ROOT_DIR/scripts/strip-toolchain-rpaths.sh"
TEST_DIR="$(mktemp -d /tmp/peekaboo-runtime-slice-rpaths.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
SDK="$TEST_DIR/SDK/MacOSX15.0.sdk"
mkdir -p "$SDK/usr/lib/swift"
printf '{"Version":"15.0","CanonicalName":"macosx15.0"}\n' > "$SDK/SDKSettings.json"
cat > "$SDK/usr/lib/swift/libswiftCore.tbd" <<'TBD'
--- !tapi-tbd
tbd-version: 4
targets: [ arm64-macos, x86_64-macos ]
install-name: '/usr/lib/swift/libswiftCore.dylib'
...
TBD
printf 'void fixture(void) {}\n' > "$TEST_DIR/runtime.c"
printf 'extern void fixture(void); int main(void) { fixture(); return 0; }\n' > "$TEST_DIR/main.c"
printf 'int main(void) { return 0; }\n' > "$TEST_DIR/no-import.c"
TOOLCHAIN_RPATH='/Applications/Xcode Runner.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-6.2/macosx'
for arch in arm64 x86_64; do
  mkdir "$TEST_DIR/$arch"
  xcrun clang -arch "$arch" -mmacosx-version-min=15.0 -Wl,-adhoc_codesign -dynamiclib "$TEST_DIR/runtime.c" \
    -install_name @rpath/libswiftCompatibilityFixture.dylib -o "$TEST_DIR/$arch/libswiftCompatibilityFixture.dylib"
  xcrun clang -arch "$arch" -mmacosx-version-min=15.0 "$TEST_DIR/main.c" -L"$TEST_DIR/$arch" \
    -lswiftCompatibilityFixture -Wl,-rpath,/usr/lib/swift -Wl,-rpath,@loader_path -o "$TEST_DIR/$arch/good"
  xcrun clang -arch "$arch" -mmacosx-version-min=15.0 "$TEST_DIR/main.c" -L"$TEST_DIR/$arch" \
    -lswiftCompatibilityFixture -Wl,-rpath,/usr/lib/swift -Wl,-rpath,@loader_path \
    -Wl,-rpath,"$TOOLCHAIN_RPATH" -o "$TEST_DIR/$arch/toolchain-rpath"
  xcrun clang -arch "$arch" -mmacosx-version-min=15.0 "$TEST_DIR/main.c" -L"$TEST_DIR/$arch" \
    -lswiftCompatibilityFixture -o "$TEST_DIR/$arch/no-rpath"
  xcrun clang -arch "$arch" -mmacosx-version-min=15.0 "$TEST_DIR/no-import.c" -o "$TEST_DIR/$arch/no-import"
  xcrun clang -arch "$arch" -mmacosx-version-min=15.0 "$TEST_DIR/no-import.c" \
    -Wl,-rpath,"$TOOLCHAIN_RPATH" -o "$TEST_DIR/$arch/no-import-toolchain-rpath"
done
lipo -create "$TEST_DIR/arm64/libswiftCompatibilityFixture.dylib" "$TEST_DIR/x86_64/libswiftCompatibilityFixture.dylib" \
  -output "$TEST_DIR/libswiftCompatibilityFixture.dylib"
# Both permutations prove that another architecture's rpath cannot hide the defect.
for broken_arch in arm64 x86_64; do
  other_arch=arm64
  [[ "$broken_arch" != arm64 ]] || other_arch=x86_64
  lipo -create "$TEST_DIR/$broken_arch/no-rpath" "$TEST_DIR/$other_arch/good" -output "$TEST_DIR/broken"
  if "$VERIFIER" --runtime-sdk-root "$TEST_DIR/SDK" \
    "$TEST_DIR/broken" "$TEST_DIR" > "$TEST_DIR/result" 2>&1; then
    echo "Verifier accepted missing $broken_arch compatibility rpath" >&2; exit 1
  fi
  if ! grep -Fq -- "$broken_arch" "$TEST_DIR/result" ||
    ! grep -Fq -- 'no executable-relative LC_RPATH' "$TEST_DIR/result"; then
    cat "$TEST_DIR/result" >&2; exit 1
  fi

  for kind in toolchain-rpath no-import-toolchain-rpath; do
    lipo -create "$TEST_DIR/$broken_arch/$kind" "$TEST_DIR/$other_arch/good" -output "$TEST_DIR/host-path"
    for mode in --standalone --rpaths-only; do
      args=("$mode" "$TEST_DIR/host-path")
      [[ "$mode" == --rpaths-only ]] || args+=("$TEST_DIR")
      if "$VERIFIER" "${args[@]}" > "$TEST_DIR/result" 2>&1; then
        echo "Verifier accepted $broken_arch $kind ($mode)" >&2; exit 1
      fi
      grep -Fq "Non-system absolute LC_RPATH ($broken_arch): $TOOLCHAIN_RPATH" "$TEST_DIR/result"
    done
    "$STRIPPER" "$TEST_DIR/host-path"
    codesign --force --sign - --timestamp=none "$TEST_DIR/host-path"
    "$VERIFIER" --runtime-sdk-root "$TEST_DIR/SDK" "$TEST_DIR/host-path" "$TEST_DIR"
    for arch in arm64 x86_64; do
      rpaths=$(otool -arch "$arch" -l "$TEST_DIR/host-path" | awk '
        $1 == "cmd" && $2 == "LC_RPATH" { rpath = 1; next }
        rpath && $1 == "path" { print $2; rpath = 0 }
      ')
      if [[ "$kind" == no-import-toolchain-rpath && "$arch" == "$broken_arch" ]]; then
        [[ -z "$rpaths" ]]
      else
        [[ "$rpaths" == $'/usr/lib/swift\n@loader_path' ]]
      fi
    done
  done
done
lipo -create "$TEST_DIR/arm64/good" "$TEST_DIR/x86_64/good" -output "$TEST_DIR/good"
"$VERIFIER" --runtime-sdk-root "$TEST_DIR/SDK" \
  "$TEST_DIR/good" "$TEST_DIR" > "$TEST_DIR/result" 2>&1
before=$(shasum -a 256 "$TEST_DIR/good")
"$STRIPPER" "$TEST_DIR/good"
[[ "$before" == "$(shasum -a 256 "$TEST_DIR/good")" ]]

# Bundle scans must also inspect Mach-O files without an executable mode bit.
cp "$TEST_DIR/good" "$TEST_DIR/inspection-only"
chmod 644 "$TEST_DIR/inspection-only"
"$VERIFIER" --rpaths-only "$TEST_DIR/inspection-only"

# All non-system absolute paths are rejected, including prefix and traversal tricks.
for rpath in /usr/lib /usr/lib/swift /usr/lib/system /Users/runner/build /usr/library /usr/lib/../../Users/runner; do
  xcrun clang -mmacosx-version-min=15.0 "$TEST_DIR/no-import.c" \
    -Wl,-rpath,"$rpath" -o "$TEST_DIR/absolute-rpath"
  case "$rpath" in
    /usr/lib|/usr/lib/swift|/usr/lib/system)
      "$VERIFIER" --rpaths-only "$TEST_DIR/absolute-rpath" ;;
    *)
      if "$VERIFIER" --rpaths-only "$TEST_DIR/absolute-rpath" > "$TEST_DIR/result" 2>&1; then
        echo "Verifier accepted non-system rpath: $rpath" >&2; exit 1
      fi
      grep -Fq "Non-system absolute LC_RPATH" "$TEST_DIR/result" ;;
  esac
done

# A thin SwiftPM product is sanitized too; the caller owns signing after the edit.
cp "$TEST_DIR/arm64/toolchain-rpath" "$TEST_DIR/thin"
"$STRIPPER" "$TEST_DIR/thin"
codesign --force --sign - --timestamp=none "$TEST_DIR/thin"
codesign --verify --strict "$TEST_DIR/thin"
"$VERIFIER" --runtime-sdk-root "$TEST_DIR/SDK" "$TEST_DIR/thin" "$TEST_DIR"

# A library only needs the architectures whose executable slices import it.
for importing_arch in arm64 x86_64; do
  other_arch=arm64
  [[ "$importing_arch" != arm64 ]] || other_arch=x86_64
  destination="$TEST_DIR/import-$importing_arch"
  mkdir "$destination"
  lipo -create "$TEST_DIR/$importing_arch/good" "$TEST_DIR/$other_arch/no-import" -output "$destination/executable"
  cp "$TEST_DIR/$importing_arch/libswiftCompatibilityFixture.dylib" "$destination/"
  "$VERIFIER" --runtime-sdk-root "$TEST_DIR/SDK" "$destination/executable" "$destination" > "$TEST_DIR/result" 2>&1
  cp "$TEST_DIR/$other_arch/libswiftCompatibilityFixture.dylib" "$destination/"
  if "$VERIFIER" --runtime-sdk-root "$TEST_DIR/SDK" "$destination/executable" "$destination" > "$TEST_DIR/result" 2>&1; then
    echo "Verifier accepted a library missing its importing $importing_arch slice" >&2; exit 1
  fi
  if ! grep -Fq -- "library is missing $importing_arch" "$TEST_DIR/result"; then
    cat "$TEST_DIR/result" >&2; exit 1
  fi
done
printf 'test-swift-runtime-slice-rpaths: ok (per-slice rpath policy and pre-signing cleanup; no fixture execution)\n'
