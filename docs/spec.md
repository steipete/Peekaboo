## Peekaboo: Full & Final Detailed Specification v1.0.0-beta.17
https://aistudio.google.com/prompts/1B0Va41QEZz5ZMiGmLl2gDme8kQ-LQPW-

**Project Vision:** Peekaboo is a macOS utility exposed via a Node.js MCP server, enabling AI agents to perform advanced screen captures, image analysis via user-configured AI providers, and query application/window information. The core macOS interactions are handled by a native Swift command-line interface (CLI) named `peekaboo`, which is called by the Node.js server. All image captures automatically exclude window shadows/frames.

**Core Components:**

1.  **Node.js/TypeScript MCP Server (`@steipete/peekaboo-mcp`):**
    *   **NPM Package Name:** `@steipete/peekaboo-mcp`.
    *   **GitHub Project Name:** `Peekaboo`.
    *   Implements MCP server logic using the latest stable `@modelcontextprotocol/sdk` (v1.12.0+).
    *   Exposes three primary MCP tools: `image`, `analyze`, `list`.
    *   Translates MCP tool calls into commands for the Swift `peekaboo` CLI.
    *   Parses structured JSON output from the Swift `peekaboo` CLI.
    *   Handles image data preparation (reading files, Base64 encoding) for MCP responses if image data is explicitly requested by the client.
    *   Manages interaction with configured AI providers based on environment variables. All AI provider calls (Ollama, OpenAI, etc.) are made from this Node.js layer.
    *   Implements robust logging to a file using `pino`, ensuring no logs interfere with MCP stdio communication.
2.  **Swift CLI (`peekaboo`):**
    *   A standalone macOS command-line tool, built as a universal binary (arm64 + x86_64).
    *   Handles all direct macOS system interactions: image capture, application/window listing, and fuzzy application matching.
    *   **Does NOT directly interact with any AI providers (Ollama, OpenAI, etc.).**
    *   Outputs all results and errors in a structured JSON format via a global `--json-output` flag. This JSON includes a `debug_logs` array for internal Swift CLI logs, which the Node.js server can relay to its own logger.
    *   The `peekaboo` binary is bundled at the root of the `@steipete/peekaboo-mcp` NPM package.

---

### I. Node.js/TypeScript MCP Server (`@steipete/peekaboo-mcp`)

#### A. Project Setup & Distribution

1.  **Language/Runtime:** Node.js (latest LTS recommended, e.g., v18+ or v20+), TypeScript (latest stable, e.g., v5+).
2.  **Package Manager:** NPM.
3.  **`package.json`:**
    *   `name`: `"@steipete/peekaboo-mcp"`
    *   `version`: Semantic versioning (e.g., `1.0.0-beta.17`).
    *   `type`: `"module"` (for ES Modules).
    *   `main`: `"dist/index.js"` (compiled server entry point).
    *   `bin`: `{ "peekaboo-mcp": "dist/index.js" }`.
    *   `files`: `["dist/", "peekaboo", "README.md", "LICENSE"]` (includes compiled JS and the Swift `peekaboo` binary at package root).
    *   `scripts`:
        *   `build`: Command to compile TypeScript (e.g., `tsc`).
        *   `build:swift`: Build Swift CLI (`./scripts/build-swift-universal.sh`).
        *   `build:all`: Build both Swift CLI and TypeScript (`npm run build:swift && npm run build`).
        *   `start`: `node dist/index.js`.
        *   `prepublishOnly`: `npm run build:all`.
    *   `dependencies`: `@modelcontextprotocol/sdk` (v1.12.0+), `zod` (for input validation), `pino` (for logging), `openai` (for OpenAI API interaction). Support for other AI providers like Anthropic is planned.
    *   `devDependencies`: `typescript`, `@types/node`, `pino-pretty` (for optional development console logging), `vitest` (for testing).
4.  **Distribution:** Published to NPM as `@steipete/peekaboo-mcp`. Installable via `npm i -g @steipete/peekaboo-mcp` or usable with `npx @steipete/peekaboo-mcp`.
5.  **Swift CLI Location Strategy:**
    *   The Node.js server will first check the environment variable `PEEKABOO_CLI_PATH`. If set and points to a valid executable, that path will be used.
    *   If `PEEKABOO_CLI_PATH` is not set or invalid, the server will fall back to a bundled path, resolved relative to its own script location (e.g., `path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'peekaboo')`, assuming the compiled server script is in `dist/` and `peekaboo` binary is at the package root).

#### B. Server Initialization & Configuration (`src/index.ts`)

1.  **Imports:** `Server`, `StdioServerTransport` from `@modelcontextprotocol/sdk`; `pino` from `pino`; `os`, `path` from Node.js built-ins.
2.  **Server Info:** `name: "peekaboo-mcp"`, `version: <package_version from package.json>`.
3.  **Server Capabilities:** Advertise `tools` capability.
4.  **Logging (Pino):**
    *   Instantiate `pino` logger with transport configuration.
    *   **Default Log Location:** `~/Library/Logs/peekaboo-mcp.log` with fallback to `path.join(os.tmpdir(), 'peekaboo-mcp.log')` if the primary location is not writable.
    *   **Directory Creation:** Automatically creates log directories with `mkdir: true` option.
    *   **Fallback Handling:** Tests write access to the configured log directory and falls back to temp directory if needed.
    *   **Log Level:** Controlled by ENV VAR `PEEKABOO_LOG_LEVEL` (standard Pino levels: `trace`, `debug`, `info`, `warn`, `error`, `fatal`). Default: `"info"`.
    *   **Conditional Console Logging (Development Only):** If ENV VAR `PEEKABOO_CONSOLE_LOGGING="true"`, add a second Pino transport targeting `process.stderr` using `pino-pretty` for human-readable output.
    *   **Strict Rule:** All server operational logging must use the configured Pino instance. No direct `console.log/warn/error` that might output to `stdout`.
5.  **Environment Variables (Read by Server):**
    *   `PEEKABOO_AI_PROVIDERS`: Comma-separated list of `provider_name/default_model_for_provider` pairs (e.g., `"openai/gpt-4o,ollama/llava:latest"`). Currently, recognized `provider_name` values are `"openai"` and `"ollama"`. Support for `"anthropic"` is planned. If unset/empty, `analyze` tool reports AI not configured.
    *   `OPENAI_API_KEY`: API key for OpenAI.
    *   `ANTHROPIC_API_KEY`: API key for Anthropic (used for future planned support).
    *   (Other cloud provider API keys as standard ENV VAR names).
    *   `PEEKABOO_OLLAMA_BASE_URL`: Base URL for local Ollama instance. Default: `"http://localhost:11434"`.
    *   `PEEKABOO_LOG_LEVEL`: For Pino logger. Default: `"info"`.
    *   `PEEKABOO_LOG_FILE`: Path to the server's log file. Default: `~/Library/Logs/peekaboo-mcp.log` with fallback to temp directory.
    *   `PEEKABOO_DEFAULT_SAVE_PATH`: Default base absolute path for saving images captured by `image` if not specified in the tool input. If this ENV is also not set, the Swift CLI will use its own temporary directory logic.
    *   `PEEKABOO_CONSOLE_LOGGING`: Boolean (`"true"`/`"false"`) for dev console logs. Default: `"false"`.
    *   `PEEKABOO_CLI_PATH`: Optional override for Swift `peekaboo` CLI path.
6.  **Server Status Reporting Logic:**
    *   A utility function `generateServerStatusString()` creates a formatted string with server name, version, and configured AI providers.
    *   **Tool Descriptions:** When the server handles a `ListToolsRequest`, it appends the server status information to the `description` field of each advertised tool (`image`, `analyze`, `list`).
    *   **Direct Access via `list` tool:** The server status string can also be retrieved directly by calling the `list` tool with `item_type: "server_status"` (see Tool 3 details).
7.  **Tool Registration:** Register `image`, `analyze`, `list` with their Zod input schemas and handler functions.
8.  **Transport:** `await server.connect(new StdioServerTransport());`.
9.  **Shutdown:** Implement graceful shutdown on `SIGINT`, `SIGTERM` with proper cleanup and log flushing.

#### C. MCP Tool Specifications & Node.js Handler Logic

**General Node.js Handler Pattern (for tools calling Swift `peekaboo` CLI):**

1.  Validate MCP `input` against the tool's Zod schema. If invalid, log error with Pino and return MCP error `ToolResponse`.
2.  Construct command-line arguments for Swift `peekaboo` CLI based on MCP `input`. **Always include `--json-output`**.
3.  Log the constructed Swift command with Pino at `debug` level.
4.  Execute Swift `peekaboo` CLI using `child_process.spawn`, capturing `stdout`, `stderr`, and `exitCode`.
5.  If any data is received on Swift CLI's `stderr`, log it immediately with Pino at `warn` level, prefixed (e.g., `[SwiftCLI-stderr]`).
6.  On Swift CLI process close:
    *   If `exitCode !== 0` or `stdout` is empty/not parseable as JSON:
        *   Log failure details with Pino (`error` level).
        *   Construct MCP error `ToolResponse` (e.g., `errorCode: "SWIFT_CLI_EXECUTION_ERROR"` or `SWIFT_CLI_INVALID_OUTPUT` in `_meta`). 
        *   **Error Message Prioritization:** The primary `message` in the error response will be derived by mapping the Swift CLI's exit code to a specific, user-friendly error message (e.g., "Screen Recording permission is not granted..."). If the exit code is unknown, the message will be derived from the Swift CLI's `stderr` output if available, prefixed with "Peekaboo CLI Error: ". Otherwise, a generic message like "Swift CLI execution failed (exit code: X)" will be used. The `details` field will contain `stdout` or `stderr` for additional context.
    *   If `exitCode === 0`:
        *   Attempt to parse `stdout` as JSON. If parsing fails, treat as error (above).
        *   Let `swiftResponse = JSON.parse(stdout)`.
        *   If `swiftResponse.debug_logs` (array of strings) exists, log each entry via Pino at `debug` level, clearly marked as from backend (e.g., `logger.debug({ backend: "swift", swift_log: entry })`).
        *   If `swiftResponse.success === false`:
            *   Extract `swiftResponse.error.message`, `swiftResponse.error.code`, `swiftResponse.error.details`.
            *   Construct and return MCP error `ToolResponse`, relaying these details (e.g., `message` in `content`, `code` in `_meta.backend_error_code`).
        *   If `swiftResponse.success === true`:
            *   Process `swiftResponse.data` to construct the success MCP `ToolResponse`.
            *   Relay `swiftResponse.messages` as `TextContentItem`s in the MCP response if appropriate.
            *   For `image` with `input.return_data: true`:
                *   Iterate `swiftResponse.data.saved_files.[*].path`.
                *   For each path, read image file into a `Buffer`.
                *   Base64 encode the `Buffer`.
                *   Construct `ImageContentItem` for MCP `ToolResponse.content`, including `data` (Base64 string) and `mimeType` (from `swiftResponse.data.saved_files.[*].mime_type`).
    *   Augment successful `ToolResponse` with initial server status string if applicable (see B.6).
    *   Send MCP `ToolResponse`.

**Tool 1: `image` - Screen Capture & Analysis**

**Purpose:** Captures macOS screen content and optionally analyzes it using AI models.

**Input Schema (Zod):**
```typescript
z.object({
  app_target: z.string().optional().describe(
    "Optional. Specifies the capture target.\\n" +
    "For example:\\n" +
    "Omit or use an empty string (e.g., `''`) for all screens.\\n" +
    "Use `'screen:INDEX'` (e.g., `'screen:0'`) for a specific display.\\n" +
    "Use `'frontmost'` for all windows of the current foreground application.\\n" +
    "Use `'AppName'` (e.g., `'Safari'`) for all windows of that application.\\n" +
    "Use `'AppName:WINDOW_TITLE:Title'` (e.g., `'TextEdit:WINDOW_TITLE:My Notes'`) for a window of 'AppName' matching that title.\\n" +
    "Use `'AppName:WINDOW_INDEX:Index'` (e.g., `'Preview:WINDOW_INDEX:0'`) for a window of 'AppName' at that index.\\n" +
    "Ensure components are correctly colon-separated."
  ),
  path: z.string().optional().describe(
    "Optional. Base absolute path for saving the image.\\n" +
    "Relevant if `format` is `'png'`, `'jpg'`, or if `'data'` is used with the intention to also save the file.\\n" +
    "If a `question` is provided and `path` is omitted, a temporary path is used for image capture, and this temporary file is deleted after analysis."
  ),
  question: z.string().optional().describe(
    "Optional. If provided, the captured image will be analyzed by an AI model.\\n" +
    "The server automatically selects an AI provider from the `PEEKABOO_AI_PROVIDERS` environment variable.\\n" +
    "The analysis result (text) is included in the response."
  ),
  format: z.enum(["png", "jpg", "data"]).optional().describe(
    "Optional. Output format.\\n" +
    "Can be `'png'`, `'jpg'`, or `'data'`.\\n" +
    "If `'png'` or `'jpg'`, saves the image to the specified `path`.\\n" +
    "If `'data'`, returns Base64 encoded PNG data inline in the response.\\n" +
    "If `path` is also provided when `format` is `'data'`, the image is saved (as PNG) AND Base64 data is returned.\\n" +
    "Defaults to `'data'` if `path` is not given."
  ),
  capture_focus: z.preprocess(
    (val) => (val === "" || val === null ? undefined : val),
    z.enum(["background", "auto", "foreground"])
      .optional()
      .default("auto")
      .describe(
        "Optional. Focus behavior. 'auto' (default): bring target to front only if not already active. " +
        "'background': capture without altering window focus. " +
        "'foreground': always bring target to front before capture."
      )
  ),
})
```

**Input Parameters:**
1. `app_target` (optional): Specifies capture target with flexible syntax:
   - Empty/omitted: All screens
   - `"screen:INDEX"`: Specific display (e.g., `"screen:0"`)
   - `"frontmost"`: All windows of foreground application
   - `"AppName"`: All windows of specified application
   - `"AppName:WINDOW_TITLE:Title"`: Specific window by title
   - `"AppName:WINDOW_INDEX:Index"`: Specific window by index
2. `path` (optional): Base absolute path for saving images. Uses temporary path if omitted.
3. `question` (optional): If provided, captured image is analyzed by AI model.
4. `format` (optional): Output format ("png", "jpg", "data"). Defaults to "data" if no path.
5. `capture_focus` (optional): Focus behavior ("background", "auto", "foreground"). Default: "auto".

**Enhanced Path Handling:**
- **Smart Path Resolution**: Automatically determines if path is file or directory
- **Multi-Capture Support**: For multiple captures, appends screen/window identifiers
- **Directory Auto-Creation**: Creates intermediate directories automatically
- **Extension Preservation**: Maintains file extensions when appending identifiers
- **Fallback Logic**: Uses PEEKABOO_DEFAULT_SAVE_PATH or temporary directory if path not specified

**Node.js Handler Logic:**
1. Validate input against Zod schema.
2. **Path Resolution**: Use centralized `resolveImagePath()` logic to determine effective save path.
3. **Swift CLI Execution**: Build arguments and execute Swift CLI with `--json-output`.
4. **Response Processing**: Parse JSON response and handle saved files.
5. **AI Analysis** (if question provided):
   - Check configured AI providers
   - Iterate through all saved files for analysis
   - Use `performAutomaticAnalysis()` with auto-selected provider
   - Include analysis results and timing information
6. **Data Return Logic**: Return Base64 data if format is "data" or no path provided (and no question).
7. **Metadata Enhancement**: Include comprehensive metadata for each saved file.

**Output Schema:**
```json
{
  "content": [
    {
      "type": "text",
      "text": "Captured 2 images: Screen 0 (Main Display), Screen 1 (External Display). Saved to: /path/to/captures/"
    },
    {
      "type": "text",
      "text": "Analysis Result: The screenshot shows a desktop with Safari and TextEdit windows open..."
    },
    {
      "type": "image",
      "data": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...",
      "mimeType": "image/png",
      "metadata": {
        "item_label": "Screen 0 (Main Display)",
        "window_title": null,
        "window_id": null,
        "source_path": "/path/to/screen_0.png"
      }
    }
  ],
  "saved_files": [
    {
      "path": "/path/to/screen_0.png",
      "item_label": "Screen 0 (Main Display)",
      "window_title": null,
      "window_id": null,
      "window_index": null,
      "mime_type": "image/png"
    }
  ],
  "analysis_text": "The screenshot shows a desktop with Safari and TextEdit windows open...",
  "model_used": "ollama/llava:latest"
}
```

**Key Features:**
- **Flexible Targeting**: Supports screens, applications, and specific windows
- **Smart Path Handling**: Automatic directory creation and path resolution
- **Integrated AI Analysis**: Optional AI-powered image analysis with auto-provider selection
- **Multiple Output Formats**: File saving and/or Base64 data return
- **Comprehensive Metadata**: Detailed information about captured content
- **Non-Intrusive Capture**: Configurable focus behavior to avoid workflow disruption
- **Error Recovery**: Robust error handling with detailed error messages

**Tool 2: `analyze` - AI-Powered Image Analysis**

**Purpose:** Analyzes a pre-existing image file from the local filesystem using a configured AI model.

**Input Schema (Zod):**
```typescript
z.object({
  image_path: z.string().optional().describe("Required. Absolute path to image file (.png, .jpg, .jpeg, .webp) to be analyzed."),
  question: z.string().describe("Required. Question for the AI about the image."),
  provider_config: z.object({
    type: z.enum(["auto", "ollama", "openai"]).default("auto"),
    model: z.string().optional(),
  }).optional(),
  // Silent fallback parameter (not advertised in schema)
  path: z.string().optional(),
}).refine((data) => data.image_path || data.path, {
  message: "image_path is required",
  path: ["image_path"],
})
```

**Input Parameters:**
1. `image_path` (required): Absolute path to image file (.png, .jpg, .jpeg, .webp) to be analyzed.
2. `question` (required): Question for the AI about the image (e.g., "What objects are in this picture?", "Extract text from this screenshot").
3. `provider_config` (optional): Explicit provider/model configuration:
   - `type`: AI provider ("auto", "ollama", "openai"). Default: "auto" (uses server's PEEKABOO_AI_PROVIDERS preference).
   - `model`: Optional model name. If omitted, uses default model for the chosen provider.

**Node.js Handler Logic:**
1. Validate input against Zod schema with image path requirement.
2. Validate image file extension (.png, .jpg, .jpeg, .webp).
3. Check AI providers configuration (PEEKABOO_AI_PROVIDERS environment variable).
4. Parse configured providers and determine effective provider/model.
5. Read image file as Base64.
6. **Performance Tracking**: Record start time before AI analysis.
7. Call AI provider with image data and question.
8. **Performance Reporting**: Calculate analysis duration and include timing information in response.
9. Format response with analysis result and metadata.

**Enhanced Error Handling:**
- Unsupported image formats with specific format guidance
- Missing AI provider configuration with setup instructions
- File read errors with detailed error messages
- AI provider failures with specific error context
- Comprehensive validation with helpful error messages

**Output Schema:**
```json
{
  "content": [
    {
      "type": "text",
      "text": "[AI analysis result text]"
    },
    {
      "type": "text", 
      "text": "👻 Peekaboo: Analyzed image with openai/gpt-4o in 2.34s."
    }
  ],
  "analysis_text": "[AI analysis result text]",
  "model_used": "openai/gpt-4o"
}
```

**Key Features:**
- **Performance Timing**: Includes analysis duration in seconds for performance monitoring
- **Provider Flexibility**: Supports auto-selection or explicit provider/model specification
- **Comprehensive Validation**: Validates file formats, paths, and configuration
- **Detailed Error Messages**: Provides specific guidance for common issues
- **Fallback Support**: Silent fallback from `image_path` to `path` parameter for compatibility

**Tool 3: `list` - System Information & Status**

**Purpose:** Lists various system items on macOS, providing situational awareness for AI agents.

**Input Schema (Zod):**
```typescript
z.object({
  item_type: z.enum(["running_applications", "application_windows", "server_status", ""]).optional(),
  app: z.string().optional(),
  include_window_details: z.array(z.enum(["off_screen", "bounds", "ids"])).optional(),
})
```

**Input Parameters:**
1. `item_type` (optional): Specifies the type of items to list. If omitted or empty, defaults to `"application_windows"` if `app` is provided, otherwise `"running_applications"`.
   - `"running_applications"`: Lists all currently running applications.
   - `"application_windows"`: Lists open windows for a specific application. Requires the `app` parameter.
   - `"server_status"`: Returns comprehensive information about the Peekaboo MCP server, including version, configuration, permissions, and system status.
2. `app` (optional): Required when `item_type` is `"application_windows"`. Specifies the target application by name or bundle ID. Fuzzy matching is used.
3. `include_window_details` (optional): Only applicable for `"application_windows"`. Array of additional details to include:
   - `"ids"`: Include window IDs.
   - `"bounds"`: Include window position and size (x, y, width, height).
   - `"off_screen"`: Indicate if windows are currently off-screen.

**Node.js Handler Logic:**
1. Validate input against Zod schema.
2. Determine effective item type (with fallback logic).
3. **Special Case for `server_status`**: If `item_type === "server_status"`, the handler generates comprehensive server status information directly without calling the Swift CLI, including:
   - Server version and AI provider configuration
   - Native Swift CLI binary status (location, version, executable status)
   - System permissions (Screen Recording, Accessibility)
   - Environment configuration (log files, AI providers, custom paths)
   - Configuration issues and recommendations
   - System information (platform, architecture, Node.js version)
4. For other item types, build Swift CLI arguments and execute the CLI.
5. Parse Swift CLI JSON response and format for MCP.

**Output Examples:**

*Server Status (comprehensive diagnostics):*
```
--- Peekaboo MCP Server Status ---
Name: peekaboo-mcp
Version: 1.0.0-beta.17
Configured AI Providers: ollama/llava:latest, openai/gpt-4o
---

## Native Binary (Swift CLI) Status
- Location: /path/to/peekaboo
- Status: ✅ Found and executable
- Version: 1.0.0-beta.17
- Executable: Yes

## System Permissions
- Screen Recording: ✅ Granted
- Accessibility: ❌ Not granted

## Environment Configuration
- Log File: ~/Library/Logs/peekaboo-mcp.log
  Status: ✅ Directory writable
- Log Level: info
- Console Logging: Disabled
- AI Providers: ollama/llava:latest,openai/gpt-4o
- Custom CLI Path: Not set (using default)
- Default Save Path: Not set

## Configuration Issues
✅ No configuration issues detected

## System Information
- Platform: darwin
- Architecture: arm64
- OS Version: 23.1.0
- Node.js Version: v20.10.0
```

*Running Applications:*
```json
{
  "content": [{ "type": "text", "text": "Found 5 running applications:\n\n1. Safari (com.apple.Safari) - PID: 1234 [ACTIVE] - Windows: 3\n2. TextEdit (com.apple.TextEdit) - PID: 5678 - Windows: 1\n..." }],
  "application_list": [
    {
      "app_name": "Safari",
      "bundle_id": "com.apple.Safari", 
      "pid": 1234,
      "is_active": true,
      "window_count": 3
    }
    // ... more applications
  ]
}
```

*Application Windows (with details):*
```json
{
  "content": [{ "type": "text", "text": "Found 2 windows for application: Safari (com.apple.Safari) - PID: 1234\n\nWindows:\n1. \"Welcome to Safari\" [ID: 67] [ON-SCREEN] [0,0 800×600]\n2. \"GitHub\" [ID: 68] [ON-SCREEN] [100,100 1200×800]" }],
  "window_list": [
    {
      "window_title": "Welcome to Safari",
      "window_id": 67,
      "window_index": 0,
      "is_on_screen": true,
      "bounds": { "x": 0, "y": 0, "width": 800, "height": 600 }
    },
    {
      "window_title": "GitHub", 
      "window_id": 68,
      "window_index": 1,
      "is_on_screen": true,
      "bounds": { "x": 100, "y": 100, "width": 1200, "height": 800 }
    }
  ],
  "target_application_info": {
    "app_name": "Safari",
    "bundle_id": "com.apple.Safari",
    "pid": 1234
  }
}
```

---

### II. Swift CLI (`peekaboo`)

#### A. General CLI Design

1.  **Executable Name:** `peekaboo` (Universal macOS binary: arm64 + x86_64).
2.  **Argument Parser:** Use `swift-argument-parser` package.
3.  **Top-Level Commands (Subcommands of `peekaboo`):** `image`, `list`. (No `analyze` command).
4.  **Global Option (for all commands/subcommands):** `--json-output` (Boolean flag).
    *   If present: All `stdout` from Swift CLI MUST be a single, valid JSON object. `stderr` should be empty on success, or may contain system-level error text on catastrophic failure before JSON can be formed.
    *   If absent: Output human-readable text to `stdout` and `stderr` as appropriate for direct CLI usage.
    *   **Success JSON Structure:**
        ```json
        {
          "success": true,
          "data": { /* Command-specific structured data */ },
          "messages": ["Optional user-facing status/warning message from Swift CLI operations"],
          "debug_logs": ["Internal Swift CLI debug log entry 1", "Another trace message"]
        }
        ```
    *   **Error JSON Structure:**
        ```json
        {
          "success": false,
          "error": {
            "message": "Detailed, user-understandable error message.",
            "code": "SWIFT_ERROR_CODE_STRING", // e.g., PERMISSION_DENIED_SCREEN_RECORDING
            "details": "Optional additional technical details or context."
          },
          "debug_logs": ["Contextual debug log leading to error"]
        }
        ```
    *   **Standardized Swift Error Codes (`error.code` values):**
        *   `PERMISSION_ERROR_SCREEN_RECORDING`
        *   `PERMISSION_ERROR_ACCESSIBILITY`
        *   `APP_NOT_FOUND`
        *   `AMBIGUOUS_APP_IDENTIFIER`
        *   `WINDOW_NOT_FOUND`
        *   `CAPTURE_FAILED`
        *   `FILE_IO_ERROR`: Enhanced with detailed context about the specific failure (permission denied, directory missing, disk space, etc.)
        *   `INVALID_ARGUMENT`
        *   `SIPS_ERROR`
        *   `INTERNAL_SWIFT_ERROR`
        *   `UNKNOWN_ERROR`
5.  **Permissions Handling:**
    *   The CLI must proactively check for Screen Recording permission before attempting any capture or window listing that requires it (e.g., reading window titles via `CGWindowListCopyWindowInfo`).
    *   If Accessibility is used for `--capture-focus foreground` window raising, check that permission.
    *   If permissions are missing, output the specific JSON error (e.g., code `PERMISSION_ERROR_SCREEN_RECORDING`) and exit with a distinct exit code for that error. Do not hang or prompt interactively.
6.  **Temporary File Management:**
    *   If the CLI needs to save an image temporarily (e.g., if `screencapture` is used as a fallback for PDF, or if no `--path` is given by Node.js), it uses `FileManager.default.temporaryDirectory` with unique filenames (e.g., `peekaboo_<uuid>_<info>.<format>`).
    *   These self-created temporary files **MUST be deleted by the Swift CLI** after it has successfully generated and flushed its JSON output to `stdout`.
    *   Files saved to a user/Node.js-specified `--path` are **NEVER** deleted by the Swift CLI.
7.  **Internal Logging for `--json-output`:**
    *   When `--json-output` is active, internal verbose/debug messages are collected into the `debug_logs: [String]` array in the final JSON output. They are **NOT** printed to `stderr`.
    *   For standalone CLI use (no `--json-output`), these debug messages can print to `stderr`.

#### B. `peekaboo image` Command

*   **Options (defined using `swift-argument-parser`):**
    *   `--app <String?>`: App identifier.
    *   `--path <String?>`: Output path for the captured image(s). Can be either a file path or directory path.
        *   **File Path Logic**: If the path appears to be a file (contains an extension and doesn't end with `/`), the CLI intelligently handles it:
            *   For single screen capture (`--screen-index` specified): Uses the exact file path provided.
            *   For multiple screen/window capture: Appends screen/window identifiers to avoid overwriting (e.g., `/tmp/capture.png` becomes `/tmp/capture_1_timestamp.png`, `/tmp/capture_2_timestamp.png`).
        *   **Directory Path Logic**: If the path appears to be a directory (no extension or ends with `/`), generated filenames are placed in that directory.
        *   **Auto-Creation**: The CLI automatically creates intermediate directories as needed for both file and directory paths.
        *   **Edge Cases**: Special directory indicators like `.` and `..` are handled correctly.
    *   `--mode <ModeEnum?>`: `ModeEnum` is `screen, window, multi`. Default logic: if `--app` then `window`, else `screen`.
    *   `--window-title <String?>`: For `mode window`.
    *   `--window-index <Int?>`: For `mode window`.
    *   `--format <FormatEnum?>`: `FormatEnum` is `png, jpg`. Default `png`.
    *   `--capture-focus <FocusEnum?>`: `FocusEnum` is `background, foreground`. Default `background`.
*   **Behavior:**
    *   Implements fuzzy app matching. On ambiguity, returns JSON error with `code: "AMBIGUOUS_APP_IDENTIFIER"` and lists potential matches in `error.details` or `error.message`.
    *   Always attempts to exclude window shadow/frame (`CGWindowImageOption.boundsIgnoreFraming` or `screencapture -o` if shelled out for PDF). No cursor is captured.
    *   **Background Capture (`--capture-focus background` or default):**
        *   Primary method: Uses `CGWindowListCopyWindowInfo` to identify target window(s)/screen(s).
        *   Captures via `CGDisplayCreateImage` (for screen mode) or `CGWindowListCreateImageFromArray` (for window/multi modes).
        *   Converts `CGImage` to `Data` (PNG or JPG) and saves to file (at user `--path` or its own temp path).
    *   **Foreground Capture (`--capture-focus foreground`):**
        *   Activates app using `NSRunningApplication.activate(options: [.activateIgnoringOtherApps])`.
        *   If a specific window needs raising (e.g., from `--window-index` or specific `--window-title` for an app with many windows), it *may* attempt to use Accessibility API (`AXUIElementPerformAction(kAXRaiseAction)`) if available and permissioned.
        *   If specific window raise fails (or Accessibility not used/permitted), it logs a warning to the `debug_logs` array (e.g., "Could not raise specific window; proceeding with frontmost of activated app.") and captures the most suitable front window of the activated app.
        *   Capture mechanism is still preferably native CG APIs.
    *   **Multi-Screen (`--mode screen`):** Enumerates `CGGetActiveDisplayList`, captures each display using `CGDisplayCreateImage`. Filenames (if saving) get display-specific suffixes (e.g., `_display0_main.png`, `_display1.png`).
    *   **Multi-Window (`--mode multi`):** Uses `CGWindowListCopyWindowInfo` for target app's PID, captures each relevant window (on-screen by default) with `CGWindowListCreateImageFromArray`. Filenames get window-specific suffixes.
    *   **PDF Format Handling (as per Q7 decision):** If `--format pdf` were still supported (it's removed), it would use `Process` to call `screencapture -t pdf -R<bounds>` or `-l<id>`. Since PDF is removed, this is not applicable.
*   **JSON Output `data` field structure (on success):**
    ```json
    {
      "saved_files": [ // Array is always present, even if empty (e.g. capture failed before saving)
        {
          "path": "/absolute/path/to/saved/image.png", // Absolute path
          "item_label": "Display 1 / Main", // Or window_title for window/multi modes
          "window_id": 12345, // CGWindowID (UInt32), optional, if available & relevant
          "window_index": 0,  // Optional, if relevant (e.g. for multi-window or indexed capture)
          "mime_type": "image/png" // Actual MIME type of the saved file
        }
        // ... more items if mode is screen or multi ...
      ]
    }
    ```

#### C. `peekaboo list` Command

*   **Subcommands & Options:**
    *   `peekaboo list apps [--json-output]`
    *   `peekaboo list windows --app <app_identifier_string> [--include-details <comma_separated_string_of_options>] [--json-output]`
        *   `--include-details` options: `off_screen`, `bounds`, `ids`.
*   **Behavior:**
    *   `apps`: Uses `NSWorkspace.shared.runningApplications`. For each app, retrieves `localizedName`, `bundleIdentifier`, `processIdentifier` (pid), `isActive`. To get `window_count`, it performs a `CGWindowListCopyWindowInfo` call filtered by the app's PID and counts on-screen windows.
    *   `windows`:
        *   Resolves `app_identifier` using fuzzy matching. If ambiguous, returns JSON error.
        *   Uses `CGWindowListCopyWindowInfo` filtered by the target app's PID.
        *   If `--include-details` contains `"off_screen"`, uses `CGWindowListOption.optionAllScreenWindows` (and includes `kCGWindowIsOnscreen` boolean in output). Otherwise, uses `CGWindowListOption.optionOnScreenOnly`.
        *   Extracts `kCGWindowName` (title).
        *   If `"ids"` in `--include-details`, extracts `kCGWindowNumber` as `window_id`.
        *   If `"bounds"` in `--include-details`, extracts `kCGWindowBounds` as `bounds: {x, y, width, height}`.
        *   `window_index` is the 0-based index from the filtered array returned by `CGWindowListCopyWindowInfo` (reflecting z-order for on-screen windows).
*   **JSON Output `data` field structure (on success):**
    *   For `apps`:
        ```json
        {
          "applications": [
            {
              "app_name": "Safari",
              "bundle_id": "com.apple.Safari",
              "pid": 501,
              "is_active": true,
              "window_count": 3 // Count of on-screen windows for this app
            }
            // ... more applications ...
          ]
        }
        ```
    *   For `windows`:
        ```json
        {
          "target_application_info": {
            "app_name": "Safari",
            "pid": 501,
            "bundle_id": "com.apple.Safari"
          },
          "windows": [
            {
              "window_title": "Apple",
              "window_id": 67, // if "ids" requested
              "window_index": 0,
              "is_on_screen": true, // Potentially useful, especially if "off_screen" included
              "bounds": {"x": 0, "y": 0, "width": 800, "height": 600} // if "bounds" requested
            }
            // ... more windows ...
          ]
        }
        ```

---

### III. Build, Packaging & Distribution

1.  **Swift CLI (`peekaboo`):**
    *   `Package.swift` defines an executable product named `peekaboo`.
    *   Build process (e.g., part of NPM `prepublishOnly` or a separate build script): `swift build -c release --arch arm64 --arch x86_64`.
    *   The resulting universal binary (e.g., from `.build/apple/Products/Release/peekaboo`) is copied to the root of the `@steipete/peekaboo-mcp` NPM package directory before publishing.
2.  **Node.js MCP Server:**
    *   TypeScript is compiled to JavaScript (e.g., into `dist/`) using `tsc`.
    *   The NPM package includes `dist/` and the `peekaboo` Swift binary (at package root).

---

### IV. Documentation (`README.md` for `@steipete/peekaboo-mcp` NPM Package)

1.  **Project Overview:** Briefly state vision and components.
2.  **Prerequisites:**
    *   macOS version (e.g., 12.0+ or as required by Swift/APIs).
    *   Xcode Command Line Tools (recommended for a stable development environment on macOS, even if not strictly used by the final Swift binary for all operations).
    *   Ollama (if using local Ollama for analysis) + instructions to pull models.
3.  **Installation:**
    *   Primary: `npm install -g @steipete/peekaboo-mcp`.
    *   Alternative: `npx @steipete/peekaboo-mcp`.
4.  **MCP Client Configuration:**
    *   Provide example JSON snippets for configuring popular MCP clients (e.g., VS Code, Cursor) to use `@steipete/peekaboo-mcp`.
    *   Example for VS Code/Cursor using `npx` for robustness:
        ```json
        {
          "mcpServers": {
            "PeekabooMCP": {
              "command": "npx",
              "args": ["@steipete/peekaboo-mcp"],
              "env": {
                "PEEKABOO_AI_PROVIDERS": "ollama/llava:latest,openai/gpt-4o",
                "OPENAI_API_KEY": "sk-yourkeyhere"
                /* other ENV VARS */
              }
            }
          }
        }
        ```
5.  **Required macOS Permissions:**
    *   **Screen Recording:** Essential for ALL `image` functionalities and for `list` if it needs to read window titles (which it does via `CGWindowListCopyWindowInfo`). Provide clear, step-by-step instructions for System Settings. Include `open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"` command.
    *   **Accessibility:** Required *only* if `image` with `capture_focus: "foreground"` needs to perform specific window raising actions (beyond simple app activation) via the Accessibility API. Explain this nuance. Include `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"` command.
6.  **Environment Variables (for Node.js `@steipete/peekaboo-mcp` server):**
    *   `PEEKABOO_AI_PROVIDERS`: Crucial for `analyze`. Explain format (`provider/model,provider/model`), effect, and that `analyze` reports "not configured" if unset. List recognized `provider` names ("ollama", "openai").
    *   `OPENAI_API_KEY` (and similar for other cloud providers): How they are used.
    *   `PEEKABOO_OLLAMA_BASE_URL`: Default and purpose.
    *   `PEEKABOO_LOG_LEVEL`: For `pino` logger. Values and default.
    *   `PEEKABOO_LOG_FILE`: Path to the server's log file. Default: `~/Library/Logs/peekaboo-mcp.log` with fallback to temp directory.
    *   `PEEKABOO_DEFAULT_SAVE_PATH`: Default base absolute path for saving images captured by `image` if not specified in the tool input. If this ENV is also not set, the Swift CLI will use its own temporary directory logic.
    *   `PEEKABOO_CONSOLE_LOGGING`: For development.
    *   `PEEKABOO_CLI_PATH`: For overriding bundled Swift CLI.
7.  **MCP Tool Overview:**
    *   Brief descriptions of `image`, `analyze`, `list` and their primary purpose.
8.  **Link to Detailed Tool Specification:** A separate `TOOL_API_REFERENCE.md` (generated from or summarizing the Zod schemas and output structures in this document) for users/AI developers needing full schema details.
9.  **Troubleshooting / Support:** Link to GitHub issues.

---

### V. Testing Strategy

Comprehensive testing is crucial for ensuring the reliability and correctness of Peekaboo. The strategy includes unit tests for individual modules, integration tests for component interactions, and end-to-end tests for validating complete user flows.

#### A. Unit Tests

*   **Node.js Server (`src/`)**: Unit tests are written using Jest for utility functions, individual tool handlers (mocking Swift CLI execution and AI provider calls), and schema validation logic. Focus is on isolating and testing specific pieces of logic.
*   **Swift CLI (`peekaboo-cli/`)**: Swift XCTests are used to test individual functions, argument parsing, JSON serialization/deserialization, and core macOS interaction logic (potentially mocking system calls where feasible or testing against known system states).

#### B. Integration Tests

*   **Node.js Server & Swift CLI**: Tests that verify the correct interaction between the Node.js server and the Swift CLI. This involves the Node.js server actually spawning the Swift CLI process and validating that arguments are passed correctly and JSON responses are parsed as expected. These tests might use a real (but controlled) Swift CLI binary.
*   **Node.js Server & AI Providers**: Tests that verify the interaction with AI providers. These would typically involve mocking the AI provider SDKs/APIs to simulate various responses (success, error, specific content) and ensure the Node.js server handles them correctly.

#### C. Path Handling & Error Message Tests

*   **Path Logic Testing**: Comprehensive tests for the enhanced Swift CLI path handling:
    *   **File vs Directory Detection**: Tests validating the logic that determines whether a path is intended as a file or directory.
    *   **Single vs Multiple Capture**: Tests ensuring single screen captures use exact file paths, while multiple captures append identifiers appropriately.
    *   **Auto-Creation**: Tests verifying automatic creation of intermediate directories for both file and directory paths.
    *   **Special Cases**: Tests for edge cases like `.`, `..`, hidden files, unicode characters, and paths with spaces.
    *   **Extension Preservation**: Tests ensuring file extensions are preserved correctly when appending screen/window identifiers.

*   **Enhanced Error Messages**: Tests for the improved error reporting system:
    *   **File Write Errors**: Tests validating detailed error messages for permission denied, missing directories, disk space issues, and generic I/O errors.
    *   **Error Context**: Tests ensuring error messages include helpful guidance for common issues.
    *   **Error Code Consistency**: Tests verifying error codes remain stable and exit codes are consistent.

#### D. End-to-End (E2E) Tests

E2E tests validate the entire system flow from the perspective of an MCP client. They ensure all components work together as expected.

1.  **Setup:**
    *   The test runner will start an instance of the `@steipete/peekaboo-mcp` server.
    *   The environment will be configured appropriately (e.g., `PEEKABOO_AI_PROVIDERS` pointing to mock services or controlled real services, `PEEKABOO_LOG_LEVEL` set for test visibility).
    *   A mock Swift CLI could be used for some scenarios to control its output precisely, or the real Swift CLI for full integration.

2.  **Test Scenarios (Examples):**
    *   **Tool Discovery:** Client sends `ListToolsRequest`, verifies the correct tools (`image`, `analyze`, `list`) and their schemas are returned.
    *   **`image` tool - Screen Capture:**
        *   Call `image` to capture the entire screen and save to a file. Verify the file is created and is a valid image.
        *   Call `image` to capture a specific (test) application's window, save to file, and return data. Verify file creation, image data in response, and correct metadata.
        *   Test different modes (`screen`, `window`, `multi`) and options (`format`, `capture_focus`).
        *   Test error conditions: invalid app name, permissions not granted (if testable in CI environment or via mocks).
    *   **`analyze` tool - Image Analysis:**
        *   Provide a test image and a question. Configure `PEEKABOO_AI_PROVIDERS` to use a mock AI service.
        *   Call `analyze`, verify the mock AI service was called with the correct parameters (image data, question, model).
        *   Verify the mock AI service's response is correctly relayed in the MCP `ToolResponse`.
        *   Test with different AI provider configurations (auto, specific). Test error handling if AI provider is unavailable or returns an error.
    *   **`list` tool - Listing System Items:**
        *   Call `list` for `running_applications`. Verify the structure of the response (may need to mock Swift CLI or run in a controlled environment to get predictable app lists).
        *   Call `list` for `application_windows` of a known (test) application. Verify window details.
        *   Call `list` for `server_status`. Verify the server status string is returned.
        *   Test error conditions: app not found for `application_windows`.

3.  **Tooling:**
    *   E2E tests can be written using a test runner like Jest, combined with a library or custom code to simulate an MCP client (i.e., send JSON-RPC requests and receive responses over stdio if testing against a server started with `StdioServerTransport`).
    *   Assertions will be made on the MCP `ToolResponse` objects and any side effects (e.g., files created, logs written).

4.  **Execution:**
    *   E2E tests are typically run as a separate suite, often in a CI/CD pipeline, as they can be slower and require more setup than unit or integration tests.
