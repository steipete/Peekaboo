import Foundation
import Testing
@testable import PeekabooAgentRuntime

struct CaptureToolPathResolverTests {
    @Test
    func `output directory expands tilde`() {
        let url = CaptureToolPathResolver.outputDirectory(from: "~/Desktop/peekaboo-capture")

        #expect(url.path == NSString(string: "~/Desktop/peekaboo-capture").expandingTildeInPath)
    }

    @Test
    func `video file paths expand tilde`() {
        let inputURL = CaptureToolPathResolver.fileURL(from: "~/Movies/input.mov")
        let outputPath = CaptureToolPathResolver.filePath(from: "~/Desktop/output.mp4")

        #expect(inputURL.path == NSString(string: "~/Movies/input.mov").expandingTildeInPath)
        #expect(outputPath == NSString(string: "~/Desktop/output.mp4").expandingTildeInPath)
    }
}
