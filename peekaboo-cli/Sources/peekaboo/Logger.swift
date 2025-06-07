import Foundation

class Logger {
    static let shared = Logger()
    private var debugLogs: [String] = []
    private var isJsonOutputMode = false
    private let queue = DispatchQueue(label: "logger.queue", attributes: .concurrent)

    private init() {}

    func setJsonOutputMode(_ enabled: Bool) {
        queue.async(flags: .barrier) {
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
        return queue.sync {
            return self.debugLogs
        }
    }

    func clearDebugLogs() {
        queue.async(flags: .barrier) {
            self.debugLogs.removeAll()
        }
    }
}
