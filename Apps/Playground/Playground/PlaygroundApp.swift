import AppKit
import OSLog
import PeekabooFoundation
import SwiftUI

private let logger = Logger(subsystem: "boo.peekaboo.playground", category: "App")
private let clickLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Click")
private let keyLogger = Logger(subsystem: "boo.peekaboo.playground", category: "Key")

@MainActor
final class PlaygroundTabRouter: ObservableObject {
    @Published var selectedTab: String = "text"
}

@main
struct PlaygroundApp: App {
    @StateObject private var actionLogger = ActionLogger.shared
    @StateObject private var tabRouter = PlaygroundTabRouter()
    @State private var eventMonitor: Any?

    init() {
        self.setupGlobalMouseClickMonitor()
        self.setupGlobalKeyMonitor()
    }

    private func setupGlobalMouseClickMonitor() {
        // Monitor mouse clicks globally within the app
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            self.handleGlobalMouseClick(event)
        }
    }

    private func handleGlobalMouseClick(_ event: NSEvent) -> NSEvent {
        guard let window = event.window else {
            return event
        }

        let locationInWindow = event.locationInWindow
        let windowFrame = window.frame

        // Convert to screen coordinates (top-left origin like Peekaboo uses)
        // macOS uses bottom-left origin, so we need to flip Y coordinate
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let screenX = windowFrame.origin.x + locationInWindow.x
        let screenY = screenHeight - (windowFrame.origin.y + locationInWindow.y)
        let screenLocation = NSPoint(x: screenX, y: screenY)

        let clickType: ClickType = event.type == .leftMouseDown ? .single : .right
        let descriptor = self.elementDescriptor(for: window, at: locationInWindow)

        let logMessage = self.formatClickLogMessage(
            type: clickType,
            descriptor: descriptor,
            windowLocation: locationInWindow,
            screenLocation: screenLocation)
        clickLogger.info("\(logMessage, privacy: .public)")

        // Don't duplicate log in ActionLogger - let the button handlers do their specific logging
        // This is just for system-level logging
        return event
    }

    private func setupGlobalKeyMonitor() {
        // Monitor key events globally within the app
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            let (eventTypeStr, keyInfo) = self.describeKeyEvent(event)

            let logMessage = "\(eventTypeStr): \(keyInfo) (keyCode: \(event.keyCode))"
            keyLogger.info("\(logMessage, privacy: .public)")

            // Also log to ActionLogger for UI display (only for keyDown events)
            if event.type == .keyDown {
                ActionLogger.shared.log(.keyboard, "Key pressed: \(keyInfo)")
            }

            return event
        }
    }

    private let specialKeyLabels: [UInt16: String] = [
        36: "Return",
        76: "Enter",
        48: "Tab",
        53: "Escape",
        49: "Space",
        51: "Delete",
        117: "Forward Delete",
        123: "Left Arrow",
        124: "Right Arrow",
        125: "Down Arrow",
        126: "Up Arrow",
        115: "Home",
        119: "End",
        116: "Page Up",
        121: "Page Down",
        122: "F1",
        120: "F2",
        99: "F3",
        118: "F4",
        96: "F5",
        97: "F6",
        98: "F7",
        100: "F8",
        101: "F9",
        109: "F10",
        103: "F11",
        111: "F12",
        105: "F13",
        107: "F14",
        113: "F15",
        57: "Caps Lock",
        114: "Help",
        71: "Clear",
    ]

    private func specialKeyName(for keyCode: UInt16) -> String {
        self.specialKeyLabels[keyCode] ?? ""
    }

    private func describeKeyEvent(_ event: NSEvent) -> (String, String) {
        var eventTypeStr: String
        var keyInfo = ""

        switch event.type {
        case .keyDown:
            eventTypeStr = "Key Down"
            keyInfo = self.describeKeyCharacters(event)
        case .keyUp:
            eventTypeStr = "Key Up"
            keyInfo = self.describeKeyCharacters(event)
        case .flagsChanged:
            eventTypeStr = "Modifier Changed"
            keyInfo = self.describeModifierFlags(event.modifierFlags)
        default:
            eventTypeStr = "Unknown"
        }

        return (eventTypeStr, keyInfo)
    }

    private func describeKeyCharacters(_ event: NSEvent) -> String {
        var keyInfo = ""
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            keyInfo = "'\(chars)'"
        }
        let specialKey = self.specialKeyName(for: event.keyCode)
        if !specialKey.isEmpty {
            keyInfo = keyInfo.isEmpty ? specialKey : "\(keyInfo) (\(specialKey))"
        }
        return keyInfo
    }

    private func describeModifierFlags(_ flags: NSEvent.ModifierFlags) -> String {
        var modifiers: [String] = []
        if flags.contains(.command) { modifiers.append("⌘ Command") }
        if flags.contains(.shift) { modifiers.append("⇧ Shift") }
        if flags.contains(.option) { modifiers.append("⌥ Option") }
        if flags.contains(.control) { modifiers.append("⌃ Control") }
        if flags.contains(.function) { modifiers.append("fn Function") }
        return modifiers.isEmpty ? "Released" : modifiers.joined(separator: " + ")
    }

    private func elementDescriptor(for window: NSWindow, at location: CGPoint) -> String? {
        guard let contentView = window.contentView,
              let hitView = contentView.hitTest(location)
        else {
            return nil
        }

        return self.describeHitView(hitView)
    }

    private func describeHitView(_ hitView: NSView) -> String {
        if let button = hitView as? NSButton {
            return button.title.isEmpty ? "button" : "'\(button.title)' button"
        }

        if let accessibilityLabel = hitView.accessibilityLabel(), !accessibilityLabel.isEmpty {
            return accessibilityLabel
        }

        let accessibilityId = hitView.accessibilityIdentifier()
        if !accessibilityId.isEmpty {
            let cleaned = accessibilityId
                .replacingOccurrences(of: "-button", with: "")
                .replacingOccurrences(of: "-", with: " ")
            return "\(cleaned) element"
        }

        let className = String(describing: type(of: hitView))
            .replacingOccurrences(of: "SwiftUI.", with: "")
            .replacingOccurrences(of: "AppKit.", with: "")
        return className
    }

    private func formatClickLogMessage(
        type: ClickType,
        descriptor: String?,
        windowLocation: CGPoint,
        screenLocation: CGPoint) -> String
    {
        let windowCoords = "window: (\(Int(windowLocation.x)), \(Int(windowLocation.y)))"
        let screenCoords = "screen: (\(Int(screenLocation.x)), \(Int(screenLocation.y)))"
        let coordinateDetails = "at \(windowCoords), \(screenCoords)"
        if let descriptor, !descriptor.isEmpty {
            return "\(type) click on \(descriptor) \(coordinateDetails)"
        }
        return "\(type) click \(coordinateDetails)"
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(self.actionLogger)
                .environmentObject(self.tabRouter)
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

                Divider()

                Button("Switch to Click Testing Tab") {
                    self.tabRouter.selectedTab = "click"
                    self.actionLogger.log(.menu, "Switched to tab: Click Testing")
                }
                .keyboardShortcut("1", modifiers: [.command, .option])

                Button("Switch to Text Input Tab") {
                    self.tabRouter.selectedTab = "text"
                    self.actionLogger.log(.menu, "Switched to tab: Text Input")
                }
                .keyboardShortcut("2", modifiers: [.command, .option])

                Button("Switch to Controls Tab") {
                    self.tabRouter.selectedTab = "controls"
                    self.actionLogger.log(.menu, "Switched to tab: Controls")
                }
                .keyboardShortcut("3", modifiers: [.command, .option])

                Button("Switch to Scroll & Gestures Tab") {
                    self.tabRouter.selectedTab = "scroll"
                    self.actionLogger.log(.menu, "Switched to tab: Scroll & Gestures")
                }
                .keyboardShortcut("4", modifiers: [.command, .option])

                Button("Switch to Window Tab") {
                    self.tabRouter.selectedTab = "window"
                    self.actionLogger.log(.menu, "Switched to tab: Window")
                }
                .keyboardShortcut("5", modifiers: [.command, .option])

                Button("Switch to Drag & Drop Tab") {
                    self.tabRouter.selectedTab = "drag"
                    self.actionLogger.log(.menu, "Switched to tab: Drag & Drop")
                }
                .keyboardShortcut("6", modifiers: [.command, .option])

                Button("Switch to Keyboard Tab") {
                    self.tabRouter.selectedTab = "keyboard"
                    self.actionLogger.log(.menu, "Switched to tab: Keyboard")
                }
                .keyboardShortcut("7", modifiers: [.command, .option])
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
