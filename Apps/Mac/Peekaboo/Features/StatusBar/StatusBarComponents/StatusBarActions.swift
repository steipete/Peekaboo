import SwiftUI
import PeekabooCore
import os.log

// MARK: - Action Components

/// Bottom action buttons view
struct ActionButtonsView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.openWindow) private var openWindow
    
    private let logger = Logger(subsystem: "boo.peekaboo.app", category: "StatusBarActions")

    var body: some View {
        HStack(spacing: 12) {
            // Session picker / current session indicator
            if let currentSession = sessionStore.currentSession {
                CurrentSessionIndicator(session: currentSession)
            } else {
                NewSessionButton(onCreateSession: createNewSession)
            }

            ExpandButton(onOpenMainWindow: openMainWindow)
        }
    }

    private func createNewSession() {
        logger.info("Creating new session")
        _ = sessionStore.createSession(title: "New Session")
        openMainWindow()
    }

    private func openMainWindow() {
        logger.info("Opening main window")
        
        // Show dock icon temporarily
        DockIconManager.shared.temporarilyShowDock()
        
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
        
        // Use SwiftUI's openWindow directly
        openWindow(id: "main")
    }
}

/// Current session indicator display
struct CurrentSessionIndicator: View {
    let session: ConversationSession

    var body: some View {
        HStack {
            Image(systemName: "text.bubble")
                .font(.caption)
            Text(session.title)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(6)
        .frame(maxWidth: .infinity)
    }
}

/// New session creation button
struct NewSessionButton: View {
    let onCreateSession: () -> Void

    var body: some View {
        Button(action: onCreateSession) {
            Label("New Session", systemImage: "plus.circle")
                .font(.caption)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.small)
        .buttonStyle(.bordered)
    }
}

/// Expand to main window button
struct ExpandButton: View {
    let onOpenMainWindow: () -> Void

    var body: some View {
        Button(action: onOpenMainWindow) {
            Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.caption)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.small)
        .buttonStyle(.bordered)
    }
}

/// Quick actions view for idle state
struct QuickActionsView: View {
    let onOpenMainWindow: () -> Void
    let onCreateNewSession: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onOpenMainWindow) {
                Label("Open Main Window", systemImage: "rectangle.stack")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.bordered)

            Button(action: onCreateNewSession) {
                Label("New Session", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
    }
}