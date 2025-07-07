import AppKit
import os.log
import SwiftUI

@main
struct PeekabooApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Core state
    @State private var settings = PeekabooSettings()
    @State private var sessionStore = SessionStore()
    @State private var permissions = Permissions()
    @State private var speechRecognizer = SpeechRecognizer()

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

        // Main window
        WindowGroup("Peekaboo", id: "main") {
            MainWindow()
                .environment(self.settings)
                .environment(self.sessionStore)
                .environment(self.permissions)
                .environment(self.speechRecognizer)
                .environment(self.agent ?? PeekabooAgent(settings: self.settings, sessionStore: self.sessionStore))
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenWindow.main"))) { _ in
                    // Window will automatically open when this notification is received
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 600)

        // Settings scene
        Settings {
            SettingsWindow()
                .environment(self.settings)
                .environment(self.permissions)
        }
    }

    private func setupApp() {
        // Initialize agent
        if self.agent == nil {
            self.agent = PeekabooAgent(settings: self.settings, sessionStore: self.sessionStore)
        }

        // Connect app delegate to state
        self.appDelegate.connectToState(
            settings: self.settings,
            sessionStore: self.sessionStore,
            permissions: self.permissions,
            speechRecognizer: self.speechRecognizer,
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
    private let logger = Logger(subsystem: "com.steipete.peekaboo", category: "App")
    private var statusBarController: StatusBarController?

    // State connections
    private var settings: PeekabooSettings?
    private var sessionStore: SessionStore?
    private var permissions: Permissions?
    private var speechRecognizer: SpeechRecognizer?
    private var agent: PeekabooAgent?

    func applicationDidFinishLaunching(_: Notification) {
        self.logger.info("Peekaboo launching...")

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

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
        self.openWindow(id: "main")
    }

    func showSettings() {
        SettingsOpener.openSettings()
    }

    private func openWindow(id: String) {
        // Post notification to open window
        NotificationCenter.default.post(name: Notification.Name("OpenWindow.\(id)"), object: nil)
        
        // Activate app
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
