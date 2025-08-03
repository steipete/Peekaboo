import AppKit
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "boo.peekaboo.playground", category: "App")
private let clickLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Click")
private let keyLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Key")

@main
struct PlaygroundApp: App {
    @StateObject private var actionLogger = ActionLogger.shared
    @State private var eventMonitor: Any?

    init() {
        self.setupGlobalMouseClickMonitor()
        self.setupGlobalKeyMonitor()
    }

    private func setupGlobalMouseClickMonitor() {
        // Monitor mouse clicks globally within the app
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            if let window = event.window {
                let locationInWindow = event.locationInWindow
                let windowFrame = window.frame

                // Convert to screen coordinates (top-left origin like Peekaboo uses)
                // macOS uses bottom-left origin, so we need to flip Y coordinate
                let screenHeight = NSScreen.main?.frame.height ?? 0
                let screenLocation = NSPoint(
                    x: windowFrame.origin.x + locationInWindow.x,
                    y: screenHeight - (windowFrame.origin.y + locationInWindow.y))

                let clickType = event.type == .leftMouseDown ? "Left" : "Right"

                // Try to identify what was clicked
                if let contentView = window.contentView,
                   let hitView = contentView.hitTest(locationInWindow)
                {
                    // Try to get element description from the hit view
                    var elementDesc = "unknown element"

                    // Check if it's a button
                    if let button = hitView as? NSButton {
                        elementDesc = button.title.isEmpty ? "button" : "'\(button.title)' button"
                    }
                    // Check accessibility label
                    else if let accessibilityLabel = hitView.accessibilityLabel(), !accessibilityLabel.isEmpty {
                        elementDesc = accessibilityLabel
                    }
                    // Check accessibility identifier
                    else if !hitView.accessibilityIdentifier().isEmpty {
                        let accessibilityId = hitView.accessibilityIdentifier()
                        // Clean up identifier for display
                        let cleaned = accessibilityId
                            .replacingOccurrences(of: "-button", with: "")
                            .replacingOccurrences(of: "-", with: " ")
                        elementDesc = cleaned + " element"
                    }
                    // Fall back to view class name
                    else {
                        let className = String(describing: type(of: hitView))
                            .replacingOccurrences(of: "SwiftUI.", with: "")
                            .replacingOccurrences(of: "AppKit.", with: "")
                        elementDesc = className
                    }

                    let logMessage = "\(clickType) click on \(elementDesc) at window: (\(Int(locationInWindow.x)), \(Int(locationInWindow.y))), screen: (\(Int(screenLocation.x)), \(Int(screenLocation.y)))"
                    clickLogger.info("\(logMessage)")

                    // Don't duplicate log in ActionLogger - let the button handlers do their specific logging
                    // This is just for system-level logging
                } else {
                    let logMessage = "\(clickType) click at window: (\(Int(locationInWindow.x)), \(Int(locationInWindow.y))), screen: (\(Int(screenLocation.x)), \(Int(screenLocation.y)))"
                    clickLogger.info("\(logMessage)")
                }
            }
            return event
        }
    }

    private func setupGlobalKeyMonitor() {
        // Monitor key events globally within the app
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            let eventTypeStr: String
            var keyInfo = ""

            switch event.type {
            case .keyDown:
                eventTypeStr = "Key Down"
                // Get the key character if available
                if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
                    keyInfo = "'\(chars)'"
                }
                // Add key code for special keys
                let specialKey = self.specialKeyName(for: event.keyCode)
                if !specialKey.isEmpty {
                    keyInfo = keyInfo.isEmpty ? specialKey : "\(keyInfo) (\(specialKey))"
                }
            case .keyUp:
                eventTypeStr = "Key Up"
                if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
                    keyInfo = "'\(chars)'"
                }
                let specialKey = self.specialKeyName(for: event.keyCode)
                if !specialKey.isEmpty {
                    keyInfo = keyInfo.isEmpty ? specialKey : "\(keyInfo) (\(specialKey))"
                }
            case .flagsChanged:
                eventTypeStr = "Modifier Changed"
                var modifiers: [String] = []
                if event.modifierFlags.contains(.command) { modifiers.append("⌘ Command") }
                if event.modifierFlags.contains(.shift) { modifiers.append("⇧ Shift") }
                if event.modifierFlags.contains(.option) { modifiers.append("⌥ Option") }
                if event.modifierFlags.contains(.control) { modifiers.append("⌃ Control") }
                if event.modifierFlags.contains(.function) { modifiers.append("fn Function") }
                keyInfo = modifiers.isEmpty ? "Released" : modifiers.joined(separator: " + ")
            default:
                eventTypeStr = "Unknown"
            }

            // Log with more detail for debugging
            let logMessage = "\(eventTypeStr): \(keyInfo) (keyCode: \(event.keyCode))"
            keyLogger.info("\(logMessage)")

            // Also log to ActionLogger for UI display (only for keyDown events)
            if event.type == .keyDown {
                ActionLogger.shared.log(.keyboard, "Key pressed: \(keyInfo)")
            }

            return event
        }
    }

    private func specialKeyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 36: "Return"
        case 76: "Enter"
        case 48: "Tab"
        case 53: "Escape"
        case 49: "Space"
        case 51: "Delete"
        case 117: "Forward Delete"
        case 123: "Left Arrow"
        case 124: "Right Arrow"
        case 125: "Down Arrow"
        case 126: "Up Arrow"
        case 115: "Home"
        case 119: "End"
        case 116: "Page Up"
        case 121: "Page Down"
        case 122: "F1"
        case 120: "F2"
        case 99: "F3"
        case 118: "F4"
        case 96: "F5"
        case 97: "F6"
        case 98: "F7"
        case 100: "F8"
        case 101: "F9"
        case 109: "F10"
        case 103: "F11"
        case 111: "F12"
        case 105: "F13"
        case 107: "F14"
        case 113: "F15"
        case 57: "Caps Lock"
        case 114: "Help"
        case 71: "Clear"
        default: ""
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(self.actionLogger)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Peekaboo Playground") {
                    logger.info("About menu clicked")
                    self.actionLogger.log(.menu, "About menu clicked")
                }
            }

            CommandMenu("Test Menu") {
                Button("Test Action 1") {
                    logger.info("Test Action 1 clicked")
                    self.actionLogger.log(.menu, "Test Action 1 clicked")
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Test Action 2") {
                    logger.info("Test Action 2 clicked")
                    self.actionLogger.log(.menu, "Test Action 2 clicked")
                }
                .keyboardShortcut("2", modifiers: [.command])

                Divider()

                Menu("Submenu") {
                    Button("Nested Action A") {
                        logger.info("Nested Action A clicked")
                        self.actionLogger.log(.menu, "Submenu > Nested Action A clicked")
                    }

                    Button("Nested Action B") {
                        logger.info("Nested Action B clicked")
                        self.actionLogger.log(.menu, "Submenu > Nested Action B clicked")
                    }
                }

                Divider()

                Button("Disabled Action") {
                    logger.info("This should not be logged - disabled")
                }
                .disabled(true)
            }

            CommandGroup(after: .textEditing) {
                Button("Clear All Logs") {
                    logger.info("Clear logs menu clicked")
                    self.actionLogger.clearLogs()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }

        WindowGroup("Log Viewer", id: "log-viewer") {
            LogViewerWindow()
                .environmentObject(self.actionLogger)
        }
        .windowResizability(.contentSize)
    }
}
