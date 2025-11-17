//
//  AgentChatPreconditions.swift
//  PeekabooCLI
//

import Foundation

struct AgentChatPreconditions {
    struct Flags {
        let jsonOutput: Bool
        let quiet: Bool
        let dryRun: Bool
        let noCache: Bool
        let audio: Bool
        let audioFileProvided: Bool
    }

    static func firstViolation(for flags: Flags) -> String? {
        if flags.jsonOutput { return AgentMessages.Chat.jsonDisabled }
        if flags.quiet { return AgentMessages.Chat.quietDisabled }
        if flags.dryRun { return AgentMessages.Chat.dryRunDisabled }
        if flags.noCache { return AgentMessages.Chat.noCacheDisabled }
        if flags.audio || flags.audioFileProvided { return AgentMessages.Chat.typedOnly }
        return nil
    }
}
