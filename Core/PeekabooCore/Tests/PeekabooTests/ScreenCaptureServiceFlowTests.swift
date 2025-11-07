import AppKit
import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooCore

@Suite("ScreenCaptureService test harness", .tags(.ui))
@MainActor
struct ScreenCaptureServiceFlowTests {
    private func makeFixtures() -> ScreenCaptureService.TestFixtures {
        let primary = ScreenCaptureService.TestFixtures.Display(
            name: "Primary",
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            scaleFactor: 2.0,
            imageSize: CGSize(width: 1920, height: 1080),
            imageData: ScreenCaptureService.TestFixtures.makeImage(width: 10, height: 5, color: .systemBlue))

        let external = ScreenCaptureService.TestFixtures.Display(
            name: "External",
            bounds: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            scaleFactor: 2.0,
            imageSize: CGSize(width: 2560, height: 1440),
            imageData: ScreenCaptureService.TestFixtures.makeImage(width: 8, height: 8, color: .systemPink))

        let app = ServiceApplicationInfo(
            processIdentifier: 4242,
            bundleIdentifier: "com.peekaboo.testapp",
            name: "TestApp",
            bundlePath: "/Applications/TestApp.app",
            isActive: true,
            isHidden: false,
            windowCount: 2)

        let windows = [
            ScreenCaptureService.TestFixtures.Window(
                application: app,
                title: "Dashboard",
                bounds: CGRect(x: 200, y: 200, width: 900, height: 700),
                imageData: ScreenCaptureService.TestFixtures.makeImage(width: 6, height: 4, color: .systemGreen)),
            ScreenCaptureService.TestFixtures.Window(
                application: app,
                title: "Logs",
                bounds: CGRect(x: 300, y: 300, width: 600, height: 400),
                imageData: ScreenCaptureService.TestFixtures.makeImage(width: 4, height: 3, color: .systemYellow)),
        ]

        return ScreenCaptureService.TestFixtures(displays: [primary, external], windows: windows)
    }

    @Test("captureScreen returns fixture metadata")
    func captureScreenUsesFixtures() async throws {
        let fixtures = self.makeFixtures()
        let logging = MockLoggingService()
        let service = ScreenCaptureService.makeTestService(fixtures: fixtures, loggingService: logging)

        let result = try await service.captureScreen(displayIndex: 1)

        #expect(result.metadata.displayInfo?.name == "External")
        #expect(result.metadata.size == CGSize(width: 2560, height: 1440))
        #expect(result.imageData == fixtures.displays[1].imageData)
        #expect(logging.loggedEntries.isEmpty == false)
    }

    @Test("captureWindow resolves applications via fixtures")
    func captureWindowUsesFixtures() async throws {
        let fixtures = self.makeFixtures()
        let service = ScreenCaptureService.makeTestService(fixtures: fixtures)

        let result = try await service.captureWindow(appIdentifier: "com.peekaboo.testapp", windowIndex: 1)

        #expect(result.metadata.windowInfo?.title == "Logs")
        #expect(result.metadata.applicationInfo?.bundleIdentifier == "com.peekaboo.testapp")
        #expect(result.metadata.windowInfo?.index == 1)
    }

    @Test("permission denial surfaces permission error")
    func permissionFailureShortCircuitsCapture() async {
        let fixtures = self.makeFixtures()
        let service = ScreenCaptureService.makeTestService(fixtures: fixtures, permissionGranted: false)

        do {
            _ = try await service.captureScreen(displayIndex: nil)
            Issue.record("Expected captureScreen to throw when permission denied")
        } catch PeekabooError.permissionDeniedScreenRecording {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
