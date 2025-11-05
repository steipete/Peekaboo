import Foundation
import os

/// OS Logger instance for CLI-specific logging using the unified logging system
/// This complements the custom Logger class used for CLI output formatting
extension os.Logger {
    /// Logger for CLI-specific operations
    static let cli = os.Logger(subsystem: "boo.peekaboo.cli", category: "CLI")

    /// Logger for CLI command execution
    static let command = os.Logger(subsystem: "boo.peekaboo.cli", category: "Command")

    /// Logger for CLI configuration
    static let config = os.Logger(subsystem: "boo.peekaboo.cli", category: "Config")

    /// Logger for CLI errors
    static let error = os.Logger(subsystem: "boo.peekaboo.cli", category: "Error")
}
