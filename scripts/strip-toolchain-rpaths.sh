#!/usr/bin/env bash
# Run on build products before signing; install_name_tool invalidates existing signatures.
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "Usage: $0 <mach-o>" >&2
  exit 2
fi
BINARY="$1"
architectures=$(lipo -archs "$BINARY")
WORK_DIR=$(mktemp -d "$(dirname "$BINARY")/.strip-toolchain-rpaths.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT
slices=()
changed=false
for architecture in $architectures; do
  slice="$WORK_DIR/$architecture"
  if [[ "$architectures" == "$architecture" ]]; then
    cp -p "$BINARY" "$slice"
  else
    lipo "$BINARY" -thin "$architecture" -output "$slice"
  fi
  slices+=("$slice")
  load_commands=$(otool -arch "$architecture" -l "$slice")
  while IFS= read -r rpath; do
    case "$rpath" in
      /*.xctoolchain/usr/lib/swift*/macosx|/Library/Developer/CommandLineTools/usr/lib/swift*/macosx)
        install_name_tool -delete_rpath "$rpath" "$slice"
        printf 'Removed toolchain LC_RPATH (%s): %s\n' "$architecture" "$rpath"
        changed=true
        ;;
    esac
  done < <(awk '
    $1 == "cmd" && $2 == "LC_RPATH" { in_rpath = 1; next }
    in_rpath && $1 == "path" {
      sub(/^[[:space:]]*path /, ""); sub(/ \(offset [0-9]+\)$/, "")
      print; in_rpath = 0
    }
  ' <<< "$load_commands")
done

if [[ "$changed" == true ]]; then
  if [[ "${#slices[@]}" -eq 1 ]]; then
    mv "${slices[0]}" "$WORK_DIR/output"
  else
    lipo -create "${slices[@]}" -output "$WORK_DIR/output"
  fi
  chmod "$(stat -f '%Lp' "$BINARY")" "$WORK_DIR/output"
  mv "$WORK_DIR/output" "$BINARY"
fi
