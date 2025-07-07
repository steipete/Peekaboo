import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
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

        let contentView = PopoverContentView()
            .environment(self.agent)
            .environment(self.sessionStore)
            .environment(self.permissions)
            .environment(self.speechRecognizer)
            .environment(self.settings)

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
            title: "Settings...",
            action: #selector(self.openSettings),
            keyEquivalent: ",").with { $0.keyEquivalentModifierMask = .command })

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "About Peekaboo",
            action: #selector(self.showAbout),
            keyEquivalent: ""))

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q").with { $0.keyEquivalentModifierMask = .command })

        // Configure menu items
        menu.items.forEach { $0.target = self }

        // Show menu
        self.statusItem.menu = menu
        self.statusItem.button?.performClick(nil)
        self.statusItem.menu = nil
    }

    // MARK: - Menu Actions

    @objc private func openSession(_ sender: NSMenuItem) {
        guard let sessionId = sender.representedObject as? String else { return }
        // TODO: Open session detail window
        print("Open session: \(sessionId)")
    }

    @objc private func openMainWindow() {
        // Check if window already exists by looking for windows with "Peekaboo" in the title
        for window in NSApp.windows {
            if window.title == "Peekaboo" || window.title.contains("Peekaboo") {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
        
        // If window doesn't exist, post notification to open it
        NotificationCenter.default.post(name: Notification.Name("OpenWindow.main"), object: nil)
        
        // Give it a moment to create the window, then activate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func openSettings() {
        SettingsOpener.openSettings()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    // MARK: - Icon Animation

    private func observeAgentState() {
        _ = withObservationTracking {
            self.agent.isExecuting
        } onChange: {
            Task { @MainActor in
                if self.agent.isExecuting {
                    self.startAnimating()
                } else {
                    self.stopAnimating()
                }
                self.observeAgentState() // Continue observing
            }
        }
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

// MARK: - Popover Content View

struct PopoverContentView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MainWindow()
            .frame(width: 400, height: 500)
    }
}

// MARK: - NSMenuItem Extension

extension NSMenuItem {
    func with(_ configure: (NSMenuItem) -> Void) -> NSMenuItem {
        configure(self)
        return self
    }
}
