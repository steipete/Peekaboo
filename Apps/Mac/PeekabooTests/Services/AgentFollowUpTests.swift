import Foundation
import PeekabooCore
import Testing
@testable import Peekaboo

@Suite(.tags(.services, .unit))
@MainActor
struct AgentFollowUpTests {
    @Test
    func `A queued follow-up is logged once at acceptance`() async throws {
        let gate = FollowUpGate()
        let (agent, store) = makeFollowUpAgent(gate: gate)
        defer { gate.releaseAll() }

        let first = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")
        try await agent.executeTask("second")
        #expect(!gate.didEnter("second"))
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .user }.map(\.content) == ["first", "second"])

        gate.release("first")
        await gate.waitUntilEntered("second")
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .user }.map(\.content) == ["first", "second"])
        gate.release("second")
        try await first.value
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .user }.map(\.content) == ["first", "second"])
    }

    @Test(arguments: [true, false])
    func `An immediate prompt is logged exactly once`(existingSession: Bool) async throws {
        let gate = FollowUpGate()
        let (agent, store) = makeFollowUpAgent(gate: gate, startsWithSession: existingSession)
        defer { gate.releaseAll() }

        let task = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")
        #expect(store.sessions.count == 1)
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .user }.map(\.content) == ["first"])
        gate.release("first")
        try await task.value
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .user }.map(\.content) == ["first"])
    }

    @Test
    func `Streamed assistant turns do not gain a combined duplicate`() async throws {
        let gate = FollowUpGate()
        let replies = ["I'll call the sleep tool as requested.", "FIRSTDONE"]
        let (agent, store) = makeFollowUpAgent(gate: gate, runner: { _, store in
            let session = try #require(store.currentSession)
            for reply in replies {
                store.addMessage(ConversationMessage(role: .assistant, content: reply), to: session)
            }
            return sampleFollowUpResult(replies.joined())
        })
        defer { gate.releaseAll() }

        let task = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")
        gate.release("first")
        try await task.value
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .assistant }.map(\.content) == replies)
    }

    @Test
    func `A non-streaming run appends its result even when an older reply matches`() async throws {
        let gate = FollowUpGate()
        let (agent, store) = makeFollowUpAgent(gate: gate)
        defer { gate.releaseAll() }
        let session = try #require(store.currentSession)
        store.addMessage(ConversationMessage(role: .assistant, content: "first"), to: session)

        let task = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")
        gate.release("first")
        try await task.value
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .assistant }.map(\.content) == [
            "first",
            "first",
        ])
    }

    @Test
    func `An empty result adds no empty assistant message`() async throws {
        let gate = FollowUpGate()
        let (agent, store) = makeFollowUpAgent(gate: gate, runner: { _, _ in sampleFollowUpResult("") })
        defer { gate.releaseAll() }

        for prompt in ["first", "second"] {
            let task = Task { try await agent.executeTask(prompt) }
            await gate.waitUntilEntered(prompt)
            gate.release(prompt)
            try await task.value
        }
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .assistant }.isEmpty)
    }

    @Test
    func `The first prompt in a new chat gets a generated title`() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SessionStore(
            storageURL: directory.appendingPathComponent("sessions.json"),
            titleOverride: { "Title: \($0)" })
        let gate = FollowUpGate()
        defer { gate.releaseAll() }
        let agent = PeekabooAgent(
            settings: makeTestSettings(),
            sessionStore: store,
            services: PeekabooServices(initializeAgentService: false),
            taskRunner: { text in
                try await gate.enter(text)
                return sampleFollowUpResult(text)
            })

        // No current session: the agent creates one, as a menu bar prompt does.
        let task = Task { try await agent.executeTask("plan my week") }
        await gate.waitUntilEntered("plan my week")
        gate.release("plan my week")
        try await task.value

        let titled = await waitUntil(timeout: .seconds(5)) { store.sessions.first?.title == "Title: plan my week" }
        #expect(titled)
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.messages.filter { $0.role == .user }.map(\.content) == ["plan my week"])
    }

    @Test
    func `A queued prompt's failure keeps its own session for retry`() async throws {
        let gate = FollowUpGate()
        let (agent, store) = makeFollowUpAgent(gate: gate, failingTexts: ["other chat"])
        defer { gate.releaseAll() }
        let first = store.currentSession
        let other = store.createSession(title: "Other", modelName: "test")
        if let first {
            store.selectSession(first)
        }

        let running = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")
        try await agent.executeTask("other chat", in: other)
        gate.release("first")
        await gate.waitUntilEntered("other chat")
        gate.release("other chat")
        _ = await running.result

        #expect(agent.lastTask == "other chat")
        #expect(agent.lastTaskSessionId == other.id)
        #expect(agent.lastTaskSessionId != first?.id)
    }

    @Test
    func `Follow-up waits for the live task and Stop stays available`() async throws {
        let gate = FollowUpGate()
        let (agent, _) = makeFollowUpAgent(gate: gate)
        defer { gate.releaseAll() }

        var firstReturned = false
        let first = Task {
            try await agent.executeTask("first")
            firstReturned = true
        }
        await gate.waitUntilEntered("first")
        #expect(agent.isProcessing)

        var followUpReturned = false
        let followUp = Task {
            try await agent.executeTask("second")
            followUpReturned = true
        }
        let followUpSettled = await waitUntil { followUpReturned || gate.didEnter("second") }
        #expect(followUpSettled)
        #expect(followUpReturned)
        #expect(!gate.didEnter("second"))
        #expect(agent.isProcessing)

        gate.release("first")
        await gate.waitUntilEntered("second")
        #expect(!firstReturned)
        #expect(agent.isProcessing)

        gate.release("second")
        try await first.value
        try await followUp.value
        #expect(firstReturned)
        #expect(!agent.isProcessing)
        #expect(gate.entered == ["first", "second"])
    }

    @Test
    func `Stop during a follow-up cancels the live task and drops the queue`() async throws {
        let gate = FollowUpGate()
        let (agent, _) = makeFollowUpAgent(gate: gate)
        defer { gate.releaseAll() }

        let first = Task {
            try await agent.executeTask("first")
        }
        await gate.waitUntilEntered("first")

        var followUpReturned = false
        let followUp = Task {
            try await agent.executeTask("second")
            followUpReturned = true
        }
        let followUpSettled = await waitUntil { followUpReturned || gate.didEnter("second") }
        #expect(followUpSettled)
        #expect(followUpReturned)
        #expect(!gate.didEnter("second"))
        #expect(agent.isProcessing)

        agent.cancelCurrentTask()
        let cancelled = await waitUntil { gate.wasCancelled("first") }
        gate.releaseAll()
        let firstResult = await first.result
        try await followUp.value

        #expect(cancelled)
        #expect(gate.wasCancelled("first"))
        #expect(!gate.didEnter("second"))
        #expect(!agent.isProcessing)
        guard case let .failure(error) = firstResult else {
            Issue.record("Stop should fail the live task")
            return
        }
        #expect(error is CancellationError)
    }

    @Test
    func `A failed task still runs the accepted follow-up`() async throws {
        let gate = FollowUpGate()
        let (agent, store) = makeFollowUpAgent(gate: gate, failingTexts: ["first"])
        defer { gate.releaseAll() }

        let first = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")

        var followUpReturned = false
        let followUp = Task {
            try await agent.executeTask("second")
            followUpReturned = true
        }
        let accepted = await waitUntil { followUpReturned }
        #expect(accepted)
        #expect(!gate.didEnter("second"))

        gate.release("first")
        await gate.waitUntilEntered("second")
        #expect(agent.isProcessing)
        gate.release("second")
        let firstResult = await first.result
        try await followUp.value

        #expect(gate.entered == ["first", "second"])
        guard case .failure = firstResult else {
            Issue.record("the live failure should still surface")
            return
        }
        let contents = store.sessions.flatMap(\.messages).map(\.content).joined(separator: "\n")
        #expect(contents.contains("network down"))
        #expect(contents.contains("second"))
        #expect(!agent.isProcessing)
    }

    @Test
    func `A prompt sent while Stop is unwinding still runs`() async throws {
        let gate = FollowUpGate()
        gate.holdCancellation = true
        let (agent, store) = makeFollowUpAgent(gate: gate)
        defer { gate.releaseAll() }

        let first = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")
        agent.cancelCurrentTask()

        var retryReturned = false
        let retry = Task {
            try await agent.executeTask("retry")
            retryReturned = true
        }
        let accepted = await waitUntil { retryReturned }
        #expect(accepted)
        #expect(!gate.didEnter("retry"))
        #expect(agent.isProcessing)
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .user }.map(\.content) == ["first", "retry"])

        gate.finishHeldCancellation()
        await gate.waitUntilEntered("retry")
        #expect(agent.isProcessing)
        #expect(gate.wasCancelled("first"))
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .user }.map(\.content) == ["first", "retry"])

        gate.release("retry")
        let firstResult = await first.result
        try await retry.value
        // The retry runs on the runner finishRunner() started, which nothing here awaits.
        let idle = await waitUntil(timeout: .seconds(5)) { !agent.isProcessing }
        #expect(idle)
        #expect(gate.entered == ["first", "retry"])
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .user }.map(\.content) == ["first", "retry"])
        guard case let .failure(error) = firstResult else {
            Issue.record("Stop should fail the live task")
            return
        }
        #expect(error is CancellationError)
    }

    @Test
    func `A queued follow-up stays on the session that accepted it`() async throws {
        let gate = FollowUpGate()
        let (agent, store) = makeFollowUpAgent(gate: gate)
        defer { gate.releaseAll() }
        let originalId = store.currentSession?.id

        let first = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")

        var followUpReturned = false
        let followUp = Task {
            try await agent.executeTask("second")
            followUpReturned = true
        }
        let accepted = await waitUntil { followUpReturned }
        #expect(accepted)

        let other = store.createSession(title: "Other", modelName: "test")
        gate.release("first")
        await gate.waitUntilEntered("second")
        gate.release("second")
        try await first.value
        try await followUp.value

        let original = store.sessions.first { $0.id == originalId }?.messages.map(\.content) ?? []
        let moved = store.sessions.first { $0.id == other.id }?.messages.map(\.content) ?? []
        #expect(original.contains { $0.contains("second") })
        #expect(moved.allSatisfy { !$0.contains("second") })
    }

    @Test
    func `Resuming another session waits until the live task finishes`() async throws {
        let gate = FollowUpGate()
        let (agent, store) = makeFollowUpAgent(gate: gate)
        defer { gate.releaseAll() }
        let original = try #require(store.currentSession)
        let other = store.createSession(title: "Other", modelName: "test")
        store.selectSession(original)

        let first = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")
        try await agent.resumeSession(other.id, withTask: "second")
        #expect(store.currentSession?.id == original.id)
        #expect(agent.currentSessionId == original.id)
        #expect(!gate.didEnter("second"))
        #expect(store.sessions.first { $0.id == original.id }?.messages.filter { $0.role == .user }.map(\.content) == [
            "first",
        ])
        #expect(store.sessions.first { $0.id == other.id }?.messages.filter { $0.role == .user }.map(\.content) == [
            "second",
        ])

        gate.release("first")
        await gate.waitUntilEntered("second")
        #expect(store.currentSession?.id == other.id)
        gate.release("second")
        try await first.value
    }

    @Test
    func `A second Stop drops prompts accepted while cancellation unwinds`() async throws {
        let gate = FollowUpGate()
        gate.holdCancellation = true
        let (agent, store) = makeFollowUpAgent(gate: gate)
        defer { gate.releaseAll() }

        let first = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")
        agent.cancelCurrentTask()
        try await agent.executeTask("retry")
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .user }.map(\.content) == ["first", "retry"])
        agent.cancelCurrentTask()

        let cancelled = await waitUntil { gate.wasCancelled("first") }
        #expect(cancelled)
        gate.finishHeldCancellation()
        _ = await first.result
        let settled = await waitUntil { !agent.isProcessing || gate.didEnter("retry") }
        #expect(settled)
        #expect(!gate.didEnter("retry"))
        #expect(!agent.isProcessing)
        #expect(store.sessions.flatMap(\.messages).filter { $0.role == .user }.map(\.content) == ["first", "retry"])
        gate.release("retry")
    }

    @Test(arguments: [true, false])
    func `A deleted originating session cannot redirect a queued prompt`(deleteBeforeAcceptance: Bool) async throws {
        let gate = FollowUpGate()
        let (agent, store) = makeFollowUpAgent(gate: gate)
        defer { gate.releaseAll() }
        let originalID = try #require(store.currentSession).id

        let first = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")
        if deleteBeforeAcceptance {
            store.sessions.removeAll { $0.id == originalID }
        }
        try await agent.executeTask("discarded")
        let other = store.createSession(title: "Other", modelName: "test")
        store.sessions.removeAll { $0.id == originalID }

        gate.release("first")
        let settled = await waitUntil { !agent.isProcessing || gate.didEnter("discarded") }
        #expect(settled)
        let discardedDidRun = gate.didEnter("discarded")
        #expect(!discardedDidRun)
        gate.release("discarded")
        let result = await first.result
        let otherMessages = store.sessions.first { $0.id == other.id }?.messages.map(\.content) ?? []
        #expect(otherMessages.allSatisfy { !$0.contains("discarded") })
        guard case let .failure(error) = result else {
            Issue.record("A deleted session should reject its queued prompt")
            return
        }
        #expect(error as? AgentError == .executionFailed("The queued session no longer exists"))
    }

    @Test
    func `A streaming reply stays ahead of a queued follow-up`() async throws {
        let gate = FollowUpGate()
        let (agent, store) = makeFollowUpAgent(gate: gate)
        defer { gate.releaseAll() }

        let first = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")
        try await agent.executeTask("second")
        agent.handleAgentEvent(.thinkingMessage(content: "planning the reply"))
        agent.handleAgentEvent(.assistantMessage(content: "partial"))

        gate.release("first")
        await gate.waitUntilEntered("second")
        gate.release("second")
        try await first.value

        let contents = store.sessions.flatMap(\.messages).map(\.content)
        let planning = try #require(contents.firstIndex(where: { $0.contains("planning the reply") }))
        let partial = try #require(contents.firstIndex(of: "partial"))
        let secondUser = try #require(contents.firstIndex(of: "second"))
        let firstSummary = try #require(contents.firstIndex(where: { $0.hasPrefix("Task completed") }))
        #expect(planning < secondUser)
        #expect(partial < secondUser)
        #expect(firstSummary < secondUser)
        let userMessages = store.sessions.flatMap(\.messages).filter { $0.role == .user }.map(\.content)
        #expect(userMessages == ["first", "second"])
    }

    @Test
    func `A streamed middle follow-up is written once`() async throws {
        let gate = FollowUpGate()
        let (agent, store) = makeFollowUpAgent(gate: gate)
        defer { gate.releaseAll() }

        let first = Task { try await agent.executeTask("one") }
        await gate.waitUntilEntered("one")
        try await agent.executeTask("two")
        try await agent.executeTask("three")
        gate.release("one")
        await gate.waitUntilEntered("two")
        agent.handleAgentEvent(.assistantMessage(content: "partial-two"))
        gate.release("two")
        await gate.waitUntilEntered("three")
        gate.release("three")
        try await first.value

        let messages = store.sessions.flatMap(\.messages)
        let assistant = messages.filter { $0.role == .assistant }.map(\.content)
        #expect(assistant.filter { $0 == "partial-two" }.count == 1)
        #expect(!assistant.contains("two"))
        let contents = messages.map(\.content)
        let partial = try #require(contents.firstIndex(of: "partial-two"))
        let three = try #require(contents.firstIndex(of: "three"))
        #expect(partial < three)
        let userMessages = messages.filter { $0.role == .user }.map(\.content)
        #expect(userMessages == ["one", "two", "three"])
    }

    @Test
    func `A queued follow-up keeps the failed prompt the banner retries`() async throws {
        let gate = FollowUpGate()
        let (agent, store) = makeFollowUpAgent(gate: gate, failingTexts: ["first", "second"])
        defer { gate.releaseAll() }
        let sessionID = try #require(store.currentSession).id

        let first = Task { try await agent.executeTask("first") }
        await gate.waitUntilEntered("first")
        try await agent.executeTask("second")
        gate.release("first")
        await gate.waitUntilEntered("second")
        #expect(agent.lastTask == "first")
        #expect(agent.lastTaskSessionId == sessionID)
        gate.release("second")
        _ = await first.result

        #expect(agent.lastTask == "first")
        #expect(agent.lastTaskSessionId == sessionID)
        #expect(agent.lastTask != "second")
    }
}

@MainActor
private final class FollowUpGate {
    var holdCancellation = false
    private(set) var entered: [String] = []
    private var waiters: [String: CheckedContinuation<Void, Never>] = [:]
    private var parked: [String: ParkedWork] = [:]

    func didEnter(_ name: String) -> Bool {
        self.entered.contains(name)
    }

    func wasCancelled(_ name: String) -> Bool {
        self.parked[name]?.cancelled == true
    }

    func enter(_ name: String) async throws {
        self.entered.append(name)
        self.waiters.removeValue(forKey: name)?.resume()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.park(name, continuation)
            }
        } onCancel: {
            Task { @MainActor in
                self.cancel(name)
            }
        }
    }

    func waitUntilEntered(_ name: String) async {
        if self.didEnter(name) {
            return
        }
        await withCheckedContinuation { continuation in
            if self.didEnter(name) {
                continuation.resume()
                return
            }
            self.waiters[name] = continuation
        }
    }

    func release(_ name: String) {
        self.finish(name, result: .success(()))
    }

    func releaseAll() {
        for name in Array(self.parked.keys) {
            self.release(name)
        }
    }

    func finishHeldCancellation() {
        for name in Array(self.parked.keys) where self.parked[name]?.cancelled == true {
            self.finish(name, result: .failure(CancellationError()))
        }
    }

    private func park(_ name: String, _ continuation: CheckedContinuation<Void, any Error>) {
        var slot = self.parked[name] ?? ParkedWork()
        if slot.finished {
            continuation.resume(with: slot.result ?? .success(()))
            return
        }
        slot.continuation = continuation
        self.parked[name] = slot
    }

    private func cancel(_ name: String) {
        var slot = self.parked[name] ?? ParkedWork()
        slot.cancelled = true
        self.parked[name] = slot
        if self.holdCancellation {
            return
        }
        self.finish(name, result: .failure(CancellationError()))
    }

    private func finish(_ name: String, result: Result<Void, any Error>) {
        var slot = self.parked[name] ?? ParkedWork()
        guard !slot.finished else { return }
        slot.finished = true
        slot.result = result
        let continuation = slot.continuation
        slot.continuation = nil
        self.parked[name] = slot
        continuation?.resume(with: result)
    }
}

@MainActor
private struct ParkedWork {
    var continuation: CheckedContinuation<Void, any Error>?
    var finished = false
    var cancelled = false
    var result: Result<Void, any Error>?
}

@MainActor
private func makeFollowUpAgent(
    gate: FollowUpGate,
    failingTexts: Set<String> = [],
    runner: (@MainActor (String, SessionStore) throws -> AgentExecutionResult)? = nil,
    startsWithSession: Bool = true) -> (PeekabooAgent, SessionStore)
{
    let settings = makeTestSettings()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let sessionStore = SessionStore(storageURL: directory.appendingPathComponent("sessions.json"))
    if startsWithSession {
        let session = sessionStore.createSession(title: "Follow-up", modelName: "test")
        sessionStore.selectSession(session)
    }
    let services = PeekabooServices(initializeAgentService: false)
    let agent = PeekabooAgent(
        settings: settings,
        sessionStore: sessionStore,
        services: services,
        taskRunner: { text in
            try await gate.enter(text)
            if failingTexts.contains(text) {
                throw AgentError.executionFailed("network down")
            }
            return try runner?(text, sessionStore) ?? sampleFollowUpResult(text)
        })
    return (agent, sessionStore)
}

@MainActor
private func sampleFollowUpResult(_ text: String) -> AgentExecutionResult {
    let now = Date()
    return AgentExecutionResult(
        content: text,
        sessionId: "follow-up",
        metadata: AgentMetadata(
            executionTime: 0,
            toolCallCount: 0,
            modelName: "test",
            startTime: now,
            endTime: now))
}

@MainActor
private func waitUntil(
    timeout: Duration = .milliseconds(400),
    _ predicate: @MainActor () -> Bool) async -> Bool
{
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if predicate() {
            return true
        }
        await Task.yield()
    }
    return predicate()
}
