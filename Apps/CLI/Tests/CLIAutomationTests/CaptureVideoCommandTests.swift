import CoreGraphics
import Foundation
import PeekabooCore
import Testing

@testable import PeekabooCLI

@Suite("CaptureVideoCommand sampling")
struct CaptureVideoCommandTests {
    @Test("buildOptions clamps video defaults")
    func buildOptions() async throws {
        var cmd = CaptureVideoCommand()
        let opts = cmd.buildOptions()
        #expect(opts.maxFrames >= 1)
        #expect(opts.resolutionCap == 1440)
        #expect(opts.diffStrategy == .fast)
    }
}
