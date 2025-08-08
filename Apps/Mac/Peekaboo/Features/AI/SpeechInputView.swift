import SwiftUI
import AVFoundation
import Tachikoma

/// Voice input interface for controlling agents with speech
struct SpeechInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var speechRecognizer: SpeechRecognizer
    @State private var isRecordingPermissionGranted = false
    @State private var showingPermissionAlert = false
    
    // Agent integration
    let agent: PeekabooAgent
    let onTranscriptReceived: (String) -> Void
    let onAudioReceived: (Data, TimeInterval) -> Void
    
    // UI state
    @State private var recordingProgress: Double = 0.0
    @State private var recordingTimer: Timer?
    @State private var recordingStartTime: Date?
    
    init(
        settings: PeekabooSettings,
        agent: PeekabooAgent,
        onTranscriptReceived: @escaping (String) -> Void = { _ in },
        onAudioReceived: @escaping (Data, TimeInterval) -> Void = { _, _ in }
    ) {
        self.agent = agent
        self.onTranscriptReceived = onTranscriptReceived
        self.onAudioReceived = onAudioReceived
        self._speechRecognizer = State(initialValue: SpeechRecognizer(settings: settings))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Voice Control")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Speak to control your agent")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Recognition mode selector
            Picker("Recognition Mode", selection: $speechRecognizer.recognitionMode) {
                ForEach(RecognitionMode.allCases, id: \.self) { mode in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.rawValue)
                            .font(.headline)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(speechRecognizer.isListening)
            
            // Recording visualization
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 200, height: 200)
                
                // Progress ring
                if speechRecognizer.isListening {
                    Circle()
                        .trim(from: 0, to: recordingProgress)
                        .stroke(
                            AngularGradient(
                                colors: [.blue, .green, .blue],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 190, height: 190)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.1), value: recordingProgress)
                }
                
                // Microphone icon
                VStack(spacing: 8) {
                    Image(systemName: speechRecognizer.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(speechRecognizer.isListening ? .red : .primary)
                        .scaleEffect(speechRecognizer.isListening ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: speechRecognizer.isListening)
                    
                    Text(speechRecognizer.isListening ? "Listening..." : "Tap to start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onTapGesture {
                Task {
                    await toggleRecording()
                }
            }
            
            // Transcript display
            if !speechRecognizer.transcript.isEmpty {
                ScrollView {
                    Text(speechRecognizer.transcript)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                .frame(maxHeight: 120)
            }
            
            // Error display
            if let error = speechRecognizer.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
            
            // Action buttons
            HStack(spacing: 16) {
                // Cancel button
                Button("Cancel") {
                    stopRecording()
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                // Send to agent button
                Button("Send to Agent") {
                    sendToAgent()
                }
                .buttonStyle(.borderedProminent)
                .disabled(speechRecognizer.transcript.isEmpty || agent.isProcessing)
                
                // Stop/Start recording button
                Button(speechRecognizer.isListening ? "Stop" : "Record") {
                    Task {
                        await toggleRecording()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!isRecordingPermissionGranted)
            }
        }
        .padding(24)
        .frame(width: 480, height: 560)
        .onAppear {
            checkPermissions()
        }
        .alert("Recording Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Peekaboo needs microphone access to use voice control. Please enable it in System Settings.")
        }
    }
    
    // MARK: - Private Methods
    
    private func checkPermissions() {
        Task {
            let authorized = await speechRecognizer.requestAuthorization()
            await MainActor.run {
                self.isRecordingPermissionGranted = authorized
                if !authorized {
                    self.showingPermissionAlert = true
                }
            }
        }
    }
    
    private func toggleRecording() async {
        if speechRecognizer.isListening {
            stopRecording()
        } else {
            await startRecording()
        }
    }
    
    private func startRecording() async {
        guard isRecordingPermissionGranted else {
            showingPermissionAlert = true
            return
        }
        
        do {
            try speechRecognizer.startListening()
            recordingStartTime = Date()
            startRecordingTimer()
        } catch {
            speechRecognizer.error = error
        }
    }
    
    private func stopRecording() {
        speechRecognizer.stopListening()
        stopRecordingTimer()
        
        // If we have recorded audio data (from direct mode), pass it to the callback
        if let audioData = speechRecognizer.recordedAudioData,
           let duration = speechRecognizer.recordedAudioDuration {
            onAudioReceived(audioData, duration)
        }
        
        // Always pass transcript if available
        if !speechRecognizer.transcript.isEmpty {
            onTranscriptReceived(speechRecognizer.transcript)
        }
    }
    
    private func sendToAgent() {
        guard !speechRecognizer.transcript.isEmpty else { return }
        
        let transcript = speechRecognizer.transcript
        
        // Close the speech input view
        dismiss()
        
        // Send to agent based on recognition mode
        Task {
            do {
                if speechRecognizer.recognitionMode == .direct,
                   let audioData = speechRecognizer.recordedAudioData,
                   let duration = speechRecognizer.recordedAudioDuration {
                    // Send raw audio to agent
                    try await agent.executeTaskWithAudio(
                        audioData: audioData,
                        duration: duration,
                        transcript: transcript
                    )
                } else {
                    // Send transcribed text to agent
                    try await agent.executeTask(transcript)
                }
            } catch {
                // Handle error - could show an alert or update UI state
                print("Failed to execute agent task: \\(error)")
            }
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard let startTime = recordingStartTime else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                
                // Update progress (max 30 seconds for visual purposes)
                recordingProgress = min(elapsed / 30.0, 1.0)
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingProgress = 0.0
        recordingStartTime = nil
    }
}

// MARK: - Preview

#Preview {
    SpeechInputView(
        settings: PeekabooSettings(),
        agent: PeekabooAgent(
            settings: PeekabooSettings(),
            sessionStore: SessionStore()
        )
    )
}