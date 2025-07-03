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
              peekaboo --app Safari                          # Capture Safari window
              peekaboo --mode screen                         # Capture entire screen
              peekaboo --mode frontmost                      # Capture active window
              peekaboo image --app "Visual Studio Code"      # Capture VS Code
              peekaboo image --app Chrome --window-title "Gmail" # Capture specific window
              peekaboo image --app Finder --path ~/Desktop/finder.png
              
              peekaboo list apps                             # List all running apps
              peekaboo list windows --app Safari             # List Safari windows
              peekaboo list server_status                    # Check permissions
              
              peekaboo analyze screenshot.png "What error is shown?"
              peekaboo analyze ui.png "Find the login button" --provider ollama
              peekaboo analyze diagram.png "Explain this" --model gpt-4o

            COMMON WORKFLOWS:
              # Capture and analyze in one go
              peekaboo --app Safari --path /tmp/page.png && peekaboo analyze /tmp/page.png "What's on this page?"
              
              # Debug UI issues
              peekaboo --mode frontmost --path bug.png && peekaboo analyze bug.png "What UI issues do you see?"
              
              # Document all windows
              for app in Safari Chrome "Visual Studio Code"; do
                peekaboo --app "$app" --mode multi --path ~/Screenshots/
              done

            PERMISSIONS:
              Screen Recording permission is required for capturing screenshots.
              Grant via: System Settings > Privacy & Security > Screen Recording
              
              Accessibility permission is optional for window focus control.
              Grant via: System Settings > Privacy & Security > Accessibility

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
              GitHub: https://github.com/steipete/peekaboo
              
            """,
        version: Version.current,
        subcommands: [ImageCommand.self, ListCommand.self, AnalyzeCommand.self, ConfigCommand.self],
        defaultSubcommand: ImageCommand.self
    )

    mutating func run() async throws {
        // This shouldn't be called as we have subcommands and a default
        fatalError("Main command run() should not be called directly")
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
