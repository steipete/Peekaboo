import SwiftUI
import PeekabooCore
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
            if isVoiceMode {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            TextField(isProcessing ? "Ask a follow-up..." : "Ask Peekaboo...", text: $inputText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isInputFocused)
                .onSubmit {
                    onSubmit()
                }

            // Voice mode toggle
            Button(action: { isVoiceMode.toggle() }) {
                Image(systemName: isVoiceMode ? "keyboard" : "mic")
                    .font(.body)
                    .foregroundColor(isVoiceMode ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(isVoiceMode ? "Switch to text input" : "Switch to voice input")

            Button(action: onSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty && !isVoiceMode)
        }
    }
}

/// Voice input interface with recording controls
struct VoiceInputView: View {
    @Environment(SpeechRecognizer.self) private var speechRecognizer
    @Environment(RealtimeVoiceService.self) private var realtimeService
    
    @State private var useRealtimeMode = true  // Enable realtime mode by default
    @State private var showRealtimeWindow = false
    
    let onToggleRecording: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Mode toggle
            HStack {
                Label("Realtime Mode", systemImage: "waveform.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Toggle("", isOn: $useRealtimeMode)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .padding(.horizontal)
            
            if useRealtimeMode {
                // Realtime mode UI
                VStack(spacing: 12) {
                    if realtimeService.isConnected {
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
                        Text(realtimeService.connectionState.rawValue.capitalized)
                            .font(.headline)
                        
                        // Live transcript
                        if !realtimeService.currentTranscript.isEmpty {
                            Text(realtimeService.currentTranscript)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .frame(maxHeight: 60)
                        }
                        
                        // End session button
                        Button("End Session") {
                            Task {
                                await realtimeService.endSession()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        // Start session button
                        Button(action: {
                            showRealtimeWindow = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.linearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                
                                Text("Start Realtime Conversation")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .frame(minHeight: 200)
            } else {
                // Traditional recording mode
                VStack(spacing: 8) {
                    if speechRecognizer.isListening {
                        HStack(spacing: 4) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(speechRecognizer.isListening ? 1.2 : 0.8)
                                    .animation(
                                        Animation.easeInOut(duration: 0.6)
                                            .repeatForever()
                                            .delay(Double(index) * 0.2),
                                        value: speechRecognizer.isListening)
                            }
                        }
                        .frame(height: 20)
                    }

                    Text(speechRecognizer.transcript.isEmpty ? "Listening..." : speechRecognizer.transcript)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .frame(maxHeight: 100)

                    // Microphone button
                    Button(action: onToggleRecording) {
                        Image(systemName: speechRecognizer.isListening ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(speechRecognizer.isListening ? .red : .accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .frame(minHeight: 200)
            }
        }
        .sheet(isPresented: $showRealtimeWindow) {
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
                if isVoiceMode {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                TextField("What would you like me to do?", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($isInputFocused)
                    .onSubmit {
                        onSubmit()
                    }

                Button(action: onSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)

            // Recent sessions if any
            if !sessions.isEmpty {
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(sessions.prefix(3)) { session in
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
                                    onSelectSession(session)
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