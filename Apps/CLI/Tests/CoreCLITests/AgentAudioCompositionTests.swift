import Testing
@testable import PeekabooCLI

@Suite("Agent audio task composition", .tags(.safe))
struct AgentAudioCompositionTests {
    @Test("Prepends provided task with transcript")
    func combinesTaskAndTranscript() {
        let combined = AgentCommand.composeExecutionTask(providedTask: "Ship the release", transcript: "transcribed text")
        #expect(combined.contains("Ship the release"))
        #expect(combined.contains("Audio transcript"))
    }

    @Test("Falls back to transcript when task missing")
    func usesTranscriptOnly() {
        let combined = AgentCommand.composeExecutionTask(providedTask: nil, transcript: "hello world")
        #expect(combined == "hello world")
    }
}
