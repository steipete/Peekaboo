import Combine
import PeekabooCore
import SwiftUI

/// Displays the complete history of tool executions for the current task
struct ToolExecutionHistoryView: View {
    @Environment(PeekabooAgent.self) private var agent

    var body: some View {
        if !self.agent.toolExecutionHistory.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Label("Tool Execution Progress", systemImage: "gearshape.2")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(self.agent.toolExecutionHistory.count) steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Tool execution list
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(self.agent.toolExecutionHistory) { execution in
                        ToolExecutionRow(execution: execution)
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }
}

/// Individual row for a tool execution
struct ToolExecutionRow: View {
    let execution: ToolExecution
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main row
            HStack(spacing: 8) {
                // Tool icon with status
                EnhancedToolIcon(
                    toolName: self.execution.toolName,
                    status: self.execution.status)

                // Tool summary
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.toolSummary)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.medium)

                    // Show result summary if completed
                    if self.execution.status == .completed,
                       let resultSummary = ToolFormatter.toolResultSummary(
                           toolName: execution.toolName,
                           result: execution.result)
                    {
                        Text(resultSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Duration or running indicator
                if self.execution.status == .running {
                    // Show elapsed time for running tools
                    TimeIntervalText(startTime: self.execution.timestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if let duration = execution.duration {
                    // Show fixed duration for completed tools
                    Text(ToolFormatter.formatDuration(duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Expand button for tools with arguments or results
                if self.hasExpandableContent {
                    Button(action: { self.toggleExpansion() }, label: {
                        Image(systemName: self.expansionIcon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    })
                    .buttonStyle(.plain)
                }
            }

            // Expanded content
            if self.isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Arguments section
                    if let arguments = self.execution.arguments, !arguments.isEmpty, arguments != "{}" {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Arguments:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            Text(self.formattedArguments)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }

                    // Result section
                    if let result = execution.result,
                       !result.isEmpty, result != "{}"
                    {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Result:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            Text(self.formattedResult(result))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.leading, 32)
                .padding(.top, 4)
            }
        }
    }

    private var toolSummary: String {
        ToolFormatter.compactToolSummary(
            toolName: self.execution.toolName,
            arguments: self.execution.arguments ?? "")
    }

    private var formattedArguments: String {
        guard let arguments = execution.arguments,
              let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: formatted, encoding: .utf8)
        else {
            return self.execution.arguments ?? ""
        }
        return string
    }

    private func formattedResult(_ result: String) -> String {
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: formatted, encoding: .utf8)
        else {
            return result
        }
        return string
    }

    private var hasExpandableContent: Bool {
        // Has content if we have non-empty arguments or results
        !(self.execution.arguments?.isEmpty ?? true) || self.execution.result != nil
    }

    private var expansionIcon: String {
        self.isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle"
    }

    private func toggleExpansion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.isExpanded.toggle()
        }
    }
}

/// A view that displays elapsed time since a start time, updating every second
struct TimeIntervalText: View {
    let startTime: Date
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(ToolFormatter.formatDuration(self.currentTime.timeIntervalSince(self.startTime)))
            .onReceive(self.timer) { _ in
                self.currentTime = Date()
            }
    }
}

#Preview {
    ToolExecutionHistoryView()
        .frame(width: 400)
        .padding()
}
