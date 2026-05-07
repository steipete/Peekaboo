import Foundation
import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe))
struct RunCommandPathTests {
    @Test
    func `run command paths expand tilde`() throws {
        var command = try RunCommand.parse(["~/Library/Caches/script.peekaboo.json"])
        command.output = "~/Library/Caches/result.json"
        let output = try #require(command.output)

        #expect(command.resolvedScriptPath() == NSString(string: "~/Library/Caches/script.peekaboo.json")
            .expandingTildeInPath)
        #expect(command.resolvedOutputPath(from: output) == NSString(string: "~/Library/Caches/result.json")
            .expandingTildeInPath)
    }
}
