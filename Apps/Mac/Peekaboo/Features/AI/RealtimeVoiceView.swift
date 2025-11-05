//
//  RealtimeVoiceView.swift
//  Peekaboo
//

import PeekabooCore
import SwiftUI
import Tachikoma
import TachikomaAudio

/// Real-time voice conversation interface using OpenAI Realtime API
struct RealtimeVoiceView: View {
    @Environment(RealtimeVoiceService.self) private var realtimeService
    @Environment(\.dismiss) private var dismiss

    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            self.headerView

            // Connection status
            self.connectionStatusView

            // Main interaction area
            if self.realtimeService.isConnected {
                self.connectedView
            } else {
                self.disconnectedView
            }

            // Conversation transcript
            if !self.realtimeService.conversationHistory.isEmpty {
                self.transcriptView
            }

            Spacer()

            // Action buttons
            self.actionButtons
        }
        .padding(24)
        .frame(width: 520, height: 640)
        .alert("Connection Error", isPresented: self.$showError) {
            Button("OK") {
                self.showError = false
            }
        } message: {
            Text(self.errorMessage)
        }
        .onAppear {
            self.startPulseAnimation()
        }
    }

    // MARK: - View Components

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))

            Text("Realtime Voice Assistant")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Have a natural conversation with Peekaboo")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var connectionStatusView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(self.realtimeService.isConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            Text(self.realtimeService.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundColor(.secondary)

            if self.realtimeService.isConnected {
                Text("•")
                    .foregroundColor(.secondary)

                Text(self.realtimeService.connectionState.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var connectedView: some View {
        VStack(spacing: 20) {
            // Visual feedback circle
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 180, height: 180)

                // Activity indicator based on state
                if self.realtimeService.connectionState == .listening {
                    // Recording animation
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing),
                            lineWidth: 3)
                        .frame(width: 180, height: 180)
                        .scaleEffect(self.pulseAnimation ? 1.1 : 1.0)
                        .opacity(self.pulseAnimation ? 0.6 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: self.pulseAnimation)
                } else if self.realtimeService.connectionState == .speaking {
                    // Speaking animation
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            .frame(width: 180, height: 180)
                            .scaleEffect(1.0 + Double(index) * 0.15)
                            .opacity(1.0 - Double(index) * 0.3)
                            .animation(
                                .easeOut(duration: 2.0)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.4),
                                value: self.pulseAnimation)
                    }
                } else if self.realtimeService.connectionState == .processing {
                    // Processing animation
                    ProgressView()
                        .scaleEffect(1.5)
                }

                // Center icon
                Image(systemName: self.iconForState)
                    .font(.system(size: 60))
                    .foregroundColor(self.colorForState)
            }

            // Status text
            Text(self.statusText)
                .font(.headline)
                .foregroundColor(.primary)

            // Audio level indicator
            if self.realtimeService.audioLevel > 0 {
                self.audioLevelView
            }

            // Current transcript
            if !self.realtimeService.currentTranscript.isEmpty {
                Text(self.realtimeService.currentTranscript)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .transition(.opacity)
            }
        }
    }

    private var disconnectedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Not Connected")
                .font(.headline)
                .foregroundColor(.secondary)

            if self.isConnecting {
                ProgressView("Connecting...")
                    .progressViewStyle(.linear)
                    .frame(width: 200)
            } else {
                Button("Start Conversation") {
                    self.startConversation()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Conversation History", systemImage: "text.bubble")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(
                            Array(self.realtimeService.conversationHistory.enumerated()),
                            id: \.offset)
                        { index, message in
                            HStack {
                                Text(message)
                                    .font(.caption)
                                    .padding(8)
                                    .background(message.hasPrefix("User:") ? Color.blue.opacity(0.1) : Color.gray
                                        .opacity(0.1))
                                    .cornerRadius(8)
                                    .id(index)

                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 150)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                .onChange(of: self.realtimeService.conversationHistory.count) { _, _ in
                    // Scroll to bottom when new messages arrive
                    withAnimation {
                        proxy.scrollTo(self.realtimeService.conversationHistory.count - 1, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var audioLevelView: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                Rectangle()
                    .fill(index < Int(self.realtimeService.audioLevel * 20) ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 20)
            }
        }
        .frame(height: 20)
        .cornerRadius(2)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Close") {
                Task {
                    await self.realtimeService.endSession()
                }
                self.dismiss()
            }
            .buttonStyle(.bordered)

            if self.realtimeService.isConnected {
                if self.realtimeService.connectionState == .speaking {
                    Button("Interrupt") {
                        Task {
                            try? await self.realtimeService.interrupt()
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Button("End Session") {
                    Task {
                        await self.realtimeService.endSession()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }

    // MARK: - Helper Properties

    private var iconForState: String {
        switch self.realtimeService.connectionState {
        case .idle:
            "mic.slash"
        case .listening:
            "mic.fill"
        case .processing:
            "brain"
        case .speaking:
            "speaker.wave.3.fill"
        case .error:
            "exclamationmark.triangle.fill"
        }
    }

    private var colorForState: Color {
        switch self.realtimeService.connectionState {
        case .idle:
            .gray
        case .listening:
            .red
        case .processing:
            .blue
        case .speaking:
            .green
        case .error:
            .orange
        }
    }

    private var statusText: String {
        switch self.realtimeService.connectionState {
        case .idle:
            "Ready to listen"
        case .listening:
            "Listening..."
        case .processing:
            "Processing..."
        case .speaking:
            "Speaking..."
        case .error:
            "Error occurred"
        }
    }

    // MARK: - Actions

    private func startConversation() {
        self.isConnecting = true
        self.errorMessage = ""

        Task {
            do {
                try await self.realtimeService.startSession()
                self.isConnecting = false
            } catch {
                self.isConnecting = false
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }

    private func startPulseAnimation() {
        self.pulseAnimation = true
    }
}

// MARK: - Voice Settings View

struct RealtimeVoiceSettingsView: View {
    @Environment(RealtimeVoiceService.self) private var realtimeService
    @AppStorage("realtimeVoice") private var selectedVoice = "alloy"
    @AppStorage("realtimeInstructions") private var customInstructions = ""
    @AppStorage("realtimeVAD") private var useVAD = true

    var body: some View {
        Form {
            Section("Voice Selection") {
                Picker("Assistant Voice", selection: self.$selectedVoice) {
                    ForEach(RealtimeVoice.allCases, id: \.rawValue) { voice in
                        Text(voice.displayName)
                            .tag(voice.rawValue)
                    }
                }
                .onChange(of: self.selectedVoice) { _, newValue in
                    if let voice = RealtimeVoice(rawValue: newValue) {
                        self.realtimeService.updateVoice(voice)
                    }
                }

                Text("Voice changes will take effect in the next conversation")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Instructions") {
                TextEditor(text: self.$customInstructions)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)

                Text("Custom instructions for the AI assistant")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Voice Detection") {
                Toggle("Use Voice Activity Detection (VAD)", isOn: self.$useVAD)

                Text("VAD automatically detects when you start and stop speaking")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - RealtimeVoice Extension

extension RealtimeVoice {
    var displayName: String {
        switch self {
        case .alloy: "Alloy (Neutral)"
        case .echo: "Echo (Smooth)"
        case .fable: "Fable (British)"
        case .onyx: "Onyx (Deep)"
        case .nova: "Nova (Friendly)"
        case .shimmer: "Shimmer (Energetic)"
        }
    }
}
