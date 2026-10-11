import Foundation
import PeekabooFoundation
import Testing

private actor RecoveryCounter {
    private var count = 0
    func increment() {
        self.count += 1
    }

    func value() -> Int {
        self.count
    }
}

private struct FixtureRecovery: PeekabooFoundation.RecoverableError {
    let counter: RecoveryCounter
    let isRecoverable: Bool
    let category: ErrorCategory = .network
    let errorCode = "fixture"
    func attemptRecovery() async throws {
        await self.counter.increment()
    }
}

struct RecoveryDispatchPreconditionsTests {
    @Test
    func `unrecoverable errors do not start recovery`() async {
        let counter = RecoveryCounter()
        let manager = ErrorRecoveryManager()
        do {
            try await manager.attemptRecovery(for: FixtureRecovery(counter: counter, isRecoverable: false))
            Issue.record("Recovery unexpectedly started")
        } catch {
            #expect(error is ErrorRecoveryFailure)
        }
        #expect(await counter.value() == 0)
        do {
            try await manager.attemptRecovery(for: FixtureRecovery(counter: counter, isRecoverable: true))
        } catch { Issue.record("Eligible recovery failed: \(error)") }
        #expect(await counter.value() == 1)
    }

    @Test
    func `cancelled tasks do not dispatch recovery`() async {
        let counter = RecoveryCounter()
        let manager = ErrorRecoveryManager()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                try await manager.attemptRecovery(for: FixtureRecovery(counter: counter, isRecoverable: true))
                Issue.record("Cancelled recovery unexpectedly started")
            } catch { #expect(error is CancellationError) }
        }
        await task.value
        #expect(await counter.value() == 0)
    }
}
