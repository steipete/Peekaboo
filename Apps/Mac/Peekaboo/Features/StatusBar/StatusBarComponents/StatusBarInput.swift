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

/// Voice input (dictation) interface with minimal controls.
struct VoiceInputView: View {
    @Environment(SpeechRecognizer.self) private var speechRecognizer

    let onClose: () -> Void
    let onSubmitTranscript: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(self.speechRecognizer.isListening ? "Listening…" : "Dictation", systemImage: "mic")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button("Close", action: self.onClose)
                    .buttonStyle(.borderless)
            }

            Text(self.speechRecognizer.transcript.isEmpty ? "Speak to dictate your next request." : self
                .speechRecognizer.transcript)
                .font(.body)
                .foregroundStyle(self.speechRecognizer.transcript.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(4)
                .textSelection(.enabled)

            HStack(spacing: 10) {
                Button {
                    self.toggleRecording()
                } label: {
                    Label(
                        self.speechRecognizer.isListening ? "Stop" : "Start",
                        systemImage: self.speechRecognizer.isListening ? "stop.circle.fill" : "mic.circle.fill")
                }
                .buttonStyle(.bordered)

                Button("Send") {
                    let transcript = self.speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !transcript.isEmpty else { return }
                    self.speechRecognizer.stopListening()
                    self.onSubmitTranscript(transcript)
                    self.onClose()
                }
                .buttonStyle(.borderedProminent)
                .disabled(self.speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            self.startListeningIfPossible()
        }
        .onDisappear {
            self.speechRecognizer.stopListening()
        }
    }

    private func toggleRecording() {
        if self.speechRecognizer.isListening {
            self.speechRecognizer.stopListening()
        } else {
            self.startListeningIfPossible()
        }
    }

    private func startListeningIfPossible() {
        Task {
            do {
                try self.speechRecognizer.startListening()
            } catch {
                // Keep the UI responsive; the parent view logs details when needed.
            }
        }
    }
}

/// Enhanced input area with voice mode detection
struct IdleStateInputView: View {
    @Binding var inputText: String
    @Binding var isVoiceMode: Bool
    @FocusState.Binding var isInputFocused: Bool

    let sessions: [ConversationSession]
    let onSubmit: () -> Void
    let onSelectSession: (ConversationSession) -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header with ghost icon
            VStack(spacing: 8) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                    .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.5))

                Text("Ask Peekaboo")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.top)

            // Input field - always visible
            HStack(spacing: 8) {
                if self.isVoiceMode {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                TextField("What would you like me to do?", text: self.$inputText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused(self.$isInputFocused)
                    .onSubmit {
                        self.onSubmit()
                    }

                Button(action: self.onSubmit, label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                })
                .buttonStyle(.plain)
                .disabled(self.inputText.isEmpty)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)

            // Recent sessions if any
            if !self.sessions.isEmpty {
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(self.sessions.prefix(3)) { session in
                                HStack {
                                    Text(session.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Text(formatSessionDuration(session))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                                .cornerRadius(4)
                                .onTapGesture {
                                    self.onSelectSession(session)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 100)
                }
            }

            Spacer(minLength: 0)
        }
    }
}
