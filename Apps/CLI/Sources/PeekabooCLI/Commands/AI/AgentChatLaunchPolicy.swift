//
//  AgentChatLaunchPolicy.swift
//  PeekabooCLI
//

import Foundation

enum ChatLaunchStrategy: Equatable {
    case none
    case helpOnly
    case interactive(initialPrompt: String?)
}

struct AgentChatLaunchContext {
    let chatFlag: Bool
    let hasTaskInput: Bool
    let listSessions: Bool
    let normalizedTaskInput: String?
    let capabilities: TerminalCapabilities
}

/// Determines how the agent should launch chat mode based on flags and terminal context.
@available(macOS 14.0, *)
struct AgentChatLaunchPolicy {
    func strategy(for context: AgentChatLaunchContext) -> ChatLaunchStrategy {
        if context.chatFlag {
            return .interactive(initialPrompt: context.normalizedTaskInput)
        }

        if context.hasTaskInput || context.listSessions {
            return .none
        }

        if context.capabilities.isInteractive && !context.capabilities.isPiped && !context.capabilities.isCI {
            return .interactive(initialPrompt: nil)
        }

        return .helpOnly
    }
}
