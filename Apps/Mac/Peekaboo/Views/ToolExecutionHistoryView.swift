import SwiftUI

/// Displays the complete history of tool executions for the current task
struct ToolExecutionHistoryView: View {
    @Environment(PeekabooAgent.self) private var agent
    
    var body: some View {
        if !agent.toolExecutionHistory.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Label("Tool Execution Progress", systemImage: "gearshape.2")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(agent.toolExecutionHistory.count) steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Tool execution list
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(agent.toolExecutionHistory) { execution in
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
                // Status indicator
                statusIndicator
                
                // Tool icon
                Text(PeekabooAgent.iconForTool(execution.toolName))
                    .font(.system(size: 14))
                
                // Tool name and args
                VStack(alignment: .leading, spacing: 2) {
                    Text(execution.toolName)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.medium)
                    
                    Text(execution.arguments)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Timestamp
                Text(execution.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // Expand button for completed tools with results
                if execution.status == .completed && execution.result != nil {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down.circle" : "chevron.right.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Expanded result
            if isExpanded, let result = execution.result {
                Text(result)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 44)
                    .padding(.top, 2)
                    .lineLimit(3)
            }
        }
    }
    
    private var statusIndicator: some View {
        Group {
            switch execution.status {
            case .running:
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

#Preview {
    ToolExecutionHistoryView()
        .frame(width: 400)
        .padding()
}