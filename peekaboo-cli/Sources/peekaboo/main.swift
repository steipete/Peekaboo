import ArgumentParser
import Foundation

/// Main command-line interface for Peekaboo.
///
/// Provides a comprehensive CLI for capturing screenshots and analyzing images
/// using AI vision models. Supports multiple capture modes and AI providers.
@available(macOS 14.0, *)
struct PeekabooCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "peekaboo",
        abstract: "Lightning-fast macOS screenshots and AI vision analysis (v\(Version.current))",
        discussion: """
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
              
              peekaboo analyze screenshot.png "What error is shown?"
              peekaboo analyze ui.png "Find the login button" --provider ollama
              peekaboo analyze diagram.png "Explain this" --model gpt-4o

            COMMON WORKFLOWS:
              # Capture and analyze in one command (NEW!)
              peekaboo image --app Safari --analyze "What's on this page?"
              peekaboo image --mode frontmost --analyze "What UI issues do you see?"
              
              # Or use separate commands for more control
              peekaboo image --app Safari --path /tmp/page.png && peekaboo analyze /tmp/page.png "What's on this page?"
              
              # Document all windows
              for app in Safari Chrome "Visual Studio Code"; do
                peekaboo image --app "$app" --mode multi --path ~/Screenshots/
              done

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
              
            SEE ALSO:
              Website: https://peekaboo.boo
              GitHub: https://github.com/steipete/peekaboo
              
            """,
        version: Version.current,
        subcommands: [ImageCommand.self, ListCommand.self, AnalyzeCommand.self, ConfigCommand.self, PermissionsCommand.self],
        defaultSubcommand: nil
    )

    mutating func run() async throws {
        // When no subcommand is provided, print help
        print(Self.helpMessage())
    }
}

/// Application entry point.
///
/// Initializes configuration and launches the command-line parser.
@main
struct Main {
    static func main() async {
        // Load configuration at startup
        _ = ConfigurationManager.shared.loadConfiguration()
        
        // Run the command
        await PeekabooCommand.main()
    }
}
