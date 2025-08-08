//
//  RealtimeVoiceView.swift
//  Peekaboo
//

import SwiftUI
import PeekabooCore
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
            headerView
            
            // Connection status
            connectionStatusView
            
            // Main interaction area
            if realtimeService.isConnected {
                connectedView
            } else {
                disconnectedView
            }
            
            // Conversation transcript
            if !realtimeService.conversationHistory.isEmpty {
                transcriptView
            }
            
            Spacer()
            
            // Action buttons
            actionButtons
        }
        .padding(24)
        .frame(width: 520, height: 640)
        .alert("Connection Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            startPulseAnimation()
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
                    endPoint: .bottomTrailing
                ))
            
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
                .fill(realtimeService.isConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            Text(realtimeService.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if realtimeService.isConnected {
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(realtimeService.connectionState.rawValue.capitalized)
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
                if realtimeService.connectionState == .listening {
                    // Recording animation
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .opacity(pulseAnimation ? 0.6 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                } else if realtimeService.connectionState == .speaking {
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
                                value: pulseAnimation
                            )
                    }
                } else if realtimeService.connectionState == .processing {
                    // Processing animation
                    ProgressView()
                        .scaleEffect(1.5)
                }
                
                // Center icon
                Image(systemName: iconForState)
                    .font(.system(size: 60))
                    .foregroundColor(colorForState)
            }
            
            // Status text
            Text(statusText)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Audio level indicator
            if realtimeService.audioLevel > 0 {
                audioLevelView
            }
            
            // Current transcript
            if !realtimeService.currentTranscript.isEmpty {
                Text(realtimeService.currentTranscript)
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
            
            if isConnecting {
                ProgressView("Connecting...")
                    .progressViewStyle(.linear)
                    .frame(width: 200)
            } else {
                Button("Start Conversation") {
                    startConversation()
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
                        ForEach(Array(realtimeService.conversationHistory.enumerated()), id: \.offset) { index, message in
                            HStack {
                                Text(message)
                                    .font(.caption)
                                    .padding(8)
                                    .background(message.hasPrefix("User:") ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
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
                .onChange(of: realtimeService.conversationHistory.count) { _, _ in
                    // Scroll to bottom when new messages arrive
                    withAnimation {
                        proxy.scrollTo(realtimeService.conversationHistory.count - 1, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var audioLevelView: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                Rectangle()
                    .fill(index < Int(realtimeService.audioLevel * 20) ? Color.green : Color.gray.opacity(0.3))
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
                    await realtimeService.endSession()
                }
                dismiss()
            }
            .buttonStyle(.bordered)
            
            if realtimeService.isConnected {
                if realtimeService.connectionState == .speaking {
                    Button("Interrupt") {
                        Task {
                            try? await realtimeService.interrupt()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("End Session") {
                    Task {
                        await realtimeService.endSession()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var iconForState: String {
        switch realtimeService.connectionState {
        case .idle:
            return "mic.slash"
        case .listening:
            return "mic.fill"
        case .processing:
            return "brain"
        case .speaking:
            return "speaker.wave.3.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var colorForState: Color {
        switch realtimeService.connectionState {
        case .idle:
            return .gray
        case .listening:
            return .red
        case .processing:
            return .blue
        case .speaking:
            return .green
        case .error:
            return .orange
        }
    }
    
    private var statusText: String {
        switch realtimeService.connectionState {
        case .idle:
            return "Ready to listen"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .speaking:
            return "Speaking..."
        case .error:
            return "Error occurred"
        }
    }
    
    // MARK: - Actions
    
    private func startConversation() {
        isConnecting = true
        errorMessage = ""
        
        Task {
            do {
                try await realtimeService.startSession()
                isConnecting = false
            } catch {
                isConnecting = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func startPulseAnimation() {
        pulseAnimation = true
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
                Picker("Assistant Voice", selection: $selectedVoice) {
                    ForEach(RealtimeVoice.allCases, id: \.rawValue) { voice in
                        Text(voice.displayName)
                            .tag(voice.rawValue)
                    }
                }
                .onChange(of: selectedVoice) { _, newValue in
                    if let voice = RealtimeVoice(rawValue: newValue) {
                        realtimeService.updateVoice(voice)
                    }
                }
                
                Text("Voice changes will take effect in the next conversation")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Instructions") {
                TextEditor(text: $customInstructions)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
                
                Text("Custom instructions for the AI assistant")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Voice Detection") {
                Toggle("Use Voice Activity Detection (VAD)", isOn: $useVAD)
                
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
        case .alloy: return "Alloy (Neutral)"
        case .echo: return "Echo (Smooth)"
        case .fable: return "Fable (British)"
        case .onyx: return "Onyx (Deep)"
        case .nova: return "Nova (Friendly)"
        case .shimmer: return "Shimmer (Energetic)"
        }
    }
}