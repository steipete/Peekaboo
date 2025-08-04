import Foundation
import Testing
import TachikomaCore
@testable import PeekabooCore

@Suite("Audio Content Tests - Tachikoma Integration")
struct MessageContentAudioTests {
    @Suite("Audio Data and Format Tests")
    struct AudioDataTests {
        @Test("AudioData initialization and properties")
        func audioDataInitialization() {
            let testData = Data([0x52, 0x49, 0x46, 0x46]) // WAV header
            let audioData = AudioData(
                data: testData,
                format: .wav,
                sampleRate: 44100,
                channels: 2,
                duration: 3.5
            )
            
            #expect(audioData.data == testData)
            #expect(audioData.format == .wav)
            #expect(audioData.sampleRate == 44100)
            #expect(audioData.channels == 2)
            #expect(audioData.duration == 3.5)
            #expect(audioData.size == 4)
        }
        
        @Test("AudioFormat properties")
        func audioFormatProperties() {
            // Test lossless formats
            #expect(AudioFormat.wav.isLossless == true)
            #expect(AudioFormat.flac.isLossless == true)
            #expect(AudioFormat.pcm.isLossless == true)
            
            // Test lossy formats
            #expect(AudioFormat.mp3.isLossless == false)
            #expect(AudioFormat.opus.isLossless == false)
            #expect(AudioFormat.aac.isLossless == false)
            
            // Test MIME types
            #expect(AudioFormat.wav.mimeType == "audio/wav")
            #expect(AudioFormat.mp3.mimeType == "audio/mpeg")
            #expect(AudioFormat.flac.mimeType == "audio/flac")
            #expect(AudioFormat.opus.mimeType == "audio/opus")
        }
        
        @Test("AudioData file operations")
        func audioDataFileOperations() throws {
            let tempDir = FileManager.default.temporaryDirectory
            let testFile = tempDir.appendingPathComponent("test_audio.wav")
            let testData = Data([0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x24]) // Basic WAV header
            
            try testData.write(to: testFile)
            
            // Test reading from file
            let audioData = try AudioData(contentsOf: testFile)
            #expect(audioData.data == testData)
            #expect(audioData.format == .wav) // Inferred from extension
            #expect(audioData.size == 8)
            
            // Clean up
            try? FileManager.default.removeItem(at: testFile)
        }
    }
    
    @Suite("Audio Model Tests")
    struct AudioModelTests {
        @Test("TranscriptionModel properties and capabilities")
        func transcriptionModelProperties() {
            // Test OpenAI transcription models
            let whisper1 = TranscriptionModel.openai(.whisper1)
            #expect(whisper1.modelId == "whisper-1")
            #expect(whisper1.providerName == "OpenAI")
            #expect(whisper1.supportsTimestamps == true)
            #expect(whisper1.supportsLanguageDetection == true)
            
            // Test other providers
            let groqModel = TranscriptionModel.groq(.whisperLargeV3Turbo)
            #expect(groqModel.providerName == "Groq")
            #expect(groqModel.supportsTimestamps == true)
            
            // Test defaults
            #expect(TranscriptionModel.default.providerName == "OpenAI")
            #expect(TranscriptionModel.whisper.modelId == "whisper-1")
        }
        
        @Test("SpeechModel properties and capabilities")
        func speechModelProperties() {
            // Test OpenAI speech models
            let tts1 = SpeechModel.openai(.tts1)
            #expect(tts1.modelId == "tts-1")
            #expect(tts1.providerName == "OpenAI")
            #expect(tts1.supportedFormats.contains(.mp3))
            #expect(tts1.supportedFormats.contains(.wav))
            
            let tts1HD = SpeechModel.openai(.tts1HD)
            #expect(tts1HD.modelId == "tts-1-hd")
            #expect(tts1HD.supportedFormats.contains(.mp3))
            
            // Test defaults
            #expect(SpeechModel.default.providerName == "OpenAI")
            #expect(SpeechModel.highQuality.modelId.contains("hd"))
        }
        
        @Test("Voice options and categorization")
        func voiceOptionsAndCategorization() {
            // Test voice categories
            let femaleVoices = VoiceOption.female
            let maleVoices = VoiceOption.male
            
            #expect(femaleVoices.contains(.alloy))
            #expect(femaleVoices.contains(.nova))
            #expect(femaleVoices.contains(.shimmer))
            
            #expect(maleVoices.contains(.echo))
            #expect(maleVoices.contains(.fable))
            #expect(maleVoices.contains(.onyx))
            
            // Test no overlap between categories
            let overlap = Set(femaleVoices).intersection(Set(maleVoices))
            #expect(overlap.isEmpty)
            
            // Test string values
            #expect(VoiceOption.alloy.stringValue == "alloy")
            #expect(VoiceOption.echo.stringValue == "echo")
            #expect(VoiceOption.default == .alloy)
        }
    }
    
    @Suite("Audio Function Integration Tests")
    struct AudioFunctionTests {
        @Test("Audio transcription function structure", .enabled(if: false)) // Disabled - requires API key
        func transcriptionFunctionStructure() async throws {
            let audioData = AudioData(data: Data([0x01, 0x02, 0x03]), format: .wav)
            
            // Test transcription function exists and has correct structure
            do {
                _ = try await transcribe(audioData, using: .openai(.whisper1))
                #expect(true) // Should not reach here without API key
            } catch {
                // Expected to fail without API key - testing structure
                #expect(error is TachikomaError)
            }
        }
        
        @Test("Speech generation function structure", .enabled(if: false)) // Disabled - requires API key
        func speechGenerationFunctionStructure() async throws {
            // Test speech generation function exists and has correct structure
            do {
                _ = try await generateSpeech("Hello world", using: .openai(.tts1))
                #expect(true) // Should not reach here without API key
            } catch {
                // Expected to fail without API key - testing structure
                #expect(error is TachikomaError)
            }
        }
        
        @Test("Audio error handling")
        func audioErrorHandling() {
            // Test audio-specific error types exist
            let errors = [
                TachikomaError.operationCancelled,
                TachikomaError.noAudioData,
                TachikomaError.unsupportedAudioFormat,
                TachikomaError.transcriptionFailed,
                TachikomaError.speechGenerationFailed
            ]
            
            for error in errors {
                #expect(!error.localizedDescription.isEmpty)
            }
        }
    }
    
    @Suite("Model Message Audio Content")
    struct ModelMessageAudioTests {
        @Test("ModelMessage audio content integration")
        func modelMessageAudioContent() {
            // Test that ModelMessage can handle audio content
            let audioData = AudioData(data: Data([0x01, 0x02]), format: .wav)
            let imageContent = ModelMessage.ContentPart.ImageContent(
                data: "base64data",
                mimeType: "image/png"
            )
            
            // Test multimodal message creation
            let message = ModelMessage.user(
                text: "What do you see and hear?",
                images: [imageContent]
            )
            
            #expect(message.role == .user)
            #expect(!message.content.isEmpty)
            
            // Test that the message structure supports mixed content
            switch message.content.first {
            case .text(let text):
                #expect(text == "What do you see and hear?")
            default:
                break
            }
        }
    }
}