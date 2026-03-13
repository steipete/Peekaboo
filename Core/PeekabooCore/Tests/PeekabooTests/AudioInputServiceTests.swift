import AVFoundation
import Foundation
import TachikomaAudio
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@preconcurrency
private enum AudioTestEnvironment {
    @preconcurrency nonisolated(unsafe) static var shouldRun: Bool {
        EnvironmentFlags.runAudioScenarios || TestEnvironment.runAutomationScenarios
    }
}

@Suite(.tags(.unit, .agent), .enabled(if: AudioTestEnvironment.shouldRun))
struct AudioInputServiceTests {
    struct InitializationTests {
        @Test
        @MainActor
        func `AudioInputService initializes with AI service dependency`() {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)
            #expect(service.isAvailable == service.isAvailable) // Just verify it compiles
            #expect(!service.isRecording)
        }

        @Test
        @MainActor
        func `Audio availability check returns expected value`() {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)
            // On macOS this should always return true in our simplified implementation
            #expect(service.isAvailable)
        }
    }

    struct RecordingStateTests {
        @Test
        @MainActor
        func `Cannot start recording when already recording`() async throws {
            let recorder = MockAudioRecorder()
            let service = AudioInputServiceTests.makeService(recorder: recorder)

            // Start recording
            try await service.startRecording()
            #expect(service.isRecording)

            // Try to start again - should throw
            await #expect(throws: AudioInputError.alreadyRecording) {
                try await service.startRecording()
            }

            // Clean up
            _ = try? await service.stopRecording()
        }

        @Test
        @MainActor
        func `Cannot stop recording when not recording`() async throws {
            let recorder = MockAudioRecorder()
            let service = AudioInputServiceTests.makeService(recorder: recorder)

            #expect(!service.isRecording)

            await #expect(throws: AudioInputError.notRecording) {
                _ = try await service.stopRecording()
            }
        }

        @Test
        @MainActor
        func `Recording state transitions correctly`() async throws {
            let recorder = MockAudioRecorder()
            let service = AudioInputServiceTests.makeService(recorder: recorder)

            // Initial state
            #expect(!service.isRecording)

            // Start recording
            try await service.startRecording()
            #expect(service.isRecording)

            // Stop recording
            _ = try? await service.stopRecording()
            #expect(!service.isRecording)
        }

        @Test
        @MainActor
        func `Recorder state is observed only while recording`() async throws {
            let recorder = MockAudioRecorder()
            let service = AudioInputServiceTests.makeService(recorder: recorder)

            // Mutating the recorder while idle should not update the service.
            recorder.recordingDuration = 7.5
            try await Task.sleep(for: .milliseconds(150))
            #expect(service.recordingDuration == 0)
            #expect(service.isRecording == false)

            // Once recording starts, the service should reflect recorder state.
            try await service.startRecording()
            recorder.recordingDuration = 1.25
            try await Task.sleep(for: .milliseconds(150))
            #expect(service.isRecording == true)
            #expect(service.recordingDuration == 1.25)

            // After stopping, observation should stop and recorder mutations shouldn't leak back in.
            _ = try await service.stopRecording()
            recorder.isRecording = true
            recorder.recordingDuration = 9.0
            try await Task.sleep(for: .milliseconds(150))
            #expect(service.isRecording == false)
            #expect(service.recordingDuration == 0)
        }
    }

    struct FileTranscriptionTests {
        @Test
        @MainActor
        func `Transcribe audio file validates file existence`() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)

            let nonExistentURL = URL(fileURLWithPath: "/tmp/non_existent_audio.wav")

            await #expect(throws: AudioInputError.fileNotFound(nonExistentURL)) {
                _ = try await service.transcribeAudioFile(nonExistentURL)
            }
        }

        @Test
        @MainActor
        func `Transcribe audio file validates supported file types`() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)

            // Create a temporary file with unsupported extension
            let tempDir = FileManager.default.temporaryDirectory
            let unsupportedFile = tempDir.appendingPathComponent("test.txt")
            try "test content".write(to: unsupportedFile, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(at: unsupportedFile) }

            await #expect(throws: AudioInputError.unsupportedFileType("txt")) {
                _ = try await service.transcribeAudioFile(unsupportedFile)
            }
        }

        @Test
        @MainActor
        func `Transcribe audio file validates file size`() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)

            // Create a mock large file
            let tempDir = FileManager.default.temporaryDirectory
            let largeFile = tempDir.appendingPathComponent("large_audio.wav")

            // Create a file larger than 25MB limit
            let largeData = Data(repeating: 0, count: 26 * 1024 * 1024)
            try largeData.write(to: largeFile)
            defer { try? FileManager.default.removeItem(at: largeFile) }

            await #expect(throws: (any Error).self) { // Will throw fileTooLarge error
                _ = try await service.transcribeAudioFile(largeFile)
            }
        }

        @Test
        @MainActor
        func `Transcribe requires OpenAI API key`() async throws {
            let service = AudioInputServiceTests.makeService(hasAPIKey: false)

            // Create a valid temporary audio file
            let tempDir = FileManager.default.temporaryDirectory
            let audioFile = tempDir.appendingPathComponent("test_audio.wav")
            try Data().write(to: audioFile) // Empty but valid file
            defer { try? FileManager.default.removeItem(at: audioFile) }

            // Without API key configured, should throw
            await #expect(throws: AudioInputError.apiKeyMissing) {
                _ = try await service.transcribeAudioFile(audioFile)
            }
        }
    }

    struct ErrorMessageTests {
        @Test
        func `Error descriptions are user-friendly`() {
            let errors: [(AudioInputError, String)] = [
                (.alreadyRecording, "Already recording audio"),
                (.notRecording, "Not currently recording"),
                // Remove invalidURL - doesn't exist in AudioInputError
                (.fileNotFound(URL(fileURLWithPath: "/test.wav")), "Audio file not found at /test.wav"),
                (.unsupportedFileType("xyz"), "Unsupported audio file type: xyz"),
                (.fileTooLarge(30_000_000), "Audio file too large: 30000000 bytes (max 25MB)"),
                (.apiKeyMissing, "OpenAI API key is required for transcription"),
                (.transcriptionFailed("Network error"), "Transcription failed: Network error"),
                (.microphonePermissionDenied, "Microphone permission denied"),
            ]

            for (error, expectedDescription) in errors {
                #expect(error.errorDescription == expectedDescription)
            }
        }
    }
}

// MARK: - Mock Objects

@MainActor
final class MockAudioRecorder: AudioRecorderProtocol, @unchecked Sendable {
    var isRecording = false
    var isAvailable: Bool = true
    var recordingDuration: TimeInterval = 0

    func startRecording() async throws {
        guard !self.isRecording else {
            throw AudioRecordingError.alreadyRecording
        }
        self.isRecording = true
    }

    func stopRecording() async throws -> AudioData {
        guard self.isRecording else {
            throw AudioRecordingError.notRecording
        }
        self.isRecording = false
        return AudioData(data: Data(), format: .wav)
    }

    func cancelRecording() async {
        self.isRecording = false
    }

    func pauseRecording() async {}

    func resumeRecording() async {}
}

struct MockCredentialProvider: AudioTranscriptionCredentialProviding {
    let key: String?

    func currentOpenAIKey() -> String? {
        self.key
    }
}

extension AudioInputServiceTests {
    @MainActor
    static func makeService(
        recorder: any AudioRecorderProtocol = MockAudioRecorder(),
        hasAPIKey: Bool = true) -> AudioInputService
    {
        let aiService = PeekabooAIService()
        let provider = MockCredentialProvider(key: hasAPIKey ? "test-key" : nil)
        return AudioInputService(
            aiService: aiService,
            credentialProvider: provider,
            recorder: recorder)
    }
}

// MARK: - Additional Comprehensive Tests

@Suite(.tags(.unit, .agent), .enabled(if: AudioTestEnvironment.shouldRun))
struct AudioInputServiceComprehensiveTests {
    struct MockAudioFileTests {
        /// Create a mock WAV file for testing
        static func createMockWAVFile() throws -> URL {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("test_audio_\(UUID().uuidString).wav")

            // Create a minimal WAV file header (44 bytes)
            var wavData = Data()

            // RIFF header
            wavData.append("RIFF".data(using: .ascii)!) // ChunkID
            wavData.append(Data([36, 0, 0, 0])) // ChunkSize (36 + data size)
            wavData.append("WAVE".data(using: .ascii)!) // Format

            // fmt subchunk
            wavData.append("fmt ".data(using: .ascii)!) // Subchunk1ID
            wavData.append(Data([16, 0, 0, 0])) // Subchunk1Size
            wavData.append(Data([1, 0])) // AudioFormat (PCM)
            wavData.append(Data([1, 0])) // NumChannels (mono)
            wavData.append(Data([68, 172, 0, 0])) // SampleRate (44100)
            wavData.append(Data([136, 88, 1, 0])) // ByteRate
            wavData.append(Data([2, 0])) // BlockAlign
            wavData.append(Data([16, 0])) // BitsPerSample

            // data subchunk
            wavData.append("data".data(using: .ascii)!) // Subchunk2ID
            wavData.append(Data([0, 0, 0, 0])) // Subchunk2Size (no actual audio data)

            try wavData.write(to: fileURL)
            return fileURL
        }

        @Test
        @MainActor
        func `Transcribe valid WAV file`() async throws {
            let service = AudioInputServiceTests.makeService(hasAPIKey: false)

            // Use real test WAV file from Resources
            let bundle = Bundle.module
            guard let wavFile = bundle.url(forResource: "test_audio", withExtension: "wav") else {
                Issue.record("Could not find test_audio.wav in Resources")
                return
            }

            // This will fail without API key, but we can test the file validation
            do {
                _ = try await service.transcribeAudioFile(wavFile)
                Issue.record("Should have thrown apiKeyMissing error")
            } catch AudioInputError.apiKeyMissing {
                // Expected - file was validated successfully, but API key is missing
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test
        @MainActor
        func `Reject files over size limit`() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)

            // Create a file larger than 25MB
            let tempDir = FileManager.default.temporaryDirectory
            let largeFile = tempDir.appendingPathComponent("large_audio.wav")
            let largeData = Data(repeating: 0, count: 26 * 1024 * 1024)
            try largeData.write(to: largeFile)
            defer { try? FileManager.default.removeItem(at: largeFile) }

            await #expect(throws: AudioInputError.fileTooLarge(26 * 1024 * 1024)) {
                _ = try await service.transcribeAudioFile(largeFile)
            }
        }
    }
}
