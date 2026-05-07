import Foundation
import Testing
@testable import PeekabooCLI

struct CaptureCommandPathTests {
    @Test
    func `live output directory expands tilde`() throws {
        var cmd = CaptureLiveCommand()
        cmd.path = "~/Desktop/peekaboo-live"

        let url = try cmd.resolveOutputDirectory()

        #expect(url.path == NSString(string: "~/Desktop/peekaboo-live").expandingTildeInPath)
    }

    @Test
    func `video paths expand tilde`() throws {
        var cmd = CaptureVideoCommand()
        cmd.input = "~/Movies/input.mov"
        cmd.path = "~/Desktop/peekaboo-video"
        cmd.videoOut = "~/Desktop/peekaboo-video.mp4"

        let inputURL = cmd.inputVideoURL()
        let outputURL = try cmd.resolveOutputDirectory()
        let videoOut = CaptureCommandPathResolver.filePath(from: cmd.videoOut)

        #expect(inputURL.path == NSString(string: "~/Movies/input.mov").expandingTildeInPath)
        #expect(outputURL.path == NSString(string: "~/Desktop/peekaboo-video").expandingTildeInPath)
        #expect(videoOut == NSString(string: "~/Desktop/peekaboo-video.mp4").expandingTildeInPath)
    }
}
