import AVFoundation
import Foundation
import Observation

/// Provides speech-to-text capabilities for voice-driven automation.
///
/// `SpeechRecognizer` enables users to interact with Peekaboo using voice commands by
/// recording audio and sending it to AI models for superior transcription quality.
/// This approach provides better accuracy than system speech recognition.
///
/// ## Overview
///
/// The speech recognizer:
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
@Observable
@MainActor
final class SpeechRecognizer: NSObject {
    var isListening = false
    var transcript = ""
    var isAvailable = false
    var error: Error?

    private var audioRecorder: AudioRecorder?
    private let settings: PeekabooSettings

    init(settings: PeekabooSettings) {
        self.settings = settings
        super.init()
        self.audioRecorder = AudioRecorder(settings: settings)
        self.checkAuthorization()
    }

    func requestAuthorization() async -> Bool {
        guard let recorder = audioRecorder else { return false }
        return await recorder.requestAuthorization()
    }

    func startListening() throws {
        guard let recorder = audioRecorder else {
            throw SpeechError.notInitialized
        }

        guard self.isAvailable else {
            throw SpeechError.notAuthorized
        }

        guard !self.isListening else { return }

        // Reset transcript
        self.transcript = ""
        self.error = nil

        // Start recording
        try recorder.startRecording()
        self.isListening = true

        // Observe recorder state
        Task {
            await self.observeRecorderState()
        }
    }

    func stopListening() {
        guard self.isListening else { return }

        self.audioRecorder?.stopRecording()
        self.isListening = false
    }

    private func observeRecorderState() async {
        guard let recorder = audioRecorder else { return }

        // Wait a bit for transcription to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Update transcript from recorder
        self.transcript = recorder.transcript
        self.error = recorder.error
        self.isAvailable = recorder.isAvailable
    }

    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            self.isAvailable = true
        case .denied, .restricted:
            self.isAvailable = false
        case .notDetermined:
            self.isAvailable = false
        @unknown default:
            self.isAvailable = false
        }
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case notAuthorized
    case notInitialized
    case requestCreationFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Microphone access is not authorized. Please enable it in System Settings."
        case .notInitialized:
            "Audio recorder not initialized."
        case .requestCreationFailed:
            "Failed to create audio recording request."
        }
    }
}
