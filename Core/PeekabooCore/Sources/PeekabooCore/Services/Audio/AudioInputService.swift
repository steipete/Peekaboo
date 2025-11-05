//
//  AudioInputService.swift
//  PeekabooCore
//

import Foundation
import Observation
import os.log
import Tachikoma // For TachikomaError
import TachikomaAudio

/// Error types for audio input operations
public enum AudioInputError: LocalizedError, Equatable {
    case alreadyRecording
    case notRecording
    case fileNotFound(URL)
    case unsupportedFileType(String)
    case fileTooLarge(Int)
    case microphonePermissionDenied
    case audioSessionError(String)
    case transcriptionFailed(String)
    case apiKeyMissing

    public var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            "Already recording audio"
        case .notRecording:
            "Not currently recording"
        case let .fileNotFound(url):
            "Audio file not found at \(url.path)"
        case let .unsupportedFileType(type):
            "Unsupported audio file type: \(type)"
        case let .fileTooLarge(size):
            "Audio file too large: \(size) bytes (max 25MB)"
        case .microphonePermissionDenied:
            "Microphone permission denied"
        case let .audioSessionError(message):
            "Audio session error: \(message)"
        case let .transcriptionFailed(message):
            "Transcription failed: \(message)"
        case .apiKeyMissing:
            "OpenAI API key is required for transcription"
        }
    }
}

/// Service for handling audio input and transcription
@MainActor
@Observable
public final class AudioInputService {
    // MARK: - Properties

    @ObservationIgnored
    private let aiService: PeekabooAIService
    @ObservationIgnored
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "AudioInputService")
    @ObservationIgnored
    private let recorder = AudioRecorder()
    @ObservationIgnored
    private var stateObservationTask: Task<Void, Never>?

    public private(set) var isRecording = false
    public private(set) var recordingDuration: TimeInterval = 0

    // Maximum file size: 25MB (OpenAI Whisper limit)
    @ObservationIgnored
    private let maxFileSize = 25 * 1024 * 1024

    // Supported audio formats for transcription
    @ObservationIgnored
    private let supportedExtensions = ["wav", "mp3", "m4a", "mp4", "mpeg", "mpga", "webm"]

    // MARK: - Initialization

    public init(aiService: PeekabooAIService) {
        self.aiService = aiService

        // Observe recorder state changes
        self.stateObservationTask = Task { @MainActor [weak self] in
            await self?.observeRecorderState()
        }
    }

    deinit {
        stateObservationTask?.cancel()
    }

    // MARK: - Public Properties

    /// Check if audio recording is available
    public var isAvailable: Bool {
        self.recorder.isAvailable
    }

    // MARK: - Private Methods

    private func observeRecorderState() async {
        // Poll recorder state at a lightweight interval while the task is active
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            // Sync recorder state with our published properties
            if self.isRecording != self.recorder.isRecording {
                self.isRecording = self.recorder.isRecording
            }
            if self.recordingDuration != self.recorder.recordingDuration {
                self.recordingDuration = self.recorder.recordingDuration
            }
        }
    }

    // MARK: - Recording Methods

    /// Start recording audio from the microphone
    public func startRecording() async throws {
        do {
            try await self.recorder.startRecording()
            self.logger.info("Started audio recording")
        } catch let error as AudioRecordingError {
            // Convert AudioRecordingError to AudioInputError
            switch error {
            case .alreadyRecording:
                throw AudioInputError.alreadyRecording
            case .microphonePermissionDenied:
                throw AudioInputError.microphonePermissionDenied
            case let .audioEngineError(message):
                throw AudioInputError.audioSessionError(message)
            default:
                throw AudioInputError.audioSessionError(error.localizedDescription)
            }
        } catch {
            throw AudioInputError.audioSessionError(error.localizedDescription)
        }
    }

    /// Stop recording and return the transcription
    public func stopRecording() async throws -> String {
        do {
            let audioData = try await recorder.stopRecording()
            self.logger.info("Stopped audio recording")

            // Transcribe the recorded audio using TachikomaAudio
            let text = try await transcribe(audioData)
            return text
        } catch let error as AudioRecordingError {
            // Convert AudioRecordingError to AudioInputError
            switch error {
            case .notRecording:
                throw AudioInputError.notRecording
            case .noRecordingAvailable:
                throw AudioInputError.audioSessionError("No recording available")
            default:
                throw AudioInputError.audioSessionError(error.localizedDescription)
            }
        } catch let error as TachikomaError {
            // Convert TachikomaError to AudioInputError
            switch error {
            case let .authenticationFailed(message) where message.contains("API_KEY"):
                throw AudioInputError.apiKeyMissing
            case let .invalidInput(message), let .apiError(message):
                throw AudioInputError.transcriptionFailed(message)
            default:
                throw AudioInputError.transcriptionFailed(error.localizedDescription)
            }
        } catch {
            throw AudioInputError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Cancel recording without transcription
    public func cancelRecording() async {
        await self.recorder.cancelRecording()
        self.logger.info("Cancelled audio recording")
    }

    // MARK: - Transcription Methods

    /// Transcribe an audio file using OpenAI Whisper
    public func transcribeAudioFile(_ url: URL) async throws -> String {
        // Validate file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioInputError.fileNotFound(url)
        }

        // Validate file extension
        let fileExtension = url.pathExtension.lowercased()
        guard self.supportedExtensions.contains(fileExtension) else {
            throw AudioInputError.unsupportedFileType(fileExtension)
        }

        // Validate file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? Int {
            guard fileSize <= self.maxFileSize else {
                throw AudioInputError.fileTooLarge(fileSize)
            }
        }

        // Use AI service to transcribe
        do {
            let transcription = try await aiService.transcribeAudio(at: url)
            self.logger.info("Successfully transcribed audio file")
            return transcription
        } catch {
            self.logger.error("Transcription failed: \(error)")
            throw AudioInputError.transcriptionFailed(error.localizedDescription)
        }
    }
}

// MARK: - PeekabooAIService Extension

extension PeekabooAIService {
    /// Transcribe audio using TachikomaAudio's transcription API
    public func transcribeAudio(at url: URL) async throws -> String {
        // Use TachikomaAudio's convenient transcribe function
        do {
            let text = try await transcribe(contentsOf: url)
            return text
        } catch {
            // Convert errors to AudioInputError for compatibility
            if let tachikomaError = error as? TachikomaError {
                switch tachikomaError {
                case let .authenticationFailed(message) where message.contains("API_KEY"):
                    throw AudioInputError.apiKeyMissing
                case let .invalidInput(message):
                    throw AudioInputError.transcriptionFailed(message)
                case let .apiError(message):
                    throw AudioInputError.transcriptionFailed(message)
                default:
                    throw AudioInputError.transcriptionFailed(error.localizedDescription)
                }
            }
            throw AudioInputError.transcriptionFailed(error.localizedDescription)
        }
    }
}
