import CoreGraphics
import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

struct CaptureVideoCommandTests {
    @Test
    func `buildOptions clamps video defaults`() {
        let cmd = CaptureVideoCommand()
        let opts = cmd.buildOptions()
        #expect(opts.maxFrames >= 1)
        #expect(opts.resolutionCap == 1440)
        #expect(opts.diffStrategy == .fast)
    }

    @Test
    func `parsing requires input positional`() throws {
        #expect(throws: (any Error).self) {
            _ = try CaptureVideoCommand.parse([])
        }
    }

    @Test
    func `parsing sets input positional`() throws {
        let cmd = try CaptureVideoCommand.parse(["/tmp/demo.mov"])
        #expect(cmd.input == "/tmp/demo.mov")
    }
}
