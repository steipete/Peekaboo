---
summary: 'Review MCP Testing Results guidance'
read_when:
  - 'planning work related to mcp testing results'
  - 'debugging or extending features described here'
---

# MCP Testing Results

## Testing Setup
- **Reloaderoo**: Built from source at `/Users/steipete/Projects/reloaderoo-fork`
- **Peekaboo MCP Server**: Local build at `/Users/steipete/Projects/Peekaboo/Server`
- **Peekaboo CLI**: Binary at `/Users/steipete/Projects/Peekaboo/peekaboo`

## Test Results

### ✅ Hot-Reload Test
- Modified `Server/src/index.ts` to add a log message
- Verified modification was applied after rebuild
- Hot-reload functionality confirmed working

### ✅ Image Capture Tool
- Successfully captured frontmost window to `/tmp/peekaboo-test/screenshot.png`
- Tool correctly identifies application windows
- Returns proper metadata including window title and app name

### ⚠️ Analyze Tool
- Tool requires `PEEKABOO_AI_PROVIDERS` environment variable
- Environment variables need to be passed when starting the server
- Direct parameter-based provider config not yet supported

### ✅ List Tool
- Successfully lists running applications (92 found)
- Provides detailed app information including bundle IDs and PIDs
- Server status shows configuration details

## Available Tools

Based on `list-tools` inspection:

1. **image** - Capture and analyze screen content
   - Supports various targets: screen, app, frontmost
   - Output formats: png, jpg, data (base64)
   - Optional AI analysis with question parameter

2. **analyze** - Analyze existing images with AI
   - Requires image_path and question
   - Supports provider configuration

3. **list** - List system items
   - Types: running_applications, application_windows, server_status
   - Provides detailed window information

4. **see** - Identify UI elements (not yet tested)

5. **click** - Click UI elements

6. **type** - Type text

7. **scroll** - Scroll content

8. **hotkey** - Press keyboard shortcuts

9. **swipe** - Perform swipe gestures

10. **run** - Execute shell commands

11. **sleep** - Add delays

12. **clean** - Clean up resources

13. **agent** - AI agent task execution

14. **app** - Application management

15. **window** - Window management

16. **menu** - Menu interaction

17. **permissions** - Check system permissions

18. **move** - Move mouse cursor

19. **drag** - Drag operations

20. **dialog** - Dialog interaction

21. **space** - Virtual desktop management

22. **dock** - Dock management

## Key Findings

### CLI vs MCP Server Differences

1. **No standalone `analyze` command in CLI** - The analyze functionality has been integrated into:
   - `peekaboo image --analyze "question"` 
   - `peekaboo see --analyze "question"`
   - When calling `peekaboo analyze`, it's incorrectly treated as an agent task

2. **Environment Variables** - The MCP server requires environment variables for configuration:
   - `PEEKABOO_AI_PROVIDERS` - Must be set when starting the server
   - `PEEKABOO_CLI_PATH` - Points to the Peekaboo binary location
   - API keys (OPENAI_API_KEY, ANTHROPIC_API_KEY) must also be in environment

3. **Configuration Files** - The CLI reads from `~/.peekaboo/config.json` but the MCP server does not

## Working Tools Confirmed

- ✅ **image** - Captures screenshots successfully
- ✅ **list** - Lists apps, windows, and server status
- ✅ **sleep** - Simple timing tool works
- ⚠️ **see** - Requires valid window target
- ⚠️ **analyze** - Requires AI provider environment setup

## Critical Bugs Found

### See Tool Data Format Mismatch ❌
Testing the `see` tool revealed a critical data format incompatibility:

**Error**: `Cannot read properties of undefined (reading 'x')`

**Root Cause**: 
- CLI returns UI elements with `frame` property as `[[x,y], [width,height]]` array format
- MCP tool expects `bounds` property as `{x, y, width, height}` object format

**Example of CLI output** (from `/Users/steipete/.peekaboo/session/[ID]/map.json`):
```json
{
  "frame": [[0, 0], [1920, 1243]],
  "isActionable": false,
  "label": "scroll area",
  "role": "AXUnknown"
}
```

**Expected by MCP tool**:
```json
{
  "bounds": {
    "x": 0,
    "y": 0,
    "width": 1920,
    "height": 1243
  },
  "is_actionable": false,
  "label": "scroll area",
  "role": "AXUnknown"
}
```

This bug prevents the see tool from working through the MCP interface.

## Next Steps

1. ~~Fix the CLI command recognition bug (add "analyze" to known commands or document removal)~~ ✅ Reverted - analyze command doesn't exist
2. Make MCP server read Peekaboo config file for AI providers
3. **PRIORITY**: Fix see tool data format transformation in MCP handler
4. Test automation tools (click, type, scroll) with proper targets
5. Test error handling scenarios