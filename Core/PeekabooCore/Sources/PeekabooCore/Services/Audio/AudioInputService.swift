//
//  AudioInputService.swift
//  PeekabooCore
//

import AVFoundation
import Foundation
import Tachikoma
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
    
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    
    @Published public private(set) var isRecording = false
    @Published public private(set) var recordingDuration: TimeInterval = 0
    
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    
    // Maximum file size: 25MB (OpenAI Whisper limit)
    private let maxFileSize = 25 * 1024 * 1024
    
    // Supported audio formats for transcription
    private let supportedExtensions = ["wav", "mp3", "m4a", "mp4", "mpeg", "mpga", "webm"]
    
    // MARK: - Initialization
    
    public init(aiService: PeekabooAIService) {
        self.aiService = aiService
    }
    
    // MARK: - Public Properties
    
    /// Check if audio recording is available
    public var isAvailable: Bool {
        // On macOS, audio recording is generally available
        // In a real implementation, you might check for microphone permissions
        return true
    }
    
    // MARK: - Recording Methods
    
    /// Start recording audio from the microphone
    public func startRecording() async throws {
        guard !isRecording else {
            throw AudioInputError.alreadyRecording
        }
        
        // Check microphone permission
        let authorized = await checkMicrophonePermission()
        guard authorized else {
            throw AudioInputError.microphonePermissionDenied
        }
        
        // Setup audio session
        try setupAudioSession()
        
        // Create temporary file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        guard let url = recordingURL else {
            throw AudioInputError.audioSessionError("Failed to create recording URL")
        }
        
        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioInputError.audioSessionError("Failed to create audio engine")
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Create audio file
        audioFile = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self, let audioFile = self.audioFile else { return }
            
            do {
                try audioFile.write(from: buffer)
            } catch {
                self.logger.error("Failed to write audio buffer: \(error)")
            }
        }
        
        // Start the audio engine
        try audioEngine.start()
        
        // Update state
        isRecording = true
        recordingStartTime = Date()
        
        // Start duration timer
        let startTime = recordingStartTime
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = startTime else { return }
            Task { @MainActor in
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
        
        logger.info("Started audio recording")
    }
    
    /// Stop recording and return the transcription
    public func stopRecording() async throws -> String {
        guard isRecording else {
            throw AudioInputError.notRecording
        }
        
        // Stop the audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        // Close the audio file
        audioFile = nil
        
        // Stop the timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Update state
        isRecording = false
        recordingDuration = 0
        recordingStartTime = nil
        
        logger.info("Stopped audio recording")
        
        // Transcribe the recorded audio
        guard let url = recordingURL else {
            throw AudioInputError.audioSessionError("No recording URL available")
        }
        
        defer {
            // Clean up the temporary file
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
        
        return try await transcribeAudioFile(url)
    }
    
    /// Cancel recording without transcription
    public func cancelRecording() async {
        guard isRecording else { return }
        
        // Stop the audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        // Close the audio file
        audioFile = nil
        
        // Stop the timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Update state
        isRecording = false
        recordingDuration = 0
        recordingStartTime = nil
        
        // Clean up the temporary file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
        
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
    
    // MARK: - Private Methods
    
    private func setupAudioSession() throws {
        // On macOS, AVAudioSession is not available
        // Audio setup is handled by AVAudioEngine
        // This method is kept for API compatibility
    }
    
    private func checkMicrophonePermission() async -> Bool {
        // On macOS 10.14+, we need to check for microphone permission
        // For simplicity, we'll return true here
        // In a real implementation, you'd use AVCaptureDevice.requestAccess
        return await withCheckedContinuation { continuation in
            #if os(macOS)
            if #available(macOS 10.14, *) {
                switch AVCaptureDevice.authorizationStatus(for: .audio) {
                case .authorized:
                    continuation.resume(returning: true)
                case .notDetermined:
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        continuation.resume(returning: granted)
                    }
                case .denied, .restricted:
                    continuation.resume(returning: false)
                @unknown default:
                    continuation.resume(returning: false)
                }
            } else {
                // Pre-10.14, no permission needed
                continuation.resume(returning: true)
            }
            #else
            continuation.resume(returning: true)
            #endif
        }
    }
}

// MARK: - PeekabooAIService Extension

extension PeekabooAIService {
    /// Transcribe audio using Tachikoma's transcription API
    public func transcribeAudio(at url: URL) async throws -> String {
        // Tachikoma will handle API key validation internally
        // It uses the same OPENAI_API_KEY environment variable
        do {
            // Use Tachikoma's convenient transcribe function
            let text = try await Tachikoma.transcribe(contentsOf: url)
            return text
        } catch {
            // Convert Tachikoma errors to AudioInputError for compatibility
            if let tachikomaError = error as? TachikomaError {
                switch tachikomaError {
                case .authenticationFailed(let message) where message.contains("OPENAI_API_KEY"):
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