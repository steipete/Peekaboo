import Foundation
import PeekabooCore
import Testing

@testable import PeekabooCLI

// Note: These are lightweight, non-I/O tests—real screen/video IO is not exercised here.
// They validate flag validation and MP4 toggle plumbing to replace the removed watch suites
// without requiring fixtures or permissions.
@Suite("Capture command validation")
struct CaptureEndToEndTests {
    @Test("video flags reject dual sampling")
    func videoMutualExclusion() async throws {
        var cmd = CaptureVideoCommand()
        cmd.input = "/tmp/foo.mov"
        cmd.sampleFps = 2
        cmd.everyMs = 100
        await #expect(throws: ValidationError.self) {
            _ = try cmd.run(using: CommandRuntime.mock())
        }
    }

    @Test("live uses temp output when no path provided")
    func liveTempPath() async throws {
        var cmd = CaptureLiveCommand()
        cmd.runtime = CommandRuntime.mock()
        let url = try cmd.resolveOutputDirectory()
        #expect(url.path.contains("capture-sessions"))
    }
}

extension CommandRuntime {
    fileprivate static func mock() -> CommandRuntime {
        CommandRuntime(services: PeekabooServicesMock(), configuration: .init(jsonOutput: true))
    }
}

private struct PeekabooServicesMock: PeekabooServiceProviding {
    var screenCapture: any ScreenCaptureServiceProtocol { ScreenCaptureServiceMock() }
    var screens: any ScreenServiceProtocol { ScreenServiceMock() }
    var windows: any WindowServiceProtocol { WindowServiceMock() }
    var menus: any MenuServiceProtocol { fatalError("unused") }
}

private struct ScreenCaptureServiceMock: ScreenCaptureServiceProtocol {
    func captureScreen(
        displayIndex: Int?,
        visualizerMode: CaptureVisualizerMode
    ) async throws -> CaptureResult { throw PeekabooError
        .captureFailed(reason: "mock")
    }

    func captureWindow(
        appIdentifier: String,
        windowIndex: Int?,
        visualizerMode: CaptureVisualizerMode
    ) async throws -> CaptureResult { throw PeekabooError
        .captureFailed(reason: "mock")
    }

    func captureFrontmost(visualizerMode: CaptureVisualizerMode) async throws -> CaptureResult { throw PeekabooError
        .captureFailed(reason: "mock")
    }

    func captureArea(
        _ rect: CGRect,
        visualizerMode: CaptureVisualizerMode
    ) async throws -> CaptureResult { throw PeekabooError
        .captureFailed(reason: "mock")
    }

    func hasScreenRecordingPermission() async -> Bool { true }
}

private struct ScreenServiceMock: ScreenServiceProtocol {
    func listScreens() -> [ScreenInfo] { [ScreenInfo(index: 0, name: "Mock", frame: .zero)] }
}

private struct WindowServiceMock: WindowServiceProtocol {
    func listWindows() async throws -> [ServiceWindowInfo] { [] }
    // Signature defined by WindowServiceProtocol; suppress parameter-count lint for the mock implementation.
    // swiftlint:disable:next function_parameter_count
    func focusWindow(
        applicationName: String,
        windowIndex: Int?,
        timeout: TimeInterval?,
        retryCount: Int?,
        spaceSwitch: Bool,
        bringToCurrentSpace: Bool
    ) async throws {}
}
