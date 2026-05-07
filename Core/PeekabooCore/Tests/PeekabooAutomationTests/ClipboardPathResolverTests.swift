import Foundation
import Testing
@testable import PeekabooAutomationKit

struct ClipboardPathResolverTests {
    @Test
    func `file URL expands tilde paths`() {
        let url = ClipboardPathResolver.fileURL(from: "~/Desktop/snippet.png")

        #expect(url.path == NSString(string: "~/Desktop/snippet.png").expandingTildeInPath)
    }

    @Test
    func `optional file path expands tilde paths`() {
        let path = ClipboardPathResolver.filePath(from: "~/Desktop/clip.bin")

        #expect(path == NSString(string: "~/Desktop/clip.bin").expandingTildeInPath)
    }
}
