#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER_DIR="$ROOT_DIR/Helpers/MenuBarHelper"
BUILD_DIR="$HELPER_DIR/build"
APP_DIR="$BUILD_DIR/MenubarHelper.app"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"

# Build the helper binary; allow undefined private symbols (resolved at runtime via dlopen).
swiftc -O -framework AppKit \
  -Xlinker -undefined -Xlinker dynamic_lookup \
  "$HELPER_DIR/main.swift" \
  -o "$APP_DIR/Contents/MacOS/menubar-helper"

# Copy Info.plist to make it LSUIElement.
cp "$HELPER_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "Built helper at $APP_DIR"
