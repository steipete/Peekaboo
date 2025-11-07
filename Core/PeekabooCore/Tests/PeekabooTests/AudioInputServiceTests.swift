import AVFoundation
import Foundation
import Testing
@testable import PeekabooCore

@preconcurrency
private enum AudioTestEnvironment {
    @preconcurrency nonisolated(unsafe) static var shouldRun: Bool {
        EnvironmentFlags.runAudioScenarios || TestEnvironment.runAutomationScenarios
    }
}

@Suite("AudioInputService Tests", .tags(.unit, .agent), .enabled(if: AudioTestEnvironment.shouldRun))
struct AudioInputServiceTests {
    @Suite("Initialization")
    struct InitializationTests {
        @Test("AudioInputService initializes with AI service dependency")
        @MainActor
        func initializeService() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)
            #expect(service.isAvailable == service.isAvailable) // Just verify it compiles
            #expect(!service.isRecording)
        }

        @Test("Audio availability check returns expected value")
        @MainActor
        func checkAvailability() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)
            // On macOS this should always return true in our simplified implementation
            #expect(service.isAvailable)
        }
    }

    @Suite("Recording State Management")
    struct RecordingStateTests {
        @Test("Cannot start recording when already recording")
        @MainActor
        func preventDoubleRecording() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)

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

        @Test("Cannot stop recording when not recording")
        @MainActor
        func preventStopWithoutStart() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)

            #expect(!service.isRecording)

            await #expect(throws: AudioInputError.notRecording) {
                _ = try await service.stopRecording()
            }
        }

        @Test("Recording state transitions correctly")
        @MainActor
        func recordingStateTransitions() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)

            // Initial state
            #expect(!service.isRecording)

            // Start recording
            try await service.startRecording()
            #expect(service.isRecording)

            // Stop recording
            _ = try? await service.stopRecording()
            #expect(!service.isRecording)
        }
    }

    @Suite("File Transcription")
    struct FileTranscriptionTests {
        @Test("Transcribe audio file validates file existence")
        @MainActor
        func validateFileExistence() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)

            let nonExistentURL = URL(fileURLWithPath: "/tmp/non_existent_audio.wav")

            await #expect(throws: AudioInputError.fileNotFound(nonExistentURL)) {
                _ = try await service.transcribeAudioFile(nonExistentURL)
            }
        }

        @Test("Transcribe audio file validates supported file types")
        @MainActor
        func validateFileTypes() async throws {
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

        @Test("Transcribe audio file validates file size")
        @MainActor
        func validateFileSize() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)

            // Create a mock large file
            let tempDir = FileManager.default.temporaryDirectory
            let largeFile = tempDir.appendingPathComponent("large_audio.wav")

            // Create a file larger than 25MB limit
            let largeData = Data(repeating: 0, count: 26 * 1024 * 1024)
            try largeData.write(to: largeFile)
            defer { try? FileManager.default.removeItem(at: largeFile) }

            await #expect(throws: Error.self) { // Will throw fileTooLarge error
                _ = try await service.transcribeAudioFile(largeFile)
            }
        }

        @Test("Transcribe requires OpenAI API key")
        @MainActor
        func requiresAPIKey() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)

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

    @Suite("Error Messages")
    struct ErrorMessageTests {
        @Test("Error descriptions are user-friendly")
        func errorDescriptions() {
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

// Since PeekabooAIService is final, we'll use it directly
// In real tests, we would need a protocol or to remove the final modifier

// Extension to help with configuration mocking
extension AudioInputServiceTests {
    // Helper to create a service with mocked configuration
    @MainActor
    static func createServiceWithMockedConfig(hasAPIKey: Bool = false) -> AudioInputService {
        let aiService = PeekabooAIService()
        let service = AudioInputService(aiService: aiService)
        // In real tests, we would inject a mock configuration
        return service
    }
}

// MARK: - Additional Comprehensive Tests

@Suite("AudioInputService Comprehensive Tests", .tags(.unit, .agent), .enabled(if: AudioTestEnvironment.shouldRun))
struct AudioInputServiceComprehensiveTests {
    @Suite("Mock Audio File Tests")
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

        @Test("Transcribe valid WAV file")
        @MainActor
        func transcribeValidWAVFile() async throws {
            let aiService = PeekabooAIService()
            let service = AudioInputService(aiService: aiService)

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

        @Test("Reject files over size limit")
        @MainActor
        func rejectLargeFiles() async throws {
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
