import PeekabooCore
import SwiftUI

// MARK: - Input Components

/// Text input area for the status bar
struct StatusBarInputView: View {
    @Binding var inputText: String
    @FocusState.Binding var isInputFocused: Bool

    let isProcessing: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField(self.isProcessing ? "Ask a follow‑up…" : "Ask Peekaboo…", text: self.$inputText)
                .textFieldStyle(.roundedBorder)
                .focused(self.$isInputFocused)
                .onSubmit(self.onSubmit)

            Button(action: self.onSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        self.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.secondary
                            : Color.accentColor)
            }
            .buttonStyle(.borderless)
            .disabled(self.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
