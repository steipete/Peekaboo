import CoreGraphics
import Foundation
import PeekabooCore
import Testing

@testable import PeekabooCLI

@Suite("Capture live behavior (logic only)")
struct CaptureLiveBehaviorTests {
    @Test("resolveMode defaults to window when targeting app/pid/title")
    func resolveModeWindow() async throws {
        var cmd = CaptureLiveCommand()
        cmd.app = "Safari"
        #expect(cmd.resolveMode() == .window)
        cmd.app = nil
        cmd.windowTitle = "Log"
        #expect(cmd.resolveMode() == .window)
    }

    @Test("resolveMode defaults to frontmost when no targeting")
    func resolveModeDefault() async throws {
        let cmd = CaptureLiveCommand()
        #expect(cmd.resolveMode() == .frontmost)
    }
}
