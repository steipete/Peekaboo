import Commander
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

    @Test("parsing requires input positional")
    func parsingRequiresInput() async throws {
        #expect(throws: (any Error).self) {
            _ = try CaptureVideoCommand.parse([])
        }
    }

    @Test("parsing sets input positional")
    func parsingSetsInput() async throws {
        let cmd = try CaptureVideoCommand.parse(["/tmp/demo.mov"])
        #expect(cmd.input == "/tmp/demo.mov")
    }

    @Test("commanderSignature includes input argument")
    func signatureIncludesInputArgument() async throws {
        let signature = CaptureVideoCommand.commanderSignature()
        #expect(signature.arguments.count == 1)
        #expect(signature.arguments.first?.label == "input")
        #expect(signature.arguments.first?.isOptional == false)
    }

    @Test("parsing sets input with options")
    func parsingSetsInputWithOptions() async throws {
        let cmd = try CaptureVideoCommand.parse(["/path/to/video.mp4", "--max-frames", "10", "--sample-fps", "5"])
        #expect(cmd.input == "/path/to/video.mp4")
        #expect(cmd.maxFrames == 10)
        #expect(cmd.sampleFps == 5)
    }
}
