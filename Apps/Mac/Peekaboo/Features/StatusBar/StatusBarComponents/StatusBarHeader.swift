import AppKit
import PeekabooCore
import SwiftUI

// MARK: - Header Components

/// Compact, macOS-native header for the menu bar popover.
struct StatusBarHeaderView: View {
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore

    @Binding var isVoiceMode: Bool

    let onOpenMainWindow: () -> Void
    let onOpenInspector: () -> Void
    let onOpenSettings: () -> Void
    let onNewSession: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image("MenuIcon")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text("Peekaboo")
                    .font(.headline)

                Text(self.subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if self.agent.isProcessing {
                Button(role: .destructive) {
                    self.agent.cancelCurrentTask()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Cancel")
            } else {
                Button {
                    self.isVoiceMode.toggle()
                } label: {
                    Image(systemName: self.isVoiceMode ? "keyboard" : "mic")
                }
                .buttonStyle(.borderless)
                .help(self.isVoiceMode ? "Switch to text" : "Dictate")
            }

            Menu {
                Button("Open Peekaboo") { self.onOpenMainWindow() }
                Button("New Session") { self.onNewSession() }

                Divider()

                Button("Inspector") { self.onOpenInspector() }
                Button("Settings…") { self.onOpenSettings() }

                Divider()

                Button("About Peekaboo") { NSApp.orderFrontStandardAboutPanel(nil) }
                Button("Quit Peekaboo") { NSApp.terminate(nil) }
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
