import Foundation

/// Thread-safe logging utility for Peekaboo.
///
/// Provides logging functionality that can switch between stderr output (for normal operation)
/// and buffered collection (for JSON output mode) to avoid interfering with structured output.
final class Logger: @unchecked Sendable {
    static let shared = Logger()
    private var debugLogs: [String] = []
    private var isJsonOutputMode = false
    private let queue = DispatchQueue(label: "logger.queue", attributes: .concurrent)

    private init() {}

    func setJsonOutputMode(_ enabled: Bool) {
        queue.sync(flags: .barrier) {
            self.isJsonOutputMode = enabled
            // Don't clear logs automatically - let tests manage this explicitly
        }
    }

    func debug(_ message: String) {
        queue.async(flags: .barrier) {
            if self.isJsonOutputMode {
                self.debugLogs.append(message)
            } else {
                fputs("DEBUG: \(message)\n", stderr)
            }
        }
    }

    func info(_ message: String) {
        queue.async(flags: .barrier) {
            if self.isJsonOutputMode {
                self.debugLogs.append("INFO: \(message)")
            } else {
                fputs("INFO: \(message)\n", stderr)
            }
        }
    }

    func warn(_ message: String) {
        queue.async(flags: .barrier) {
            if self.isJsonOutputMode {
                self.debugLogs.append("WARN: \(message)")
            } else {
                fputs("WARN: \(message)\n", stderr)
            }
        }
    }

    func error(_ message: String) {
        queue.async(flags: .barrier) {
            if self.isJsonOutputMode {
                self.debugLogs.append("ERROR: \(message)")
            } else {
                fputs("ERROR: \(message)\n", stderr)
            }
        }
    }

    func getDebugLogs() -> [String] {
        queue.sync {
            self.debugLogs
        }
    }

    func clearDebugLogs() {
        queue.sync(flags: .barrier) {
            self.debugLogs.removeAll()
        }
    }

    /// For testing - ensures all pending operations are complete
    func flush() {
        queue.sync(flags: .barrier) {
            // This ensures all pending async operations are complete
        }
    }
}
