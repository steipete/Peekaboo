#!/bin/bash

# Peekaboo TextEdit Automation Test Script
# Tests comprehensive UI automation with font changes and text formatting

echo "🚀 Starting TextEdit automation test..."

# Ensure TextEdit is running
open -a TextEdit

# Wait for TextEdit to open
sleep 2

# Clean previous sessions
rm -rf ~/.peekaboo/session/*

# Capture initial state with annotations
echo "📸 Capturing TextEdit window..."
./peekaboo see --app TextEdit --window-title "Untitled.rtf" --annotate

# Type initial text
echo "⌨️  Typing initial text..."
./peekaboo type "Testing Peekaboo automation with TextEdit"

# Apply bold formatting
echo "🔤 Applying bold formatting..."
./peekaboo click --on C1

# Type bold text
./peekaboo type " - This text is BOLD"

# Change font to Times New Roman
echo "🔤 Changing font to Times New Roman..."
./peekaboo click --on G24
sleep 0.5
./peekaboo type "Times"
./peekaboo hotkey --keys enter

# Turn off bold
echo "🔤 Turning off bold..."
./peekaboo click --on C1

# Type regular text
./peekaboo type ". Now using Times New Roman regular"

# Change font size to 18pt
echo "🔤 Changing font size to 18pt..."
./peekaboo click --on G25
sleep 0.5
./peekaboo type "18"
./peekaboo hotkey --keys enter

# Apply italic formatting
echo "🔤 Applying italic formatting..."
./peekaboo click --on C2

# Type italic text
./peekaboo type " (18pt italic)!"

# Capture final state
echo "📸 Capturing final result..."
./peekaboo see --mode frontmost --path textedit-automation-result.png

echo "✅ TextEdit automation test completed!"
echo "📄 Result saved to: textedit-automation-result.png"