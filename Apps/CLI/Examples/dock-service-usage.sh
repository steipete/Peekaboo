#!/bin/bash
# Example usage of the DockCommandV2 with PeekabooCore services

echo "=== Dock Service Usage Examples ==="
echo ""

# List all Dock items
echo "1. List all Dock items:"
echo "   peekaboo dock-v2 list"
echo ""

# List all items including separators
echo "2. List all items including separators:"
echo "   peekaboo dock-v2 list --include-all"
echo ""

# Launch an app from the Dock
echo "3. Launch Safari from Dock:"
echo "   peekaboo dock-v2 launch Safari"
echo ""

# Right-click a Dock item
echo "4. Right-click Finder in Dock:"
echo "   peekaboo dock-v2 right-click --app Finder"
echo ""

# Right-click and select menu item
echo "5. Right-click Finder and create new window:"
echo "   peekaboo dock-v2 right-click --app Finder --select \"New Window\""
echo ""

# Hide/Show Dock
echo "6. Hide the Dock:"
echo "   peekaboo dock-v2 hide"
echo ""

echo "7. Show the Dock:"
echo "   peekaboo dock-v2 show"
echo ""

# JSON output examples
echo "8. Get Dock items as JSON:"
echo "   peekaboo dock-v2 list --json-output"
echo ""

echo "=== Comparison with Original Commands ==="
echo ""
echo "The V2 commands use PeekabooCore services for better modularity:"
echo "- dock    : Direct implementation using AXorcist"
echo "- dock-v2 : Uses DockService from PeekabooCore"
echo ""
echo "Both provide the same functionality with identical interfaces."