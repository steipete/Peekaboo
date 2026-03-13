import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe))
struct AgentAudioCompositionTests {
    @Test
    func `Prepends provided task with transcript`() {
        let combined = AgentCommand.composeExecutionTask(
            providedTask: "Ship the release",
            transcript: "transcribed text"
        )
        #expect(combined.contains("Ship the release"))
        #expect(combined.contains("Audio transcript"))
    }

    @Test
    func `Falls back to transcript when task missing`() {
        let combined = AgentCommand.composeExecutionTask(providedTask: nil, transcript: "hello world")
        #expect(combined == "hello world")
    }
}
