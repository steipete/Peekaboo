import CoreGraphics
import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

struct CaptureLiveBehaviorTests {
    @Test
    func `resolveMode defaults to window when targeting app pid title or index`() throws {
        var cmd = CaptureLiveCommand()
        cmd.app = "Safari"
        #expect(try cmd.resolveMode() == .window)
        cmd.app = nil
        cmd.windowTitle = "Log"
        #expect(try cmd.resolveMode() == .window)
        cmd.windowTitle = nil
        cmd.windowIndex = 0
        #expect(try cmd.resolveMode() == .window)
    }

    @Test
    func `resolveMode defaults to frontmost when no targeting`() throws {
        let cmd = CaptureLiveCommand()
        #expect(try cmd.resolveMode() == .frontmost)
    }
}
