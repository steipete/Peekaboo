# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

To test this project interactive we can use:
`PEEKABOO_AI_PROVIDERS="ollama/llava:latest" npx @modelcontextprotocol/inspector npx -y @steipete/peekaboo-mcp@beta`


## Common Commands

### Building
```bash
# Build TypeScript server
npm run build

# Build Swift CLI only
npm run build:swift

# Build everything (Swift CLI + TypeScript)
npm run build:all

# Build universal Swift binary with optimizations
./scripts/build-swift-universal.sh
```

### Testing
```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:coverage

# Run tests in watch mode
npm run test:watch

# Run Swift tests (CI-compatible tests only)
npm run test:swift

# Run Swift tests with local-only tests (requires test host app)
cd peekaboo-cli
RUN_LOCAL_TESTS=true swift test

# Full integration test suite
npm run test:integration
```

#### Local Testing with Test Host App

For comprehensive testing including actual screenshot functionality:

1. **Open the test host app:**
   ```bash
   cd peekaboo-cli/TestHost
   swift run
   ```

2. **The test host app provides:**
   - Real-time permission status (Screen Recording, Accessibility, CLI availability)
   - Interactive permission prompts
   - Test pattern windows for screenshot validation
   - Log output for debugging

3. **Run local-only tests with the test host running:**
   ```bash
   cd peekaboo-cli
   RUN_LOCAL_TESTS=true swift test --filter LocalIntegration
   ```

4. **Or use Xcode for better debugging:**
   - Open `Package.swift` in Xcode
   - Run the test host app target first
   - Run tests with local environment variable: `RUN_LOCAL_TESTS=true`

**Note:** Local tests require actual system permissions and are designed to work with the test host application for controlled testing scenarios.

### Development
```bash
# Start TypeScript compilation in watch mode
npm run dev

# Run the server directly
npm start

# Clean build artifacts
npm run clean

# Lint Swift code
npm run lint:swift

# Format Swift code
npm run format:swift

# Prepare for release (comprehensive checks)
npm run prepare-release
```

### Testing the MCP server
```bash
# Test with a simple JSON-RPC request
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' | node dist/index.js

# Run the MCP server (after building)
peekaboo-mcp
```

### Using the Swift CLI directly
```bash
# Capture screenshots
./peekaboo-cli/.build/debug/peekaboo image --app "Safari" --path screenshot.png
./peekaboo-cli/.build/debug/peekaboo image --mode frontmost --path screenshot.png

# List applications or windows
./peekaboo-cli/.build/debug/peekaboo list apps --json-output
./peekaboo-cli/.build/debug/peekaboo list windows --app "Finder" --json-output

# Analyze images with AI (NEW)
PEEKABOO_AI_PROVIDERS="openai/gpt-4o" ./peekaboo-cli/.build/debug/peekaboo analyze image.png "What is shown in this image?"
PEEKABOO_AI_PROVIDERS="ollama/llava:latest" ./peekaboo-cli/.build/debug/peekaboo analyze image.png "Describe this screenshot" --json-output

# Use multiple AI providers (auto-selects first available)
PEEKABOO_AI_PROVIDERS="openai/gpt-4o,ollama/llava:latest" ./peekaboo-cli/.build/debug/peekaboo analyze image.png "What application is this?"

# Configuration management (NEW)
./peekaboo-cli/.build/debug/peekaboo config init                    # Create default config file
./peekaboo-cli/.build/debug/peekaboo config show                    # Display current config
./peekaboo-cli/.build/debug/peekaboo config show --effective        # Show merged configuration
./peekaboo-cli/.build/debug/peekaboo config edit                    # Edit config in default editor
./peekaboo-cli/.build/debug/peekaboo config validate                # Validate config syntax
```

## Code Architecture

### Project Structure
- **Node.js MCP Server** (`src/`): TypeScript implementation of the Model Context Protocol server
  - `index.ts`: Main server entry point with MCP initialization
  - `tools/`: Tool implementations (`image.ts`, `analyze.ts`, `list.ts`)
  - `utils/`: Utilities for Swift CLI integration, AI providers, and server status
  - `types/`: Shared TypeScript type definitions

- **Swift CLI** (`peekaboo-cli/`): Native macOS binary for system interactions
  - Handles all screen capture, window management, and application listing
  - **NEW**: Can now analyze images directly using AI providers (OpenAI, Ollama)
  - Outputs structured JSON when called with `--json-output`
  - AI analysis functionality available via the `analyze` command

### Key Design Patterns

1. **Tool Handler Pattern**: Each MCP tool follows a consistent pattern:
   - Validate input with Zod schema
   - Construct Swift CLI command
   - Execute Swift CLI and capture JSON output
   - Parse response and handle errors
   - Return MCP-formatted response

2. **AI Provider Abstraction**: Both the MCP server and Swift CLI support multiple AI providers:
   - Configured via `PEEKABOO_AI_PROVIDERS` environment variable
   - Format: `provider/model,provider/model` (e.g., `ollama/llava:latest,openai/gpt-4o`)
   - Auto-selection tries providers in order until one is available
   - Swift CLI implements providers using native URLSession for HTTP requests
   - Supports OpenAI (requires `OPENAI_API_KEY`) and Ollama (local server)

3. **Error Handling**: Standardized error codes from Swift CLI:
   - `PERMISSION_DENIED_SCREEN_RECORDING`
   - `PERMISSION_DENIED_ACCESSIBILITY`
   - `APP_NOT_FOUND`
   - `AMBIGUOUS_APP_IDENTIFIER`
   - `WINDOW_NOT_FOUND`
   - `CAPTURE_FAILED`
   - `FILE_IO_ERROR`

4. **Logging Strategy**:
   - Uses Pino logger to file (default: `/tmp/peekaboo-mcp.log`)
   - No stdout logging to avoid interfering with MCP protocol
   - Debug logs from Swift CLI captured in JSON `debug_logs` array

### Important Implementation Details

1. **Universal Binary**: The Swift CLI is built as a universal binary (arm64 + x86_64) for maximum compatibility

2. **Permissions**: 
   - Screen Recording permission required for all capture operations
   - Accessibility permission only needed for foreground window focus

3. **Image Capture**: Always excludes window shadows/frames using `CGWindowImageOption.boundsIgnoreFraming`

4. **Fuzzy App Matching**: Swift CLI implements intelligent fuzzy matching for application names

5. **Environment Variables**:
   - `PEEKABOO_AI_PROVIDERS`: Configure AI backends for analysis
   - `PEEKABOO_LOG_LEVEL`: Control logging verbosity (trace, debug, info, warn, error, fatal)
   - `PEEKABOO_DEFAULT_SAVE_PATH`: Default location for captured images
   - `PEEKABOO_CLI_PATH`: Override bundled Swift CLI path
   - `OPENAI_API_KEY`: Required for OpenAI provider
   - `PEEKABOO_OLLAMA_BASE_URL`: Optional Ollama server URL (default: http://localhost:11434)

6. **Configuration File** (NEW):
   - Location: `~/.config/peekaboo/config.json`
   - Format: JSONC (JSON with Comments)
   - Supports environment variable expansion: `${VAR_NAME}`
   - Precedence: CLI args > env vars > config file > defaults
   - Manage with: `peekaboo config` subcommand
   
   Example configuration:
   ```json
   {
     // AI Provider Settings
     "aiProviders": {
       "providers": "openai/gpt-4o,ollama/llava:latest",
       "openaiApiKey": "${OPENAI_API_KEY}",
       "ollamaBaseUrl": "http://localhost:11434"
     },
     
     // Default Settings
     "defaults": {
       "savePath": "~/Desktop/Screenshots",
       "imageFormat": "png",
       "captureMode": "window",
       "captureFocus": "auto"
     },
     
     // Logging
     "logging": {
       "level": "info",
       "path": "~/.config/peekaboo/logs/peekaboo.log"
     }
   }
   ```

7. **Swift CLI AI Analysis Architecture** (NEW):
   - Protocol-based design with `AIProvider` protocol
   - Native URLSession implementation for HTTP requests
   - Built-in JSON encoding/decoding using Codable
   - Async/await support for modern Swift concurrency
   - No external dependencies required

## Common Development Tasks

- When modifying tool schemas, update both the Zod schema in TypeScript and ensure the Swift CLI output matches
- After Swift CLI changes, rebuild with `npm run build:swift` and test JSON output manually
- Use `PEEKABOO_LOG_LEVEL=debug` for detailed debugging during development
- Test permissions by running `./peekaboo list server_status --json-output`
- Test AI analysis with: `PEEKABOO_AI_PROVIDERS="ollama/llava:latest" ./peekaboo analyze screenshot.png "What is this?"`
- When adding new AI providers, implement the `AIProvider` protocol in `peekaboo-cli/Sources/peekaboo/AIProviders/`

## Swift Testing Framework

**IMPORTANT**: This project uses the Swift Testing framework (introduced in Xcode 16), NOT XCTest. When writing or modifying tests:

1. **Use Swift Testing imports and attributes**:
   - Import `Testing` not `XCTest`
   - Use `@Test` attribute for test functions
   - Use `@Suite` for test suites
   - Use `#expect()` and `#require()` macros instead of `XCTAssert`

2. **Key differences from XCTest**:
   - Test discovery: Use `@Test` attribute on any function
   - Suite type: Prefer `struct` over `class` (automatic state isolation)
   - Assertions: `#expect(expression)` and `#require(expression)`
   - Setup/Teardown: Use `init()` and `deinit` (on classes/actors)
   - Async: Simply mark test functions as `async`
   - Parameterized tests: Use `@Test(arguments:)`

3. **Common conversions**:
   - `XCTAssertEqual(a, b)` → `#expect(a == b)`
   - `XCTAssertTrue(x)` → `#expect(x)`
   - `XCTAssertFalse(x)` → `#expect(!x)`
   - `XCTUnwrap(x)` → `try #require(x)`
   - `XCTAssertThrowsError` → `#expect(throws: Error.self) { ... }`

4. **Build Settings**: Ensure test targets have "Enable Testing Frameworks" set to "Yes" in Build Settings

See `/docs/swift-testing-playbook.md` for comprehensive migration guide.