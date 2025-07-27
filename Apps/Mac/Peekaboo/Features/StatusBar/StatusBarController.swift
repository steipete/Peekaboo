import AppKit
import SwiftUI
import os.log

/// Controls the Peekaboo status bar item and popover interface.
///
/// `StatusBarController` manages the macOS status bar integration, providing quick access
/// to Peekaboo's features through a menu bar icon. It handles the popover UI, icon animations,
/// and coordinates with other app components like the agent and session store.
///
/// ## Overview
///
/// The status bar controller provides:
/// - A persistent menu bar icon with animated states
/// - Quick access popover with main app functionality
/// - Visual feedback for agent execution states
/// - Integration with system appearance changes
///
/// ## Topics
///
/// ### Initialization
///
/// - ``init(agent:sessionStore:permissions:speechRecognizer:settings:)``
///
/// ### Icon Management
///
/// - ``IconState``
/// - ``updateIcon()``
/// - ``startAnimatingIcon()``
/// - ``stopAnimatingIcon()``
///
/// ### Popover Control
///
/// - ``togglePopover()``
/// - ``showPopover()``
/// - ``closePopover()``
///
/// ### App Integration
///
/// The controller maintains references to key app components for coordinated functionality.
@MainActor
final class StatusBarController: NSObject {
    private let logger = Logger(subsystem: "com.steipete.Peekaboo", category: "StatusBar")
    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    // State connections
    private let agent: PeekabooAgent
    private let sessionStore: SessionStore
    private let permissions: Permissions
    private let speechRecognizer: SpeechRecognizer
    private let settings: PeekabooSettings

    // Icon animation
    private var animationTimer: Timer?
    private var currentIconState = IconState.idle

    enum IconState: String, CaseIterable {
        case idle
        case peek1
        case peek2
        case peek3

        var next: IconState {
            let all = IconState.allCases
            guard let currentIndex = all.firstIndex(of: self) else { return .idle }
            let nextIndex = (currentIndex + 1) % all.count
            return all[nextIndex]
        }
    }

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
        self.observeAgentState()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = NSImage(named: "ghost.idle")
        button.image?.isTemplate = true
        button.action = #selector(self.statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        self.popover.contentSize = NSSize(width: 400, height: 500)
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
            // Recreate the content view to ensure fresh state
            let contentView = MenuBarStatusView()
                .environment(self.agent)
                .environment(self.sessionStore)
                .environment(self.speechRecognizer)
            
            self.popover.contentViewController = NSHostingController(rootView: contentView)
            
            guard let button = statusItem.button else { return }
            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Focus on input field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.popover.contentViewController?.view.window?.makeFirstResponder(nil)
            }
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
        menu.items.forEach { item in
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
            defer: false
        )
        
        window.title = session.title
        window.center()
        window.contentView = NSHostingView(
            rootView: SessionMainWindow()
                .environment(sessionStore)
                .environment(agent)
                .environment(speechRecognizer)
                .environment(permissions)
                .environment(settings)
        )
        
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func openMainWindow() {
        self.logger.info("openMainWindow action triggered from menu")
        
        // First ensure the app is active
        NSApp.activate(ignoringOtherApps: true)
        
        // Open the main window directly through app delegate
        if let appDelegate = NSApp.delegate as? AppDelegate {
            self.logger.info("Found AppDelegate, calling showMainWindow")
            appDelegate.showMainWindow()
        } else {
            self.logger.error("Could not find AppDelegate!")
        }
        
        // Also post notification as backup
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
        
        // Open the inspector window directly through app delegate
        if let appDelegate = NSApp.delegate as? AppDelegate {
            self.logger.info("Found AppDelegate, calling showInspector")
            appDelegate.showInspector()
        } else {
            self.logger.error("Could not find AppDelegate!")
        }
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    // MARK: - Icon Animation

    private func observeAgentState() {
        _ = withObservationTracking {
            self.agent.isProcessing
        } onChange: {
            Task { @MainActor in
                if self.agent.isProcessing {
                    self.startAnimating()
                    // If popover is shown, refresh its content
                    if self.popover.isShown {
                        self.refreshPopoverContent()
                    }
                } else {
                    self.stopAnimating()
                }
                self.observeAgentState() // Continue observing
            }
        }
    }
    
    private func refreshPopoverContent() {
        let contentView = MenuBarStatusView()
            .environment(self.agent)
            .environment(self.sessionStore)
            .environment(self.speechRecognizer)
        
        self.popover.contentViewController = NSHostingController(rootView: contentView)
    }

    private func startAnimating() {
        self.stopAnimating()

        self.animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.currentIconState = self.currentIconState.next
                self.updateIcon()
            }
        }
    }

    private func stopAnimating() {
        self.animationTimer?.invalidate()
        self.animationTimer = nil
        self.currentIconState = .idle
        self.updateIcon()
    }

    private func updateIcon() {
        self.statusItem.button?.image = NSImage(named: "ghost.\(self.currentIconState.rawValue)")
        self.statusItem.button?.image?.isTemplate = true
    }
}


// MARK: - NSMenuItem Extension

extension NSMenuItem {
    func with(_ configure: (NSMenuItem) -> Void) -> NSMenuItem {
        configure(self)
        return self
    }
}
