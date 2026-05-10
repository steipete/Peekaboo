import AppKit
import PeekabooCore
import SwiftUI

// MARK: - Header Components

/// Compact, macOS-native header for the menu bar popover.
struct StatusBarHeaderView: View {
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore

    let onOpenMainWindow: () -> Void
    let onOpenInspector: () -> Void
    let onOpenSettings: () -> Void
    let onNewSession: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image("MenuIcon")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text("Peekaboo")
                    .font(.headline)

                Text(self.subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if !self.agent.isProcessing {
                StatusPill(text: "Ready", systemImage: "checkmark.circle.fill", tint: .green)
            }

            if self.agent.isProcessing {
                Button(role: .destructive) {
                    self.agent.cancelCurrentTask()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Cancel")
            }

            Menu {
                Button { self.onOpenMainWindow() } label: {
                    Label("Open Peekaboo", systemImage: "macwindow")
                }
                Button { self.onNewSession() } label: {
                    Label("New Session", systemImage: "plus.bubble")
                }

                Divider()

                Button { self.onOpenInspector() } label: {
                    Label("Inspector", systemImage: "scope")
                }
                Button { self.onOpenSettings() } label: {
                    Label("Settings…", systemImage: "gearshape")
                }

                Divider()

                Button { NSApp.orderFrontStandardAboutPanel(nil) } label: {
                    Label("About Peekaboo", systemImage: "info.circle")
                }
                Button { NSApp.terminate(nil) } label: {
                    Label("Quit Peekaboo", systemImage: "power")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .help("Menu")
        }
    }

    private var subtitleText: String {
        if self.agent.isProcessing {
            return "Working…"
        }

        if let session = self.sessionStore.currentSession {
            return session.title
        }

        return "Ready"
    }
}

private struct StatusPill: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(self.text, systemImage: self.systemImage)
            .font(.caption2.weight(.medium))
            .labelStyle(.iconOnly)
            .foregroundStyle(self.tint)
            .help(self.text)
    }
}
