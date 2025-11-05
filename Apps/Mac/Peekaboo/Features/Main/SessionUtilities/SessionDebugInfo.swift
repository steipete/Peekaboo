import PeekabooCore
import SwiftUI

// MARK: - Session Debug Info

struct SessionDebugInfo: View {
    let session: ConversationSession
    let isActive: Bool

    var body: some View {
        HStack(spacing: 20) {
            // Left group: Session info
            HStack(spacing: 16) {
                // Session ID (shortened)
                HStack(spacing: 4) {
                    Image(systemName: "number.square.fill")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))

                    Text(String(self.session.id.prefix(8)))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .help(self.session.id) // Full ID on hover
                }

                Divider()
                    .frame(height: 12)

                // Messages & Tools combined
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "message.fill")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                        Text("\(self.session.messages.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                        Text("\(self.session.messages.flatMap(\.toolCalls).count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }

            Spacer()

            // Right group: Duration
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))

                SessionDurationText(startTime: self.session.startTime)
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}
