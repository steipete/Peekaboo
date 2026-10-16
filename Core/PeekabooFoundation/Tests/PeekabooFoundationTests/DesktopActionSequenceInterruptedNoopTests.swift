import PeekabooFoundation
import Testing

struct DesktopActionSequenceInterruptedNoopTests {
    @Test
    func `interrupted batch keeps a suspected no-op prefix as a no-op`() throws {
        let delivery = DesktopActionOutcome.Delivery(mechanism: .processTargetedEvents, mode: .background)
        let noOp = DesktopActionOutcome.suspectedNoop(
            route: .bridge,
            delivery: delivery,
            unitCount: .one)
        let betweenTargets = try #require(DesktopActionSequenceAccumulator.interruptedBatch(
            completedOutcomes: [noOp],
            succeededCount: 0,
            attemptedCount: 1,
            plannedCount: 2,
            inFlightAttemptMayHaveDispatched: false))
        let outcome = try #require(betweenTargets.outcome)

        #expect(betweenTargets.effect == .suspectedNoop)
        #expect(outcome == noOp)
        #expect(outcome.evidence == .observedNoChange)
        #expect(outcome.escalation == .refreshTarget)

        let duringTarget = try #require(DesktopActionSequenceAccumulator.interruptedBatch(
            completedOutcomes: [noOp],
            succeededCount: 0,
            attemptedCount: 1,
            plannedCount: 2,
            inFlightAttemptMayHaveDispatched: true))
        #expect(duringTarget.effect == .unverifiable)
        #expect(duringTarget.outcome?.state == .indeterminate)
    }
}
