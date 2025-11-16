import Foundation
import os

enum AutomationLogCategory: String, CaseIterable {
    case scroll = "Scroll"
    case gesture = "Gesture"
    case drag = "Drag"
    case cursor = "Focus"
    case window = "Window"
    case app = "App"
    case dock = "Dock"
    case menu = "Menu"
    case open = "Open"
    case space = "Space"
    case agent = "Agent"
    case mcp = "MCP"
    case dialog = "Dialog"
}

enum AutomationEventLogger {
    private static let subsystem = "boo.peekaboo.playground"
    private static var loggers: [AutomationLogCategory: os.Logger] = [:]
    private static let lock = NSLock()

    static func log(_ category: AutomationLogCategory, _ message: some StringProtocol) {
        let logger = self.logger(for: category)
        let text = String(message)
        logger.info("\(text, privacy: .public)")
    }

    private static func logger(for category: AutomationLogCategory) -> os.Logger {
        self.lock.lock()
        defer { self.lock.unlock() }

        if let existing = self.loggers[category] {
            return existing
        }

        let logger = os.Logger(subsystem: self.subsystem, category: category.rawValue)
        self.loggers[category] = logger
        return logger
    }
}
