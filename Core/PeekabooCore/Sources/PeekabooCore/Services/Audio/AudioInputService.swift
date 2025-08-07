//
//  AudioInputService.swift
//  PeekabooCore
//

import Foundation
import TachikomaAudio
import Tachikoma  // For TachikomaError
import os.log

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
            return "Already recording audio"
        case .notRecording:
            return "Not currently recording"
        case .fileNotFound(let url):
            return "Audio file not found at \(url.path)"
        case .unsupportedFileType(let type):
            return "Unsupported audio file type: \(type)"
        case .fileTooLarge(let size):
            return "Audio file too large: \(size) bytes (max 25MB)"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        case .audioSessionError(let message):
            return "Audio session error: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .apiKeyMissing:
            return "OpenAI API key is required for transcription"
        }
    }
}

/// Service for handling audio input and transcription
@MainActor
public final class AudioInputService: ObservableObject {
    
    // MARK: - Properties
    
    private let aiService: PeekabooAIService
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "AudioInputService")
    private let recorder = AudioRecorder()
    private var stateObservationTask: Task<Void, Never>?
    
    @Published public private(set) var isRecording = false
    @Published public private(set) var recordingDuration: TimeInterval = 0
    
    // Maximum file size: 25MB (OpenAI Whisper limit)
    private let maxFileSize = 25 * 1024 * 1024
    
    // Supported audio formats for transcription
    private let supportedExtensions = ["wav", "mp3", "m4a", "mp4", "mpeg", "mpga", "webm"]
    
    // MARK: - Initialization
    
    public init(aiService: PeekabooAIService) {
        self.aiService = aiService
        
        // Observe recorder state changes
        stateObservationTask = Task { @MainActor [weak self] in
            await self?.observeRecorderState()
        }
    }
    
    deinit {
        stateObservationTask?.cancel()
    }
    
    // MARK: - Public Properties
    
    /// Check if audio recording is available
    public var isAvailable: Bool {
        recorder.isAvailable
    }
    
    // MARK: - Private Methods
    
    private func observeRecorderState() async {
        // Use Combine to observe recorder state changes
        for await _ in Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .values {
            // Sync recorder state with our published properties
            if isRecording != recorder.isRecording {
                isRecording = recorder.isRecording
            }
            if recordingDuration != recorder.recordingDuration {
                recordingDuration = recorder.recordingDuration
            }
        }
    }
    
    // MARK: - Recording Methods
    
    /// Start recording audio from the microphone
    public func startRecording() async throws {
        do {
            try await recorder.startRecording()
            logger.info("Started audio recording")
        } catch let error as AudioRecordingError {
            // Convert AudioRecordingError to AudioInputError
            switch error {
            case .alreadyRecording:
                throw AudioInputError.alreadyRecording
            case .microphonePermissionDenied:
                throw AudioInputError.microphonePermissionDenied
            case .audioEngineError(let message):
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
            logger.info("Stopped audio recording")
            
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
            case .authenticationFailed(let message) where message.contains("API_KEY"):
                throw AudioInputError.apiKeyMissing
            case .invalidInput(let message), .apiError(let message):
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
        await recorder.cancelRecording()
        logger.info("Cancelled audio recording")
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
        guard supportedExtensions.contains(fileExtension) else {
            throw AudioInputError.unsupportedFileType(fileExtension)
        }
        
        // Validate file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? Int {
            guard fileSize <= maxFileSize else {
                throw AudioInputError.fileTooLarge(fileSize)
            }
        }
        
        // Use AI service to transcribe
        do {
            let transcription = try await aiService.transcribeAudio(at: url)
            logger.info("Successfully transcribed audio file")
            return transcription
        } catch {
            logger.error("Transcription failed: \(error)")
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
                case .authenticationFailed(let message) where message.contains("API_KEY"):
                    throw AudioInputError.apiKeyMissing
                case .invalidInput(let message):
                    throw AudioInputError.transcriptionFailed(message)
                case .apiError(let message):
                    throw AudioInputError.transcriptionFailed(message)
                default:
                    throw AudioInputError.transcriptionFailed(error.localizedDescription)
                }
            }
            throw AudioInputError.transcriptionFailed(error.localizedDescription)
        }
    }
}