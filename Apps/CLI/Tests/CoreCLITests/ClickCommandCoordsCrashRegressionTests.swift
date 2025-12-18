import Darwin
import Testing
@testable import PeekabooCLI

@Suite("ClickCommand coordinate crash regression")
struct ClickCommandCoordsCrashRegressionTests {
    @Test("click --coords ',' returns failure (no crash)")
    @MainActor
    func clickCoordsCommaReturnsFailure() async {
        let status = await executePeekabooCLI(arguments: ["peekaboo", "click", "--coords", ",", "--json"])
        #expect(status == EXIT_FAILURE)
    }
}
