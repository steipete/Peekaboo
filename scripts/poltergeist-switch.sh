#!/bin/bash

# Script to switch between local and npm versions of Poltergeist

PACKAGE_JSON="package.json"

case "$1" in
  "local")
    echo "🏠 Switching to local Poltergeist..."
    # Using npx with local path
    sed -i '' 's|"poltergeist:\([^"]*\)": "npx @steipete/poltergeist@latest \([^"]*\)"|"poltergeist:\1": "npx ../poltergeist \2"|g' $PACKAGE_JSON
    sed -i '' 's|"poltergeist:\([^"]*\)": "node ../poltergeist/dist/cli.js \([^"]*\)"|"poltergeist:\1": "npx ../poltergeist \2"|g' $PACKAGE_JSON
    echo "✅ Switched to local version (npx ../poltergeist)"
    ;;
    
  "npm")
    echo "📦 Switching to npm Poltergeist..."
    # Using npm package
    sed -i '' 's|"poltergeist:\([^"]*\)": "npx ../poltergeist \([^"]*\)"|"poltergeist:\1": "npx @steipete/poltergeist@latest \2"|g' $PACKAGE_JSON
    sed -i '' 's|"poltergeist:\([^"]*\)": "node ../poltergeist/dist/cli.js \([^"]*\)"|"poltergeist:\1": "npx @steipete/poltergeist@latest \2"|g' $PACKAGE_JSON
    echo "✅ Switched to npm version (npx @steipete/poltergeist@latest)"
    ;;
    
  "status")
    echo "📊 Current Poltergeist setup:"
    grep -E '"poltergeist:' $PACKAGE_JSON | head -1
    ;;
    
  *)
    echo "Usage: $0 {local|npm|status}"
    echo ""
    echo "  local  - Use local Poltergeist from ../poltergeist"
    echo "  npm    - Use npm package @steipete/poltergeist"  
    echo "  status - Show current configuration"
    exit 1
    ;;
esac