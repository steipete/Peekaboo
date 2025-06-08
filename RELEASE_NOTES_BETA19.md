# Peekaboo MCP v1.0.0-beta.19 Release Notes

## 🎉 What's New

### Enhanced Error Handling & User Experience

This release focuses on making Peekaboo more user-friendly by gracefully handling edge cases and providing more helpful error messages.

### ✨ Features

#### 1. Automatic Format Fallback for Invalid Values
- When an invalid format is provided (empty string, null, or unrecognized format), Peekaboo now automatically falls back to PNG instead of returning an error
- This makes the tool more resilient to incorrect inputs

#### 2. Screen Capture Protection
- Screen captures with `format: "data"` now automatically fall back to PNG format
- This prevents "Maximum call stack size exceeded" errors that occur when trying to encode large screen images as base64
- A helpful warning message explains why the fallback occurred
- Application window captures can still use `format: "data"` without restrictions

#### 3. Enhanced Error Messages for Ambiguous App Names
- When multiple applications match an identifier (e.g., "C" matches Calendar, Console, and Cursor), the error message now lists all matching applications with their bundle IDs
- Example error message:
  ```
  Image capture failed: Multiple applications match identifier 'C'. Please be more specific.
  Matches found: Calendar (com.apple.iCal), Console (com.apple.Console), Cursor (com.todesktop.230313mzl4w4u92)
  ```
- This helps users quickly identify the correct application name to use
- Applies to both `image` and `list` tools

## 🐛 Bug Fixes
- Fixed potential stack overflow when capturing screens with `format: "data"`
- Improved error message clarity throughout the application

## 📦 Installation

```bash
npm install -g @steipete/peekaboo-mcp@beta
```

Or with npx:
```bash
npx @steipete/peekaboo-mcp@beta
```

## 🙏 Thanks
Thanks to all the beta testers for your feedback! Special thanks to @mattydebie for reviewing all these changes! 😊