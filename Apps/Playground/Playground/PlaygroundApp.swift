import SwiftUI
import OSLog
import AppKit

private let logger = Logger(subsystem: "com.steipete.PeekabooPlayground", category: "App")
private let clickLogger = Logger(subsystem: "com.steipete.PeekabooPlayground", category: "Click")

@main
struct PlaygroundApp: App {
    @StateObject private var actionLogger = ActionLogger.shared
    @State private var eventMonitor: Any?
    
    init() {
        setupGlobalMouseClickMonitor()
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
                    y: screenHeight - (windowFrame.origin.y + locationInWindow.y)
                )
                
                let clickType = event.type == .leftMouseDown ? "Left" : "Right"
                let logMessage = "\(clickType) click at window: (\(Int(locationInWindow.x)), \(Int(locationInWindow.y))), screen: (\(Int(screenLocation.x)), \(Int(screenLocation.y)))"
                
                clickLogger.info("\(logMessage)")
                ActionLogger.shared.log(.click, logMessage)
            }
            return event
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(actionLogger)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Peekaboo Playground") {
                    logger.info("About menu clicked")
                    actionLogger.log(.menu, "About menu clicked")
                }
            }
            
            CommandMenu("Test Menu") {
                Button("Test Action 1") {
                    logger.info("Test Action 1 clicked")
                    actionLogger.log(.menu, "Test Action 1 clicked")
                }
                .keyboardShortcut("1", modifiers: [.command])
                
                Button("Test Action 2") {
                    logger.info("Test Action 2 clicked")
                    actionLogger.log(.menu, "Test Action 2 clicked")
                }
                .keyboardShortcut("2", modifiers: [.command])
                
                Divider()
                
                Menu("Submenu") {
                    Button("Nested Action A") {
                        logger.info("Nested Action A clicked")
                        actionLogger.log(.menu, "Submenu > Nested Action A clicked")
                    }
                    
                    Button("Nested Action B") {
                        logger.info("Nested Action B clicked")
                        actionLogger.log(.menu, "Submenu > Nested Action B clicked")
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
                    actionLogger.clearLogs()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
        
        WindowGroup("Log Viewer", id: "log-viewer") {
            LogViewerWindow()
                .environmentObject(actionLogger)
        }
        .windowResizability(.contentSize)
    }
}