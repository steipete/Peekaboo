#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:?usage: prepare-codeql-plugin-server.sh OUTPUT_DIR}"
DEVELOPER_DIR="${DEVELOPER_DIR:?select Xcode before preparing the macro host}"
PLUGIN_ROOT="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/usr"
test -x "$PLUGIN_ROOT/bin/swift-plugin-server"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

arch -x86_64 /usr/bin/true
xcrun clang -Wall -Wextra -Werror -arch arm64 -arch x86_64 -mmacosx-version-min=15.0 \
  "-DPLUGIN_SERVER_PATH=\"$PLUGIN_ROOT/bin/swift-plugin-server\"" \
  "$ROOT_DIR/scripts/codeql-native-plugin-server.c" -o "$OUTPUT_DIR/native-plugin-server"

# Exercise both a Rosetta caller and sandboxed SwiftUI macro expansion. A script
# wrapper cannot be read inside the macro sandbox, so the bridge is a binary.
arch -x86_64 "$OUTPUT_DIR/native-plugin-server" </dev/null
cat > "$OUTPUT_DIR/probe.swift" <<'SWIFT'
import SwiftUI
extension EnvironmentValues {
    @Entry var codeqlFixtureName: String = "fixture"
}
SWIFT
xcrun swiftc -typecheck -j 2 -target arm64-apple-macosx15.0 \
  -module-cache-path "$OUTPUT_DIR/module-cache" \
  -Xfrontend -external-plugin-path \
  -Xfrontend "$PLUGIN_ROOT/lib/swift/host/plugins#$OUTPUT_DIR/native-plugin-server" \
  "$OUTPUT_DIR/probe.swift"
