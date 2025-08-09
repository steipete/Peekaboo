import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore

// Test comment for Poltergeist CLI rebuild detection

// Simple stderr logging function
func logError(_ message: String) {
    let data = Data("\(message)\n".utf8)
    FileHandle.standardError.write(data)
}

// Generate dynamic permissions section for help
func getDynamicPermissionsSection() -> String {
    // We can't use async in the configuration initializer, so we'll provide a static fallback
    // The actual dynamic checking happens in the permissions command
    """
    PERMISSIONS:
      Peekaboo requires system permissions to function properly.

      Screen Recording (Required): For all screenshot operations
      Accessibility (Optional): For window focus control

      Check current status and grant instructions:
        peekaboo permissions
    """
}

/// Main command-line interface for Peekaboo.
///
/// Provides a comprehensive CLI for capturing screenshots and analyzing images
/// using AI vision models. Supports multiple capture modes and AI providers.
struct Peekaboo: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "peekaboo",
        abstract: "Lightning-fast macOS screenshots, AI vision analysis, " +
            "and GUI automation with intelligent focus management",
        discussion: """
        VERSION: \(Version.fullVersion)

        EXAMPLES:
          peekaboo image --app Safari                    # Capture Safari window
          peekaboo image --mode screen                   # Capture entire screen
          peekaboo image --mode frontmost                # Capture active window
          peekaboo image --app "Visual Studio Code"      # Capture VS Code
          peekaboo image --app Chrome --window-title "Gmail" # Capture specific window
          peekaboo image --app Finder --path ~/Desktop/finder.png

          peekaboo list apps                             # List all running apps
          peekaboo list windows --app Safari             # List Safari windows
          peekaboo list permissions                      # Check permissions

          peekaboo agent "Open TextEdit and write Hello"  # AI agent automation
          peekaboo agent "Click the login button"           # Automate UI interactions
          peekaboo learn                                  # Load complete usage guide for AI

          peekaboo see --app Safari                      # Identify UI elements
          peekaboo click "Submit" --space-switch         # Click with auto-focus & Space switching
          peekaboo type "Hello\\nWorld" --delay 50        # Type with newline
          peekaboo press return                          # Press Enter key
          peekaboo window focus --app Terminal           # Explicit focus management
          peekaboo space list                           # List all Spaces

        COMMON WORKFLOWS:
          # Capture and automate with AI agent
          peekaboo image --app Safari --path /tmp/page.png
          peekaboo agent "Describe what's on the page in /tmp/page.png"

          # Document all windows
          for app in Safari Chrome "Visual Studio Code"; do
            peekaboo image --app "$app" --mode multi --path ~/Screenshots/
          done

          # Cross-Space automation workflow
          peekaboo see --app "TextEdit"                  # Find UI elements
          peekaboo click --on T1 --space-switch          # Auto-switch Space & click
          peekaboo type "Hello from Space 2!"            # Type with auto-focus

        \(getDynamicPermissionsSection())

        CONFIGURATION:
          Peekaboo uses a configuration file at ~/.config/peekaboo/config.json

          peekaboo config init        # Create default configuration file
          peekaboo config edit        # Open config in your editor
          peekaboo config show        # Display current configuration
          peekaboo config validate    # Check configuration syntax

          The config file uses JSONC format (JSON with Comments) and supports:
          • Comments using // and /* */
          • Environment variable expansion with ${VAR_NAME}
          • Hierarchical settings for AI providers, defaults, and logging

          For detailed configuration options and environment variables,
          see: https://github.com/steipete/peekaboo#configuration

        LEARNING PEEKABOO:
          For AI agents and automation scripts, use the learn command to load
          all Peekaboo documentation in one go:

          peekaboo learn              # Complete usage guide with all tools

          This outputs comprehensive documentation including system instructions,
          all available tools with parameters and examples, and best practices.

        SEE ALSO:
          Website: https://peekaboo.boo
          GitHub: https://github.com/steipete/peekaboo

        """,
        version: Version.fullVersion,
        subcommands: [
            // Core commands
            ImageCommand.self,
            ListCommand.self,
            ToolsCommand.self,
            ConfigCommand.self,
            PermissionsCommand.self,
            LearnCommand.self,
            // Interaction commands
            SeeCommand.self,
            ClickCommand.self,
            TypeCommand.self,
            PressCommand.self,
            ScrollCommand.self,
            HotkeyCommand.self,
            SwipeCommand.self,
            DragCommand.self,
            MoveCommand.self,
            // System commands
            RunCommand.self,
            SleepCommand.self,
            CleanCommand.self,
            WindowCommand.self,
            MenuCommand.self,
            MenuBarCommand.self,
            AppCommand.self,
            DockCommand.self,
            DialogCommand.self,
            SpaceCommand.self,
            // Agent commands
            AgentCommand.self,
            // MCP commands
            MCPCommand.self,
        ]
    )
}

/// Application entry point.
///
/// Initializes configuration and launches the command-line parser.
@main
struct Main {
    static func main() async {
        #if DEBUG
        // Check for build staleness in debug mode
        checkBuildStaleness()
        #endif

        // Initialize CoreGraphics silently to prevent CGS_REQUIRE_INIT error
        _ = CGMainDisplayID()

        // Load configuration at startup
        _ = ConfigurationManager.shared.loadConfiguration()
        
        // Initialize visualizer connection for CLI (non-Mac app) usage
        // This ensures XPC connection to Mac app's visualizer service is established early
        PeekabooServices.shared.ensureVisualizerConnection()
        
        // Initialize MCP client with default servers
        // Note: MCP initialization happens within MCPCommand commands

        // Run the command normally - ArgumentParser will handle unknown commands
        await Peekaboo.main()
    }
}
