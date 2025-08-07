# Audio Architecture

## Overview

The Peekaboo audio system is built on top of TachikomaAudio, a dedicated audio module that provides comprehensive audio processing capabilities including transcription, speech synthesis, and audio recording. This document describes the architecture and usage of audio functionality in Peekaboo.

## Architecture

### Module Separation

The audio system is organized into two main components:

1. **TachikomaAudio** (in Tachikoma package)
   - Core audio functionality
   - Provider implementations (OpenAI, Groq, Deepgram, ElevenLabs)
   - Audio recording with AVFoundation
   - Type definitions and protocols

2. **PeekabooCore AudioInputService**
   - High-level service for Peekaboo applications
   - Integration with PeekabooAIService
   - UI state management (@Published properties)
   - Error handling specific to Peekaboo

### Key Components

#### TachikomaAudio Module

Located in `/Tachikoma/Sources/TachikomaAudio/`:

- **Types** (`Types/`)
  - `AudioTypes.swift`: Core types like `AudioData`, `AudioFormat`
  - `AudioModels.swift`: Request/response models for providers

- **Transcription** (`Transcription/`)
  - `AudioProviders.swift`: Provider protocols and factories
  - `OpenAIAudioProvider.swift`: OpenAI Whisper implementation
  - Additional providers for Groq, Deepgram, ElevenLabs

- **Recording** (`Recording/`)
  - `AudioRecorder.swift`: Cross-platform audio recording with AVFoundation

- **Global Functions** (`AudioFunctions.swift`)
  - Convenient functions like `transcribe()`, `generateSpeech()`
  - Batch operations for processing multiple files

#### PeekabooCore Integration

Located in `/Core/PeekabooCore/Sources/PeekabooCore/Services/Audio/`:

- **AudioInputService.swift**
  - @MainActor service for UI integration
  - Delegates recording to TachikomaAudio.AudioRecorder
  - Provides @Published properties for SwiftUI binding
  - Handles error conversion between TachikomaAudio and Peekaboo

## Usage

### Basic Audio Recording

```swift
import PeekabooCore

@MainActor
class ViewModel: ObservableObject {
    let audioService: AudioInputService
    
    func startRecording() async {
        do {
            try await audioService.startRecording()
            // audioService.isRecording is now true
            // audioService.recordingDuration updates automatically
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopAndTranscribe() async {
        do {
            let transcription = try await audioService.stopRecording()
            print("Transcribed text: \(transcription)")
        } catch {
            print("Failed to transcribe: \(error)")
        }
    }
}
```

### Direct Transcription with TachikomaAudio

```swift
import TachikomaAudio

// Transcribe a file
let text = try await transcribe(contentsOf: audioFileURL)

// Transcribe with specific model
let result = try await transcribe(
    audioData,
    using: .openai(.whisper1),
    language: "en"
)

// Access detailed results
print("Text: \(result.text)")
print("Language: \(result.language ?? "unknown")")
print("Segments: \(result.segments ?? [])")
```

### Speech Synthesis

```swift
import TachikomaAudio

// Generate speech with default settings
let audioData = try await generateSpeech("Hello world")

// Generate with specific voice and settings
let result = try await generateSpeech(
    "This is a test",
    using: .openai(.tts1HD),
    voice: .nova,
    speed: 1.2,
    format: .mp3
)

// Save to file
try result.audioData.write(to: outputURL)
```

### Audio Recording with TachikomaAudio

```swift
import TachikomaAudio

@MainActor
class RecorderViewModel: ObservableObject {
    let recorder = AudioRecorder()
    
    func record() async {
        do {
            try await recorder.startRecording()
            
            // Recording for some time...
            try await Task.sleep(for: .seconds(5))
            
            let audioData = try await recorder.stopRecording()
            
            // Transcribe the recording
            let text = try await transcribe(audioData)
            print("Transcribed: \(text)")
        } catch {
            print("Recording failed: \(error)")
        }
    }
}
```

## Provider Configuration

### API Keys

Audio providers require API keys set as environment variables:

- `OPENAI_API_KEY`: For OpenAI Whisper and TTS
- `GROQ_API_KEY`: For Groq transcription
- `DEEPGRAM_API_KEY`: For Deepgram transcription
- `ELEVENLABS_API_KEY`: For ElevenLabs TTS

### Model Selection

#### Transcription Models

```swift
// OpenAI
.openai(.whisper1)

// Groq
.groq(.whisperLargeV3)
.groq(.distilWhisperLargeV3En)

// Deepgram
.deepgram(.nova2)

// ElevenLabs
.elevenlabs(.default)
```

#### Speech Models

```swift
// OpenAI
.openai(.tts1)      // Standard quality
.openai(.tts1HD)    // High quality

// ElevenLabs
.elevenlabs(.multilingualV2)
.elevenlabs(.turboV2)
```

## Error Handling

### AudioInputError (PeekabooCore)

```swift
public enum AudioInputError: LocalizedError {
    case alreadyRecording
    case notRecording
    case fileNotFound(URL)
    case unsupportedFileType(String)
    case fileTooLarge(Int)
    case microphonePermissionDenied
    case audioSessionError(String)
    case transcriptionFailed(String)
    case apiKeyMissing
}
```

### AudioRecordingError (TachikomaAudio)

```swift
public enum AudioRecordingError: LocalizedError {
    case alreadyRecording
    case notRecording
    case microphonePermissionDenied
    case audioEngineError(String)
    case failedToCreateFile
    case noRecordingAvailable
    case recordingTooShort
    case recordingTooLong
}
```

## Permissions

### macOS

Audio recording requires microphone permission. The system will automatically prompt the user when first attempting to record.

Add to your app's Info.plist:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record audio for transcription.</string>
```

## Testing

### Unit Tests

Audio functionality is tested in:
- `/Core/PeekabooCore/Tests/PeekabooTests/AudioInputServiceTests.swift`
- `/Tachikoma/Tests/TachikomaTests/Audio/` (if present)

### Test Resources

A test WAV file is provided at:
- `/Core/PeekabooCore/Tests/PeekabooTests/Resources/test_audio.wav`

This file was generated using macOS's `say` command:
```bash
say -o test_audio.wav --data-format=LEI16@22050 "Hello world, this is a test audio file for Peekaboo"
```

## Migration Notes

### From Direct OpenAI API to TachikomaAudio

The audio system was refactored from using direct OpenAI API calls in PeekabooAIService to using the comprehensive TachikomaAudio module. This provides:

1. **Better separation of concerns**: Audio functionality is isolated in its own module
2. **Multiple provider support**: Easy to switch between OpenAI, Groq, Deepgram, etc.
3. **Type safety**: Strongly typed models, requests, and responses
4. **Reusability**: Audio functionality can be used across different projects

### Breaking Changes

- `PeekabooAIService.transcribeAudio()` now uses TachikomaAudio internally
- Direct AVAudioEngine usage in AudioInputService replaced with AudioRecorder
- Import statements changed from `import Tachikoma` to `import TachikomaAudio` for audio functionality

## Performance Considerations

### Recording

- Default sample rate: 44.1kHz, mono, 16-bit
- Maximum recording duration: 5 minutes (configurable)
- Recording creates temporary WAV files in system temp directory

### Transcription

- File size limit: 25MB (OpenAI Whisper limit)
- Supported formats: WAV, MP3, M4A, MP4, MPEG, MPGA, WEBM, FLAC
- Batch operations use concurrency control (default: 3 concurrent operations)

### Speech Synthesis

- Maximum text length varies by provider (typically 4096 characters)
- Output formats: MP3, WAV, OPUS, AAC, FLAC, PCM
- Speed range: 0.25x to 4.0x (OpenAI)

## Future Enhancements

Potential improvements for the audio system:

1. **Local transcription**: Add support for on-device transcription using Core ML
2. **Streaming transcription**: Real-time transcription as audio is being recorded
3. **Audio effects**: Pre-processing for noise reduction, normalization
4. **Voice activity detection**: Automatic start/stop based on speech detection
5. **Multi-language detection**: Automatic language detection without hints
6. **Custom voices**: Support for voice cloning and custom voice models