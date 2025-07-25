# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

To test this project interactive we can use:
`PEEKABOO_AI_PROVIDERS="ollama/llava:latest" npx @modelcontextprotocol/inspector npx -y @steipete/peekaboo-mcp@beta`

## Recent Updates

- **Playground test app created** (2025-01-24): Added comprehensive SwiftUI test application at `Playground/` for testing all Peekaboo automation features. Includes its own logging utility `playground-log.sh` based on vtlog. See the "Playground Test App" section below.

- **vtlog utility added** (2025-01-07): Adopted the vtlog logging utility from the VibeTunnel project. The script is located at `scripts/vtlog.sh` and provides easy access to PeekabooInspector's unified logging output. See the "Debugging with vtlog" section below for usage.

- **Unified configuration directory** (2025-01-07): Migrated from `~/.config/peekaboo/` to `~/.peekaboo/` for better discoverability. API keys are now stored separately in `~/.peekaboo/credentials` with proper permissions (chmod 600). Automatic migration happens on first run.


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

### Building

#### Workspace Structure
The project uses an Xcode workspace that includes multiple projects:
- **Apps/Peekaboo.xcworkspace** - Main workspace containing:
  - Apps/Mac/Peekaboo.xcodeproj (Mac app)
  - Apps/CLI (Swift Package)
  - Core/PeekabooCore (Swift Package)
  - Core/AXorcist (Swift Package)

```bash
# Open the workspace (recommended)
open Apps/Peekaboo.xcworkspace

# Build everything from command line
xcodebuild -workspace Apps/Peekaboo.xcworkspace -scheme Peekaboo -configuration Debug build

# Run the Mac app
xcodebuild -workspace Apps/Peekaboo.xcworkspace -scheme Peekaboo -configuration Debug build && \
  open ~/Library/Developer/Xcode/DerivedData/Peekaboo-*/Build/Products/Debug/Peekaboo.app
```

#### Building Individual Components

**PeekabooCore Library**
```bash
cd Core/PeekabooCore
swift build
swift test
```

**AXorcist Library**
```bash
cd Core/AXorcist
swift build
swift test
```

**CLI Tool**
```bash
cd Apps/CLI
swift build
# Or use npm scripts from root:
npm run build:swift
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

# Configuration management (UPDATED)
./peekaboo-cli/.build/debug/peekaboo config init                    # Create default config file
./peekaboo-cli/.build/debug/peekaboo config show                    # Display current config
./peekaboo-cli/.build/debug/peekaboo config show --effective        # Show merged configuration
./peekaboo-cli/.build/debug/peekaboo config edit                    # Edit config in default editor
./peekaboo-cli/.build/debug/peekaboo config validate                # Validate config syntax
./peekaboo-cli/.build/debug/peekaboo config set-credential KEY VALUE # Set API key securely
```

## Code Architecture

### Project Structure

The Peekaboo project is organized into multiple components:

#### Core Libraries

- **PeekabooCore** (`Core/PeekabooCore/`): Shared service layer for all Peekaboo apps
  - `Services/`: Service protocols and implementations
    - `PeekabooServices.swift`: Main service container providing unified access
    - `Implementations/`: Concrete service implementations
    - `Protocols/`: Service interfaces for dependency injection
  - `AI/`: AI provider implementations (OpenAI, Ollama)
  - `Models/`: Shared data models
  - `Configuration/`: Configuration management
  - **Key Feature**: Direct API access without CLI subprocess spawning

- **AXorcist** (`Core/AXorcist/`): macOS accessibility library
  - Modern Swift wrapper around Accessibility APIs
  - Type-safe attribute access and window manipulation
  - Used by PeekabooCore for all UI automation

#### Applications

- **Mac App** (`Apps/Mac/`): Native macOS application
  - Uses PeekabooCore services directly (no CLI subprocess calls)
  - Features: Inspector mode, agent integration, status bar control
  - Built with SwiftUI and modern macOS APIs

- **CLI** (`Apps/CLI/`): Command-line interface
  - Standalone tool for terminal usage
  - Implements same functionality as PeekabooCore services
  - Outputs structured JSON when called with `--json-output`
  - Being migrated to use PeekabooCore internally

- **MCP Server** (`src/`): TypeScript Model Context Protocol server
  - `index.ts`: Main server entry point
  - `tools/`: MCP tool implementations
  - Currently uses CLI subprocess calls (migration to PeekabooCore planned)

### PeekabooCore Service Architecture

PeekabooCore provides a unified service layer that all Peekaboo applications can use:

```swift
// Access all services through PeekabooServices
let services = PeekabooServices.shared

// Screen capture
let result = try await services.screenCapture.captureFrontmost()

// UI automation
try await services.automation.click(
    target: .text("Submit"),
    sessionId: sessionId
)

// Window management
try await services.windows.resizeWindow(
    appIdentifier: "Safari",
    size: CGSize(width: 1200, height: 800)
)
```

**Available Services:**
- `screenCapture`: Screen and window capture operations
- `applications`: Application and window queries
- `automation`: Click, type, scroll, and other UI automation
- `windows`: Window positioning, resizing, and management
- `menu`: Menu bar interaction
- `dock`: Dock manipulation
- `dialogs`: Dialog detection and interaction
- `sessions`: Element detection session management
- `files`: File system operations
- `configuration`: Configuration management
- `process`: Process and script execution

**Benefits:**
- No subprocess spawning overhead
- Type-safe Swift APIs
- Shared across all Peekaboo apps
- Testable with protocol-based design
- Consistent error handling

### Key Design Patterns

1. **Service Protocol Pattern**: Each service has a protocol for easy testing and mocking:
   ```swift
   public protocol ScreenCaptureServiceProtocol {
       func captureScreen(displayIndex: Int?) async throws -> CaptureResult
       func captureWindow(appIdentifier: String, windowIndex: Int?) async throws -> CaptureResult
       // ...
   }
   ```

2. **Tool Handler Pattern**: Each MCP tool follows a consistent pattern:
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

6. **Configuration Files** (UPDATED):
   - Config directory: `~/.peekaboo/`
   - Config file: `~/.peekaboo/config.json` (JSONC format with comments)
   - Credentials: `~/.peekaboo/credentials` (key=value format, chmod 600)
   - Supports environment variable expansion: `${VAR_NAME}` in config.json
   - Precedence: CLI args > env vars > credentials file > config file > defaults
   - Manage with: `peekaboo config` subcommand
   
   Example configuration:
   ```json
   {
     // AI Provider Settings
     "aiProviders": {
       "providers": "openai/gpt-4o,ollama/llava:latest",
       // NOTE: API keys should be in ~/.peekaboo/credentials or env vars
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
       "path": "~/.peekaboo/logs/peekaboo.log"
     }
   }
   ```
   
   Example credentials file:
   ```
   # ~/.peekaboo/credentials (chmod 600)
   OPENAI_API_KEY=sk-...
   ANTHROPIC_API_KEY=sk-ant-...
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
- Store API keys securely: `./peekaboo config set-credential OPENAI_API_KEY sk-...`
- Check effective configuration: `./peekaboo config show --effective`
- Migration: Old configs in `~/.config/peekaboo/` are auto-migrated to `~/.peekaboo/` on first run

## Service Architecture Migration

The project has undergone a major architectural change to improve performance and code reuse:

### Migration Overview (Completed January 2025)

**Before**: Mac app → spawns CLI subprocess → performs operation → returns JSON
**After**: Mac app → calls PeekabooCore service directly → returns Swift types

This migration eliminates:
- Process spawning overhead
- JSON serialization/deserialization
- String-based error handling
- Subprocess management complexity

### Migration Status

✅ **Completed:**
- Mac app fully migrated to PeekabooCore services
- All CLI commands now have equivalent service implementations
- AXorcist library enhanced with additional UI automation capabilities
- Service protocol architecture established

🚧 **In Progress:**
- CLI tool migration to use PeekabooCore internally
- MCP server migration from CLI subprocess to PeekabooCore

### Using PeekabooCore in Your Code

```swift
import PeekabooCore

// Old way (subprocess)
let process = Process()
process.executableURL = URL(fileURLWithPath: cliPath)
process.arguments = ["image", "--mode", "frontmost", "--json-output"]
// ... handle process execution, JSON parsing, etc.

// New way (direct service call)
let services = PeekabooServices.shared
let result = try await services.screenCapture.captureFrontmost()
// result is a strongly-typed CaptureResult
```

### Benefits for Developers
- **Performance**: ~10x faster operations without subprocess overhead
- **Type Safety**: Swift types instead of JSON parsing
- **Error Handling**: Structured errors instead of string parsing
- **Testing**: Easy to mock services with protocols
- **Code Reuse**: Same services across Mac app, CLI, and future apps

## AXorcist Integration

This project relies heavily on the **AXorcist** library for macOS accessibility features. When working with window manipulation, UI element interaction, or any accessibility-related functionality:

1. **Always use AXorcist APIs** rather than raw accessibility APIs
2. **We can modify AXorcist** - If you encounter limitations or need additional functionality, feel free to enhance the AXorcist library directly
3. **Key AXorcist patterns**:
   - Use `Element` wrapper instead of raw `AXUIElement`
   - Use typed attributes like `Attribute<String>.title` instead of string constants
   - Use enum-based actions like `.performAction(.press)` for cleaner code
   - All Element methods are `@MainActor` - ensure your code respects this

4. **Window Manipulation** (NEW):
   - The `window` command provides comprehensive window control
   - Supports close, minimize, maximize, move, resize, and focus operations
   - Can target windows by app name, window title, or index
   - Uses AXorcist's window manipulation methods like `setPosition()`, `setSize()`, `setMinimized()`, etc.

5. **Common AXorcist usage**:
   ```swift
   // Get windows for an app
   let axApp = AXUIElementCreateApplication(app.processIdentifier)
   let appElement = Element(axApp)
   let windows = appElement.windows() ?? []
   
   // Manipulate windows
   window.setPosition(CGPoint(x: 100, y: 100))
   window.setSize(CGSize(width: 800, height: 600))
   window.setMinimized(true)
   
   // Perform actions
   if let closeButton = window.closeButton() {
       try closeButton.performAction(.press)
   }
   ```

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

## Debugging with vtlog

The PeekabooInspector app uses macOS unified logging system. We provide a convenient `vtlog` script to simplify log access.

### Quick Start with vtlog

The `vtlog` script is located at `scripts/vtlog.sh`. It's designed to be context-friendly by default.

**Default behavior: Shows last 50 lines from the past 5 minutes**

```bash
# Show recent logs (default: last 50 lines from past 5 minutes)
./scripts/vtlog.sh

# Stream logs continuously (like tail -f)
./scripts/vtlog.sh -f

# Show only errors
./scripts/vtlog.sh -e

# Show more lines
./scripts/vtlog.sh -n 100

# View logs from different time range
./scripts/vtlog.sh -l 30m

# Filter by category
./scripts/vtlog.sh -c OverlayManager

# Search for specific text
./scripts/vtlog.sh -s "element selected"
```

### Common Use Cases

```bash
# Quick check for recent errors (context-friendly)
./scripts/vtlog.sh -e

# Debug overlay issues
./scripts/vtlog.sh -c OverlayManager -n 100

# Watch logs in real-time while testing
./scripts/vtlog.sh -f

# Find accessibility problems
./scripts/vtlog.sh -s "AXError" -l 2h

# Export comprehensive debug logs
./scripts/vtlog.sh -d -l 1h --all -o ~/Desktop/peekaboo-debug.log

# Get all logs without tail limit
./scripts/vtlog.sh --all
```

### Available Categories (PeekabooInspector)
- **OverlayManager** - UI overlay management and element tracking
- **OverlayView** - Individual overlay window rendering
- **InspectorView** - Main inspector UI
- **AppOverlayView** - Application-specific overlay views

### Manual Log Commands

If you prefer using the native `log` command directly:

```bash
# Stream logs
log stream --predicate 'subsystem == "com.steipete.PeekabooInspector"' --level info

# Show historical logs
log show --predicate 'subsystem == "com.steipete.PeekabooInspector"' --info --last 30m

# Filter by category
log stream --predicate 'subsystem == "com.steipete.PeekabooInspector" AND category == "OverlayManager"'
```

### Tips
- Run `./scripts/vtlog.sh --help` for full documentation
- Use `-d` flag for debug-level logs during development
- The app logs persist after the app quits, useful for crash debugging
- Add `--json` for machine-readable output

### Note on CLI Logging
The Peekaboo CLI tool currently uses custom file-based logging (not unified logging). CLI logs are:
- Written to stderr in normal mode
- Collected in JSON output when using `--json-output`
- Controlled by `PEEKABOO_LOG_LEVEL` environment variable

## Mac App Architecture

The Peekaboo Mac app is a modern SwiftUI application that showcases the full capabilities of PeekabooCore:

### Key Features
- **Inspector Mode**: Visual overlay for identifying UI elements
- **Agent Integration**: OpenAI-powered automation with real-time event streaming
- **Status Bar Control**: Quick access from the menu bar
- **Session Management**: Track and replay automation sessions

### Architecture Overview

```swift
// Main app entry point
@main
struct PeekabooApp: App {
    @StateObject private var statusBarController = StatusBarController()
    
    var body: some Scene {
        // Main window
        WindowGroup {
            MainWindow()
        }
        
        // Settings window
        Settings {
            SettingsWindow()
        }
    }
}
```

### Service Integration

The Mac app uses PeekabooCore services directly:

```swift
// In PeekabooToolExecutor.swift
class PeekabooToolExecutor {
    private let services = PeekabooServices.shared
    
    func captureScreen() async throws -> CaptureResult {
        return try await services.screenCapture.captureFrontmost()
    }
    
    func performClick(target: String) async throws {
        try await services.automation.click(
            target: .text(target),
            sessionId: currentSessionId
        )
    }
}
```

### Inspector Mode

The Inspector feature provides visual feedback for UI automation:

1. **OverlayManager**: Manages overlay windows for each application
2. **OverlayView**: Renders bounding boxes around UI elements
3. **InspectorView**: Main UI for controlling the inspector

### Agent System

The app includes an OpenAI agent for natural language automation:

- **PeekabooAgent**: Orchestrates tool execution based on user prompts
- **AgentEventStream**: Real-time streaming of agent actions
- **Tool Integration**: Agent can capture screens, click elements, type text, etc.

### Building and Running

```bash
# Open in Xcode (recommended)
open Apps/Peekaboo.xcworkspace

# Build and run
xcodebuild -workspace Apps/Peekaboo.xcworkspace -scheme Peekaboo -configuration Debug build && \
  open ~/Library/Developer/Xcode/DerivedData/Peekaboo-*/Build/Products/Debug/Peekaboo.app

# Run tests
xcodebuild -workspace Apps/Peekaboo.xcworkspace -scheme Peekaboo -configuration Debug test
```

## Playground Test App

The **Playground** directory contains a comprehensive SwiftUI test application specifically designed for testing all Peekaboo automation features. This app provides a controlled environment with various UI elements and interactions that can be automated.

### Features

- **Click Testing**: Various button types, toggles, click areas, context menus
- **Text Input**: Multiple field types, secure fields, multiline editors, special characters
- **UI Controls**: Sliders, checkboxes, radio buttons, steppers, date/color pickers
- **Scroll & Gestures**: Scroll views, swipe/pinch/rotation detection
- **Window Management**: Window controls, positioning, resizing, multiple windows
- **Drag & Drop**: Draggable items, drop zones, reorderable lists
- **Keyboard**: Key detection, modifiers, hotkeys, sequence recording

### Building and Running

```bash
# Build the Playground app
cd Playground
swift build

# Run the app
./.build/debug/Playground
```

### Logging with playground-log.sh

The Playground app includes a dedicated logging utility inspired by vtlog. You can use it directly or via the wrapper script in the project root:

```bash
# From project root (recommended)
./scripts/playground-log.sh

# Or directly from Playground directory
./Playground/scripts/playground-log.sh

# Show recent logs (default: last 50 lines from past 5 minutes)
./scripts/playground-log.sh

# Stream logs continuously (like tail -f)
./scripts/playground-log.sh -f

# Show only errors
./scripts/playground-log.sh -e

# Show logs for specific category
./scripts/playground-log.sh -c Click

# Search for specific text
./scripts/playground-log.sh -s "button clicked"

# Export logs to file
./scripts/playground-log.sh --all -o playground-test.log

# Show available categories
./scripts/playground-log.sh --categories
```

#### Available Categories (Playground)

- **Click** - Button clicks, toggles, click areas
- **Text** - Text input, field changes
- **Menu** - Menu selections, context menus
- **Window** - Window operations
- **Scroll** - Scroll events
- **Drag** - Drag and drop operations
- **Keyboard** - Key presses, hotkeys
- **Focus** - Focus changes
- **Gesture** - Swipes, pinches, rotations
- **Control** - Sliders, pickers, other controls
- **App** - Application events

#### playground-log.sh Features

- **Color-coded output**: Different categories are highlighted in different colors
- **Time-based filtering**: Show logs from specific time ranges (5m, 30m, 1h, etc.)
- **Category filtering**: Focus on specific types of actions
- **Search functionality**: Find specific log entries
- **JSON output**: Machine-readable format for processing
- **File export**: Save logs for analysis
- **Continuous streaming**: Watch logs in real-time

#### Usage Examples

```bash
# Debug click interactions in the last 30 minutes
./scripts/playground-log.sh -c Click -d -l 30m

# Watch keyboard events in real-time
./scripts/playground-log.sh -c Keyboard -f

# Search for specific automation tests
./scripts/playground-log.sh -s "automation" -n 100

# Export comprehensive test session logs
./scripts/playground-log.sh --all -o "test-session-$(date +%Y%m%d-%H%M%S).log"

# Show only error events
./scripts/playground-log.sh -e -l 1h
```

### Testing Automation

Each UI element in the Playground app has:
- Unique accessibility identifiers (e.g., `single-click-button`, `basic-text-field`)
- Proper labeling for element detection
- Clear visual boundaries
- State indicators and feedback

This makes it ideal for testing Peekaboo's automation capabilities in a controlled environment.

## Troubleshooting

### Common Issues and Solutions

#### Permission Errors

**Screen Recording Permission Denied**
```
Error: PERMISSION_DENIED_SCREEN_RECORDING
```
**Solution**: Grant Screen Recording permission in System Settings → Privacy & Security → Screen Recording

**Accessibility Permission Denied**
```
Error: PERMISSION_DENIED_ACCESSIBILITY
```
**Solution**: Grant Accessibility permission in System Settings → Privacy & Security → Accessibility

#### Build Issues

**Swift Package Resolution Failed**
```bash
# Clear package cache
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf .build

# Reset packages in Xcode
open Apps/Peekaboo.xcworkspace
# File → Packages → Reset Package Caches
```

**CLI Build Fails**
```bash
# Ensure you're in the right directory
cd Apps/CLI
swift build

# Or from root with npm
npm run build:swift
```

#### Runtime Issues

**MCP Server Not Starting**
```bash
# Check logs
tail -f /tmp/peekaboo-mcp.log

# Test basic functionality
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' | node dist/index.js
```

**CLI JSON Output Issues**
```bash
# Always use --json-output flag for programmatic use
./peekaboo image --mode frontmost --json-output

# Check stderr for debug logs
PEEKABOO_LOG_LEVEL=debug ./peekaboo image --mode frontmost --json-output 2>debug.log
```

**AI Provider Connection Failed**
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Verify OpenAI API key
echo $OPENAI_API_KEY

# Test with explicit provider
PEEKABOO_AI_PROVIDERS="ollama/llava:latest" ./peekaboo analyze image.png "test"
```

#### Development Tips

**Debugging Service Calls**
```swift
// Enable verbose logging in PeekabooCore
let services = PeekabooServices.shared
// Add breakpoints in service implementations

// Check service protocol conformance
print(type(of: services.screenCapture))
```

**Testing Without Permissions**
```bash
# Use the test host app for controlled testing
cd Apps/CLI/TestHost
swift run

# Run tests that don't require permissions
swift test --filter "!LocalIntegration"
```

**Inspector Mode Not Working**
1. Ensure Accessibility permission is granted
2. Check overlay windows aren't being blocked by other apps
3. Use vtlog to check for errors: `./scripts/vtlog.sh -c OverlayManager`

### Getting Help

- **Logs**: Check `/tmp/peekaboo-mcp.log` for MCP server issues
- **vtlog**: Use `./scripts/vtlog.sh` for Mac app and Inspector logs
- **Debug Output**: Set `PEEKABOO_LOG_LEVEL=debug` for verbose CLI output
- **Test Host**: Use the test host app for permission and UI testing