import Foundation
import PeekabooFoundation
import Testing

private actor RecoveryGate {
    private var count = 0
    private var release: CheckedContinuation<Void, Never>?
    private var entered: CheckedContinuation<Void, Never>?
    func recover() async {
        self.count += 1
        if self.count == 1 {
            await withCheckedContinuation { continuation in
                self.release = continuation
                self.entered?.resume()
                self.entered = nil
            }
        }
    }

    func waitUntilEntered() async {
        if self.release != nil {
            return
        }
        await withCheckedContinuation { self.entered = $0 }
    }

    func open() {
        self.release?.resume(); self.release = nil
    }

    func value() -> Int {
        self.count
    }
}

private struct GatedRecovery: PeekabooFoundation.RecoverableError {
    let gate: RecoveryGate
    let category: ErrorCategory = .network
    let errorCode = "gated"
    func attemptRecovery() async throws {
        await self.gate.recover()
    }
}

struct RecoverySingleFlightTests {
    @Test
    func `concurrent recovery does not repeat the action`() async throws {
        let gate = RecoveryGate()
        let manager = ErrorRecoveryManager()
        let error = GatedRecovery(gate: gate)
        let first = Task { try await manager.attemptRecovery(for: error) }
        await gate.waitUntilEntered()
        do {
            try await manager.attemptRecovery(for: error)
            Issue.record("Duplicate recovery unexpectedly started")
        } catch { #expect(error is ErrorRecoveryFailure) }
        #expect(await gate.value() == 1)
        await gate.open()
        try await first.value
        try await manager.attemptRecovery(for: error)
        #expect(await gate.value() == 2)
    }
}
