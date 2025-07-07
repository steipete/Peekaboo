# Menu Extraction Implementation

## Overview

We've successfully implemented comprehensive menu bar extraction in Peekaboo using pure accessibility APIs, without any clicking or UI disruption.

## Key Features

### 1. Pure Accessibility-Based Extraction
- Extracts entire menu hierarchy using the accessibility tree
- No clicking or menu opening required
- Preserves user's current UI state
- Works with nested submenus

### 2. Available Commands

#### `menu list --app AppName`
Lists all menus for a specific application with full hierarchy:
```bash
peekaboo menu list --app Calculator
```

#### `menu list-all`
Lists menus for the frontmost application (system-wide enumeration limited by macOS):
```bash
peekaboo menu list-all
peekaboo menu list-all --json-output
```

### 3. Data Structure

The menu extraction provides:
- Menu titles
- Enabled/disabled state
- Keyboard shortcuts
- Full submenu hierarchy
- Menu item count

Example JSON structure:
```json
{
  "app_name": "Calculator",
  "menus": [
    {
      "title": "View",
      "enabled": true,
      "items": [
        {
          "title": "Scientific",
          "enabled": true,
          "shortcut": "⌘2"
        },
        {
          "title": "Programmer",
          "enabled": true,
          "shortcut": "⌘3"
        }
      ]
    }
  ]
}
```

### 4. Agent Integration

The AI agent can now:
- Use `menu(app="AppName", subcommand="list")` to discover all menus
- Navigate complex menu structures
- Make informed decisions about available options
- Execute menu commands without trial and error

### 5. Implementation Details

#### Menu Extraction Functions
- `extractFullMenu()`: Extracts complete menu structure from menu bar items
- `extractMenuItems()`: Recursively extracts menu items and submenus
- Uses AXorcist's Element wrapper for clean API access

#### Key Insights
- Menu bars are per-application, not system-wide
- Menu items have children that represent submenus
- Accessibility provides full menu structure without activation
- Status items require special handling via AXGroup elements

### 6. Technical Architecture

```swift
// Extract menu without clicking
if let menuBar = app.menuBar() {
    for menuBarItem in menuBar.children() {
        if menuBarItem.role() == AXRoleNames.kAXMenuBarItemRole {
            // This menu bar item has the full menu structure as children
            let menuData = extractFullMenu(from: menuBarItem)
        }
    }
}
```

### 7. Benefits

1. **Non-Disruptive**: No visual changes or menu activation
2. **Complete Information**: Full menu hierarchy in one call
3. **Performance**: Fast extraction without UI interaction
4. **Reliability**: Works consistently across applications
5. **Agent-Friendly**: Structured data for AI decision making

## Future Enhancements

1. **Multi-App Enumeration**: Iterate through all running applications
2. **Menu Search**: Find menu items by partial text match
3. **AXorcist Integration**: Move functionality to AXorcist library
4. **Menu State Monitoring**: Track menu changes over time
5. **Contextual Menus**: Support for right-click menus

## Usage Examples

### Basic Usage
```bash
# List all menus for an app
peekaboo menu list --app Safari

# Get frontmost app's menus
peekaboo menu list-all

# JSON output for programmatic access
peekaboo menu list --app Finder --json-output
```

### Agent Usage
```bash
# Discover menus
peekaboo agent "List all menus in Calculator"

# Navigate menus
peekaboo agent "Switch Calculator to Scientific mode using the menu"

# Complex tasks
peekaboo agent "Find and use the export function in the current app"
```

This implementation provides a solid foundation for menu automation while respecting macOS security and user experience constraints.