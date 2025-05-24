import Foundation

class Logger {
    static let shared = Logger()
    private var debugLogs: [String] = []
    private var isJsonOutputMode = false
    
    private init() {}
    
    func setJsonOutputMode(_ enabled: Bool) {
        isJsonOutputMode = enabled
        debugLogs.removeAll()
    }
    
    func debug(_ message: String) {
        if isJsonOutputMode {
            debugLogs.append(message)
        } else {
            fputs("DEBUG: \(message)\n", stderr)
        }
    }
    
    func info(_ message: String) {
        if isJsonOutputMode {
            debugLogs.append("INFO: \(message)")
        } else {
            fputs("INFO: \(message)\n", stderr)
        }
    }
    
    func warn(_ message: String) {
        if isJsonOutputMode {
            debugLogs.append("WARN: \(message)")
        } else {
            fputs("WARN: \(message)\n", stderr)
        }
    }
    
    func error(_ message: String) {
        if isJsonOutputMode {
            debugLogs.append("ERROR: \(message)")
        } else {
            fputs("ERROR: \(message)\n", stderr)
        }
    }
    
    func getDebugLogs() -> [String] {
        return debugLogs
    }
    
    func clearDebugLogs() {
        debugLogs.removeAll()
    }
} 