import Foundation
import Testing
@testable import PeekabooCore

@Suite("MessageContent Audio Tests", .tags(.unit, .models))
struct MessageContentAudioTests {
    @Suite("AudioContent Model")
    struct AudioContentTests {
        @Test("AudioContent initializes with all properties")
        func initializeAudioContent() {
            let audioContent = AudioContent(
                url: "file:///tmp/audio.wav",
                base64: "base64encodeddata",
                transcript: "Hello world",
                duration: 5.5,
                mimeType: "audio/wav")

            #expect(audioContent.url == "file:///tmp/audio.wav")
            #expect(audioContent.base64 == "base64encodeddata")
            #expect(audioContent.transcript == "Hello world")
            #expect(audioContent.duration == 5.5)
            #expect(audioContent.mimeType == "audio/wav")
        }

        @Test("AudioContent encodes and decodes correctly")
        func codableAudioContent() throws {
            let original = AudioContent(
                url: "file:///tmp/audio.wav",
                base64: "base64encodeddata",
                transcript: "Hello world",
                duration: 5.5,
                mimeType: "audio/wav")

            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(AudioContent.self, from: data)

            #expect(decoded.url == original.url)
            #expect(decoded.base64 == original.base64)
            #expect(decoded.transcript == original.transcript)
            #expect(decoded.duration == original.duration)
            #expect(decoded.mimeType == original.mimeType)
        }

        @Test("AudioContent handles optional properties")
        func optionalProperties() throws {
            let minimal = AudioContent(
                url: nil,
                base64: nil,
                transcript: "Just a transcript",
                duration: nil,
                mimeType: nil)

            #expect(minimal.url == nil)
            #expect(minimal.base64 == nil)
            #expect(minimal.transcript == "Just a transcript")
            #expect(minimal.duration == nil)
            #expect(minimal.mimeType == nil)

            // Should still encode/decode properly
            let encoder = JSONEncoder()
            let data = try encoder.encode(minimal)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(AudioContent.self, from: data)

            #expect(decoded.transcript == "Just a transcript")
        }
    }

    @Suite("MessageContent Audio Integration")
    struct MessageContentIntegrationTests {
        @Test("MessageContent audio case works correctly")
        func messageContentAudioCase() {
            let audioContent = AudioContent(
                url: nil,
                base64: nil,
                transcript: "Test transcript",
                duration: 3.0,
                mimeType: "audio/wav")

            let message = MessageContent.audio(audioContent)

            switch message {
            case let .audio(content):
                #expect(content.transcript == "Test transcript")
                #expect(content.duration == 3.0)
                #expect(content.mimeType == "audio/wav")
            default:
                Issue.record("Expected audio case")
            }
        }

        @Test("Multiple content types including audio")
        func multipleContentTypes() {
            let contents: [MessageContent] = [
                .text("Hello"),
                .audio(AudioContent(
                    url: nil,
                    base64: nil,
                    transcript: "Audio message",
                    duration: 2.5,
                    mimeType: nil)),
                .text("Goodbye"),
            ]

            #expect(contents.count == 3)

            // Verify first is text
            if case let .text(text) = contents[0] {
                #expect(text == "Hello")
            } else {
                Issue.record("Expected text at index 0")
            }

            // Verify second is audio
            if case let .audio(audio) = contents[1] {
                #expect(audio.transcript == "Audio message")
                #expect(audio.duration == 2.5)
            } else {
                Issue.record("Expected audio at index 1")
            }

            // Verify third is text
            if case let .text(text) = contents[2] {
                #expect(text == "Goodbye")
            } else {
                Issue.record("Expected text at index 2")
            }
        }
    }

    @Suite("Audio Metadata Formatting")
    struct AudioMetadataFormattingTests {
        @Test("Format audio transcript with duration")
        func formatWithDuration() {
            let audioContent = AudioContent(
                url: nil,
                base64: nil,
                transcript: "Hello world",
                duration: 5.5,
                mimeType: nil)

            // This tests the formatting logic used in converters
            var text = audioContent.transcript ?? ""
            if let duration = audioContent.duration {
                text = "[Audio transcript, duration: \(Int(duration))s] \(audioContent.transcript ?? "")"
            }

            #expect(text == "[Audio transcript, duration: 5s] Hello world")
        }

        @Test("Format audio transcript without duration")
        func formatWithoutDuration() {
            let audioContent = AudioContent(
                url: nil,
                base64: nil,
                transcript: "Hello world",
                duration: nil,
                mimeType: nil)

            // Without duration, just use transcript
            let text = audioContent.transcript ?? ""

            #expect(text == "Hello world")
        }
    }
}
