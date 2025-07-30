import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore

// Simple stderr logging function
func logError(_ message: String) {
    let data = Data("\(message)\n".utf8)
    FileHandle.standardError.write(data)
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
          peekaboo "Click the login button and sign in"   # Direct agent invocation
          peekaboo learn                                  # Load complete usage guide for AI

          peekaboo see --app Safari                      # Identify UI elements
          peekaboo click "Submit" --space-switch         # Click with auto-focus & Space switching
          peekaboo type "Hello" --bring-to-current-space # Type with window movement
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

        PERMISSIONS:
          Peekaboo requires system permissions to function properly:

          ✅ Screen Recording (REQUIRED)
             Needed for all screenshot operations
             Grant via: System Settings > Privacy & Security > Screen Recording

          ⚠️  Accessibility (OPTIONAL)
             Needed for window focus control (foreground capture mode)
             Grant via: System Settings > Privacy & Security > Accessibility

          Check your permissions status:
            peekaboo permissions                    # Human-readable output
            peekaboo permissions --json-output      # Machine-readable JSON

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
            ConfigCommand.self,
            PermissionsCommand.self,
            LearnCommand.self,
            // Interaction commands
            SeeCommand.self,
            ClickCommand.self,
            TypeCommand.self,
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

        // Check if we should run the agent command directly
        let args = Array(CommandLine.arguments.dropFirst())
        if !args.isEmpty {
            // Check if the first argument is NOT a known subcommand
            let knownSubcommands = [
                "image", "list", "config", "permissions", "learn",
                "see", "click", "type", "scroll", "hotkey", "swipe",
                "drag", "move", "run", "sleep", "clean", "window",
                "menu", "menubar", "app", "dock", "dialog", "space", "agent",
                "help", "--help", "-h", "--version"
            ]

            let firstArg = args[0]
            if !knownSubcommands.contains(firstArg) && !firstArg.starts(with: "-") {
                // This looks like a direct agent invocation
                // Manually create and run the agent command with the full task string
                do {
                    let taskString = args.joined(separator: " ")
                    // Create the AgentCommand by parsing with task as argument
                    var agentCommand = try AgentCommand.parse([taskString])
                    try await agentCommand.run()
                    return
                } catch {
                    AgentCommand.exit(withError: error)
                }
            }
        } else {
            // No arguments provided - show help instead of running default command
            await Peekaboo.main(["--help"])
            return
        }

        // Run the command normally
        await Peekaboo.main()
    }
}
