import AVFoundation
import Foundation
import UniformTypeIdentifiers
#if os(iOS) || os(watchOS) || os(tvOS)
import AVFAudio
#endif

/// Protocol defining audio input capabilities for the agent system
@MainActor
public protocol AudioInputServiceProtocol: AnyObject, Sendable {
    /// Start recording audio from the default input device
    func startRecording() async throws

    /// Stop recording and return the transcribed text
    func stopRecording() async throws -> String

    /// Transcribe an audio file and return the text
    func transcribeAudioFile(_ url: URL) async throws -> String

    /// Check if currently recording
    var isRecording: Bool { get }

    /// Check if audio input is available
    var isAvailable: Bool { get }
}

/// Default implementation of audio input service
@MainActor
public final class AudioInputService: AudioInputServiceProtocol, @unchecked Sendable {
    private let aiService: PeekabooAIService
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    public private(set) var isRecording = false

    public var isAvailable: Bool {
        // On macOS, check if we have any audio input devices
        #if os(macOS)
        return true // Simplified for now - could check AVCaptureDevice
        #else
        return AVAudioSession.sharedInstance().availableInputs?.isEmpty == false
        #endif
    }

    public init(aiService: PeekabooAIService) {
        self.aiService = aiService
    }

    public func startRecording() async throws {
        guard !self.isRecording else {
            throw AudioInputError.alreadyRecording
        }

        // Configure audio session (iOS only)
        #if os(iOS) || os(watchOS) || os(tvOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true)
        #endif

        // Create temporary file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "peekaboo_recording_\(UUID().uuidString).wav"
        recordingURL = tempDir.appendingPathComponent(fileName)

        guard let recordingURL else {
            throw AudioInputError.invalidURL
        }

        // Configure audio settings for optimal AI transcription
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0, // 16kHz is optimal for speech recognition
            AVNumberOfChannelsKey: 1, // Mono
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]

        // Create and start recorder
        self.audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
        self.audioRecorder?.prepareToRecord()
        self.audioRecorder?.record()
        self.isRecording = true
    }

    public func stopRecording() async throws -> String {
        guard self.isRecording else {
            throw AudioInputError.notRecording
        }

        // Stop recording
        self.audioRecorder?.stop()
        self.isRecording = false

        // Deactivate audio session (iOS only)
        #if os(iOS) || os(watchOS) || os(tvOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setActive(false)
        #endif

        guard let recordingURL else {
            throw AudioInputError.invalidURL
        }

        // Transcribe the recorded audio
        let transcript = try await transcribeAudioFile(recordingURL)

        // Clean up temporary file
        try? FileManager.default.removeItem(at: recordingURL)
        self.recordingURL = nil

        return transcript
    }

    public func transcribeAudioFile(_ url: URL) async throws -> String {
        // Validate file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioInputError.fileNotFound(url)
        }

        // Validate file type
        let supportedExtensions = ["wav", "mp3", "m4a", "aiff", "aac", "flac"]
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw AudioInputError.unsupportedFileType(url.pathExtension)
        }

        // Check file size (max 25MB for most APIs)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let maxSize: Int64 = 25 * 1024 * 1024 // 25MB
        guard fileSize <= maxSize else {
            throw AudioInputError.fileTooLarge(fileSize, maxSize)
        }

        // Use AI service to transcribe
        // For now, we'll use OpenAI's Whisper API if available
        let transcript = try await transcribeWithWhisper(url)

        return transcript
    }

    private func transcribeWithWhisper(_ url: URL) async throws -> String {
        // Check if we have OpenAI configured
        guard let openAIKey = PeekabooServices.shared.configuration.getOpenAIAPIKey(),
              !openAIKey.isEmpty
        else {
            throw AudioInputError.noTranscriptionService
        }

        // Create multipart form data request
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // Add file data
        let audioData = try Data(contentsOf: url)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body
            .append("Content-Disposition: form-data; name=\"file\"; filename=\"\(url.lastPathComponent)\"\r\n"
                .data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw AudioInputError.transcriptionFailed("Invalid response from Whisper API")
        }

        // Parse response
        struct WhisperResponse: Codable {
            let text: String
        }

        let decoder = JSONDecoder()
        let whisperResponse = try decoder.decode(WhisperResponse.self, from: data)

        return whisperResponse.text
    }
}

/// Errors that can occur during audio input operations
public enum AudioInputError: LocalizedError {
    case alreadyRecording
    case notRecording
    case invalidURL
    case fileNotFound(URL)
    case unsupportedFileType(String)
    case fileTooLarge(Int64, Int64)
    case noTranscriptionService
    case transcriptionFailed(String)
    case microphonePermissionDenied

    public var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            "Audio recording is already in progress"
        case .notRecording:
            "No audio recording is in progress"
        case .invalidURL:
            "Invalid recording URL"
        case let .fileNotFound(url):
            "Audio file not found: \(url.path)"
        case let .unsupportedFileType(type):
            "Unsupported audio file type: \(type)"
        case let .fileTooLarge(size, maxSize):
            "Audio file too large: \(size) bytes (max: \(maxSize) bytes)"
        case .noTranscriptionService:
            "No transcription service configured. Please set OPENAI_API_KEY."
        case let .transcriptionFailed(reason):
            "Transcription failed: \(reason)"
        case .microphonePermissionDenied:
            "Microphone permission denied"
        }
    }
}
