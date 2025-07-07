#!/bin/bash

echo "=== Calculator Button Mapping Test ==="
echo "Creating annotated screenshot to analyze button layout..."

# Clean previous sessions
rm -rf ~/.peekaboo/session/*

# Launch Calculator
./peekaboo app launch Calculator --json-output > /dev/null
sleep 1

# Take annotated screenshot
./peekaboo see --app Calculator --annotate --path ~/Desktop/calculator-buttons.png

echo
echo "Extracting button information..."
./peekaboo see --app Calculator --json-output | jq -r '.data.ui_elements[] | select(.role == "AXButton") | select(.is_actionable) | "\(.id)"' | sort

echo
echo "Visual inspection needed: Check ~/Desktop/calculator-buttons.png"
echo "The annotated screenshot shows button IDs overlaid on the Calculator UI"