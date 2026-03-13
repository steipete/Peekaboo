import Darwin
import Testing
@testable import PeekabooCLI

struct ClickCommandCoordsCrashRegressionTests {
    @Test
    @MainActor
    func `click --coords ',' returns failure (no crash)`() async {
        let status = await executePeekabooCLI(arguments: ["peekaboo", "click", "--coords", ",", "--json"])
        #expect(status == EXIT_FAILURE)
    }
}
