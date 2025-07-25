import AppKit
import os.log
import SwiftUI

@main
struct PeekabooApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    // Core state
    @State private var settings = PeekabooSettings()
    @State private var sessionStore = SessionStore()
    @State private var permissions = Permissions()
    @State private var speechRecognizer: SpeechRecognizer?

    // Derived state - created after core state is ready
    @State private var agent: PeekabooAgent?

    var body: some Scene {
        // Hidden window to make Settings work in MenuBarExtra apps
        // This is a workaround for FB10184971
        WindowGroup("HiddenWindow") {
            HiddenWindowView()
                .task {
                    // Initialize agent and connect app delegate
                    self.setupApp()
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)

        // Main window - Powerful debugging and development interface
        WindowGroup("Peekaboo Sessions", id: "main") {
            SessionMainWindow()
                .environment(self.settings)
                .environment(self.sessionStore)
                .environment(self.permissions)
                .environment(self.speechRecognizer ?? SpeechRecognizer(settings: self.settings))
                .environment(self.agent ?? PeekabooAgent(settings: self.settings, sessionStore: self.sessionStore))
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenWindow.main"))) { _ in
                    // Window will automatically open when this notification is received
                    DispatchQueue.main.async {
                        self.openWindow(id: "main")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StartNewSession"))) { _ in
                    // Handle new session request
                    _ = self.sessionStore.createSession(title: "New Session")
                }
                .onAppear {
                    // Make sure window has proper identifier
                    if let window = NSApp.keyWindow {
                        window.identifier = NSUserInterfaceItemIdentifier("main")
                    }
                }
        }
        .windowResizability(.automatic)
        .defaultSize(width: 900, height: 700)

        // Inspector window
        WindowGroup("Inspector", id: "inspector") {
            InspectorWindow()
                .environment(self.settings)
                .environment(self.permissions)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 450, height: 700)
        
        // Settings scene
        Settings {
            SettingsWindow()
                .environment(self.settings)
                .environment(self.permissions)
        }
    }

    private func setupApp() {
        // Initialize speech recognizer with settings
        if self.speechRecognizer == nil {
            self.speechRecognizer = SpeechRecognizer(settings: self.settings)
        }
        
        // Initialize agent
        if self.agent == nil {
            self.agent = PeekabooAgent(settings: self.settings, sessionStore: self.sessionStore)
        }

        // Set up window opening handler BEFORE connecting to state
        self.appDelegate.windowOpener = { windowId in
            Task { @MainActor in
                self.openWindow(id: windowId)
            }
        }

        // Connect app delegate to state
        self.appDelegate.connectToState(
            settings: self.settings,
            sessionStore: self.sessionStore,
            permissions: self.permissions,
            speechRecognizer: self.speechRecognizer!,
            agent: self.agent!)

        // Check permissions
        Task {
            await self.permissions.check()
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.steipete.Peekaboo", category: "App")
    private var statusBarController: StatusBarController?
    var windowOpener: ((String) -> Void)?

    // State connections
    private var settings: PeekabooSettings?
    private var sessionStore: SessionStore?
    private var permissions: Permissions?
    private var speechRecognizer: SpeechRecognizer?
    private var agent: PeekabooAgent?

    func applicationDidFinishLaunching(_: Notification) {
        self.logger.info("Peekaboo launching...")
        
        // Initialize dock icon manager (it will set the activation policy based on settings)
        // Don't set activation policy here - let DockIconManager handle it
        
        // Status bar will be created after state is connected
    }

    func connectToState(
        settings: PeekabooSettings,
        sessionStore: SessionStore,
        permissions: Permissions,
        speechRecognizer: SpeechRecognizer,
        agent: PeekabooAgent)
    {
        self.settings = settings
        self.sessionStore = sessionStore
        self.permissions = permissions
        self.speechRecognizer = speechRecognizer
        self.agent = agent

        // Now create status bar with connected state
        self.statusBarController = StatusBarController(
            agent: agent,
            sessionStore: sessionStore,
            permissions: permissions,
            speechRecognizer: speechRecognizer,
            settings: settings)
        
        // Connect dock icon manager to settings
        DockIconManager.shared.connectToSettings(settings)

        // Setup keyboard shortcuts
        self.setupKeyboardShortcuts()

        // Show onboarding if needed
        if !settings.hasValidAPIKey {
            self.showMainWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false // Menu bar app stays running
    }

    // MARK: - Window Management

    func showMainWindow() {
        self.logger.info("showMainWindow called")
        
        // Ensure dock icon is visible
        DockIconManager.shared.temporarilyShowDock()
        
        // Activate the app first
        NSApp.activate(ignoringOtherApps: true)
        
        // Find or create the main window
        DispatchQueue.main.async {
            self.logger.info("Looking for existing main window...")
            
            // First try to find an existing main window by identifier
            if let existingWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                self.logger.info("Found existing main window by identifier, bringing to front")
                existingWindow.makeKeyAndOrderFront(nil)
                return
            }
            
            // Also check by title as fallback
            if let existingWindow = NSApp.windows.first(where: { $0.title == "Peekaboo Sessions" }) {
                self.logger.info("Found existing main window by title, bringing to front")
                existingWindow.makeKeyAndOrderFront(nil)
                return
            }
            
            self.logger.info("No existing main window found, creating new one")
            
            // Use the window opener if available
            if let opener = self.windowOpener {
                self.logger.info("Using windowOpener to create main window")
                opener("main")
            } else {
                self.logger.info("No windowOpener available, posting notification")
                // Post notification to open window
                NotificationCenter.default.post(name: Notification.Name("OpenWindow.main"), object: nil)
            }
        }
    }

    func showSettings() {
        SettingsOpener.openSettings()
    }
    
    func showInspector() {
        self.openWindow(id: "inspector")
    }

    private func openWindow(id: String) {
        self.logger.info("openWindow called with id: \(id)")
        
        // Ensure dock icon is visible  
        DockIconManager.shared.temporarilyShowDock()
        
        // Use the window opener if available
        if let opener = self.windowOpener {
            self.logger.info("Using windowOpener to open window: \(id)")
            opener(id)
        } else {
            self.logger.info("WindowOpener not available, posting notification")
            // Post notification as fallback
            NotificationCenter.default.post(name: Notification.Name("OpenWindow.\(id)"), object: nil)
        }
        
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd+Shift+Space - Toggle popover
            if event.modifierFlags.contains([.command, .shift]), event.keyCode == 49 {
                self?.statusBarController?.togglePopover()
                return nil
            }

            // Cmd+Shift+P - Show main window
            if event.modifierFlags.contains([.command, .shift]), event.keyCode == 35 {
                self?.showMainWindow()
                return nil
            }

            return event
        }
    }
}
