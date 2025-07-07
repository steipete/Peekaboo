import Foundation
import Observation
import Speech

@Observable
@MainActor
final class SpeechRecognizer: NSObject {
    var isListening = false
    var transcript = ""
    var isAvailable = false
    var error: Error?

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    override init() {
        super.init()
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.recognizer?.delegate = self
        self.checkAuthorization()
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.isAvailable = status == .authorized
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    func startListening() throws {
        guard self.isAvailable else {
            throw SpeechError.notAuthorized
        }

        guard !self.isListening else { return }

        // Reset
        self.stopListening()

        // Note: AVAudioSession is not available on macOS
        // Audio input configuration happens automatically

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        // Start recognition task
        self.recognitionTask = self.recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString

                    if result.isFinal {
                        self.stopListening()
                    }
                }

                if let error {
                    self.error = error
                    self.stopListening()
                }
            }
        }

        // Configure audio input
        let recordingFormat = self.audioEngine.inputNode.outputFormat(forBus: 0)
        self.audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        self.audioEngine.prepare()
        try self.audioEngine.start()

        self.isListening = true
        self.transcript = ""
        self.error = nil
    }

    func stopListening() {
        guard self.isListening else { return }

        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        self.recognitionRequest?.endAudio()
        self.recognitionTask?.cancel()

        self.recognitionRequest = nil
        self.recognitionTask = nil
        self.isListening = false
    }

    private func checkAuthorization() {
        switch SFSpeechRecognizer.authorizationStatus() {
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

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognizer: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            self.isAvailable = available
        }
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case notAuthorized
    case requestCreationFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Speech recognition is not authorized. Please enable it in System Preferences."
        case .requestCreationFailed:
            "Failed to create speech recognition request."
        }
    }
}
