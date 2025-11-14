import os.log
import PeekabooCore
import SwiftUI

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
                NewSessionButton(onCreateSession: self.createNewSession)
            }

            ExpandButton(onOpenMainWindow: self.openMainWindow)
        }
    }

    private func createNewSession() {
        self.logger.info("Creating new session")
        _ = self.sessionStore.createSession(title: "New Session")
        self.openMainWindow()
    }

    private func openMainWindow() {
        self.logger.info("Opening main window")

        // Show dock icon temporarily
        DockIconManager.shared.temporarilyShowDock()

        // Activate the app
        NSApp.activate(ignoringOtherApps: true)

        // Use SwiftUI's openWindow directly
        self.openWindow(id: "main")
    }
}

/// Current session indicator display
struct CurrentSessionIndicator: View {
    let session: ConversationSession

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "text.bubble")
                .font(.caption)
            Text(self.session.title)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .menuActionCapsule(fillOpacity: 0.16)
    }
}

/// New session creation button
struct NewSessionButton: View {
    let onCreateSession: () -> Void

    var body: some View {
        Button(action: self.onCreateSession, label: {
            Label("New Session", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        })
        .buttonStyle(MenuActionButtonStyle())
    }
}

/// Expand to main window button
struct ExpandButton: View {
    let onOpenMainWindow: () -> Void

    var body: some View {
        Button(action: self.onOpenMainWindow, label: {
            Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        })
        .buttonStyle(MenuActionButtonStyle())
    }
}

/// Quick actions view for idle state
struct QuickActionsView: View {
    let onOpenMainWindow: () -> Void
    let onCreateNewSession: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: self.onOpenMainWindow, label: {
                Label("Open Main Window", systemImage: "rectangle.stack")
                    .frame(maxWidth: .infinity)
            })
            .buttonStyle(MenuActionButtonStyle())

            Button(action: self.onCreateNewSession, label: {
                Label("New Session", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            })
            .buttonStyle(MenuActionButtonStyle())
        }
    }
}

// MARK: - Shared Styling

struct MenuActionButtonStyle: ButtonStyle {
    typealias Body = AnyView

    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(
            configuration.label
                .foregroundStyle(.white.opacity(0.92))
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(configuration.isPressed ? 0.24 : 0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.2))))
                .shadow(color: Color.black.opacity(configuration.isPressed ? 0.1 : 0.18), radius: 12, y: 8)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed))
    }
}

extension View {
    fileprivate func menuActionCapsule(fillOpacity: Double) -> some View {
        self
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(fillOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.15))))
    }
}
