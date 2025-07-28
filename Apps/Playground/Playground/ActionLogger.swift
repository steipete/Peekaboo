import SwiftUI
import OSLog
import Combine

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
        case .click: return .blue
        case .text: return .green
        case .menu: return .purple
        case .window: return .orange
        case .scroll: return .cyan
        case .drag: return .pink
        case .keyboard: return .yellow
        case .focus: return .indigo
        case .gesture: return .red
        case .control: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .click: return "cursorarrow.click"
        case .text: return "textformat"
        case .menu: return "menubar.rectangle"
        case .window: return "macwindow"
        case .scroll: return "scroll"
        case .drag: return "hand.draw"
        case .keyboard: return "keyboard"
        case .focus: return "scope"
        case .gesture: return "hand.tap"
        case .control: return "slider.horizontal.3"
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
        return formatter.string(from: timestamp)
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
            details: details
        )
        
        entries.append(entry)
        actionCount += 1
        lastAction = message
        
        // Log to OSLog with appropriate logger
        let logger = getLogger(for: category)
        if let details = details {
            logger.info("\(message, privacy: .public) - \(details, privacy: .public)")
        } else {
            logger.info("\(message, privacy: .public)")
        }
    }
    
    func clearLogs() {
        entries.removeAll()
        actionCount = 0
        lastAction = "Logs cleared"
        clickLogger.info("Logs cleared")
    }
    
    func exportLogs() -> String {
        let header = "Peekaboo Playground Action Log\nGenerated: \(Date())\n\n"
        let logLines = entries.map { entry in
            let details = entry.details.map { " - \($0)" } ?? ""
            return "[\(entry.formattedTime)] [\(entry.category.rawValue)] \(entry.message)\(details)"
        }.joined(separator: "\n")
        
        return header + logLines
    }
    
    func copyLogsToClipboard() {
        let logs = exportLogs()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logs, forType: .string)
        
        lastAction = "Logs copied to clipboard"
        clickLogger.info("Logs exported to clipboard")
    }
    
    private func getLogger(for category: ActionCategory) -> Logger {
        switch category {
        case .click: return clickLogger
        case .text: return textLogger
        case .menu: return menuLogger
        case .window: return windowLogger
        case .scroll: return scrollLogger
        case .drag: return dragLogger
        case .keyboard: return keyboardLogger
        case .focus: return focusLogger
        case .gesture: return gestureLogger
        case .control: return controlLogger
        }
    }
}