//
//  ScreenCaptureService+Testing.swift
//  PeekabooCore
//

import AppKit
import CoreGraphics
import Foundation
import PeekabooFoundation

extension ScreenCaptureService {
    struct TestFixtures: Sendable {
        struct Display: Sendable {
            let name: String
            let bounds: CGRect
            let scaleFactor: CGFloat
            let imageSize: CGSize
            let imageData: Data
        }

        struct Window: Sendable {
            let application: ServiceApplicationInfo
            let title: String
            let bounds: CGRect
            let imageData: Data
        }

        let displays: [Display]
        let windowsByPID: [Int32: [Window]]
        let applicationsByIdentifier: [String: ServiceApplicationInfo]

        init(displays: [Display], windows: [Window] = []) {
            precondition(!displays.isEmpty, "At least one display fixture is required")
            self.displays = displays
            self.windowsByPID = Dictionary(grouping: windows, by: { $0.application.processIdentifier })

            var lookup: [String: ServiceApplicationInfo] = [:]
            for window in windows {
                let app = window.application
                lookup[app.name.lowercased()] = app
                if let bundle = app.bundleIdentifier?.lowercased() {
                    lookup[bundle] = app
                }
                lookup["pid:\(app.processIdentifier)"] = app
            }
            self.applicationsByIdentifier = lookup
        }

        func display(at index: Int?) throws -> Display {
            if let index {
                guard index >= 0, index < self.displays.count else {
                    throw PeekabooError.invalidInput(
                        """
                        displayIndex: Index \(index) is out of range. Available displays: 0-\(self.displays.count - 1)
                        """)
                }
                return self.displays[index]
            }
            return self.displays[0]
        }

        func windows(for app: ServiceApplicationInfo) -> [Window] {
            self.windowsByPID[app.processIdentifier] ?? []
        }

        func application(for identifier: String) -> ServiceApplicationInfo? {
            self.applicationsByIdentifier[identifier.lowercased()]
        }

        @MainActor
        static func makeImage(
            width: Int,
            height: Int,
            color: NSColor = .white) -> Data
        {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo)
            else {
                return Data()
            }
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            guard let cgImage = context.makeImage() else { return Data() }
            let image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:])
            else {
                return Data()
            }
            return png
        }
    }

    @MainActor
    static func makeTestService(
        fixtures: TestFixtures,
        permissionGranted: Bool = true,
        apis: [ScreenCaptureAPI] = [.modern],
        loggingService: any LoggingServiceProtocol = MockLoggingService()) -> ScreenCaptureService
    {
        let dependencies = Dependencies(
            visualizerClient: MockVisualizationClient(),
            permissionEvaluator: StubPermissionEvaluator(granted: permissionGranted),
            fallbackRunner: ScreenCaptureFallbackRunner(apis: apis),
            applicationResolver: FixtureApplicationResolver(fixtures: fixtures),
            makeModernOperator: { _, _ in
                MockModernCaptureOperator(fixtures: fixtures)
            },
            makeLegacyOperator: { _ in
                MockModernCaptureOperator(fixtures: fixtures)
            })
        return ScreenCaptureService(loggingService: loggingService, dependencies: dependencies)
    }
}

private struct StubPermissionEvaluator: ScreenRecordingPermissionEvaluating {
    let granted: Bool
    func hasPermission(logger: CategoryLogger) async -> Bool {
        if !self.granted {
            logger.warning("Test harness denying permission for screen capture")
        }
        return self.granted
    }
}

@MainActor
private final class MockVisualizationClient: VisualizationClientProtocol, @unchecked Sendable {
    private(set) var flashes: [CGRect] = []

    func connect() {}

    func showScreenshotFlash(in rect: CGRect) async -> Bool {
        self.flashes.append(rect)
        return true
    }
}

private struct FixtureApplicationResolver: ApplicationResolving {
    let fixtures: ScreenCaptureService.TestFixtures

    func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        if let app = fixtures.application(for: identifier) {
            return app
        }
        throw NotFoundError.application(identifier)
    }
}

private final class MockModernCaptureOperator: ModernScreenCaptureOperating, LegacyScreenCaptureOperating,
@unchecked Sendable {
    private let fixtures: ScreenCaptureService.TestFixtures

    init(fixtures: ScreenCaptureService.TestFixtures) {
        self.fixtures = fixtures
    }

    func captureScreen(displayIndex: Int?, correlationId: String) async throws -> CaptureResult {
        let display = try fixtures.display(at: displayIndex)
        let metadata = CaptureMetadata(
            size: display.imageSize,
            mode: .screen,
            displayInfo: DisplayInfo(
                index: displayIndex ?? 0,
                name: display.name,
                bounds: display.bounds,
                scaleFactor: display.scaleFactor))
        return CaptureResult(imageData: display.imageData, metadata: metadata)
    }

    func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        correlationId: String) async throws -> CaptureResult
    {
        let windows = self.fixtures.windows(for: app)
        guard !windows.isEmpty else {
            throw NotFoundError.window(app: app.name)
        }

        let target: ScreenCaptureService.TestFixtures.Window
        if let index = windowIndex {
            guard index >= 0, index < windows.count else {
                throw PeekabooError.invalidInput(
                    "windowIndex: Index \(index) is out of range. Available windows: 0-\(windows.count - 1)")
            }
            target = windows[index]
        } else {
            target = windows[0]
        }

        let metadata = CaptureMetadata(
            size: target.bounds.size,
            mode: .window,
            applicationInfo: app,
            windowInfo: ServiceWindowInfo(
                windowID: target.title.hashValue,
                title: target.title,
                bounds: target.bounds,
                isMinimized: false,
                isMainWindow: true,
                windowLevel: 0,
                alpha: 1.0,
                index: windowIndex ?? 0))
        return CaptureResult(imageData: target.imageData, metadata: metadata)
    }

    func captureArea(_ rect: CGRect, correlationId: String) async throws -> CaptureResult {
        let width = max(1, Int(rect.width.rounded()))
        let height = max(1, Int(rect.height.rounded()))
        let imageData = ScreenCaptureService.TestFixtures.makeImage(width: width, height: height, color: .systemGray)
        let metadata = CaptureMetadata(
            size: CGSize(width: rect.width, height: rect.height),
            mode: .area,
            displayInfo: DisplayInfo(
                index: 0,
                name: self.fixtures.displays.first?.name,
                bounds: rect,
                scaleFactor: self.fixtures.displays.first?.scaleFactor ?? 1.0))
        return CaptureResult(imageData: imageData, metadata: metadata)
    }
}
