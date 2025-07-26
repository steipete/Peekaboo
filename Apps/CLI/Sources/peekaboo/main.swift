import ArgumentParser
import Foundation
import CoreGraphics

// Simple stderr logging function
func logError(_ message: String) {
    if let data = "\(message)\n".data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

/// Main command-line interface for Peekaboo.
///
/// Provides a comprehensive CLI for capturing screenshots and analyzing images
/// using AI vision models. Supports multiple capture modes and AI providers.
struct Peekaboo: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "peekaboo",
        abstract: "Lightning-fast macOS screenshots and AI vision analysis",
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

        COMMON WORKFLOWS:
          # Capture and automate with AI agent
          peekaboo image --app Safari --path /tmp/page.png
          peekaboo agent "Describe what's on the page in /tmp/page.png"

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
        version: Version.fullVersion,
        subcommands: [
            // Core commands
            ImageCommand.self,
            ListCommand.self,
            ConfigCommand.self,
            PermissionsCommand.self,
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
            AppCommand.self,
            DockCommand.self,
            DialogCommand.self,
            // Agent commands
            AgentCommand.self,
        ]
    )
}

/// Check if the CLI binary is stale compared to the current git commit.
/// Only runs in debug builds when git config 'peekaboo.check-build-staleness' is true.
func checkBuildStaleness() {
    // Check if staleness checking is enabled via git config
    let configCheck = Process()
    configCheck.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    configCheck.arguments = ["config", "peekaboo.check-build-staleness"]
    
    let configPipe = Pipe()
    configCheck.standardOutput = configPipe
    configCheck.standardError = Pipe() // Silence stderr
    
    do {
        try configCheck.run()
        configCheck.waitUntilExit()
        
        // Only proceed if the config value is "true"
        let configData = configPipe.fileHandleForReading.readDataToEndOfFile()
        let configValue = String(data: configData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        guard configValue == "true" else {
            return // Staleness checking is disabled
        }
    } catch {
        return // Git config command failed, skip check
    }
    
    // Get current git commit hash
    let gitProcess = Process()
    gitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    gitProcess.arguments = ["rev-parse", "--short", "HEAD"]
    
    let gitPipe = Pipe()
    gitProcess.standardOutput = gitPipe
    gitProcess.standardError = Pipe() // Silence stderr
    
    do {
        try gitProcess.run()
        gitProcess.waitUntilExit()
        
        guard gitProcess.terminationStatus == 0 else {
            return // Git command failed, skip check
        }
        
        let gitData = gitPipe.fileHandleForReading.readDataToEndOfFile()
        let currentCommit = String(data: gitData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Get embedded commit from build (strip -dirty suffix if present)
        let embeddedCommit = Version.gitCommit.replacingOccurrences(of: "-dirty", with: "")
        
        // Compare commits
        if !currentCommit.isEmpty && currentCommit != embeddedCommit {
            logError("❌ CLI binary is outdated!")
            logError("   Built with commit: \(embeddedCommit)")
            logError("   Current commit:    \(currentCommit)")
            logError("   Please rebuild me, I am outdated.")
            logError("")
            logError("   Run: npm run build:swift")
            logError("   Or:  ./scripts/build-swift-debug.sh")
            exit(1)
        }
    } catch {
        return // Git command failed, skip check
    }
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
                "image", "list", "config", "permissions",
                "see", "click", "type", "scroll", "hotkey", "swipe",
                "drag", "move", "run", "sleep", "clean", "window",
                "menu", "app", "dock", "dialog", "agent",
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
