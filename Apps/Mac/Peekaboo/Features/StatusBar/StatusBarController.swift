import AppKit
import os.log
import PeekabooCore
import SwiftUI

/// Controls the Peekaboo status bar item and popover interface.
///
/// Manages the macOS status bar integration with animated icon states and popover UI.
@MainActor
final class StatusBarController: NSObject {
    private let logger = Logger(subsystem: "boo.peekaboo.app", category: "StatusBar")
    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    // State connections
    private let agent: PeekabooAgent
    private let sessionStore: SessionStore
    private let permissions: Permissions
    private let speechRecognizer: SpeechRecognizer
    private let settings: PeekabooSettings

    // Icon animation
    private let animationController = MenuBarAnimationController()

    init(
        agent: PeekabooAgent,
        sessionStore: SessionStore,
        permissions: Permissions,
        speechRecognizer: SpeechRecognizer,
        settings: PeekabooSettings)
    {
        self.agent = agent
        self.sessionStore = sessionStore
        self.permissions = permissions
        self.speechRecognizer = speechRecognizer
        self.settings = settings

        // Create status item
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        self.setupStatusItem()
        self.setupPopover()
        self.setupAnimationController()
        self.observeAgentState()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        guard let button = statusItem.button else { 
            logger.error("StatusBar button is nil - cannot setup status item")
            return 
        }

        // Use the MenuIcon asset
        let menuIcon = NSImage(named: "MenuIcon")
        if let menuIcon = menuIcon {
            logger.info("MenuIcon loaded successfully: \(menuIcon.size.width)x\(menuIcon.size.height)")
            button.image = menuIcon
            button.image?.isTemplate = true
        } else {
            logger.error("Failed to load MenuIcon - using fallback")
            // Create a simple fallback icon
            let fallbackIcon = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
                NSColor.controlAccentColor.set()
                let path = NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4))
                path.fill()
                return true
            }
            fallbackIcon.isTemplate = true
            button.image = fallbackIcon
        }
        
        button.action = #selector(self.statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        logger.info("Status bar button setup complete")
    }

    private func setupAnimationController() {
        // Pass agent reference to animation controller
        self.animationController.setAgent(self.agent)

        // Set up callback to update icon when animation renders new frame
        self.animationController.onIconUpdateNeeded = { [weak self] icon in
            self?.statusItem.button?.image = icon
        }

        // Force initial render
        self.animationController.forceRender()
    }

    private func setupPopover() {
        self.popover.contentSize = NSSize(width: 400, height: 600)
        self.popover.behavior = .transient
        self.popover.animates = false

        let contentView = MenuBarStatusView()
            .environment(self.agent)
            .environment(self.sessionStore)
            .environment(self.speechRecognizer)

        self.popover.contentViewController = NSHostingController(rootView: contentView)
    }

    // MARK: - Actions

    @objc private func statusItemClicked(_: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            self.showContextMenu()
        } else {
            self.togglePopover()
        }
    }

    func togglePopover() {
        if self.popover.isShown {
            self.popover.performClose(nil)
        } else {
            guard let button = statusItem.button else { return }
            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        // Recent sessions
        if !self.sessionStore.sessions.isEmpty {
            menu.addItem(NSMenuItem(title: "Recent Sessions", action: nil, keyEquivalent: ""))

            for session in self.sessionStore.sessions.prefix(5) {
                let item = NSMenuItem(
                    title: session.title,
                    action: #selector(self.openSession(_:)),
                    keyEquivalent: "")
                item.representedObject = session.id
                item.target = self
                menu.addItem(item)
            }

            menu.addItem(.separator())
        }

        // Actions
        menu.addItem(NSMenuItem(
            title: "Open Peekaboo",
            action: #selector(self.openMainWindow),
            keyEquivalent: "p").with { $0.keyEquivalentModifierMask = [.command, .shift] })

        menu.addItem(NSMenuItem(
            title: "Inspector",
            action: #selector(self.openInspector),
            keyEquivalent: "i").with { $0.keyEquivalentModifierMask = [.command, .shift] })

        menu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(self.openSettings),
            keyEquivalent: ",").with { $0.keyEquivalentModifierMask = .command })

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "About Peekaboo",
            action: #selector(self.showAbout),
            keyEquivalent: ""))

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = NSApp
        menu.addItem(quitItem)

        // Configure menu items (except quit which needs NSApp as target)
        for item in menu.items {
            if item.action != #selector(NSApplication.terminate(_:)) {
                item.target = self
            }
        }

        // Show menu
        self.statusItem.menu = menu
        self.statusItem.button?.performClick(nil)
        self.statusItem.menu = nil
    }

    // MARK: - Menu Actions

    @objc private func openSession(_ sender: NSMenuItem) {
        guard let sessionId = sender.representedObject as? String,
              let session = sessionStore.sessions.first(where: { $0.id == sessionId }) else { return }

        // Open session detail window
        NSApp.activate(ignoringOtherApps: true)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)

        window.title = session.title
        window.center()
        window.contentView = NSHostingView(
            rootView: SessionMainWindow()
                .environment(self.sessionStore)
                .environment(self.agent)
                .environment(self.speechRecognizer)
                .environment(self.permissions)
                .environment(self.settings))

        window.makeKeyAndOrderFront(nil)
    }

    @objc private func openMainWindow() {
        self.logger.info("openMainWindow action triggered from menu")

        // First ensure the app is active
        NSApp.activate(ignoringOtherApps: true)

        // Post notification to open main window
        self.logger.info("Posting OpenWindow.main notification")
        NotificationCenter.default.post(name: Notification.Name("OpenWindow.main"), object: nil)
    }

    @objc private func openSettings() {
        SettingsOpener.openSettings()
    }

    @objc private func openInspector() {
        self.logger.info("openInspector action triggered from menu")

        // First ensure the app is active
        NSApp.activate(ignoringOtherApps: true)

        // Post notification to trigger window opening
        // The AppDelegate listens for this notification and calls showInspector
        self.logger.info("Posting ShowInspector notification")
        NotificationCenter.default.post(name: Notification.Name("ShowInspector"), object: nil)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    // MARK: - Icon Animation

    private func observeAgentState() {
        withObservationTracking {
            // Observe multiple properties to ensure we catch all changes
            _ = self.agent.isProcessing
            _ = self.agent.toolExecutionHistory.count
            _ = self.sessionStore.currentSession?.messages.count ?? 0
        } onChange: {
            Task { @MainActor in
                // Update animation state based on agent processing
                self.animationController.updateAnimationState()

                // The MenuBarStatusView already observes these properties internally
                // so we don't need to refresh the entire popover content
                self.observeAgentState() // Continue observing
            }
        }
    }
}

// MARK: - NSMenuItem Extension

extension NSMenuItem {
    func with(_ configure: (NSMenuItem) -> Void) -> NSMenuItem {
        configure(self)
        return self
    }
}
