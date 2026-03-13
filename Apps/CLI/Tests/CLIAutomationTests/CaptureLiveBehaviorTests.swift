import CoreGraphics
import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

struct CaptureLiveBehaviorTests {
    @Test
    func `resolveMode defaults to window when targeting app/pid/title`() {
        var cmd = CaptureLiveCommand()
        cmd.app = "Safari"
        #expect(cmd.resolveMode() == .window)
        cmd.app = nil
        cmd.windowTitle = "Log"
        #expect(cmd.resolveMode() == .window)
    }

    @Test
    func `resolveMode defaults to frontmost when no targeting`() {
        let cmd = CaptureLiveCommand()
        #expect(cmd.resolveMode() == .frontmost)
    }
}
