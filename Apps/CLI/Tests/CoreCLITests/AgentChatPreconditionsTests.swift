import Testing
@testable import PeekabooCLI

@Suite("Agent chat preconditions", .tags(.safe))
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

    @Test("JSON output blocks interactive chat")
    func jsonOutputBlocks() {
        let violation = AgentChatPreconditions.firstViolation(for: self.flags(json: true))
        #expect(violation == AgentMessages.Chat.jsonDisabled)
    }

    @Test("Audio modes block interactive chat")
    func audioBlocks() {
        let mic = AgentChatPreconditions.firstViolation(for: self.flags(audio: true))
        let file = AgentChatPreconditions.firstViolation(for: self.flags(audioFile: true))
        #expect(mic == AgentMessages.Chat.typedOnly)
        #expect(file == AgentMessages.Chat.typedOnly)
    }

    @Test("Quiet and dry-run are rejected")
    func quietAndDryRun() {
        let quiet = AgentChatPreconditions.firstViolation(for: self.flags(quiet: true))
        let dryRun = AgentChatPreconditions.firstViolation(for: self.flags(dryRun: true))
        #expect(quiet == AgentMessages.Chat.quietDisabled)
        #expect(dryRun == AgentMessages.Chat.dryRunDisabled)
    }

    @Test("All clear passes")
    func passesWhenNoFlags() {
        let violation = AgentChatPreconditions.firstViolation(for: self.flags())
        #expect(violation == nil)
    }
}
