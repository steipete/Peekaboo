Of course. Here is the full and complete Software Design Document for Peekaboo 3.0. This document is a self-contained blueprint intended to be detailed enough for an engineer or an advanced agent to begin implementation.

---

### **Software Design Document: Peekaboo 3.0**

**Motto:** *Breaking out of the ghost realm.*

**Version:** 3.0
**Status:** Final (Updated January 2025)
**Last Updated:** 2025-01-08

#### **1. Vision & Scope**

**1.1. Vision**
Peekaboo 3.0 will be the definitive command-line framework for native macOS GUI automation. It will empower developers and AI agents to reliably **see, understand, and act upon** any application's user interface. By providing a powerful, semantic, and visually-driven toolset, Peekaboo will make macOS automation as simple and robust as modern web automation with Playwright.

**1.2. From "Ghost" to "Actor"**
Previous versions of Peekaboo and similar tools have acted as "ghosts"—they could see the screen and understand its structure, but could not directly interact. Peekaboo 3.0 breaks out of this ghost realm by integrating a complete set of actions, allowing it to become a first-class **actor** on the macOS desktop.

**1.3. Scope**
This document specifies a **comprehensive macOS automation ecosystem** consisting of:
- **CLI Tool**: A powerful `peekaboo` binary for command-line automation
- **Mac App**: A native macOS application with Inspector mode, AI agent integration, and visual debugging
- **MCP Server**: A Model Context Protocol server for AI agent integration
- **PeekabooCore**: A shared service layer providing direct API access for all components

#### **2. Core Principles**

*   **CLI-First:** The `peekaboo` binary is the product. It must be powerful, self-contained, and easy to distribute (e.g., via Homebrew).
*   **Semantic Interaction:** Actions are targeted at UI elements based on their accessibility properties (`role`, `title`, `identifier`), not on fragile screen coordinates.
*   **Visual & Intuitive:** The annotated screenshot workflow is a primary feature, making the tool easy to debug and use for humans and AI alike.
*   **Reliability by Default:** The CLI will have built-in auto-waits and actionability checks to eliminate flaky scripts and race conditions.
*   **Agent-Oriented:** All output is structured, machine-readable JSON to provide clear, unambiguous data for agentic parsing and decision-making.

#### **3. System Architecture**

Peekaboo 3.0 consists of multiple components built on a unified service layer:

1. **`PeekabooCore` (Service Layer):** A Swift library providing direct API access to all automation capabilities
2. **`peekaboo-cli` (CLI Tool):** A compiled Swift executable for command-line usage
3. **`Peekaboo.app` (Mac Application):** A native macOS app with Inspector mode and AI agent integration
4. **`@peekaboo/mcp` (MCP Server):** A Node.js/TypeScript server implementing the Model Context Protocol
5. **`AXorcist` (Accessibility Library):** Modern Swift wrapper around macOS Accessibility APIs

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

**Note:** This section has been significantly expanded to include all implemented commands as of January 2025.

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
      "ui_map": "/Users/user/.peekaboo/session/54321/map.json",
      "menu_bar": {
        "menus": [
          {
            "title": "File",
            "item_count": 12,
            "enabled": true
          }
        ]
      }
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

**`peekaboo scroll --direction <dir> --amount <num> [--on <element_id>] [--session-id <id>]`**

*   **Description:** Scrolls the mouse wheel in the specified direction.
*   **Arguments:**
    *   `--direction <dir>`: **Required.** Direction to scroll: `up`, `down`, `left`, or `right`.
    *   `--amount <num>`: **Required.** Number of scroll units (lines/ticks).
*   **Flags:**
    *   `--on <element_id>`: (Optional) Element to position mouse over before scrolling.
    *   `--session-id <id>`: (Optional) Session ID for element lookup.
*   **Examples:**
    ```bash
    peekaboo scroll --direction down --amount 5
    peekaboo scroll --direction up --amount 10 --on T1 --session-id 12345
    ```

**`peekaboo hotkey --keys <keys> [options]`**

*   **Description:** Press keyboard shortcuts and key combinations.
*   **Arguments:**
    *   `--keys <keys>`: **Required.** Comma-separated list of keys (e.g., "cmd,c", "ctrl,alt,delete").
*   **Supported Keys:**
    *   Modifiers: `cmd`, `command`, `ctrl`, `control`, `alt`, `option`, `shift`, `fn`
    *   Special: `escape`, `return`, `enter`, `tab`, `space`, `delete`, `backspace`
    *   Navigation: `up`, `down`, `left`, `right`, `home`, `end`, `pageup`, `pagedown`
    *   Function: `f1` through `f20`
*   **Examples:**
    ```bash
    peekaboo hotkey --keys "cmd,c"                    # Copy
    peekaboo hotkey --keys "cmd,shift,t"               # Reopen closed tab
    peekaboo hotkey --keys "ctrl,alt,delete"           # Force quit
    ```

**`peekaboo swipe --from <source> --to <target> [options]`**

*   **Description:** Perform swipe gestures between elements or coordinates.
*   **Arguments:**
    *   `--from <element_id>`: Source element ID (mutually exclusive with --from-coords).
    *   `--to <element_id>`: Target element ID (mutually exclusive with --to-coords).
    *   `--from-coords <x,y>`: Source coordinates.
    *   `--to-coords <x,y>`: Target coordinates.
*   **Flags:**
    *   `--duration <ms>`: Duration of the swipe in milliseconds (default: 500).
    *   `--session-id <id>`: Session ID for element lookup.
*   **Examples:**
    ```bash
    peekaboo swipe --from B1 --to B5 --session-id 12345
    peekaboo swipe --from-coords 100,200 --to-coords 300,400 --duration 1000
    ```

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

*   **Description:** Execute complex automation tasks using AI-powered agent. The agent uses OpenAI Chat Completions API with streaming support to break down natural language instructions into specific Peekaboo commands.
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

**`peekaboo analyze <image_path> <prompt> [options]`**

*   **Description:** Analyze images using AI vision models (OpenAI GPT-4V or Ollama LLaVA).
*   **Arguments:**
    *   `<image_path>`: **Required.** Path to the image file to analyze.
    *   `<prompt>`: **Required.** Natural language prompt describing what to analyze.
*   **Flags:**
    *   `--json-output`: Output results in JSON format
    *   `--providers <providers>`: Override AI providers (default from PEEKABOO_AI_PROVIDERS env)
*   **Environment:**
    *   `PEEKABOO_AI_PROVIDERS`: Comma-separated list of providers (e.g., "openai/gpt-4o,ollama/llava:latest")
    *   `OPENAI_API_KEY`: Required for OpenAI provider
*   **Examples:**
    ```bash
    peekaboo analyze screenshot.png "What application is shown?"
    peekaboo analyze ui.png "Describe all the buttons visible" --json-output
    PEEKABOO_AI_PROVIDERS="ollama/llava:latest" peekaboo analyze image.png "What text is visible?"
    ```

**`peekaboo move --x <x> --y <y> [options]`**

*   **Description:** Move the mouse cursor to specific coordinates without clicking.
*   **Arguments:**
    *   `--x <x>`: **Required.** X coordinate for mouse position.
    *   `--y <y>`: **Required.** Y coordinate for mouse position.
*   **Flags:**
    *   `--duration <ms>`: Duration for smooth movement (default: instant)
*   **Examples:**
    ```bash
    peekaboo move --x 500 --y 300
    peekaboo move --x 100 --y 200 --duration 500
    ```

**`peekaboo clean [options]`**

*   **Description:** Clean up session cache directories to free disk space.
*   **Flags:**
    *   `--all`: Clean all sessions regardless of age
    *   `--older-than <hours>`: Clean sessions older than specified hours (default: 24)
    *   `--dry-run`: Show what would be cleaned without deleting
*   **Examples:**
    ```bash
    peekaboo clean                        # Clean sessions older than 24 hours
    peekaboo clean --all                  # Clean all sessions
    peekaboo clean --older-than 1         # Clean sessions older than 1 hour
    peekaboo clean --dry-run              # Preview cleanup
    ```

**`peekaboo config <subcommand> [options]`**

*   **Description:** Manage Peekaboo configuration settings.
*   **Subcommands:**
    *   `init`: Create default configuration file
    *   `show`: Display current configuration
    *   `edit`: Open configuration in default editor
    *   `validate`: Validate configuration syntax
    *   `set-credential`: Securely store API keys
*   **Flags:**
    *   `--effective`: Show merged configuration from all sources (for `show`)
*   **Examples:**
    ```bash
    peekaboo config init                              # Create ~/.peekaboo/config.json
    peekaboo config show                              # Display current config
    peekaboo config show --effective                  # Show merged configuration
    peekaboo config edit                              # Open in $EDITOR
    peekaboo config set-credential OPENAI_API_KEY sk-... # Store API key securely
    ```

**`peekaboo permissions [options]`**

*   **Description:** Check and display current permission status for Peekaboo.
*   **Flags:**
    *   `--json-output`: Output results in JSON format
*   **Output:** Shows status of Screen Recording, Accessibility, and other required permissions.
*   **Examples:**
    ```bash
    peekaboo permissions
    peekaboo permissions --json-output
    ```

**`peekaboo image [options]`** *(Legacy command, maintained for compatibility)*

*   **Description:** Capture screenshots with various options. Superseded by `see` command.
*   **Options:**
    *   `--app <identifier>`: Target application
    *   `--mode <mode>`: Capture mode (screen, window, frontmost)
    *   `--path <path>`: Output path for screenshot
    *   `--window-title <title>`: Target window by title
    *   `--exclude-shadow`: Exclude window shadow
    *   `--json-output`: Output results in JSON format
*   **Examples:**
    ```bash
    peekaboo image --app Safari --path screenshot.png
    peekaboo image --mode screen --path desktop.png
    ```

**`peekaboo list <type> [options]`** *(Legacy command, maintained for compatibility)*

*   **Description:** List various system information. Partially superseded by specific commands.
*   **Types:**
    *   `apps`: List running applications
    *   `windows`: List windows for an application
    *   `permissions`: List permission status (use `permissions` command instead)
    *   `server_status`: List server and AI provider status
*   **Options:**
    *   `--app <identifier>`: Filter by application (for windows)
    *   `--json-output`: Output results in JSON format
*   **Examples:**
    ```bash
    peekaboo list apps --json-output
    peekaboo list windows --app Finder
    peekaboo list server_status
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

**`peekaboo drag [options]`**

*   **Description:** Perform drag and drop operations between UI elements, coordinates, or applications.
*   **Options:**
    *   `--from <element_id>`: Source element ID
    *   `--to <element_id>`: Target element ID
    *   `--from-coords <x,y>`: Source coordinates
    *   `--to-coords <x,y>`: Target coordinates
    *   `--to-app <name>`: Target application (e.g., "Trash") - **Enhanced feature**
    *   `--duration <ms>`: Drag duration in milliseconds (default: 500)
    *   `--modifiers <keys>`: Modifier keys (e.g., "cmd,option")
    *   `--session-id <id>`: Session ID for element lookup
*   **Special Features:**
    *   **Application Targeting:** The `--to-app` option allows dragging items directly to applications like Trash, making file operations intuitive.
*   **Examples:**
    ```bash
    peekaboo drag --from B1 --to T2 --session-id 12345
    peekaboo drag --from-coords 100,200 --to-coords 500,400
    peekaboo drag --from F1 --to-app Trash              # Drag file to Trash
    peekaboo drag --from-coords 50,50 --to-coords 300,300 --modifiers cmd,option
    ```

**`peekaboo menu <subcommand> [options]`**

*   **Description:** Interact with application menu bars and system menu extras using pure accessibility APIs, without opening or clicking menus.
*   **Subcommands:**
    *   `list`: List all menus and their items (including keyboard shortcuts)
    *   `list-all`: List menus for the frontmost application
    *   `click`: Click a menu item (default if not specified)
    *   `click-extra`: Click system menu extras in the status bar
*   **Options:**
    *   `--app <identifier>`: Target application by name, bundle ID, or 'PID:12345'
    *   `--item <name>`: Menu item to click (for simple, non-nested items)
    *   `--path <path>`: Menu path for nested items (e.g., 'File > Export > PDF')
    *   `--title <title>`: Title of menu extra (for click-extra)
    *   `--include-disabled`: Include disabled menu items in list output
*   **Key Features:**
    *   **Pure Accessibility:** Extracts complete menu structure without any UI interaction
    *   **Full Hierarchy:** Discovers all submenus and nested items recursively
    *   **Keyboard Shortcuts:** Extracts and displays all available shortcuts
    *   **Smart Discovery:** AI agents can use list to discover available options before clicking
*   **Examples:**
    ```bash
    peekaboo menu list --app Calculator                    # List all menus and items
    peekaboo menu list-all                                 # List menus for frontmost app
    peekaboo menu click --app Safari --item "New Window"
    peekaboo menu click --app TextEdit --path "Format > Font > Bold"
    peekaboo menu click-extra --title "WiFi"              # Click WiFi status menu
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

#### **5. Component 2: Peekaboo Mac Application**

The Peekaboo Mac app is a native macOS application that showcases the full capabilities of PeekabooCore with a rich graphical interface.

##### **5.1. Inspector Mode**

The Inspector is Peekaboo's visual debugging and exploration tool:

*   **Visual Overlay System:** Creates transparent overlay windows for each application
*   **Element Highlighting:** Color-coded bounding boxes around UI elements
*   **Hover Detection:** Real-time element information display on hover
*   **Multi-App Support:** Tracks and overlays multiple applications simultaneously
*   **Detail Levels:** 
    *   Essential: Only interactive elements (buttons, links, text fields)
    *   Moderate: Include static text and images
    *   All: Show every accessibility element
*   **Element Selection:** Click to select and copy element information
*   **Keyboard Shortcuts:** 
    *   `Cmd+Shift+I`: Toggle Inspector
    *   `Escape`: Exit Inspector mode

##### **5.2. AI Agent Integration**

Built-in OpenAI-powered automation agent:

*   **Natural Language Tasks:** Execute complex workflows from plain English descriptions
*   **Real-Time Streaming:** Live updates showing agent thinking and actions
*   **Session Management:** Track all agent interactions with full history
*   **Tool Orchestration:** Agent can use all Peekaboo commands
*   **Error Recovery:** Intelligent retry and error handling
*   **Model Selection:** Support for GPT-4, GPT-4 Turbo, and future models

##### **5.3. Status Bar Integration**

Always-accessible menu bar presence:

*   **Animated Ghost Icon:** Visual feedback during operations
*   **Quick Actions Menu:** Launch Inspector, Agent, or quit
*   **Popover Interface:** Compact UI for quick tasks
*   **Session Status:** Current agent execution state
*   **Keyboard Shortcuts:** Global hotkeys for common actions

##### **5.4. Session Management**

Comprehensive automation session tracking:

*   **Persistent Storage:** Sessions saved to `~/Library/Application Support/Peekaboo/`
*   **Message History:** Complete record of user prompts and agent responses
*   **Metadata Tracking:** Timestamps, duration, model used, token counts
*   **Session Replay:** Review past automation sequences
*   **Export Options:** Save sessions as JSON for analysis

##### **5.5. Speech Recognition**

Voice-driven automation (experimental):

*   **Continuous Listening:** Hands-free operation mode
*   **Wake Words:** Configurable activation phrases
*   **Transcription Display:** Real-time speech-to-text feedback
*   **Privacy Controls:** Local processing options
*   **Integration:** Works seamlessly with Agent mode

##### **5.6. Onboarding & Setup**

First-run experience:

*   **API Key Configuration:** Guided OpenAI API key setup
*   **Permission Requests:** Visual permission status and one-click grants
*   **Tutorial Mode:** Interactive walkthrough of features
*   **Settings Window:** Comprehensive preference management

#### **6. PeekabooCore Service Architecture**

PeekabooCore is the unified service layer that powers all Peekaboo applications.

##### **6.1. Design Principles**

*   **Protocol-Based:** Every service has a protocol for testability
*   **Dependency Injection:** Services can be mocked for testing
*   **Type Safety:** Swift's type system ensures correctness
*   **Performance:** Direct API calls, no subprocess overhead
*   **Async/Await:** Modern Swift concurrency throughout

##### **6.2. Available Services**

```swift
public class PeekabooServices {
    public static let shared = PeekabooServices()
    
    public let screenCapture: ScreenCaptureServiceProtocol
    public let applications: ApplicationServiceProtocol
    public let automation: UIAutomationServiceProtocol
    public let windows: WindowManagementServiceProtocol
    public let menu: MenuServiceProtocol
    public let dock: DockServiceProtocol
    public let dialogs: DialogServiceProtocol
    public let sessions: SessionServiceProtocol
    public let files: FileServiceProtocol
    public let configuration: ConfigurationServiceProtocol
    public let process: ProcessServiceProtocol
    public let logging: LoggingServiceProtocol
}
```

##### **6.3. Service Examples**

**Screen Capture:**
```swift
let result = try await services.screenCapture.captureFrontmost()
// Returns: CaptureResult with image data, app info, window info
```

**UI Automation:**
```swift
try await services.automation.click(
    target: .elementId("B1", sessionId: "12345"),
    options: ClickOptions(waitTimeout: 5.0, button: .left)
)
```

**Window Management:**
```swift
try await services.windows.resizeWindow(
    appIdentifier: .name("Safari"),
    windowIdentifier: .index(0),
    size: CGSize(width: 1200, height: 800)
)
```

##### **6.4. Error Handling**

Structured error types for each service domain:

```swift
public enum PeekabooError: Error {
    case permissionDenied(PermissionType)
    case elementNotFound(target: String, timeout: TimeInterval)
    case applicationNotFound(identifier: String)
    case ambiguousTarget(matches: [String])
    case captureFailure(reason: String)
    // ... comprehensive error cases
}
```

#### **7. Component 3: `@peekaboo/mcp` (Server & SDK)**

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

#### **8. Configuration & Environment**

##### **8.1. Configuration System**

Peekaboo uses a unified configuration system with multiple sources:

*   **Configuration Directory:** `~/.peekaboo/` (migrated from `~/.config/peekaboo/`)
*   **Main Config File:** `~/.peekaboo/config.json` (JSONC format with comments)
*   **Credentials File:** `~/.peekaboo/credentials` (key=value format, chmod 600)
*   **Precedence:** CLI args > Environment variables > Credentials file > Config file > Defaults

**Example config.json:**
```jsonc
{
  // AI Provider Settings
  "aiProviders": {
    "providers": "openai/gpt-4o,ollama/llava:latest",
    "ollamaBaseUrl": "http://localhost:11434"
  },
  
  // Default Settings
  "defaults": {
    "savePath": "~/Desktop/Screenshots",
    "imageFormat": "png",
    "captureMode": "window",
    "waitForTimeoutMs": 5000
  },
  
  // Logging
  "logging": {
    "level": "info",
    "path": "~/.peekaboo/logs/peekaboo.log"
  }
}
```

**Example credentials file:**
```
# ~/.peekaboo/credentials (chmod 600)
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
```

##### **8.2. Environment Variables**

*   `PEEKABOO_AI_PROVIDERS`: Comma-separated list of AI providers
*   `PEEKABOO_LOG_LEVEL`: Logging verbosity (trace, debug, info, warn, error)
*   `PEEKABOO_DEFAULT_SAVE_PATH`: Default screenshot save location
*   `PEEKABOO_CLI_PATH`: Override bundled CLI path (for development)
*   `OPENAI_API_KEY`: Required for OpenAI provider
*   `PEEKABOO_OLLAMA_BASE_URL`: Custom Ollama server URL

#### **9. Logging & Debugging**

##### **9.1. pblog Utility**

Peekaboo includes a powerful log viewing utility for the Mac app:

```bash
# Show recent logs (last 50 lines from past 5 minutes)
./scripts/pblog.sh

# Stream logs continuously
./scripts/pblog.sh -f

# Show only errors
./scripts/pblog.sh -e

# Filter by category
./scripts/pblog.sh -c OverlayManager

# Search for specific text
./scripts/pblog.sh -s "element selected"
```

##### **9.2. Logging Categories**

*   **OverlayManager:** UI overlay management
*   **OverlayView:** Individual overlay rendering
*   **InspectorView:** Main inspector UI
*   **AppOverlayView:** Application-specific overlays

##### **9.3. CLI Logging**

The CLI uses structured logging with JSON output support:

```bash
# Enable debug logging
PEEKABOO_LOG_LEVEL=debug peekaboo see --app Safari

# Capture debug logs with JSON output
peekaboo see --app Safari --json-output 2>debug.log
```

---

### **Addendum B: Implementation Summary**

This addendum summarizes the complete implementation as of January 2025, documenting all features and capabilities of the Peekaboo ecosystem.

#### **B.1. Complete Command Reference**

The following table lists all implemented CLI commands:

| Category | Command | Description |
|----------|---------|-------------|
| **Vision & Analysis** | `see` | Primary vision command with annotations and AI analysis |
| | `analyze` | AI-powered image analysis using vision models |
| **Mouse Actions** | `click` | Left/right/middle click with multi-click support |
| | `drag` | Drag & drop between elements, coordinates, or apps |
| | `move` | Move cursor without clicking |
| | `scroll` | Directional scrolling with configurable amount |
| | `swipe` | Touch-like gesture between points |
| **Keyboard Actions** | `type` | Type text strings with optional focus |
| | `hotkey` | Press keyboard shortcuts and combinations |
| **Window Management** | `window` | Close, minimize, maximize, move, resize, focus |
| **Application Control** | `app` | Launch, quit, hide, show, switch applications |
| **Menu Interactions** | `menu` | Click menu items, list menus, system menu extras |
| **Dock Control** | `dock` | Launch apps, right-click, show/hide dock |
| **Dialog Handling** | `dialog` | Click buttons, input text, handle file dialogs |
| **Automation** | `agent` | AI-powered task automation with natural language |
| | `run` | Execute batch scripts |
| | `sleep` | Pause execution |
| **System & Config** | `config` | Manage configuration and credentials |
| | `permissions` | Check system permissions |
| | `clean` | Manage session cache |
| **Legacy** | `image` | Screenshot capture (use `see` instead) |
| | `list` | System information queries |

#### **B.2. Mac Application Features**

The native macOS application includes:

1. **Inspector Mode**
   - Real-time UI element visualization
   - Multi-application overlay support
   - Hover information display
   - Keyboard shortcuts (Cmd+Shift+I)

2. **AI Agent Integration**
   - Natural language automation
   - Real-time execution streaming
   - Session history and replay
   - Model selection (GPT-4, GPT-4 Turbo)

3. **Status Bar Presence**
   - Always-accessible ghost icon
   - Quick action menu
   - Execution state feedback

4. **Speech Recognition**
   - Voice-driven commands
   - Continuous listening mode
   - Privacy-focused local processing

5. **Session Management**
   - Persistent session storage
   - Full interaction history
   - Export capabilities

#### **B.3. Architectural Components**

1. **PeekabooCore**
   - Unified service layer for all apps
   - Protocol-based design
   - Direct API access (no subprocess overhead)
   - Comprehensive error handling

2. **Service Architecture**
   ```
   PeekabooServices.shared
   ├── screenCapture
   ├── applications
   ├── automation
   ├── windows
   ├── menu
   ├── dock
   ├── dialogs
   ├── sessions
   ├── configuration
   ├── process
   └── logging
   ```

3. **Testing Infrastructure**
   - Swift Testing framework (not XCTest)
   - Integration test suite
   - Test host application
   - CI/CD compatible tests

#### **B.4. Key Innovations**

1. **Session Auto-Resolution**
   - Commands automatically use recent sessions
   - 10-minute validity window
   - No manual session tracking needed

2. **Drag to Applications**
   - `drag --to-app Trash` for intuitive file operations
   - Automatic app location resolution

3. **Pure Accessibility Menu Discovery**
   - Extract complete menu hierarchies without UI interaction
   - Keyboard shortcut discovery
   - AI-friendly menu exploration

4. **Unified Configuration**
   - Single config directory: `~/.peekaboo/`
   - JSONC with comments support
   - Secure credential storage
   - Environment variable expansion

5. **pblog Debugging**
   - Powerful log viewing for Mac app
   - Category-based filtering
   - Real-time streaming

#### **B.5. AI Provider Support**

1. **Multiple Providers**
   - OpenAI GPT-4V/GPT-4o
   - Ollama with LLaVA
   - Automatic fallback
   - Provider priority configuration

2. **Native Implementation**
   - Pure Swift HTTP client
   - No external dependencies
   - Async/await support

#### **B.6. Performance Optimizations**

1. **Direct Service Calls**
   - Mac app uses PeekabooCore directly
   - ~10x faster than subprocess spawning
   - Type-safe Swift APIs

2. **Parallel Processing**
   - Concurrent accessibility tree traversal
   - Batch element processing
   - Optimized screenshot capture

3. **Caching Strategy**
   - Process-isolated session cache
   - Atomic file operations
   - Automatic cleanup

This implementation represents a complete macOS automation ecosystem, suitable for both human users and AI agents, with performance, reliability, and extensibility as core design principles.
