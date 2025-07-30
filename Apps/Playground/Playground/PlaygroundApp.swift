import AppKit
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "boo.peekaboo.playground", category: "App")
private let clickLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Click")

@main
struct PlaygroundApp: App {
    @StateObject private var actionLogger = ActionLogger.shared
    @State private var eventMonitor: Any?

    init() {
        self.setupGlobalMouseClickMonitor()
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
