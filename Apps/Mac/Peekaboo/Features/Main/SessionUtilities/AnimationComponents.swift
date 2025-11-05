import PeekabooCore
import SwiftUI

// MARK: - Animated Thinking Components

struct SessionAnimatedThinkingDots: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .foregroundStyle(.secondary)
            .font(.title3.bold())
            .symbolEffect(
                .variableColor
                    .iterative
                    .hideInactiveLayers)
    }
}

struct AnimatedThinkingIndicator: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("Thinking")
                .font(.caption)
                .foregroundColor(.secondary)

            Image(systemName: "ellipsis")
                .foregroundStyle(.blue)
                .font(.caption.bold())
                .symbolEffect(
                    .variableColor
                        .iterative
                        .hideInactiveLayers)
        }
    }
}

// MARK: - Progress Indicator View

struct ProgressIndicatorView: View {
    @Environment(PeekabooAgent.self) private var agent
    @State private var animationPhase = 0.0

    init(agent: PeekabooAgent) {
        // Just for interface consistency
    }

    var body: some View {
        HStack(spacing: 12) {
            // Animated icon
            if let currentTool = agent.currentTool {
                Text(PeekabooAgent.iconForTool(currentTool))
                    .font(.title2)
                    .scaleEffect(1 + sin(self.animationPhase) * 0.1)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: self.animationPhase)
            } else if self.agent.isThinking {
                SessionAnimatedThinkingDots()
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Primary status
                if let currentTool = agent.currentTool {
                    HStack(spacing: 4) {
                        Text(currentTool)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        if let args = agent.currentToolArgs, !args.isEmpty {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(args)
                                .font(.system(.body))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else if self.agent.isThinking {
                    AnimatedThinkingIndicator()
                        .font(.system(.body, design: .rounded))
                } else {
                    Text("Processing...")
                        .font(.system(.body))
                        .foregroundColor(.secondary)
                }

                // Task context
                if !self.agent.currentTask.isEmpty, self.agent.currentTool == nil {
                    Text(self.agent.currentTask)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .onAppear {
            self.animationPhase = 1
        }
    }
}
