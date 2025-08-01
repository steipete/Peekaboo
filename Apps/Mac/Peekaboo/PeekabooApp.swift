import AppKit
import os.log
import SwiftUI

@main
struct PeekabooApp: App {
    // Test comment for Poltergeist Mac build v10 - Now testing Mac app build!
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    // Core state - initialized together for proper dependencies
    @State private var settings = PeekabooSettings()
    @State private var sessionStore = SessionStore()
    @State private var permissions = Permissions()

    // Dependencies that need the core state
    @State private var speechRecognizer: SpeechRecognizer?
    @State private var agent: PeekabooAgent?
    
    // Control Inspector window creation
    @AppStorage("inspectorWindowRequested") private var inspectorRequested = false
    
    // Logger
    private let logger = Logger(subsystem: "boo.peekaboo.app", category: "PeekabooApp")

    var body: some Scene {
        // Hidden window to make Settings work in MenuBarExtra apps
        // This is a workaround for FB10184971
        WindowGroup("HiddenWindow") {
            HiddenWindowView()
                .task {
                    // Initialize dependencies if needed
                    if self.speechRecognizer == nil {
                        self.speechRecognizer = SpeechRecognizer(settings: self.settings)
                    }
                    if self.agent == nil {
                        self.agent = PeekabooAgent(settings: self.settings, sessionStore: self.sessionStore)
                    }

                    // Set up window opening handler
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
                    await self.permissions.check()
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)
        .commandsRemoved() // Remove from File menu

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
            if inspectorRequested {
                InspectorWindow()
                    .environment(self.settings)
                    .environment(self.permissions)
            } else {
                // Placeholder view until Inspector is actually requested
                Color.clear
                    .frame(width: 1, height: 1)
                    .onAppear {
                        logger.info("Inspector window created but not yet requested")
                    }
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 450, height: 700)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))

        // Settings scene
        Settings {
            SettingsWindow()
                .environment(self.settings)
                .environment(self.permissions)
                .environmentObject(self.appDelegate.visualizerCoordinator ?? VisualizerCoordinator())
                .onAppear {
                    // Ensure visualizer coordinator is available
                    if self.appDelegate.visualizerCoordinator == nil {
                        self.logger.error("VisualizerCoordinator not initialized in AppDelegate")
                    }
                }
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "boo.peekaboo.app", category: "App")
    private var statusBarController: StatusBarController?
    var windowOpener: ((String) -> Void)?

    // State connections
    private var settings: PeekabooSettings?
    private var sessionStore: SessionStore?
    private var permissions: Permissions?
    private var speechRecognizer: SpeechRecognizer?
    private var agent: PeekabooAgent?

    // Visualizer components
    var visualizerCoordinator: VisualizerCoordinator?
    private var visualizerXPCService: VisualizerXPCService?

    func applicationDidFinishLaunching(_: Notification) {
        self.logger.info("Peekaboo launching... (Poltergeist test)")

        // Initialize dock icon manager (it will set the activation policy based on settings) - Test!
        // Don't set activation policy here - let DockIconManager handle it

        // Initialize visualizer components
        self.visualizerCoordinator = VisualizerCoordinator()

        if let coordinator = visualizerCoordinator {
            self.visualizerXPCService = VisualizerXPCService(visualizerCoordinator: coordinator)
            self.visualizerXPCService?.start()
            self.logger.info("Visualizer XPC service started")
        }

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
        
        // Connect visualizer coordinator to settings
        if let coordinator = visualizerCoordinator {
            coordinator.connectSettings(settings)
        }

        // Setup keyboard shortcuts
        self.setupKeyboardShortcuts()
        
        // Setup notification observers
        self.setupNotificationObservers()

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

    // MARK: - Notifications
    
    private func setupNotificationObservers() {
        // Listen for Inspector window request
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowInspector),
            name: Notification.Name("ShowInspector"),
            object: nil
        )
    }
    
    @objc private func handleShowInspector() {
        self.logger.info("Received ShowInspector notification")
        // Mark that Inspector has been requested
        UserDefaults.standard.set(true, forKey: "inspectorWindowRequested")
        self.showInspector()
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
    
    // MARK: - Public Access
    
    /// Returns the visualizer coordinator for preview functionality
}

// Test comment to trigger build - Wed Jul 30 02:14:41 CEST 2025
