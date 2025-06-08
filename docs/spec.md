## Peekaboo: Full & Final Detailed Specification v1.1.2
https://aistudio.google.com/prompts/1B0Va41QEZz5ZMiGmLl2gDme8kQ-LQPW-

**Project Vision:** Peekaboo is a macOS utility exposed via a Node.js MCP server, enabling AI agents to perform advanced screen captures, image analysis via user-configured AI providers, and query application/window information. The core macOS interactions are handled by a native Swift command-line interface (CLI) named `peekaboo`, which is called by the Node.js server. All image captures automatically exclude window shadows/frames.

**Core Components:**

1.  **Node.js/TypeScript MCP Server (`peekaboo-mcp`):**
    *   **NPM Package Name:** `peekaboo-mcp`.
    *   **GitHub Project Name:** `peekaboo`.
    *   Implements MCP server logic using the latest stable `@modelcontextprotocol/sdk`.
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
    *   The `peekaboo` binary is bundled at the root of the `peekaboo-mcp` NPM package.

---

### I. Node.js/TypeScript MCP Server (`peekaboo-mcp`)

#### A. Project Setup & Distribution

1.  **Language/Runtime:** Node.js (latest LTS recommended, e.g., v18+ or v20+), TypeScript (latest stable, e.g., v5+).
2.  **Package Manager:** NPM.
3.  **`package.json`:**
    *   `name`: `"peekaboo-mcp"`
    *   `version`: Semantic versioning (e.g., `1.1.1`).
    *   `type`: `"module"` (for ES Modules).
    *   `main`: `"dist/index.js"` (compiled server entry point).
    *   `bin`: `{ "peekaboo-mcp": "dist/index.js" }`.
    *   `files`: `["dist/", "peekaboo"]` (includes compiled JS and the Swift `peekaboo` binary at package root).
    *   `scripts`:
        *   `build`: Command to compile TypeScript (e.g., `tsc`).
        *   `start`: `node dist/index.js`.
        *   `prepublishOnly`: `npm run build`.
    *   `dependencies`: `@modelcontextprotocol/sdk` (latest stable), `zod` (for input validation), `pino` (for logging), `openai` (for OpenAI API interaction). Support for other AI providers like Anthropic (e.g., using `@anthropic-ai/sdk`) is planned.
    *   `devDependencies`: `typescript`, `@types/node`, `pino-pretty` (for optional development console logging).
4.  **Distribution:** Published to NPM. Installable via `npm i -g peekaboo-mcp` or usable with `npx peekaboo-mcp`.
5.  **Swift CLI Location Strategy:**
    *   The Node.js server will first check the environment variable `PEEKABOO_CLI_PATH`. If set and points to a valid executable, that path will be used.
    *   If `PEEKABOO_CLI_PATH` is not set or invalid, the server will fall back to a bundled path, resolved relative to its own script location (e.g., `path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'peekaboo')`, assuming the compiled server script is in `dist/` and `peekaboo` binary is at the package root).

#### B. Server Initialization & Configuration (`src/index.ts`)

1.  **Imports:** `McpServer`, `StdioServerTransport` from `@modelcontextprotocol/sdk`; `pino` from `pino`; `os`, `path` from Node.js built-ins.
2.  **Server Info:** `name: "PeekabooMCP"`, `version: <package_version from package.json>`.
3.  **Server Capabilities:** Advertise `tools` capability.
4.  **Logging (Pino):**
    *   Instantiate `pino` logger.
    *   **Default Transport:** File transport to `path.join(os.tmpdir(), 'peekaboo-mcp.log')`. Use `mkdir: true` option for destination.
    *   **Log Level:** Controlled by ENV VAR `PEEKABOO_LOG_LEVEL` (standard Pino levels: `trace`, `debug`, `info`, `warn`, `error`, `fatal`). Default: `"info"`.
    *   **Conditional Console Logging (Development Only):** If ENV VAR `PEEKABOO_MCP_CONSOLE_LOGGING="true"`, add a second Pino transport targeting `process.stderr.fd` (potentially using `pino-pretty` for human-readable output).
    *   **Strict Rule:** All server operational logging must use the configured Pino instance. No direct `console.log/warn/error` that might output to `stdout`.
5.  **Environment Variables (Read by Server):**
    *   `PEEKABOO_AI_PROVIDERS`: Comma-separated list of `provider_name/default_model_for_provider` pairs (e.g., `"openai/gpt-4o,ollama/qwen2.5vl:7b"`). Currently, recognized `provider_name` values are `"openai"` and `"ollama"`. Support for `"anthropic"` is planned. If unset/empty, `analyze` tool reports AI not configured.
    *   `OPENAI_API_KEY`: API key for OpenAI.
    *   `ANTHROPIC_API_KEY`: API key for Anthropic (used for future planned support).
    *   (Other cloud provider API keys as standard ENV VAR names).
    *   `PEEKABOO_OLLAMA_BASE_URL`: Base URL for local Ollama instance. Default: `"http://localhost:11434"`.
    *   `PEEKABOO_LOG_LEVEL`: For Pino logger. Default: `"info"`.
    *   `PEEKABOO_LOG_FILE`: Path to the server's log file. Default: `path.join(os.tmpdir(), 'peekaboo-mcp.log')`.
    *   `PEEKABOO_DEFAULT_SAVE_PATH`: Default base absolute path for saving images captured by `image` if not specified in the tool input. If this ENV is also not set, the Swift CLI will use its own temporary directory logic.
    *   `PEEKABOO_CONSOLE_LOGGING`: Boolean (`"true"`/`"false"`) for dev console logs. Default: `"false"`.
    *   `PEEKABOO_CLI_PATH`: Optional override for Swift `peekaboo` CLI path.
6.  **Server Status Reporting Logic:**
    *   A utility function `generateServerStatusString()` creates a formatted string: `"

--- Peekaboo MCP Server Status ---
Name: PeekabooMCP
Version: <server_version>
Configured AI Providers (from PEEKABOO_AI_PROVIDERS ENV): <parsed list or 'None Configured. Set PEEKABOO_AI_PROVIDERS ENV.'>
---"`.
    *   **Tool Descriptions:** When the server handles a `ListToolsRequest` (typically at client initialization), it appends the `generateServerStatusString()` output to the `description` field of each advertised tool (`image`, `analyze`, `list`). This provides clients with immediate server status information alongside tool capabilities.
    *   **Direct Access via `list` tool:** The server status string can also be retrieved directly by calling the `list` tool with `item_type: "server_status"` (see Tool 3 details).
7.  **Tool Registration:** Register `image`, `analyze`, `list` with their Zod input schemas and handler functions.
8.  **Transport:** `await server.connect(new StdioServerTransport());`.
9.  **Shutdown:** Implement graceful shutdown on `SIGINT`, `SIGTERM` (e.g., `await server.close(); logger.flush(); process.exit(0);`).

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

**Tool 1: `image`**

*   **MCP Description:** "Captures macOS screen content and optionally analyzes it. Targets can be the entire screen (each display separately), a specific application window, or all windows of an application, controlled by `app_target`. Supports foreground/background capture. Captured image(s) can be saved to a file (`path`), returned as Base64 data (`format: \"data\"`), or both. If a `question` is provided, the captured image is analyzed by an AI model chosen automatically from `PEEKABOO_AI_PROVIDERS`. Window shadows/frames are excluded."
*   **MCP Input Schema (`ImageInputSchema`):**
    ```typescript
    z.object({
      app_target: z.string().optional().describe(
        "Optional. Specifies the capture target. Examples:\\n" +
        "- Omitted/empty: All screens.\\n" +
        "- 'screen:INDEX': Specific display (e.g., 'screen:0').\\n" +
        "- 'frontmost': All windows of the current foreground app.\\n" +
        "- 'AppName': All windows of 'AppName'.\\n" +
        "- 'AppName:WINDOW_TITLE:Title': Window of 'AppName' with 'Title'.\\n" +
        "- 'AppName:WINDOW_INDEX:Index': Window of 'AppName' at 'Index'."
      ),
      path: z.string().optional().describe(
        "Optional. Base absolute path for saving captured image(s). If this path points to a directory, the Swift CLI will generate unique filenames inside it. If this path is omitted, behavior depends on other parameters: if a 'question' is asked or 'format' is 'data', a temporary directory is created for the capture and cleaned up afterward. Otherwise, if the 'PEEKABOO_DEFAULT_SAVE_PATH' environment variable is set, it will be used. As a final fallback, a temporary directory will be created and the saved file path(s) will be returned in the 'saved_files' output."
      ),
      question: z.string().optional().describe(
        "Optional. If provided, the captured image will be analyzed. " +
        "The server automatically selects an AI provider from 'PEEKABOO_AI_PROVIDERS'."
      ),
      format: z.enum(["png", "jpg", "data"]).optional().default("png").describe(
        "Output format. 'png' or 'jpg' save to 'path' (if provided). " +
        "'data' returns Base64 encoded PNG data inline; if 'path' is also given, saves a PNG file to 'path' too. " +
        "If 'path' is not given, 'format' defaults to 'data' behavior (inline PNG data returned)."
      ),
      capture_focus: z.enum(["background", "foreground"])
        .optional().default("background").describe(
          "Optional. Focus behavior. 'background' (default): capture without altering window focus. " +
          "'foreground': bring target to front before capture."
        )
    })
    ```
    *   **Node.js Handler - `app_target` Parsing:** The handler will parse `app_target` to determine the Swift CLI arguments for `--app`, `--mode`, `--window-title`, or `--window-index`.
        *   Omitted/empty `app_target`: maps to Swift CLI `--mode screen` (no `--app`).
        *   `"screen:INDEX"`: maps to Swift CLI `--mode screen --screen-index INDEX` (custom Swift CLI flag might be needed or logic to select from multi-screen capture).
        *   `"frontmost"`: Node.js determines frontmost app (e.g., via `list` tool logic or new Swift CLI helper), then calls Swift CLI with that app and `--mode multi` (or `window` for main window).
        *   `"AppName"`: maps to Swift CLI `--app AppName --mode multi`.
        *   `"AppName:WINDOW_TITLE:Title"`: maps to Swift CLI `--app AppName --mode window --window-title Title`.
        *   `"AppName:WINDOW_INDEX:Index"`: maps to Swift CLI `--app AppName --mode window --window-index Index`.
    *   **Node.js Handler - `format` and `path` Logic:**
        *   If `input.format === "data"`: `return_data` becomes effectively true. If `input.path` is also set, the image is saved to `input.path` (as PNG) AND Base64 PNG data is returned.
        *   If `input.format` is `"png"` or `"jpg"`:
            *   If `input.path` is provided, the image is saved to `input.path` with the specified format. No Base64 data is returned unless `input.question` is also provided (for analysis).
            *   If `input.path` is NOT provided: This implies `format: "data"` behavior; Base64 PNG data is returned.
        *   If `input.question` is provided:
            *   An `effectivePath` is determined (user's `input.path` or a temp path).
            *   Image is captured to `effectivePath`.
            *   Analysis proceeds as described below.
            *   Base64 data is NOT returned in `content` due to analysis, but `analysis_text` is.
    *   **Node.js Handler - Analysis Logic (if `input.question` is provided):**
        *   An `effectivePath` is determined (user's `input.path` or a temp path).
        *   Swift CLI is called to capture one or more images and save them to `effectivePath`.
        *   The handler then iterates through **every** saved image file.
        *   For each image, the file is read into a base64 string.
        *   The AI provider and model are determined automatically by iterating through `PEEKABOO_AI_PROVIDERS`.
        *   The image (base64) and `input.question` are sent to the chosen AI provider for analysis.
        *   If multiple images are analyzed, the final `analysis_text` in the response is a single formatted string, with each analysis result preceded by a header identifying the corresponding window/display.
        *   If a temporary path was used, all captured image files and the directory are deleted after all analyses are complete.
        *   The `analysis_text` and `model_used` are added to the tool's response.
        *   Base64 image data (`data` field in `ImageContentItem`) is *not* included in the `content` array of the response when a `question` is asked.
    *   **Node.js Handler - Resilience with `path` and `format: "data"` (No `question`):** If `input.format === "data"`, `input.question` is NOT provided, and `input.path` is specified:
        *   The handler will still attempt to process and return Base64 image data for successfully captured images even if the Swift CLI (or the handler itself) encounters an error saving to or reading from the user-specified `input.path` (or paths derived from it).
        *   In such cases where image data is returned despite a save-to-path failure, a `TextContentItem` containing a "Peekaboo Warning:" message detailing the path saving issue will be included in the `ToolResponse.content`.
*   **MCP Output Schema (`ToolResponse`):**
    *   `content`: `Array<ImageContentItem | TextContentItem>`
        *   If `input.format === "data"` (or `path` was omitted, defaulting to "data" behavior) AND `input.question` is NOT provided: Contains one or more `ImageContentItem`(s): `{ type: "image", data: "<base64_png_string_no_prefix>", mimeType: "image/png", metadata?: { item_label?: string, window_title?: string, window_id?: number, source_path?: string } }`.
        *   If `input.question` IS provided, `ImageContentItem`s with base64 image data are NOT added to `content`.
        *   Always contains `TextContentItem`(s) (summary, file paths from `saved_files` if applicable and images were saved to persistent paths, Swift CLI `messages`, and analysis results if a `question` was asked).
    *   `saved_files`: `Array<{ path: string, item_label?: string, window_title?: string, window_id?: number, mime_type: string }>`
        *   Populated if `input.path` was provided (and not a temporary path for analysis that got deleted). The `mime_type` will reflect `input.format` if it was 'png' or 'jpg' and saved, or 'image/png' if `format: "data"` also saved a file.
        *   If `input.question` is provided AND `input.path` was NOT specified (temp image used and deleted): This array will be empty.
    *   `analysis_text?: string`: (Conditionally present if `input.question` was provided) Core AI answer or error/skip message.
    *   `model_used?: string`: (Conditionally present if analysis was successful) e.g., "ollama/llava:7b", "openai/gpt-4o".
    *   `isError?: boolean` (Can be true if capture fails, or if analysis is attempted but fails, even if capture succeeded).
    *   `_meta?: { backend_error_code?: string, analysis_error?: string }` (For relaying Swift CLI error codes or analysis error messages).

**Tool 2: `analyze`**

*   **MCP Description:** "Analyzes an image file using a configured AI model (local Ollama, cloud OpenAI, etc.) and returns a textual analysis/answer. Requires image path. AI provider selection and model defaults are governed by the server's `AI_PROVIDERS` environment variable and client overrides."
*   **MCP Input Schema (`AnalyzeInputSchema`):**
    ```typescript
    z.object({
      image_path: z.string().describe("Required. Absolute path to image file (.png, .jpg, .webp) to be analyzed."),
      question: z.string().describe("Required. Question for the AI about the image."),
      provider_config: z.object({
        type: z.enum(["auto", "ollama", "openai" /* "anthropic" is planned */])
          .default("auto")
          .describe("AI provider. 'auto' uses server's PEEKABOO_AI_PROVIDERS ENV preference. Specific provider must be one of the currently implemented options ('ollama', 'openai') and enabled in server's PEEKABOO_AI_PROVIDERS."),
        model: z.string().optional().describe("Optional. Model name. If omitted, uses model from server's AI_PROVIDERS for chosen provider, or an internal default for that provider.")
      }).optional().describe("Optional. Explicit provider/model. Validated against server's PEEKABOO_AI_PROVIDERS.")
    })
    ```
*   **Node.js Handler Logic:**
    1.  Validate input. Server pre-checks `image_path` extension (`.png`, `.jpg`, `.jpeg`, `.webp`); return MCP error if not recognized.
    2.  Read `process.env.PEEKABOO_AI_PROVIDERS`. If unset/empty, return MCP error "AI analysis not configured on this server. Set the PEEKABOO_AI_PROVIDERS environment variable." Log this with Pino (`error` level).
    3.  Parse `PEEKABOO_AI_PROVIDERS` into `configuredItems = [{provider: string, model: string}]`.
    4.  **Determine Provider & Model:**
        *   `requestedProviderType = input.provider_config?.type || "auto"`.
        *   `requestedModelName = input.provider_config?.model`.
        *   `chosenProvider: string | null = null`, `chosenModel: string | null = null`.
        *   If `requestedProviderType !== "auto"`:
            *   Find entry in `configuredItems` where `provider === requestedProviderType`.
            *   If not found, MCP error: "Provider '{requestedProviderType}' is not enabled in server's PEEKABOO_AI_PROVIDERS configuration."
            *   `chosenProvider = requestedProviderType`.
            *   `chosenModel = requestedModelName || model_from_matching_configuredItem || hardcoded_default_for_chosenProvider`.
        *   Else (`requestedProviderType === "auto"`):
            *   Iterate `configuredItems` in order. For each `{provider, modelFromEnv}`:
                *   Check availability (Ollama up? Cloud API key for `provider` set in `process.env`?).
                *   If available: `chosenProvider = provider`, `chosenModel = requestedModelName || modelFromEnv`. Break.
            *   If no provider found after iteration, MCP error: "No configured AI providers in PEEKABOO_AI_PROVIDERS are currently operational."
    5.  **Execute Analysis (Node.js handles all AI calls):**
        *   Read `input.image_path` into a `Buffer`. Base64 encode.
        *   If `chosenProvider` is "ollama": Make direct HTTP POST calls to the Ollama API (e.g., `/api/generate`) using `process.env.PEEKABOO_OLLAMA_BASE_URL`. Handle Ollama API errors.
        *   If `chosenProvider` is "openai": Use the official `openai` Node.js SDK with Base64 image, `input.question`, `chosenModel`, and API key from `process.env.OPENAI_API_KEY`. Handle OpenAI API errors.
        *   If `chosenProvider` is "anthropic": (Currently not implemented) This would involve using the Anthropic SDK and API key from `process.env.ANTHROPIC_API_KEY`. For now, attempting to use Anthropic will result in an error.
    6.  Construct MCP `ToolResponse`.
*   **MCP Output Schema (`ToolResponse`):**
    *   `content`: `[{ type: "text", text: "<AI's analysis/answer>" }, { type: "text", text: "👻 Peekaboo: Analyzed image with <provider>/<model> in X.XXs." }]` (The second text item provides feedback on the analysis process).
    *   `analysis_text`: `string` (Core AI answer).
    *   `model_used`: `string` (e.g., "ollama/llava:7b", "openai/gpt-4o") - The actual provider/model pair used.
    *   `isError?: boolean`
    *   `_meta?: { backend_error_code?: string }` (For AI provider API errors).

**Tool 3: `list`**

*   **MCP Description:** "Lists system items: running applications, all windows of a specific app, or server status. App ID uses fuzzy matching."
*   **MCP Input Schema (`ListInputSchema`):**
    ```typescript
    z.object({
      item_type: z.enum(["running_applications", "application_windows", "server_status", ""])
        .optional()
        .describe(
          "Specifies the type of items to list. If omitted or empty, it defaults to 'application_windows' if 'app' is provided, otherwise 'running_applications'. Valid options are:\\n" +
          "- `running_applications`: Lists all currently running applications.\\n" +
          "- `application_windows`: Lists open windows for a specific application. Requires the `app` parameter.\\n" +
          "- `server_status`: Returns information about the Peekaboo MCP server."
        ),
      app: z.string().optional().describe(
        "Specifies the target application by name (e.g., \\"Safari\\", \\"TextEdit\\") or bundle ID. " +
        "Required when `item_type` is explicitly 'application_windows'. " +
        "Fuzzy matching is used."
      ),
      include_window_details: z.array(
        z.enum(["ids", "bounds", "off_screen"])
      ).optional().describe("Optional, for 'application_windows' only. Specifies additional details for each window. If provided for other 'item_type' values, it will be ignored only if it is an empty array.")
    }).refine(data => data.item_type !== "application_windows" || (data.app !== undefined && data.app.trim() !== ""), {
      message: "'app' identifier is required when 'item_type' is 'application_windows'.", path: ["app"],
    }).refine(data => !data.include_window_details || data.include_window_details.length === 0 || data.item_type === "application_windows", {
      message: "'include_window_details' is only applicable when 'item_type' is 'application_windows'.",
      path: ["include_window_details"]
    })
    ```
*   **Node.js Handler Logic:**
    1.  **Determine effective `item_type`:** If `input.item_type` is missing or empty, the handler sets a default: if `input.app` is provided, `item_type` becomes `"application_windows"`; otherwise, it becomes `"running_applications"`.
    2.  Validate the (now effective) input against the tool's Zod schema.
    3.  If `effective_item_type === "server_status"`, the handler generates and returns the server status string directly without calling the Swift CLI.
    4.  Otherwise, construct command-line arguments for Swift `peekaboo` CLI based on the effective input.
    5.  Execute Swift CLI and process the response as described in the general handler pattern.
*   **MCP Output Schema (`ToolResponse`):**
    *   `content`: `Array<TextContentItem>` containing a formatted list of the requested items or the server status.
    *   If `item_type: "running_applications"`: `application_list`: `Array<{ app_name: string; bundle_id: string; pid: number; is_active: boolean; window_count: number }>`.
    *   If `item_type: "application_windows"`:
        *   `window_list`: `Array<{ window_title: string; window_id?: number; window_index?: number; bounds?: {x:number,y:number,w:number,h:number}; is_on_screen?: boolean }>`.
        *   `target_application_info`: `{ app_name: string; bundle_id?: string; pid: number }`.
    *   `isError?: boolean`
    *   `_meta?: { backend_error_code?: string }`

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
    *   The resulting universal binary (e.g., from `.build/apple/Products/Release/peekaboo`) is copied to the root of the `peekaboo-mcp` NPM package directory before publishing.
2.  **Node.js MCP Server:**
    *   TypeScript is compiled to JavaScript (e.g., into `dist/`) using `tsc`.
    *   The NPM package includes `dist/` and the `peekaboo` Swift binary (at package root).

---

### IV. Documentation (`README.md` for `peekaboo-mcp` NPM Package)

1.  **Project Overview:** Briefly state vision and components.
2.  **Prerequisites:**
    *   macOS version (e.g., 12.0+ or as required by Swift/APIs).
    *   Xcode Command Line Tools (recommended for a stable development environment on macOS, even if not strictly used by the final Swift binary for all operations).
    *   Ollama (if using local Ollama for analysis) + instructions to pull models.
3.  **Installation:**
    *   Primary: `npm install -g peekaboo-mcp`.
    *   Alternative: `npx peekaboo-mcp`.
4.  **MCP Client Configuration:**
    *   Provide example JSON snippets for configuring popular MCP clients (e.g., VS Code, Cursor) to use `peekaboo-mcp`.
    *   Example for VS Code/Cursor using `npx` for robustness:
        ```json
        {
          "mcpServers": {
            "PeekabooMCP": {
              "command": "npx",
              "args": ["peekaboo-mcp"],
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
6.  **Environment Variables (for Node.js `peekaboo-mcp` server):**
    *   `PEEKABOO_AI_PROVIDERS`: Crucial for `analyze`. Explain format (`provider/model,provider/model`), effect, and that `analyze` reports "not configured" if unset. List recognized `provider` names ("ollama", "openai").
    *   `OPENAI_API_KEY` (and similar for other cloud providers): How they are used.
    *   `PEEKABOO_OLLAMA_BASE_URL`: Default and purpose.
    *   `PEEKABOO_LOG_LEVEL`: For `pino` logger. Values and default.
    *   `PEEKABOO_LOG_FILE`: Path to the server's log file. Default: `path.join(os.tmpdir(), 'peekaboo-mcp.log')`.
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
    *   The test runner will start an instance of the `peekaboo-mcp` server.
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
