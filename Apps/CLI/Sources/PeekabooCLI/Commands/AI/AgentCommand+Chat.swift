//
//  AgentCommand+Chat.swift
//  PeekabooCLI
//

import Foundation
import PeekabooAgentRuntime
import PeekabooCore
import PeekabooFoundation
import Tachikoma
import TauTUI

@available(macOS 14.0, *)
extension AgentCommand {
    private func ensureChatModePreconditions() -> Bool {
        let flags = AgentChatPreconditions.Flags(
            jsonOutput: self.jsonOutput,
            quiet: self.quiet,
            dryRun: self.dryRun,
            noCache: self.noCache,
            audio: self.audio,
            audioFileProvided: self.audioFile != nil
        )
        if let violation = AgentChatPreconditions.firstViolation(for: flags) {
            self.printAgentExecutionError(violation)
            return false
        }
        return true
    }

    func printNonInteractiveChatHelp() {
        if self.jsonOutput {
            self
                .printAgentExecutionError(
                    AgentMessages.Chat.nonInteractiveHelp
                )
            return
        }

        let hint = [
            "Interactive chat requires a TTY.",
            "To force it from scripts: peekaboo agent --chat < prompts.txt",
            "Provide a task arg or use --chat when piping input.",
            "",
        ]
        hint.forEach { print($0) }
        self.printChatHelpMenu()
    }

    @MainActor
    func runChatLoop(
        _ agentService: PeekabooAgentService,
        requestedModel: LanguageModel?,
        initialPrompt: String?,
        capabilities: TerminalCapabilities,
        queueMode: QueueMode
    ) async throws {
        guard self.ensureChatModePreconditions() else { return }

        if capabilities.isInteractive && !capabilities.isPiped {
            do {
                try await self.runTauTUIChatLoop(
                    agentService,
                    requestedModel: requestedModel,
                    initialPrompt: initialPrompt,
                    capabilities: capabilities,
                    queueMode: queueMode
                )
                return
            } catch {
                self.printAgentExecutionError(
                    "Failed to launch TauTUI chat: \(error.localizedDescription). Falling back to basic chat.")
            }
        }

        try await self.runLineChatLoop(
            agentService,
            requestedModel: requestedModel,
            initialPrompt: initialPrompt,
            capabilities: capabilities,
            queueMode: queueMode
        )
    }

    @MainActor
    private func runLineChatLoop(
        _ agentService: PeekabooAgentService,
        requestedModel: LanguageModel?,
        initialPrompt: String?,
        capabilities: TerminalCapabilities,
        queueMode: QueueMode
    ) async throws {
        var queuedWhileRunning: [String] = []
        var activeSessionId: String?
        do {
            activeSessionId = try await self.initialChatSessionId(agentService)
        } catch {
            self.printAgentExecutionError(error.localizedDescription)
            return
        }

        self.printChatWelcome(
            sessionId: activeSessionId,
            modelDescription: self.describeModel(requestedModel),
            queueMode: queueMode
        )
        self.printChatHelpIntro()

        if let seed = initialPrompt {
            try await self.performChatTurn(
                seed,
                agentService: agentService,
                sessionId: &activeSessionId,
                requestedModel: requestedModel,
                queueMode: queueMode,
                queuedWhileRunning: &queuedWhileRunning
            )
        }

        while true {
            guard let line = self.readChatLine(prompt: "> ", capabilities: capabilities) else {
                if capabilities.isInteractive {
                    print()
                }
                break
            }

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed == "/help" {
                self.printChatHelpMenu()
                continue
            }

            // If queueMode=all, batch any queued prompts gathered while a run was active
            let batchedPrompt = trimmed

            do {
                try await self.performChatTurn(
                    batchedPrompt,
                    agentService: agentService,
                    sessionId: &activeSessionId,
                    requestedModel: requestedModel,
                    queueMode: queueMode,
                    queuedWhileRunning: &queuedWhileRunning
                )
            } catch {
                self.printAgentExecutionError(error.localizedDescription)
                break
            }
        }
    }

    @MainActor
    private func runTauTUIChatLoop(
        _ agentService: PeekabooAgentService,
        requestedModel: LanguageModel?,
        initialPrompt: String?,
        capabilities: TerminalCapabilities,
        queueMode: QueueMode
    ) async throws {
        var activeSessionId: String?
        do {
            activeSessionId = try await self.initialChatSessionId(agentService)
        } catch {
            self.printAgentExecutionError(error.localizedDescription)
            return
        }

        let chatUI = AgentChatUI(
            modelDescription: self.describeModel(requestedModel),
            sessionId: activeSessionId,
            queueMode: queueMode,
            helpLines: self.chatHelpLines
        )

        try chatUI.start()
        defer { chatUI.stop() }

        var currentRun: Task<AgentExecutionResult, any Error>?
        chatUI.onCancelRequested = { [weak chatUI] in
            guard let run = currentRun else { return }
            if !run.isCancelled {
                run.cancel()
                chatUI?.markCancelling()
            }
        }

        chatUI.onInterruptRequested = { [weak chatUI] in
            if let run = currentRun, !run.isCancelled {
                run.cancel()
                chatUI?.markCancelling()
            } else {
                chatUI?.finishPromptStream()
            }
        }

        let promptStream = chatUI.promptStream(initialPrompt: initialPrompt)
        for await prompt in promptStream {
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed == "/help" {
                chatUI.showHelpMenu()
                continue
            }

            // For queueMode=all, batch any queued prompts into this turn
            let batchedPrompt: String
            if queueMode == .all {
                let extras = chatUI.drainQueuedPrompts()
                batchedPrompt = ([trimmed] + extras).joined(separator: "\n\n")
            } else {
                batchedPrompt = trimmed
            }

            chatUI.beginRun(prompt: trimmed)
            let tuiDelegate = AgentChatEventDelegate(ui: chatUI)

            let sessionForRun = activeSessionId
            currentRun = Task { @MainActor in
                try await self.runAgentTurnForTUI(
                    batchedPrompt,
                    agentService: agentService,
                    sessionId: sessionForRun,
                    requestedModel: requestedModel,
                    queueMode: queueMode,
                    delegate: tuiDelegate
                )
            }

            do {
                guard let run = currentRun else { continue }
                let result = try await run.value
                if let sessionId = result.sessionId {
                    activeSessionId = sessionId
                }
                chatUI.endRun(result: result, sessionId: activeSessionId)
            } catch is CancellationError {
                chatUI.showCancelled()
            } catch {
                chatUI.showError(error.localizedDescription)
            }

            currentRun = nil
            chatUI.setRunning(false)
        }
    }

    @MainActor
    private func runAgentTurnForTUI(
        _ input: String,
        agentService: PeekabooAgentService,
        sessionId: String?,
        requestedModel: LanguageModel?,
        queueMode: QueueMode,
        delegate: any AgentEventDelegate
    ) async throws -> AgentExecutionResult {
        if let existingSessionId = sessionId {
            return try await agentService.continueSession(
                sessionId: existingSessionId,
                userMessage: input,
                model: requestedModel,
                maxSteps: self.resolvedMaxSteps,
                dryRun: self.dryRun,
                queueMode: queueMode,
                eventDelegate: delegate,
                verbose: self.verbose
            )
        }

        return try await agentService.executeTask(
            input,
            maxSteps: self.resolvedMaxSteps,
            sessionId: nil,
            model: requestedModel,
            dryRun: self.dryRun,
            queueMode: queueMode,
            eventDelegate: delegate,
            verbose: self.verbose
        )
    }

    private func initialChatSessionId(
        _ agentService: PeekabooAgentService
    ) async throws -> String? {
        if let sessionId = self.resumeSession {
            guard try await agentService.getSessionInfo(sessionId: sessionId) != nil else {
                throw PeekabooError.sessionNotFound(sessionId)
            }
            return sessionId
        }

        if self.resume {
            let sessions = try await agentService.listSessions()
            guard let mostRecent = sessions.first else {
                throw PeekabooError.commandFailed("No sessions available to resume.")
            }
            return mostRecent.id
        }

        return nil
    }

    private func readChatLine(prompt: String, capabilities: TerminalCapabilities) -> String? {
        if capabilities.isInteractive {
            fputs(prompt, stdout)
            fflush(stdout)
        }
        return readLine()
    }

    private func performChatTurn(
        _ input: String,
        agentService: PeekabooAgentService,
        sessionId: inout String?,
        requestedModel: LanguageModel?,
        queueMode: QueueMode,
        queuedWhileRunning: inout [String]
    ) async throws {
        let startingSessionId = sessionId
        var batchedInput = input
        if queueMode == .all {
            let extras = queuedWhileRunning
            queuedWhileRunning.removeAll()
            batchedInput = ([input] + extras).joined(separator: "\n\n")
        }

        let runTask = Task { () throws -> AgentExecutionResult in
            if let existingSessionId = startingSessionId {
                let outputDelegate = self.makeDisplayDelegate(for: batchedInput)
                let streamingDelegate = self.makeStreamingDelegate(using: outputDelegate)
                let result = try await agentService.continueSession(
                    sessionId: existingSessionId,
                    userMessage: batchedInput,
                    model: requestedModel,
                    maxSteps: self.resolvedMaxSteps,
                    dryRun: self.dryRun,
                    queueMode: queueMode,
                    eventDelegate: streamingDelegate,
                    verbose: self.verbose
                )
                self.displayResult(result, delegate: outputDelegate)
                return result
            } else {
                return try await self.executeAgentTask(
                    agentService,
                    task: batchedInput,
                    requestedModel: requestedModel,
                    maxSteps: self.resolvedMaxSteps,
                    queueMode: queueMode
                )
            }
        }

        let cancelMonitor = EscapeKeyMonitor { [runTask] in
            if !runTask.isCancelled {
                runTask.cancel()
                await MainActor.run {
                    print("\n\(TerminalColor.yellow)Esc pressed – cancelling current run...\(TerminalColor.reset)")
                }
            }
        }
        cancelMonitor.start()

        let result: AgentExecutionResult
        do {
            defer { cancelMonitor.stop() }
            result = try await runTask.value
        } catch is CancellationError {
            cancelMonitor.stop()
            return
        }

        if let updatedSessionId = result.sessionId {
            sessionId = updatedSessionId
        }

        self.printChatTurnSummary(result)
    }

    private func printChatTurnSummary(_ result: AgentExecutionResult) {
        guard !self.quiet else { return }
        let duration = String(format: "%.1fs", result.metadata.executionTime)
        let sessionFragment = result.sessionId.map { String($0.prefix(8)) } ?? "–"
        let line = [
            TerminalColor.dim,
            "↺ Session ",
            sessionFragment,
            ": ",
            duration,
            " • ⚒ ",
            String(result.metadata.toolCallCount),
            TerminalColor.reset
        ].joined()
        print(line)
    }

    private func describeModel(_ requestedModel: LanguageModel?) -> String {
        requestedModel?.description ?? "default (gpt-5.1)"
    }
}
