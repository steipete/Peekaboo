import PeekabooCore
import SwiftUI

// MARK: - Expanded Tool Calls View

struct ExpandedToolCallsView: View {
    let toolCalls: [ConversationToolCall]
    let onImageTap: (NSImage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(self.toolCalls) { toolCall in
                VStack(alignment: .leading, spacing: 8) {
                    // Arguments
                    if !toolCall.arguments.isEmpty, toolCall.arguments != "{}" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Arguments")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(toolCall.arguments.formatJSON())
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(4)
                        }
                    }

                    // Result
                    if !toolCall.result.isEmpty, toolCall.result != "Running..." {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Result")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Check if result contains image data
                            if toolCall.name.contains("image") || toolCall.name.contains("screenshot"),
                               let imageData = toolCall.result.extractImageData(),
                               let image = NSImage(data: imageData)
                            {
                                Button(action: {
                                    self.onImageTap(image)
                                }) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("Click to inspect image")
                            } else {
                                Text(toolCall.result)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .lineLimit(10)
                                    .padding(8)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Detailed Tool Call View

@available(macOS 15.0, *)
struct DetailedToolCallView: View {
    let toolCall: ConversationToolCall
    let onImageTap: (NSImage) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tool header
            HStack {
                AnimatedToolIcon(
                    toolName: self.toolCall.name,
                    isRunning: false)

                Text(self.toolCall.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button(action: { self.isExpanded.toggle() }) {
                    Image(systemName: self.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            if self.isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Arguments
                    if !self.toolCall.arguments.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Arguments")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(self.toolCall.arguments.formatJSON())
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(4)
                        }
                    }

                    // Result
                    if !self.toolCall.result.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Result")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Check if result contains image data
                            if self.toolCall.name.contains("image") || self.toolCall.name.contains("screenshot"),
                               let imageData = toolCall.result.extractImageData(),
                               let image = NSImage(data: imageData)
                            {
                                Button(action: { self.onImageTap(image) }) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("Click to inspect image")

                            } else {
                                Text(self.toolCall.result)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .lineLimit(10)
                                    .padding(8)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
