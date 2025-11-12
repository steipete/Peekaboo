import PeekabooCore
import SwiftUI
import Tachikoma
import TachikomaAudio

// MARK: - Input Components

/// Text input area for the status bar
struct StatusBarInputView: View {
    @Binding var inputText: String
    @Binding var isVoiceMode: Bool
    @FocusState.Binding var isInputFocused: Bool

    let isProcessing: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if self.isVoiceMode {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            TextField(self.isProcessing ? "Ask a follow-up..." : "Ask Peekaboo...", text: self.$inputText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused(self.$isInputFocused)
                .onSubmit {
                    self.onSubmit()
                }

            // Voice mode toggle
            Button(action: { self.isVoiceMode.toggle() }, label: {
                Image(systemName: self.isVoiceMode ? "keyboard" : "mic")
                    .font(.body)
                    .foregroundColor(self.isVoiceMode ? .red : .secondary)
            })
            .buttonStyle(.plain)
            .help(self.isVoiceMode ? "Switch to text input" : "Switch to voice input")

            Button(action: self.onSubmit, label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            })
            .buttonStyle(.plain)
            .disabled(self.inputText.isEmpty && !self.isVoiceMode)
        }
    }
}

/// Voice input interface with recording controls
struct VoiceInputView: View {
    @Environment(SpeechRecognizer.self) private var speechRecognizer
    @Environment(RealtimeVoiceService.self) private var realtimeService

    @State private var useRealtimeMode = true // Enable realtime mode by default
    @State private var showRealtimeWindow = false

    let onToggleRecording: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Mode toggle
            HStack {
                Label("Realtime Mode", systemImage: "waveform.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("", isOn: self.$useRealtimeMode)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .padding(.horizontal)

            if self.useRealtimeMode {
                // Realtime mode UI
                VStack(spacing: 12) {
                    if self.realtimeService.isConnected {
                        // Connection status
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Current state
                        Text(self.realtimeService.connectionState.rawValue.capitalized)
                            .font(.headline)

                        // Live transcript
                        if !self.realtimeService.currentTranscript.isEmpty {
                            Text(self.realtimeService.currentTranscript)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .frame(maxHeight: 60)
                        }

                        // End session button
                        Button("End Session") {
                            Task {
                                await self.realtimeService.endSession()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        // Start session button
                        Button(action: {
                            self.showRealtimeWindow = true
                        }, label: {
                            VStack(spacing: 8) {
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.linearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing))

                                Text("Start Realtime Conversation")
                                    .font(.caption)
                            }
                        })
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .frame(minHeight: 200)
            } else {
                // Traditional recording mode
                VStack(spacing: 8) {
                    if self.speechRecognizer.isListening {
                        HStack(spacing: 4) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(self.speechRecognizer.isListening ? 1.2 : 0.8)
                                    .animation(
                                        Animation.easeInOut(duration: 0.6)
                                            .repeatForever()
                                            .delay(Double(index) * 0.2),
                                        value: self.speechRecognizer.isListening)
                            }
                        }
                        .frame(height: 20)
                    }

                    Text(self.speechRecognizer.transcript.isEmpty ? "Listening..." : self.speechRecognizer.transcript)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .frame(maxHeight: 100)

                    // Microphone button
                    Button(action: self.onToggleRecording, label: {
                        Image(systemName: self.speechRecognizer.isListening ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(self.speechRecognizer.isListening ? .red : .accentColor)
                    })
                    .buttonStyle(.plain)
                }
                .padding()
                .frame(minHeight: 200)
            }
        }
        .sheet(isPresented: self.$showRealtimeWindow) {
            RealtimeVoiceView()
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
