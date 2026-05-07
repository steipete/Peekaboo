import Foundation
import PeekabooAutomation
import PeekabooFoundation
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

    @Test
    func `argument resolver validates source mode and aliases`() throws {
        #expect(try CaptureToolArgumentResolver.source(from: nil) == .live)
        #expect(try CaptureToolArgumentResolver.mode(
            from: nil,
            hasRegion: true,
            hasWindowTarget: false) == .area)
        #expect(try CaptureToolArgumentResolver.mode(
            from: "region",
            hasRegion: false,
            hasWindowTarget: false) == .area)
        #expect(CaptureToolArgumentResolver.applicationIdentifier(app: nil, pid: 123) == "PID:123")

        #expect(throws: PeekabooError.self) {
            _ = try CaptureToolArgumentResolver.source(from: "camera")
        }
        #expect(throws: PeekabooError.self) {
            _ = try CaptureToolArgumentResolver.mode(
                from: "banana",
                hasRegion: false,
                hasWindowTarget: false)
        }
    }

    @Test
    func `argument resolver validates region diff strategy and capture focus`() throws {
        #expect(try CaptureToolArgumentResolver.region(from: "1, 2, 30, 40") == CGRect(
            x: 1,
            y: 2,
            width: 30,
            height: 40))
        #expect(try CaptureToolArgumentResolver.diffStrategy(from: nil) == .fast)
        #expect(try CaptureToolArgumentResolver.captureFocus(from: "foreground") == .foreground)

        #expect(throws: PeekabooError.self) {
            _ = try CaptureToolArgumentResolver.region(from: "1,two,30,40")
        }
        #expect(throws: PeekabooError.self) {
            _ = try CaptureToolArgumentResolver.region(from: "1,2,0,40")
        }
        #expect(throws: PeekabooError.self) {
            _ = try CaptureToolArgumentResolver.diffStrategy(from: "slow")
        }
        #expect(throws: PeekabooError.self) {
            _ = try CaptureToolArgumentResolver.captureFocus(from: "middle")
        }
    }
}
