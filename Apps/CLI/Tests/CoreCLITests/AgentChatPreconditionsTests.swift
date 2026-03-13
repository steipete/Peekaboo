import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe))
struct AgentChatPreconditionsTests {
    private func flags(
        json: Bool = false,
        quiet: Bool = false,
        dryRun: Bool = false,
        noCache: Bool = false,
        audio: Bool = false,
        audioFile: Bool = false
    ) -> AgentChatPreconditions.Flags {
        AgentChatPreconditions.Flags(
            jsonOutput: json,
            quiet: quiet,
            dryRun: dryRun,
            noCache: noCache,
            audio: audio,
            audioFileProvided: audioFile
        )
    }

    @Test
    func `JSON output blocks interactive chat`() {
        let violation = AgentChatPreconditions.firstViolation(for: self.flags(json: true))
        #expect(violation == AgentMessages.Chat.jsonDisabled)
    }

    @Test
    func `Audio modes block interactive chat`() {
        let mic = AgentChatPreconditions.firstViolation(for: self.flags(audio: true))
        let file = AgentChatPreconditions.firstViolation(for: self.flags(audioFile: true))
        #expect(mic == AgentMessages.Chat.typedOnly)
        #expect(file == AgentMessages.Chat.typedOnly)
    }

    @Test
    func `Quiet and dry-run are rejected`() {
        let quiet = AgentChatPreconditions.firstViolation(for: self.flags(quiet: true))
        let dryRun = AgentChatPreconditions.firstViolation(for: self.flags(dryRun: true))
        #expect(quiet == AgentMessages.Chat.quietDisabled)
        #expect(dryRun == AgentMessages.Chat.dryRunDisabled)
    }

    @Test
    func `All clear passes`() {
        let violation = AgentChatPreconditions.firstViolation(for: self.flags())
        #expect(violation == nil)
    }
}
