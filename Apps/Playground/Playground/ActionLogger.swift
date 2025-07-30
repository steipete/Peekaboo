import Combine
import OSLog
import SwiftUI

enum ActionCategory: String, CaseIterable {
    case click = "Click"
    case text = "Text"
    case menu = "Menu"
    case window = "Window"
    case scroll = "Scroll"
    case drag = "Drag"
    case keyboard = "Keyboard"
    case focus = "Focus"
    case gesture = "Gesture"
    case control = "Control"

    var color: Color {
        switch self {
        case .click: .blue
        case .text: .green
        case .menu: .purple
        case .window: .orange
        case .scroll: .cyan
        case .drag: .pink
        case .keyboard: .yellow
        case .focus: .indigo
        case .gesture: .red
        case .control: .gray
        }
    }

    var icon: String {
        switch self {
        case .click: "cursorarrow.click"
        case .text: "textformat"
        case .menu: "menubar.rectangle"
        case .window: "macwindow"
        case .scroll: "scroll"
        case .drag: "hand.draw"
        case .keyboard: "keyboard"
        case .focus: "scope"
        case .gesture: "hand.tap"
        case .control: "slider.horizontal.3"
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: ActionCategory
    let message: String
    let details: String?

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: self.timestamp)
    }
}

@MainActor
class ActionLogger: ObservableObject {
    static let shared = ActionLogger()

    @Published private(set) var entries: [LogEntry] = []
    @Published private(set) var actionCount: Int = 0
    @Published var lastAction: String = "Ready"
    @Published var showingLogViewer = false

    private let clickLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Click")
    private let textLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Text")
    private let menuLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Menu")
    private let windowLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Window")
    private let scrollLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Scroll")
    private let dragLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Drag")
    private let keyboardLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Keyboard")
    private let focusLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Focus")
    private let gestureLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Gesture")
    private let controlLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Control")

    private init() {}

    func log(_ category: ActionCategory, _ message: String, details: String? = nil) {
        let entry = LogEntry(
            timestamp: Date(),
            category: category,
            message: message,
            details: details)

        self.entries.append(entry)
        self.actionCount += 1
        self.lastAction = message

        // Log to OSLog with appropriate logger
        let logger = self.getLogger(for: category)
        if let details {
            logger.info("\(message, privacy: .public) - \(details, privacy: .public)")
        } else {
            logger.info("\(message, privacy: .public)")
        }
    }

    func clearLogs() {
        self.entries.removeAll()
        self.actionCount = 0
        self.lastAction = "Logs cleared"
        self.clickLogger.info("Logs cleared")
    }

    func exportLogs() -> String {
        let header = "Peekaboo Playground Action Log\nGenerated: \(Date())\n\n"
        let logLines = self.entries.map { entry in
            let details = entry.details.map { " - \($0)" } ?? ""
            return "[\(entry.formattedTime)] [\(entry.category.rawValue)] \(entry.message)\(details)"
        }.joined(separator: "\n")

        return header + logLines
    }

    func copyLogsToClipboard() {
        let logs = self.exportLogs()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logs, forType: .string)

        self.lastAction = "Logs copied to clipboard"
        self.clickLogger.info("Logs exported to clipboard")
    }

    private func getLogger(for category: ActionCategory) -> Logger {
        switch category {
        case .click: self.clickLogger
        case .text: self.textLogger
        case .menu: self.menuLogger
        case .window: self.windowLogger
        case .scroll: self.scrollLogger
        case .drag: self.dragLogger
        case .keyboard: self.keyboardLogger
        case .focus: self.focusLogger
        case .gesture: self.gestureLogger
        case .control: self.controlLogger
        }
    }
}
