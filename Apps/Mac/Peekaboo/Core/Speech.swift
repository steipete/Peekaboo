import AVFoundation
import Foundation
import Observation
import Speech

/// Provides speech-to-text capabilities for voice-driven automation.
///
/// `SpeechRecognizer` enables users to interact with Peekaboo using voice commands.
/// It supports multiple recognition methods:
/// - Native macOS Speech framework (no API key required)
/// - OpenAI Whisper API for enhanced accuracy
/// - Direct audio streaming to AI providers (for models that support audio input)
///
/// ## Overview
///
/// The speech recognizer:
/// - Uses native macOS Speech framework by default (no API key required)
/// - Optionally uses OpenAI Whisper for better accuracy
/// - Can record raw audio for direct submission to AI providers
/// - Requests and manages microphone permissions
/// - Provides real-time speech transcription
/// - Handles recognition errors gracefully
/// - Supports continuous listening for voice commands
///
/// ## Topics
///
/// ### State Management
///
/// - ``isListening``
/// - ``transcript``
/// - ``isAvailable``
/// - ``error``
///
/// ### Recognition Control
///
/// - ``requestAuthorization()``
/// - ``startListening()``
/// - ``stopListening()``
///
/// ### Delegate Conformance
///
/// Conforms to `SFSpeechRecognizerDelegate` for availability updates.
/// Recognition modes available for speech input
public enum RecognitionMode: String, CaseIterable {
    case native = "Native macOS"
    case whisper = "OpenAI Whisper"
    case direct = "Direct to AI"
    
    var requiresOpenAIKey: Bool {
        switch self {
        case .native, .direct:
            return false
        case .whisper:
            return true
        }
    }
    
    var description: String {
        switch self {
        case .native:
            return "Built-in macOS speech recognition (no API key required)"
        case .whisper:
            return "OpenAI Whisper for better accuracy (requires OpenAI key)"
        case .direct:
            return "Send audio directly to AI provider for native processing"
        }
    }
}

@Observable
@MainActor
final class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
    var isListening = false
    var transcript = ""
    var isAvailable = false
    var error: Error?
    
    // Recognition mode
    var recognitionMode: RecognitionMode = .native
    
    // Native speech recognition
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Optional Whisper-based recorder for enhanced accuracy
    private var audioRecorder: AudioRecorder?
    private let settings: PeekabooSettings
    
    // For direct audio recording
    private var directAudioRecorder: AVAudioRecorder?
    private var directAudioURL: URL?
    private(set) var recordedAudioData: Data?
    private(set) var recordedAudioDuration: TimeInterval?
    
    init(settings: PeekabooSettings) {
        self.settings = settings
        super.init()
        
        // Initialize native speech recognizer
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.speechRecognizer?.delegate = self
        
        // Initialize Whisper recorder if API key available
        if !settings.openAIAPIKey.isEmpty {
            self.audioRecorder = AudioRecorder(settings: settings)
        }
        
        self.checkAuthorization()
    }
    
    func requestAuthorization() async -> Bool {
        // Request both speech recognition and microphone permissions
        let speechAuthStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        let microphoneAuthStatus = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        
        let authorized = speechAuthStatus && microphoneAuthStatus
        self.isAvailable = authorized
        return authorized
    }
    
    func startListening() throws {
        guard self.isAvailable else {
            throw SpeechError.notAuthorized
        }
        
        guard !self.isListening else { return }
        
        // Reset state
        self.transcript = ""
        self.error = nil
        self.recordedAudioData = nil
        self.recordedAudioDuration = nil
        
        // Decide which recognition method to use based on mode
        switch recognitionMode {
        case .native:
            try startNativeRecognition()
        case .whisper:
            if !settings.openAIAPIKey.isEmpty {
                try startWhisperRecognition()
            } else {
                // Fall back to native if no OpenAI key
                try startNativeRecognition()
                self.error = SpeechError.apiKeyRequired
            }
        case .direct:
            try startDirectRecording()
        }
        
        self.isListening = true
    }
    
    func stopListening() {
        guard self.isListening else { return }
        
        switch recognitionMode {
        case .native:
            // Stop native recognition
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
            recognitionRequest = nil
            recognitionTask = nil
            
        case .whisper:
            // Stop Whisper recording
            audioRecorder?.stopRecording()
            
        case .direct:
            // Stop direct recording
            stopDirectRecording()
        }
        
        self.isListening = false
    }
    
    private func startNativeRecognition() throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // On macOS, we don't need to configure AVAudioSession
        // It's iOS-only API
        
        // Create and configure request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Allow network-based recognition for better accuracy
        
        // Get input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                if let error = error {
                    self.error = error
                    self.isListening = false
                }
            }
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func startWhisperRecognition() throws {
        guard let recorder = audioRecorder else {
            // Fall back to native if Whisper not available
            try startNativeRecognition()
            return
        }
        
        // Start Whisper recording
        try recorder.startRecording()
        
        // Monitor recorder state
        Task {
            await self.observeRecorderState()
        }
    }
    
    private func observeRecorderState() async {
        guard let recorder = audioRecorder else { return }
        
        // Continue observing until recording stops
        while self.isListening && recorder.isRecording {
            // Update transcript and error state from recorder
            if recorder.transcript != self.transcript {
                self.transcript = recorder.transcript
            }
            if let error = recorder.error {
                self.error = error
                self.isListening = false
                break
            }
            
            // Small delay to avoid tight loop
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    private func checkAuthorization() {
        // Check both speech recognition and microphone permissions
        let speechAuthStatus = SFSpeechRecognizer.authorizationStatus()
        let microphoneAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        self.isAvailable = speechAuthStatus == .authorized && microphoneAuthStatus == .authorized
    }
    
    // MARK: - Direct Audio Recording
    
    private func startDirectRecording() throws {
        // Create temporary file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "peekaboo_direct_recording_\(UUID().uuidString).wav"
        directAudioURL = tempDir.appendingPathComponent(fileName)
        
        guard let recordingURL = directAudioURL else {
            throw SpeechError.recordingFailed
        }
        
        // Configure audio settings for high-quality recording
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0, // 16kHz is standard for speech
            AVNumberOfChannelsKey: 1, // Mono
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        // Create and start recorder
        directAudioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
        directAudioRecorder?.prepareToRecord()
        directAudioRecorder?.record()
        
        // Update transcript to show recording status
        self.transcript = "[Recording audio for AI processing...]"
    }
    
    private func stopDirectRecording() {
        guard let recorder = directAudioRecorder else { return }
        
        // Stop recording
        recorder.stop()
        recordedAudioDuration = recorder.currentTime
        
        // Read the audio data
        if let url = directAudioURL,
           let data = try? Data(contentsOf: url) {
            recordedAudioData = data
            
            // Update transcript to show audio is ready
            let duration = Int(recordedAudioDuration ?? 0)
            self.transcript = "[Audio recorded: \(duration) seconds - ready to send to AI]"
        }
        
        // Clean up
        directAudioRecorder = nil
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case notAuthorized
    case notInitialized
    case requestCreationFailed
    case recordingFailed
    case apiKeyRequired

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Microphone access is not authorized. Please enable it in System Settings."
        case .notInitialized:
            "Audio recorder not initialized."
        case .requestCreationFailed:
            "Failed to create audio recording request."
        case .recordingFailed:
            "Failed to start audio recording."
        case .apiKeyRequired:
            "OpenAI API key required for Whisper transcription."
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognizer {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        // Update availability when speech recognizer availability changes
        Task { @MainActor in
            self.checkAuthorization()
        }
    }
}
