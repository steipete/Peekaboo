import PeekabooFoundation
import Testing

struct InteractionTargetSelectorPIDAliasTests {
    @Test(arguments: ["  PID:42  ", "pid:42", "  PiD:42  "])
    func `mutation process aliases use the normalized owner`(application: String) throws {
        let selector = InteractionTargetSelector(applicationIdentifier: application)
        try selector.validate(policy: .mutationSafe)
        #expect(try selector.normalizedApplicationTarget(policy: .mutationSafe) ==
            selector.normalizedApplicationIdentifier)
    }

    @Test(arguments: ["  pid:41  ", "  pid:42  ", "  pid:not-a-number  ", "Preview"])
    func `mutation syntax rejects both owner channels regardless of PID alias`(application: String) {
        let selector = InteractionTargetSelector(applicationIdentifier: application, processIdentifier: 42)
        for policy in [InteractionTargetSelector.Policy.interaction, .mutationSafe] {
            #expect(throws: InteractionTargetSelector.ValidationError.applicationAndProcessIdentifier) {
                try selector.normalizedApplicationTarget(policy: policy)
            }
        }
    }
}
