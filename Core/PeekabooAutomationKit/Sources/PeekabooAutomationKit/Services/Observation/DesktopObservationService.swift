import CoreGraphics
import Foundation

@MainActor
public protocol DesktopObservationServiceProtocol: Sendable {
    func observe(_ request: DesktopObservationRequest) async throws -> DesktopObservationResult
}

@MainActor
public final class DesktopObservationService: DesktopObservationServiceProtocol {
    private let screenCapture: any ScreenCaptureServiceProtocol
    private let automation: any UIAutomationServiceProtocol
    private let targetResolver: any ObservationTargetResolving

    public init(
        screenCapture: any ScreenCaptureServiceProtocol,
        automation: any UIAutomationServiceProtocol,
        applications: any ApplicationServiceProtocol)
    {
        self.screenCapture = screenCapture
        self.automation = automation
        self.targetResolver = ObservationTargetResolver(applications: applications)
    }

    public init(
        screenCapture: any ScreenCaptureServiceProtocol,
        automation: any UIAutomationServiceProtocol,
        targetResolver: any ObservationTargetResolving)
    {
        self.screenCapture = screenCapture
        self.automation = automation
        self.targetResolver = targetResolver
    }

    public func observe(_ request: DesktopObservationRequest) async throws -> DesktopObservationResult {
        let tracer = DesktopObservationTraceRecorder()

        let target = try await tracer.span("target.resolve") {
            try await self.targetResolver.resolve(request.target)
        }

        let capture = try await tracer.span("capture.\(Self.captureSpanName(for: target.kind))") {
            try await self.capture(target, options: request.capture)
        }

        let elements = try await self.detectIfNeeded(
            capture: capture,
            target: target,
            request: request,
            tracer: tracer)

        return DesktopObservationResult(
            target: target,
            capture: capture,
            elements: elements,
            files: DesktopObservationFiles(rawScreenshotPath: capture.savedPath),
            timings: tracer.timings(),
            diagnostics: DesktopObservationDiagnostics(warnings: capture.warning.map { [$0] } ?? []))
    }

    private func capture(
        _ target: ResolvedObservationTarget,
        options: DesktopCaptureOptions) async throws -> CaptureResult
    {
        switch target.kind {
        case let .screen(index):
            return try await self.screenCapture.captureScreen(
                displayIndex: index,
                visualizerMode: options.visualizerMode,
                scale: options.scale)

        case .frontmost:
            return try await self.screenCapture.captureFrontmost(
                visualizerMode: options.visualizerMode,
                scale: options.scale)

        case .appWindow:
            guard let app = target.app else {
                throw DesktopObservationError.targetNotFound("application window")
            }
            return try await self.screenCapture.captureWindow(
                appIdentifier: app.bundleIdentifier ?? app.name,
                windowIndex: target.window?.index,
                visualizerMode: options.visualizerMode,
                scale: options.scale)

        case let .windowID(windowID):
            return try await self.screenCapture.captureWindow(
                windowID: windowID,
                visualizerMode: options.visualizerMode,
                scale: options.scale)

        case let .area(rect):
            return try await self.screenCapture.captureArea(
                rect,
                visualizerMode: options.visualizerMode,
                scale: options.scale)

        case .menubar:
            throw DesktopObservationError.unsupportedTarget("menubar")

        case .menubarPopover:
            throw DesktopObservationError.unsupportedTarget("menubar popover")
        }
    }

    private func detectIfNeeded(
        capture: CaptureResult,
        target: ResolvedObservationTarget,
        request: DesktopObservationRequest,
        tracer: DesktopObservationTraceRecorder) async throws -> ElementDetectionResult?
    {
        guard request.detection.mode != .none else {
            return nil
        }

        var context = target.detectionContext ?? Self.windowContext(from: capture)
        context = WindowContext(
            applicationName: context?.applicationName,
            applicationBundleId: context?.applicationBundleId,
            applicationProcessId: context?.applicationProcessId,
            windowTitle: context?.windowTitle,
            windowID: context?.windowID,
            windowBounds: context?.windowBounds,
            shouldFocusWebContent: request.detection.allowWebFocusFallback)

        return try await tracer.span("detection.ax") {
            try await self.automation.detectElements(
                in: capture.imageData,
                snapshotId: request.output.snapshotID,
                windowContext: context)
        }
    }

    private static func windowContext(from capture: CaptureResult) -> WindowContext? {
        guard capture.metadata.applicationInfo != nil || capture.metadata.windowInfo != nil else {
            return nil
        }

        return WindowContext(
            applicationName: capture.metadata.applicationInfo?.name,
            applicationBundleId: capture.metadata.applicationInfo?.bundleIdentifier,
            applicationProcessId: capture.metadata.applicationInfo?.processIdentifier,
            windowTitle: capture.metadata.windowInfo?.title,
            windowID: capture.metadata.windowInfo?.windowID,
            windowBounds: capture.metadata.windowInfo?.bounds)
    }

    private static func captureSpanName(for kind: ResolvedObservationKind) -> String {
        switch kind {
        case .screen:
            "screen"
        case .frontmost:
            "frontmost"
        case .appWindow, .windowID:
            "window"
        case .area, .menubar, .menubarPopover:
            "area"
        }
    }
}

@MainActor
final class DesktopObservationTraceRecorder {
    private var spans: [ObservationSpan] = []

    func span<T>(_ name: String, operation: () async throws -> T) async throws -> T {
        let start = ContinuousClock.now
        do {
            let value = try await operation()
            self.record(name, start: start)
            return value
        } catch {
            self.record(name, start: start, metadata: ["success": "false"])
            throw error
        }
    }

    func timings() -> ObservationTimings {
        ObservationTimings(spans: self.spans)
    }

    private func record(_ name: String, start: ContinuousClock.Instant, metadata: [String: String] = [:]) {
        let duration = start.duration(to: ContinuousClock.now)
        let milliseconds = Double(duration.components.seconds * 1000)
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000
        self.spans.append(ObservationSpan(name: name, durationMS: milliseconds, metadata: metadata))
    }
}
