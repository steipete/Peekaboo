import Foundation
import PeekabooCore
import Testing

@testable import PeekabooCLI

@Suite("CaptureCommand basic wiring")
struct CaptureCommandTests {
    @Test("buildOptions clamps values")
    func buildOptionsClamps() async throws {
        var cmd = CaptureLiveCommand()
        cmd.duration = 999
        cmd.idleFps = 9
        cmd.activeFps = 99
        cmd.threshold = 200
        cmd.heartbeatSec = -1
        cmd.quietMs = -10
        cmd.maxFrames = 0
        cmd.resolutionCap = 10
        cmd.maxMb = -5

        let opts = try cmd.buildOptions()
        #expect(opts.duration <= 180)
        #expect(opts.idleFps <= 5)
        #expect(opts.activeFps <= 15)
        #expect(opts.changeThresholdPercent <= 100)
        #expect(opts.heartbeatSeconds >= 0)
        #expect(opts.quietMsToIdle >= 0)
        #expect(opts.maxFrames >= 1)
        #expect(opts.maxMegabytes == nil)
        #expect(opts.resolutionCap == 10)
    }

    @Test("video options defaults")
    func videoOptionsDefaults() async throws {
        let cmd = CaptureVideoCommand()
        let opts = cmd.buildOptions()
        #expect(opts.maxFrames >= 1)
        #expect(opts.resolutionCap == 1440)
        #expect(opts.diffStrategy == .fast)
    }
}
