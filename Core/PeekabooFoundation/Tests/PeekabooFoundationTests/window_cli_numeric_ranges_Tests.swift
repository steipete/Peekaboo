import PeekabooFoundation
import Testing

struct WindowCLINumericRangesTests {
    @Test(arguments: [-1, 0, Int(Int32.max) + 1])
    func `rejects invalid process identifiers`(pid: Int) {
        #expect(throws: InteractionTargetSelector.ValidationError.invalidProcessIdentifier) {
            try InteractionTargetSelector(processIdentifier: pid).validate(policy: .windowCLI())
        }
    }

    @Test
    func `rejects window identifiers that cannot be CG window IDs`() {
        #expect(throws: InteractionTargetSelector.ValidationError.invalidWindowID) {
            try InteractionTargetSelector(windowID: Int(UInt32.max) + 1).validate(policy: .windowCLI())
        }
    }

    @Test
    func `valid upper bounds and matching aliases remain supported`() throws {
        try InteractionTargetSelector(windowID: Int(UInt32.max)).validate(policy: .windowCLI())
        try InteractionTargetSelector(processIdentifier: Int(Int32.max)).validate(policy: .windowCLI())
        try InteractionTargetSelector(applicationIdentifier: "PID:42", processIdentifier: 42)
            .validate(policy: .windowCLI())
    }
}
