import SwiftUI
import PeekabooCore

// MARK: - Header Components

/// Main header view showing current status and controls
struct StatusBarHeaderView: View {
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore
    @Environment(SpeechRecognizer.self) private var speechRecognizer
    
    @Binding var isVoiceMode: Bool

    var body: some View {
        HStack {
            // Status icon
            Image(systemName: agent.isProcessing ? "brain" : "moon.stars")
                .font(.title2)
                .foregroundColor(agent.isProcessing ? .accentColor : .secondary)
                .symbolEffect(.pulse, options: .repeating, isActive: agent.isProcessing)

            // Status information
            StatusInfoView()

            Spacer()

            // Token count if available
            if let usage = agent.tokenUsage {
                TokenUsageView(usage: usage)
            }

            // Controls
            HeaderControlsView(isVoiceMode: $isVoiceMode)
        }
    }
}

/// Status information display (session title, current tool, duration)
struct StatusInfoView: View {
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let currentSession = sessionStore.currentSession {
                Text(currentSession.title)
                    .font(.headline)
                    .lineLimit(1)

                if agent.isProcessing {
                    CurrentToolView()
                } else {
                    SessionDurationView(session: currentSession)
                }
            } else {
                Text(agent.isProcessing ? "Agent Active" : "Agent Idle")
                    .font(.headline)
            }
        }
    }
}

/// Current tool execution display
struct CurrentToolView: View {
    @Environment(PeekabooAgent.self) private var agent

    var body: some View {
        if let currentTool = agent.toolExecutionHistory.last(where: { $0.status == .running }) {
            HStack(spacing: 4) {
                EnhancedToolIcon(
                    toolName: currentTool.toolName,
                    status: .running)
                    .font(.system(size: 12))
                    .frame(width: 14, height: 14)
                
                Text(ToolFormatter.compactToolSummary(
                    toolName: currentTool.toolName,
                    arguments: currentTool.arguments ?? ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        } else {
            Text("Processing...")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

/// Session duration display
struct SessionDurationView: View {
    let session: ConversationSession

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption2)
            Text(formatSessionDuration(session))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Token usage display
struct TokenUsageView: View {
    let usage: TokenUsage

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "circle.hexagongrid.circle")
                .font(.caption)
            Text("\(usage.totalTokens)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .help("Tokens: \(usage.inputTokens) in, \(usage.outputTokens) out")
    }
}

/// Header control buttons (voice toggle, cancel)
struct HeaderControlsView: View {
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SpeechRecognizer.self) private var speechRecognizer
    
    @Binding var isVoiceMode: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Voice mode toggle button
            if !agent.isProcessing {
                Button(action: { isVoiceMode.toggle() }) {
                    Image(systemName: isVoiceMode ? "keyboard" : "mic")
                        .font(.title3)
                        .foregroundColor(isVoiceMode ? .red : .accentColor)
                        .symbolEffect(
                            .pulse,
                            options: .repeating,
                            isActive: isVoiceMode && speechRecognizer.isListening)
                }
                .buttonStyle(.plain)
                .help(isVoiceMode ? "Switch to text input" : "Switch to voice input")
            }

            // Cancel button when processing
            if agent.isProcessing {
                Button(action: {
                    agent.cancelCurrentTask()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Cancel current task")
            }
        }
    }
}