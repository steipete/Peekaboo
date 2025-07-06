Of course. Here is the full and complete Software Design Document for Peekaboo 3.0. This document is a self-contained blueprint intended to be detailed enough for an engineer or an advanced agent to begin implementation.

---

### **Software Design Document: Peekaboo 3.0**

**Motto:** *Breaking out of the ghost realm.*

**Version:** 3.0
**Status:** Final

#### **1. Vision & Scope**

**1.1. Vision**
Peekaboo 3.0 will be the definitive command-line framework for native macOS GUI automation. It will empower developers and AI agents to reliably **see, understand, and act upon** any application's user interface. By providing a powerful, semantic, and visually-driven toolset, Peekaboo will make macOS automation as simple and robust as modern web automation with Playwright.

**1.2. From "Ghost" to "Actor"**
Previous versions of Peekaboo and similar tools have acted as "ghosts"—they could see the screen and understand its structure, but could not directly interact. Peekaboo 3.0 breaks out of this ghost realm by integrating a complete set of actions, allowing it to become a first-class **actor** on the macOS desktop.

**1.3. Scope**
This document specifies a **CLI-first framework**. The core product is a single, powerful `peekaboo` binary. This binary will be self-sufficient for all automation tasks. A server-based MCP wrapper is defined as a secondary component that *uses* the CLI, providing a persistent service layer for high-frequency agentic workflows.

#### **2. Core Principles**

*   **CLI-First:** The `peekaboo` binary is the product. It must be powerful, self-contained, and easy to distribute (e.g., via Homebrew).
*   **Semantic Interaction:** Actions are targeted at UI elements based on their accessibility properties (`role`, `title`, `identifier`), not on fragile screen coordinates.
*   **Visual & Intuitive:** The annotated screenshot workflow is a primary feature, making the tool easy to debug and use for humans and AI alike.
*   **Reliability by Default:** The CLI will have built-in auto-waits and actionability checks to eliminate flaky scripts and race conditions.
*   **Agent-Oriented:** All output is structured, machine-readable JSON to provide clear, unambiguous data for agentic parsing and decision-making.

#### **3. System Architecture**

Peekaboo 3.0 consists of two primary components that work in tandem:

1.  **`peekaboo-cli` (The Native Core):** A compiled Swift executable that serves as the engine. It directly interfaces with macOS APIs.
2.  **`@peekaboo/mcp` (The MCP Server & SDK):** An optional Node.js/TypeScript wrapper that provides a persistent server and a high-level client SDK for agent integration.

##### **3.1. The Process-Isolated Session Cache**

To manage state without a persistent server, Peekaboo will use a **transient, process-isolated, file-based session cache.**

*   **Isolation Strategy:** Each `peekaboo` process will create a unique session directory using its Process ID (PID). The session path will be: `~/.peekaboo/session/<PID>/`.
*   **Session ID Specification:** A new process can be instructed to use an existing session's cache via a global `--session-id <PID>` flag. This flag is applicable to all interaction commands (`click`, `type`, etc.).
*   **Intended Workflow:** The expected workflow is for an agent to first call a vision command (e.g., `see`), capture the `sessionId` from its JSON output, and then pass that ID to all subsequent action commands.
    ```bash
    # Agent/script logic
    OUTPUT=$(peekaboo see --app "Notes")
    SESSION_ID=$(echo $OUTPUT | jq -r .sessionId)
    peekaboo click --on "B1" --session-id "$SESSION_ID"
    ```

*   **Atomicity & Cache Integrity:** The `see` command will use an atomic directory rename pattern.
    1.  It will write all new session files (`raw.png`, `annotated.png`, `map.json`) to a temporary staging directory (e.g., `~/.peekaboo/session/<PID>_staging_[timestamp]/`).
    2.  Upon successful completion of all file writes, it will perform an atomic `mv` (rename) operation, replacing the old session directory (`~/.peekaboo/session/<PID>/`) with the new one.

*   **Garbage Collection:** To prevent orphaned directories from accumulating, a manual cleanup command will be provided: `peekaboo clean --all-sessions`. This command will scan the `~/.peekaboo/session/` directory and delete any session subdirectories with a modification date older than a configurable threshold (default: 24 hours).

##### **3.1.1 Automatic Session Resolution**

To improve usability and reduce friction in interactive workflows, Peekaboo implements automatic session resolution for all commands except `see`.

*   **Session Resolution Precedence:** When a command needs a session, it follows this precedence order:
    1. **Explicit `--session-id`**: If provided, use the specified session ID (highest priority)
    2. **Latest Valid Session**: Find the most recently created session within the last 10 minutes
    3. **Error**: If no valid session is found, fail with a helpful error message

*   **Time-Based Filtering:** Only sessions created within the last 10 minutes are considered "valid" for automatic resolution. This prevents accidentally using stale sessions from previous automation runs.

*   **Command-Specific Behavior:**
    *   **`see` command**: Always creates a new session (never uses existing sessions)
    *   **All other commands**: Use session resolution precedence to find appropriate session

*   **Implementation Details:**
    ```swift
    // Session resolution logic
    func resolveSession(explicitId: String?) -> String {
        if let id = explicitId { return id }
        
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        let validSessions = findSessions()
            .filter { $0.creationDate > tenMinutesAgo }
            .sorted { $0.creationDate > $1.creationDate }
        
        guard let latest = validSessions.first else {
            throw PeekabooError.noValidSessionFound
        }
        
        return latest.sessionId
    }
    ```

*   **Updated Workflow Examples:**
    ```bash
    # Interactive usage - no session tracking needed
    peekaboo see --app "Notes"
    peekaboo click --on "B1"  # Automatically uses session from 'see'
    peekaboo type "Hello World"
    
    # Explicit session control still available
    peekaboo see --app "Safari"  # Creates session 12345
    peekaboo see --app "Notes"   # Creates session 12346
    peekaboo click --on "B1" --session-id 12345  # Click in Safari
    ```

##### **3.2. Performance & Dependencies**
*   **Performance Target:** The core `peekaboo see` command, for a moderately complex window, should complete in **under 2 seconds**. Interaction commands (`click`, `type`) should target sub-500ms execution times.
*   **Dependencies:** The `peekaboo-cli` will be a self-contained binary. The Homebrew installation formula will specify the minimum required macOS version (e.g., macOS 13.0). No other runtime dependencies will be required.

#### **4. Component 1: `peekaboo-cli` (The Native Core)**

This is the evolution of the `AXorcist` project, refactored and expanded into the official Peekaboo CLI.

##### **4.1. Technology Stack & Integration**

*   **Language:** Swift
*   **Core Engine:** The existing **`AXorcist` library** will be integrated as a local Swift Package dependency. The `peekaboo-cli` command handlers will call the high-level functions provided by the `AXorcist` module.

##### **4.2. CLI Command Reference**

**Global Flags (Available for All Commands)**

*   **`--verbose`, `-v`**: Enable detailed logging output to stderr. Shows internal operations, timing information, and decision-making process.
*   **`--json-output`**: Output results in JSON format for machine consumption. Suppresses human-readable output.

When `--verbose` is enabled, commands will output timestamped log messages to stderr in the format:
```
[2025-01-06T08:05:23Z] VERBOSE: Message here
```

This is particularly useful for:
- Debugging automation scripts
- Understanding why elements aren't found
- Tracking performance bottlenecks
- Learning how Peekaboo works internally

**`peekaboo see [options]`**

*   **Description:** The primary vision command. Analyzes a window, generates a process-isolated session cache, and returns the PID which serves as the **session ID**.
*   **Options:**
    *   `--app <identifier>`: Target application by name, bundle ID, or 'PID:12345'
    *   `--window-title <title>`: Target specific window by title (partial match)
    *   `--mode <mode>`: Capture mode: `screen`, `window`, or `frontmost` (auto-inferred from other options)
    *   `--path <path>`: Output path for screenshot
    *   `--annotate`: Generate annotated screenshot with visual markers
    *   `--analyze <prompt>`: Analyze captured content with AI
*   **Mode Resolution Logic:**
    1.  **Explicit Mode:** If `--mode` is specified, that mode is used
    2.  **Auto-Inference:** If `--app` or `--window-title` is provided without `--mode`, automatically uses `window` mode
    3.  **Default:** If no app/window options are provided, defaults to `frontmost` mode
*   **Examples:**
    ```bash
    peekaboo see                              # Capture frontmost window
    peekaboo see --app Safari                 # Auto-infers window mode
    peekaboo see --mode screen                # Capture entire screen
    peekaboo see --app Notes --annotate       # Capture Notes with annotations
    ```
*   **Output (`stdout`):** A JSON object containing the session ID and file paths.
    ```json
    {
      "sessionId": "54321",
      "screenshot_raw": "/Users/user/.peekaboo/session/54321/raw.png",
      "screenshot_annotated": "/Users/user/.peekaboo/session/54321/annotated.png",
      "ui_map": "/Users/user/.peekaboo/session/54321/map.json"
    }
    ```

**`peekaboo click --on <element_id> [--session-id <id>] [--wait-for <ms>]`**

*   **Arguments:**
    *   `--on <element_id>`: **Required.** The `peekabooId` from the `map.json` of the target session.
    *   `--session-id <id>`: **Optional.** The session ID from a `see` command. If omitted, uses the most recent session created within the last 10 minutes.
*   **Flags:**
    *   `--wait-for <ms>`: (Optional) Waits up to `<ms>` milliseconds for the element to appear if not immediately found. Defaults to the value in `config.jsonc` (5000ms).

**`peekaboo type --text "..." [--on <element_id>] [--session-id <id>]`**

*   **Arguments:**
    *   `--text "..."`: **Required.** The string to type.
*   **Flags:**
    *   `--on <element_id>`: (Optional) The ID of the element to click first to ensure focus.

**`peekaboo run <path_to_script.json>`**

*   **Description:** Executes a batch script of see/act commands within a single process.
*   **Arguments:**
    *   `<path_to_script.json>`: **Required.** Path to a `.peekaboo.json` script file.
*   **Flags:**
    *   `--output <path>`: Saves the results JSON to a file instead of `stdout`.
    *   `--no-fail-fast`: Continues execution even if a step fails.

**`peekaboo sleep <duration_ms>`**

*   **Description:** A utility command that pauses execution for a specified number of milliseconds.

**`peekaboo agent <task> [options]`**

*   **Description:** Execute complex automation tasks using AI-powered agent. The agent uses OpenAI Assistants API to break down natural language instructions into specific Peekaboo commands.
*   **Arguments:**
    *   `<task>`: **Required.** Natural language description of the task to perform.
*   **Flags:**
    *   `--verbose`: Show agent's reasoning and planning process
    *   `--dry-run`: Preview planned steps without executing them
    *   `--max-steps <num>`: Maximum number of steps the agent can take (default: 20)
    *   `--model <model>`: OpenAI model to use (default: "gpt-4-turbo")
    *   `--json-output`: Output results in JSON format
*   **Environment:**
    *   `OPENAI_API_KEY`: **Required.** Your OpenAI API key
*   **Direct Invocation:**
    *   Peekaboo can be invoked directly with a task (no subcommand): `peekaboo "Open Safari and search for weather"`
*   **Examples:**
    ```bash
    # Using agent subcommand
    peekaboo agent "Open TextEdit and write 'Hello World'"
    peekaboo agent "Take a screenshot of all open windows and save to Desktop"
    peekaboo agent --verbose "Find the Terminal app and run 'ls -la'"
    peekaboo agent --dry-run "Close all Finder windows"
    
    # Direct invocation (no subcommand)
    peekaboo "Click the login button and sign in"
    peekaboo "Compose an email to john@example.com with subject 'Meeting'"
    ```
*   **How it Works:**
    1. Creates an OpenAI Assistant with access to all Peekaboo commands as functions
    2. The assistant analyzes the task and plans a sequence of actions
    3. Executes each action using the appropriate Peekaboo command
    4. Can see the screen (via `see` command) and verify results
    5. Handles errors and can retry failed actions
*   **Output:**
    ```json
    {
      "success": true,
      "steps": [
        {
          "description": "Capture current screen state",
          "command": "peekaboo_see",
          "output": "{\"sessionId\": \"12345\", ...}"
        },
        {
          "description": "Click on TextEdit in Dock",
          "command": "peekaboo_click",
          "output": "{\"success\": true}"
        }
      ],
      "summary": "Successfully opened TextEdit and typed 'Hello World'"
    }
    ```

**`peekaboo window <subcommand> [options]`**

*   **Description:** Provides window manipulation capabilities including closing, minimizing, maximizing, moving, resizing, and focusing windows.
*   **Subcommands:**
    *   `close`: Close a window
    *   `minimize`: Minimize a window to the Dock
    *   `maximize`: Maximize a window (full screen)
    *   `move`: Move a window to a new position
    *   `resize`: Resize a window
    *   `set-bounds`: Set window position and size in one operation
    *   `focus`: Bring a window to the foreground
    *   `list`: List windows for an application (convenience shortcut)
*   **Target Identification Options:**
    *   `--app <identifier>`: Target by application name, bundle ID, or 'PID:12345'
    *   `--window-title <title>`: Target by window title (partial match)
    *   `--window-index <index>`: Target by window index (0-based, frontmost is 0)
    *   `--session <id> --element <id>`: Target using session cache and element ID
*   **Examples:**
    ```bash
    peekaboo window close --app Safari
    peekaboo window minimize --app Finder --window-title "Downloads"
    peekaboo window move --app TextEdit --x 100 --y 100
    peekaboo window resize --app Terminal --width 800 --height 600
    peekaboo window set-bounds --app Chrome --x 50 --y 50 --width 1024 --height 768
    peekaboo window focus --app "Visual Studio Code"
    ```

**`peekaboo menu <subcommand> [options]`**

*   **Description:** Interact with application menu bars to click menu items and navigate menu hierarchies.
*   **Subcommands:**
    *   `click`: Click a menu item using the menu path
    *   `click-system`: Click system menu items (menu extras)
    *   `list`: List all menu items for an application
*   **Options:**
    *   `--app <identifier>`: Target application name or bundle ID
    *   `--path <path>`: Menu path using " > " separator (e.g., "File > New")
    *   `--item <item>`: Direct menu item name
    *   `--title <title>`: System menu title (for click-system)
*   **Examples:**
    ```bash
    peekaboo menu click --app Safari --path "File > New Tab"
    peekaboo menu click --app Finder --item "Empty Trash"
    peekaboo menu list --app TextEdit --include-disabled
    peekaboo menu click-system --title "Wi-Fi"
    ```

**`peekaboo app <subcommand> [options]`**

*   **Description:** Manage application lifecycle including launching, quitting, hiding, and switching between applications.
*   **Subcommands:**
    *   `launch`: Launch an application
    *   `quit`: Quit one or more applications
    *   `hide`: Hide applications
    *   `show`: Show hidden applications
    *   `switch`: Switch between applications
*   **Options:**
    *   `--app <identifier>`: Application name, bundle ID, or 'PID:12345'
    *   `--bundle-id <id>`: Launch by bundle identifier
    *   `--wait`: Wait for app to be ready (launch)
    *   `--background`: Launch without activation
    *   `--save-changes`: Save changes before quitting
    *   `--all`: Apply to all applications
    *   `--except <apps>`: Exclude specific apps (comma-separated)
    *   `--others`: Hide/show other applications
*   **Examples:**
    ```bash
    peekaboo app launch --app TextEdit --wait
    peekaboo app quit --app Safari --save-changes
    peekaboo app hide --app Slack --others
    peekaboo app switch --to Finder
    peekaboo app switch --cycle --reverse
    ```

**`peekaboo dock <subcommand> [options]`**

*   **Description:** Interact with the macOS Dock to launch apps, access dock menus, and manage dock visibility.
*   **Subcommands:**
    *   `click`: Launch an app from the Dock
    *   `right-click`: Right-click a Dock item
    *   `hide`: Hide the Dock
    *   `show`: Show the Dock
    *   `list`: List all items in the Dock
*   **Options:**
    *   `--app <name>`: Application name in Dock
    *   `--index <index>`: Dock item index (0-based)
    *   `--select <item>`: Menu item to select after right-click
    *   `--type <type>`: Filter list by type (all, apps, other)
*   **Examples:**
    ```bash
    peekaboo dock click --app Safari
    peekaboo dock right-click --app Finder --select "New Window"
    peekaboo dock hide
    peekaboo dock list --type apps
    ```

**`peekaboo dialog <subcommand> [options]`**

*   **Description:** Interact with system dialogs and alerts including clicking buttons, entering text, and handling file dialogs.
*   **Subcommands:**
    *   `click`: Click a button in a dialog
    *   `input`: Enter text in dialog fields
    *   `file`: Handle file dialogs (save/open)
    *   `dismiss`: Dismiss a dialog
    *   `list`: List active dialog information
*   **Options:**
    *   `--button <name>`: Button to click (e.g., "OK", "Cancel", "Save")
    *   `--title <title>`: Dialog window title
    *   `--text <text>`: Text to enter
    *   `--field <label>`: Field label or placeholder
    *   `--path <path>`: File path for save/open dialogs
    *   `--name <name>`: Filename for save dialogs
    *   `--force`: Force dismiss with Escape key
*   **Examples:**
    ```bash
    peekaboo dialog click --button "Save"
    peekaboo dialog input --text "password123" --field "Password"
    peekaboo dialog file --path "/Users/me/Documents" --name "report.pdf" --select "Save"
    peekaboo dialog dismiss --force
    ```

**`peekaboo drag <options>`**

*   **Description:** Perform drag and drop operations between UI elements, coordinates, or applications.
*   **Options:**
    *   `--from <element_id>`: Source element ID
    *   `--to <element_id>`: Target element ID
    *   `--from-coords <x,y>`: Source coordinates
    *   `--to-coords <x,y>`: Target coordinates
    *   `--to-app <name>`: Target application (e.g., "Trash")
    *   `--duration <ms>`: Drag duration in milliseconds (default: 500)
    *   `--modifiers <keys>`: Modifier keys (e.g., "cmd,option")
    *   `--session <id>`: Session ID for element lookup
*   **Examples:**
    ```bash
    peekaboo drag --from B1 --to T2 --session abc123
    peekaboo drag --from-coords 100,200 --to-coords 500,400
    peekaboo drag --from F1 --to-app Trash
    peekaboo drag --from-coords 50,50 --to-coords 300,300 --modifiers cmd,option
    ```

##### **4.3. Key Implementation Details**

**The `--wait-for` Mechanism:**
This mechanism is the core of Peekaboo's reliability.
1.  The CLI is called with `--on B1`. It reads the `map.json` from the specified `--session-id`.
2.  It constructs an internal **`Locator`** object from the semantic properties of element "B1" (e.g., `{role: "AXButton", title: "New Note"}`).
3.  It enters a retry loop. In each iteration, it performs a **live accessibility search** using the `Locator`.
4.  The wait succeeds if **exactly one** element matching the `Locator` is found. It fails on ambiguity (multiple matches) or timeout.

**Actionability Checks:**
Before acting on a found element, the live `AXUIElement` will be checked to ensure it is:
1.  **Visible:** `kAXHiddenAttribute` is `false`.
2.  **Enabled:** `kAXEnabledAttribute` is `true`.
3.  **On-Screen:** The element's bounding box intersects with the screen bounds. Occlusion by other windows will not be checked in this version.

**Text Entry Method (`peekaboo type`):**
Text will be entered by simulating native key events using `CGEvent(keyboardEventSource: ...)` to ensure correct application behavior.

##### **4.4. Swift Implementation Example (`click` command)**
```swift
// Inside the ClickCommand's run() method

// 1. Load the session map
let cachePath = getSessionCachePath(for: self.sessionId)
let mapURL = cachePath.appendingPathComponent("map.json")
let uiMap = try loadUIMap(from: mapURL)

// 2. Find the element's locator data from the cache
guard let targetElementData = uiMap.first(where: { $0.peekabooId == self.elementId }) else {
    throw PeekabooError.elementNotFoundInCache(id: self.elementId, session: self.sessionId)
}

let locator = createLocator(from: targetElementData)
let timeout = self.waitFor ?? ConfigurationManager.shared.defaultTimeout

// 3. Enter retry loop to find the LIVE element
let liveElement = try waitForElement(with: locator, timeout: timeout)

// 4. Perform actionability checks on the LIVE element
try performActionabilityChecks(on: liveElement)

// 5. Calculate center and perform action
let liveBbox = liveElement.frame() // Get live coordinates
let clickPoint = CGPoint(x: liveBbox.midX, y: liveBbox.midY)
EventSynthesizer.postMouseEvent(at: clickPoint, type: .leftMouseDown)
usleep(50000) // 50ms pause
EventSynthesizer.postMouseEvent(at: clickPoint, type: .leftMouseUp)

printSuccess("Clicked element \(self.elementId).")
```

#### **5. Data Schemas and Formats**

**5.1. `peekabooId` Generation**
*   **Format:** A role-based prefix and a 1-based index (e.g., `B1`, `T1`).
*   **Prefixes:** `B`(Button), `T`(TextField/Area), `L`(Link), `M`(Menu), `C`(CheckBox), `R`(Radio), `S`(Slider), `G`(Generic/Group).
*   **Numbering:** The index is assigned via a top-to-bottom, left-to-right traversal of the accessibility tree.

**5.2. Bounding Box (`bbox`) Format**
*   **Format:** The `bbox` property will be a four-element array representing `[x, y, width, height]` in screen coordinates.

**5.3. Batch Script (`*.peekaboo.json`) Schema**
```json
{
  "description": "A script to automate a series of UI interactions.",
  "steps": [
    {
      "stepId": "unique-step-id-1",
      "comment": "See the main window of the Notes app.",
      "command": "see",
      "params": {
        "app_target": "com.apple.Notes",
        "annotated": true
      }
    },
    {
      "stepId": "unique-step-id-2",
      "command": "click",
      "params": { "on": "B1" }
    },
    {
      "stepId": "unique-step-id-3",
      "command": "sleep",
      "params": { "duration_ms": 500 }
    },
    {
      "stepId": "unique-step-id-4",
      "comment": "Minimize the Notes window",
      "command": "window",
      "params": {
        "subcommand": "minimize",
        "app": "com.apple.Notes"
      }
    },
    {
      "stepId": "unique-step-id-5",
      "comment": "Open a new tab via menu",
      "command": "menu",
      "params": {
        "subcommand": "click",
        "app": "Safari",
        "path": "File > New Tab"
      }
    },
    {
      "stepId": "unique-step-id-6",
      "comment": "Launch TextEdit in background",
      "command": "app",
      "params": {
        "subcommand": "launch",
        "app": "TextEdit",
        "wait": true,
        "background": true
      }
    },
    {
      "stepId": "unique-step-id-7",
      "comment": "Click Save button in dialog",
      "command": "dialog",
      "params": {
        "subcommand": "click",
        "button": "Save"
      }
    },
    {
      "stepId": "unique-step-id-8",
      "comment": "Drag file to Trash",
      "command": "drag",
      "params": {
        "from": "F1",
        "to_app": "Trash",
        "duration": 1000
      }
    }
  ]
}
```

**5.4. Error JSON Schema**```json
{
  "status": "error",
  "code": "ELEMENT_NOT_FOUND",
  "message": "Element with ID 'B99' not found after waiting for 5000ms.",
  "details": {
    "sessionId": "54321",
    "elementId": "B99"
  }
}
```

#### **6. Configuration Management**

A configuration file at `~/.config/peekaboo/config.jsonc` allows for user-specific defaults.

*   **Hierarchy:** CLI Flag > Environment Variable > `config.jsonc` > Built-in Default.
*   **Commands:** `peekaboo config <init | show | edit | validate>`.
*   **Default `config.jsonc` Content:**
    ```jsonc
    {
      "defaults": {
        // Default timeout in milliseconds for auto-wait actions.
        "waitForTimeoutMs": 5000,
        // Default app target for `see` if none is specified.
        "defaultAppTarget": "frontmost"
      },
      "screenshot": {
        // Font size for the 'peekabooId' on interaction markers.
        "annotationFontSize": 14,
        // Default colors for annotation bounding boxes by role.
        "annotationColors": {
          "AXButton": "#007AFF",
          "AXTextField": "#34C759",
          "default": "#8E8E93"
        }
      },
      "session": {
        "cachePath": "~/.peekaboo/session",
        "cacheMaxAgeHours": 24
      }
    }
    ```

#### **7. Component 2: `@peekaboo/mcp` (Server & SDK)**

The MCP server is a **thin, stateless wrapper** around the CLI.

**7.1. Concurrency Handling**
The MCP server will handle concurrent requests by **spawning a separate `peekaboo-cli` process for each incoming tool call.** The CLI's process-isolated cache handles concurrency safely.

**7.2. Security (`run_script` Tool)**
The `run_script` tool handler will write the provided JSON to a secure temporary file using `fs.mkdtemp` and `os.tmpdir()`, execute it, and guarantee cleanup with a `finally` block, preventing any file-based attacks.

**7.3. MCP Tool Definitions**
The tools exposed will map directly to the CLI, with the agent responsible for managing the `sessionId`.

```typescript
// Example: peekaboo.click Tool in the MCP server
server.setTool("peekaboo.click", {
  schema: z.object({
    sessionId: z.string().describe("The session ID from a previous 'see' command."),
    on: z.string().describe("The peekabooId of the element to click."),
    waitFor: z.number().optional().describe("Milliseconds to wait for the element.")
  }),
  handler: async (params) => {
    const args = ["click", "--session-id", params.sessionId, "--on", params.on];
    if (params.waitFor) {
        args.push("--wait-for", String(params.waitFor));
    }
    return await executeSwiftCli(args, logger);
  },
});
```


Of course. This is the perfect next step. A tool is only as good as the actions it can perform. Your goal to "simulate all interactions that a human can do" is the correct vision for a complete automation framework.

Let's break down exactly how Peekaboo 3.0 will handle this, detailing the command-line interface and the underlying native implementation for each type of interaction. This will be an extension of the main Software Design Document.

---

### **Software Design Document: Peekaboo 3.0 - Addendum A: Interaction Commands**

#### **A.1. Core Philosophy: Simulating a Human User**

Peekaboo's interaction commands are designed to emulate a human user at the operating system level. It does not use high-level application scripting. Instead, it sends low-level mouse and keyboard events directly to the OS, which then delivers them to the currently focused application.

This is achieved in the Swift native core (`peekaboo-cli`) by using the **Quartz Event Services** (`CoreGraphics` framework). This provides programmatic access to the same event stream that physical hardware uses.

#### **A.2. Mouse Interactions**

##### **`peekaboo click`**

This is the primary command for all forms of mouse clicks. It is enhanced with flags to specify button type and click count.

**How it Works (Standard Left Click):**
When you run `peekaboo click --on B1 --session-id 12345`:
1.  The CLI reads the cache for session `12345` to find the `Locator` for element `B1`.
2.  It performs the **auto-wait and actionability checks** to find the live element on screen.
3.  It calculates the center point of the element's live bounding box (e.g., `(150.5, 220.0)`).
4.  The Swift core then executes the following native sequence:
    ```swift
    // Using Quartz Event Services
    let clickPoint = CGPoint(x: 150.5, y: 220.0)
    
    // 1. Create a "mouse down" event at the coordinates
    let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: clickPoint, mouseButton: .left)
    
    // 2. Create a "mouse up" event at the same coordinates
    let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: clickPoint, mouseButton: .left)
    
    // 3. Post the events to the system event stream
    mouseDownEvent?.post(tap: .cgSessionEventTap)
    usleep(30000) // Small delay to ensure the down event is processed
    mouseUpEvent?.post(tap: .cgSessionEventTap)
    ```

**How a Right-Click Works:**

A `right-click` is specified using the `--button` flag.

*   **CLI Command:** `peekaboo click --on M2 --button right [--session-id 12345]`
*   **Swift Implementation:** The implementation is identical to a left-click, but the `mouseType` and `mouseButton` parameters change in the `CGEvent` creation.
    ```swift
    let rightMouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, /*...*/)
    let rightMouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, /*...*/)
    ```

**How a Double-Click Works:**

A `double-click` is specified using the `--clicks` flag.

*   **CLI Command:** `peekaboo click --on B3 --clicks 2 [--session-id 12345]`
*   **Swift Implementation:** The CLI wraps the `_click` sequence in a loop and uses the `CGEventSetIntegerValueField` function to correctly set the click count, which allows the OS to interpret it as a double-click event.
    ```swift
    // Simplified Swift logic
    for i in 1...clicks {
        let mouseDownEvent = CGEvent(...)
        // Tell the OS this is part of a multi-click sequence
        mouseDownEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
        mouseUpEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
        // ... post events ...
        usleep(intervalInMicroseconds)
    }
    ```

##### **New Command: `peekaboo scroll`**

To handle scrolling, a dedicated `scroll` command is required.

*   **CLI Command:** `peekaboo scroll --direction <dir> --amount <val> [--on <element_id>] [--session-id <id>]`
*   **Arguments:**
    *   `--direction`: **Required.** `up`, `down`, `left`, or `right`.
    *   `--amount`: **Required.** The number of "lines" or "ticks" to scroll.
    *   `--on`: (Optional) If provided, Peekaboo will move the mouse over the element before scrolling.
*   **Swift Implementation:** This uses a different `CGEvent` constructor, `CGEventCreateScrollWheelEvent`.
    ```swift
    // For a vertical scroll down
    let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, verticalScroll: -10, horizontalScroll: 0, ...)
    
    // For a horizontal scroll right
    let hScrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, verticalScroll: 0, horizontalScroll: 10, ...)

    // The command loops `amount` times, posting an event each time.
    for _ in 0..<amount {
        scrollEvent?.post(tap: .cgSessionEventTap)
        usleep(20000) // Small delay between scroll ticks
    }
    ```

#### **A.3. Keyboard Interactions**

##### **`peekaboo type`**

This command handles typing strings of text.

*   **CLI Command:** `peekaboo type --text "Hello, World!" [--on T1] [--session-id 12345]`
*   **How it Works:**
    1.  If `--on` is provided, it first performs a `click` on the target element to ensure it has keyboard focus.
    2.  It then iterates through each character of the `--text` string.
    3.  For each character, it determines the required **virtual key code** and any necessary **modifier keys** (like Shift for uppercase letters or symbols).
    4.  It posts a `keyDown` event for the modifier (if any), a `keyDown` for the character key, a `keyUp` for the character key, and finally a `keyUp` for the modifier.

*   **Swift Implementation Example (for the letter 'H'):**
    ```swift
    // 1. Press Shift down
    let shiftDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x38, keyDown: true)
    shiftDown?.flags = .maskShift // Add the Shift flag
    shiftDown?.post(tap: .cgHIDEventTap)

    // 2. Press H down
    let hDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x04, keyDown: true)
    hDown?.flags = .maskShift
    hDown?.post(tap: .cgHIDEventTap)
    
    usleep(12000) // Key-press delay
    
    // 3. Release H up
    let hUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x04, keyDown: false)
    hUp?.flags = .maskShift
    hUp?.post(tap: .cgHIDEventTap)

    // 4. Release Shift up
    let shiftUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x38, keyDown: false)
    shiftUp?.flags = [] // Release all flags
    shiftUp?.post(tap: .cgHIDEventTap)
    ```

##### **New Command: `peekaboo hotkey`**

This command is for pressing key combinations like `Cmd+C`.

*   **CLI Command:** `peekaboo hotkey --keys "command,c"`
*   **Arguments:**
    *   `--keys`: A comma-separated string of key names. The keys are pressed in the order given and released in reverse order.
*   **How it Works:** This is a crucial sequence to get right.
    1.  It iterates through the provided keys, posting a `keyDown` event for each one *without* releasing it.
    2.  It then iterates through the keys **in reverse order**, posting a `keyUp` event for each one.
*   **Swift Implementation (`--keys "command,c"`):**
    ```swift
    let keysToPress: [CGKeyCode] = [0x37, 0x08] // Command, C

    // 1. Press all keys down in order
    for key in keysToPress {
        CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)?.post(tap: .cgHIDEventTap)
    }
    
    usleep(12000)
    
    // 2. Release all keys up in REVERSE order
    for key in keysToPress.reversed() {
        CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)?.post(tap: .cgHIDEventTap)
    }
    ```

---

### **A.4. Complete Interaction Command Suite**

This table summarizes the full suite of proposed interaction commands for Peekaboo 3.0.

| Command | Key Arguments | Description |
| :--- | :--- | :--- |
| **`peekaboo click`** | `--on <id>`<br>`[--session-id <id>]`<br>`--button <type>`<br>`--clicks <num>` | Performs a left, right, or middle click on a UI element. Can perform multi-clicks. |
| **`peekaboo type`** | `--text "..."`<br>`[--session-id <id>]`<br>`--on <id>` | Types a string of text. Can click an element first to focus it. |
| **`peekaboo scroll`** | `--direction <dir>`<br>`--amount <num>`<br>`[--session-id <id>]` | Scrolls the mouse wheel up, down, left, or right. |
| **`peekaboo hotkey`** | `--keys "key1,key2"` | Presses a combination of keys simultaneously (e.g., for shortcuts like Cmd+S). |
| **`peekaboo swipe`** | `--from <id1> --to <id2>`<br>`[--session-id <id>]` | Drags the mouse from the center of one element to the center of another. |

This expanded suite provides a complete, robust, and intuitive set of tools to fully emulate human interaction, allowing agents to effectively drive any macOS application.

