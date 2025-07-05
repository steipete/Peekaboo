# Peekaboo Example Automation Scripts

This directory contains example automation scripts demonstrating Peekaboo 3.0's GUI automation capabilities.

## Running Scripts

To run any script, use the `run` command:

```bash
peekaboo run examples/safari-search.peekaboo.json
```

## Available Examples

### safari-search.peekaboo.json
Opens Safari and performs a web search, demonstrating:
- Application targeting
- UI element discovery with `see`
- Text input with `type`
- Keyboard shortcuts with `hotkey`
- Element interaction with `click`

### calculator-demo.peekaboo.json
Performs a calculation using the macOS Calculator app, demonstrating:
- Button clicking by text query
- Sequential UI interactions
- AI-powered result analysis

### text-editor-demo.peekaboo.json
Creates and saves a document in TextEdit, demonstrating:
- Application launching via Spotlight
- Text typing with formatting
- Save dialog interaction
- Document content analysis

## Script Format

Peekaboo scripts are JSON files with a `.peekaboo.json` extension:

```json
{
  "name": "Script Name",
  "description": "What this script does",
  "version": "1.0.0",
  "commands": [
    {
      "command": "see",
      "args": ["--app", "AppName"],
      "comment": "Capture and analyze UI"
    },
    {
      "command": "click",
      "args": ["--query", "Button Text"],
      "comment": "Click a button"
    }
  ]
}
```

## Available Commands

- **see**: Capture screenshots and build UI element maps
- **click**: Click on UI elements by ID, query, or coordinates
- **type**: Type text or special keys
- **scroll**: Scroll in any direction
- **hotkey**: Press keyboard shortcuts
- **swipe**: Perform drag gestures
- **sleep**: Pause execution
- **run**: Execute nested scripts

## Tips

1. Always start with `see` to capture the current UI state
2. Use `--annotate` flag to generate screenshots with element IDs
3. Add `sleep` commands after actions that trigger UI changes
4. Use `--analyze` with `see` to get AI-powered descriptions
5. Test scripts incrementally by running individual commands first

## Requirements

- macOS 14.0 or later
- Screen Recording permission for Peekaboo
- Target applications must be running
- AI provider configured for analysis features