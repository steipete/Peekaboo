import AVFoundation
import Foundation
import Observation
import Tachikoma
import TachikomaAudio

/// Records audio and sends it to AI models for transcription.
///
/// `AudioRecorder` provides a modern alternative to system speech recognition by
/// recording audio and sending it directly to AI models via Tachikoma for
/// superior transcription quality.
@Observable
@MainActor
final class AudioRecorder: NSObject {
    var isRecording = false
    var transcript = ""
    var isAvailable = true
    var error: Error?

    private var audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var audioBuffer = [AVAudioPCMBuffer]()
    private var recordingURL: URL?

    // AI transcription settings
    private let settings: PeekabooSettings

    init(settings: PeekabooSettings) {
        self.settings = settings
        super.init()
        self.checkMicrophonePermission()
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    self.isAvailable = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func startRecording() throws {
        guard self.isAvailable else {
            throw AudioError.notAuthorized
        }

        guard !self.isRecording else { return }

        // Reset state
        self.stopRecording()
        self.transcript = ""
        self.error = nil
        self.audioBuffer.removeAll()

        // Create temporary file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "peekaboo_audio_\(UUID().uuidString).wav"
        self.recordingURL = tempDir.appendingPathComponent(fileName)

        guard let recordingURL = self.recordingURL else {
            throw AudioError.fileCreationFailed
        }

        // Setup audio format - 16kHz mono for optimal AI transcription
        let inputNode = self.audioEngine.inputNode
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false)!

        // Create audio file
        self.audioFile = try AVAudioFile(forWriting: recordingURL, settings: recordingFormat.settings)

        // Install tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }

            // Write to file
            do {
                try self.audioFile?.write(from: buffer)
                self.audioBuffer.append(buffer)
            } catch {
                print("Failed to write audio buffer: \(error)")
            }
        }

        // Start audio engine
        self.audioEngine.prepare()
        try self.audioEngine.start()

        self.isRecording = true
    }

    func stopRecording() {
        guard self.isRecording else { return }

        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        self.isRecording = false

        // Transcribe the audio
        if let recordingURL = self.recordingURL {
            Task {
                await self.transcribeAudio(from: recordingURL)
            }
        }
    }

    private func transcribeAudio(from url: URL) async {
        do {
            // Check if OpenAI API key is available (required for Whisper)
            guard !self.settings.openAIAPIKey.isEmpty else {
                throw AudioError.noAPIKey
            }

            // Create AudioData from the recorded file
            let audioData = try AudioData(contentsOf: url)

            // Use Tachikoma's transcribe function with OpenAI Whisper
            let transcriptionResult = try await transcribe(
                audioData,
                using: .openai(.whisper1),
                language: "en")

            await MainActor.run {
                self.transcript = transcriptionResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Clean up audio file
            try? FileManager.default.removeItem(at: url)

        } catch {
            await MainActor.run {
                self.error = error
                self.transcript = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func checkMicrophonePermission() {
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

enum AudioError: LocalizedError {
    case notAuthorized
    case fileCreationFailed
    case transcriptionFailed
    case noAPIKey
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Microphone access is not authorized. Please enable it in System Settings."
        case .fileCreationFailed:
            "Failed to create audio recording file."
        case .transcriptionFailed:
            "Failed to transcribe audio."
        case .noAPIKey:
            "OpenAI API key is required for voice transcription. Please add your OpenAI API key in Settings."
        case let .apiError(message):
            "API Error: \(message)"
        }
    }
}
