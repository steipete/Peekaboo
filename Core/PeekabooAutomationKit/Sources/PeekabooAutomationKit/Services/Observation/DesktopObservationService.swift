import CoreGraphics
import Foundation
import PeekabooFoundation

@MainActor
public protocol DesktopObservationServiceProtocol: Sendable {
    func observe(_ request: DesktopObservationRequest) async throws -> DesktopObservationResult
}

@MainActor
public final class DesktopObservationService: DesktopObservationServiceProtocol {
    private let screenCapture: any ScreenCaptureServiceProtocol
    private let automation: any UIAutomationServiceProtocol
    private let targetResolver: any ObservationTargetResolving
    private let outputWriter: any ObservationOutputWriting
    private let stateSnapshotProvider: any DesktopStateSnapshotProviding
    private let ocrRecognizer: any OCRRecognizing

    public init(
        screenCapture: any ScreenCaptureServiceProtocol,
        automation: any UIAutomationServiceProtocol,
        applications: any ApplicationServiceProtocol,
        menu: (any MenuServiceProtocol)? = nil,
        screens: any ScreenServiceProtocol = ScreenService(),
        snapshotManager: (any SnapshotManagerProtocol)? = nil,
        ocrRecognizer: any OCRRecognizing = OCRService())
    {
        self.screenCapture = screenCapture
        self.automation = automation
        self.targetResolver = ObservationTargetResolver(applications: applications, menu: menu, screens: screens)
        self.outputWriter = ObservationOutputWriter(snapshotManager: snapshotManager)
        self.stateSnapshotProvider = DesktopStateSnapshotProvider(applications: applications)
        self.ocrRecognizer = ocrRecognizer
    }

    public init(
        screenCapture: any ScreenCaptureServiceProtocol,
        automation: any UIAutomationServiceProtocol,
        targetResolver: any ObservationTargetResolving,
        outputWriter: any ObservationOutputWriting = ObservationOutputWriter(),
        stateSnapshotProvider: any DesktopStateSnapshotProviding = EmptyDesktopStateSnapshotProvider(),
        ocrRecognizer: any OCRRecognizing = OCRService())
    {
        self.screenCapture = screenCapture
        self.automation = automation
        self.targetResolver = targetResolver
        self.outputWriter = outputWriter
        self.stateSnapshotProvider = stateSnapshotProvider
        self.ocrRecognizer = ocrRecognizer
    }

    public func observe(_ request: DesktopObservationRequest) async throws -> DesktopObservationResult {
        let tracer = DesktopObservationTraceRecorder()

        let stateSnapshot = try await tracer.span("state.snapshot") {
            try await self.stateSnapshotProvider.snapshot(for: request.target)
        }

        let target = try await tracer.span("target.resolve") {
            try await self.targetResolver.resolve(request.target, snapshot: stateSnapshot)
        }

        let rawCapture = try await tracer.span("capture.\(Self.captureSpanName(for: target.kind))") {
            try await self.capture(target, options: request.capture, snapshot: stateSnapshot)
        }
        let capture = Self.normalize(capture: rawCapture, for: target)

        let detection = try await self.detectIfNeeded(
            capture: capture,
            target: target,
            request: request,
            tracer: tracer)
        let ocr = try await self.recognizeOCRIfNeeded(
            capture: capture,
            request: request,
            tracer: tracer)
        let elements = self.combineDetectionAndOCR(
            detection: detection,
            ocr: ocr,
            capture: capture,
            target: target,
            request: request)
        let files = try await self.writeOutputIfNeeded(
            capture: capture,
            elements: elements,
            options: request.output,
            tracer: tracer)

        return DesktopObservationResult(
            target: target,
            capture: capture,
            elements: elements,
            ocr: ocr,
            files: files,
            timings: tracer.timings(),
            diagnostics: DesktopObservationDiagnostics(
                warnings: capture.warning.map { [$0] } ?? [],
                stateSnapshot: DesktopStateSnapshotSummary(stateSnapshot),
                target: Self.targetDiagnostics(for: request.target, resolved: target)))
    }

    private func capture(
        _ target: ResolvedObservationTarget,
        options: DesktopCaptureOptions,
        snapshot _: DesktopStateSnapshot) async throws -> CaptureResult
    {
        guard let engineAwareCapture = self.engineAwareCapture else {
            return try await self.captureResolvedTarget(target, options: options)
        }

        return try await engineAwareCapture.withCaptureEngine(options.engine) {
            try await self.captureResolvedTarget(target, options: options)
        }
    }

    private func captureResolvedTarget(
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
            guard let bounds = target.bounds else {
                throw DesktopObservationError.targetNotFound("menu bar bounds")
            }
            return try await self.screenCapture.captureArea(
                bounds,
                visualizerMode: options.visualizerMode,
                scale: options.scale)

        case .menubarPopover:
            if let windowID = target.window?.windowID {
                return try await self.screenCapture.captureWindow(
                    windowID: CGWindowID(windowID),
                    visualizerMode: options.visualizerMode,
                    scale: options.scale)
            }
            guard let bounds = target.bounds else {
                throw DesktopObservationError.targetNotFound("menu bar popover bounds")
            }
            return try await self.screenCapture.captureArea(
                bounds,
                visualizerMode: options.visualizerMode,
                scale: options.scale)
        }
    }

    private static func normalize(capture: CaptureResult, for target: ResolvedObservationTarget) -> CaptureResult {
        guard
            let resolvedWindow = target.window,
            let capturedWindow = capture.metadata.windowInfo,
            capturedWindow.windowID == resolvedWindow.windowID
        else {
            return capture
        }

        let normalizedWindow = ServiceWindowInfo(
            windowID: capturedWindow.windowID,
            title: resolvedWindow.title.isEmpty ? capturedWindow.title : resolvedWindow.title,
            bounds: resolvedWindow.bounds,
            isMinimized: capturedWindow.isMinimized,
            isMainWindow: capturedWindow.isMainWindow,
            windowLevel: capturedWindow.windowLevel,
            alpha: capturedWindow.alpha,
            index: resolvedWindow.index,
            spaceID: capturedWindow.spaceID,
            spaceName: capturedWindow.spaceName,
            screenIndex: capturedWindow.screenIndex,
            screenName: capturedWindow.screenName,
            layer: capturedWindow.layer,
            isOnScreen: capturedWindow.isOnScreen,
            sharingState: capturedWindow.sharingState,
            isExcludedFromWindowsMenu: capturedWindow.isExcludedFromWindowsMenu)
        let metadata = CaptureMetadata(
            size: capture.metadata.size,
            mode: capture.metadata.mode,
            videoTimestampMs: capture.metadata.videoTimestampMs,
            applicationInfo: capture.metadata.applicationInfo,
            windowInfo: normalizedWindow,
            displayInfo: capture.metadata.displayInfo,
            timestamp: capture.metadata.timestamp)

        return CaptureResult(
            imageData: capture.imageData,
            savedPath: capture.savedPath,
            metadata: metadata,
            warning: capture.warning)
    }

    private var engineAwareCapture: (any EngineAwareScreenCaptureServiceProtocol)? {
        self.screenCapture as? any EngineAwareScreenCaptureServiceProtocol
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
            try await self.detectElements(
                in: capture.imageData,
                snapshotID: request.output.snapshotID,
                windowContext: context,
                timeout: request.timeout.detection)
        }
    }

    private func recognizeOCRIfNeeded(
        capture: CaptureResult,
        request: DesktopObservationRequest,
        tracer: DesktopObservationTraceRecorder) async throws -> OCRTextResult?
    {
        guard request.detection.mode == .accessibilityAndOCR || request.detection.preferOCR else {
            return nil
        }

        return try await tracer.span("detection.ocr") {
            try self.ocrRecognizer.recognizeText(in: capture.imageData)
        }
    }

    private func combineDetectionAndOCR(
        detection: ElementDetectionResult?,
        ocr: OCRTextResult?,
        capture: CaptureResult,
        target: ResolvedObservationTarget,
        request: DesktopObservationRequest) -> ElementDetectionResult?
    {
        guard let ocr else { return detection }

        let context = target.detectionContext ?? Self.windowContext(from: capture)
        guard let ocrDetection = self.ocrDetectionResult(
            from: ocr,
            capture: capture,
            context: context,
            request: request)
        else {
            return detection
        }

        guard !request.detection.preferOCR, let detection else {
            return ocrDetection
        }

        return ObservationOCRMapper.merge(
            ocrElements: ocrDetection.elements.other,
            into: detection)
    }

    private func ocrDetectionResult(
        from ocr: OCRTextResult,
        capture: CaptureResult,
        context: WindowContext?,
        request: DesktopObservationRequest) -> ElementDetectionResult?
    {
        let windowBounds = context?.windowBounds ?? Self.captureBounds(from: capture)
        let normalizedContext = WindowContext(
            applicationName: context?.applicationName,
            applicationBundleId: context?.applicationBundleId,
            applicationProcessId: context?.applicationProcessId,
            windowTitle: context?.windowTitle,
            windowID: context?.windowID,
            windowBounds: windowBounds,
            shouldFocusWebContent: context?.shouldFocusWebContent)

        return ObservationOCRMapper.detectionResult(
            from: ocr,
            snapshotID: request.output.snapshotID,
            screenshotPath: capture.savedPath ?? "",
            windowContext: normalizedContext,
            detectionTime: 0)
    }

    private func detectElements(
        in imageData: Data,
        snapshotID: String?,
        windowContext: WindowContext?,
        timeout: TimeInterval?) async throws -> ElementDetectionResult
    {
        let automation = self.automation
        let operation: @Sendable () async throws -> ElementDetectionResult = {
            try await automation.detectElements(
                in: imageData,
                snapshotId: snapshotID,
                windowContext: windowContext)
        }

        guard let timeout else {
            return try await operation()
        }

        return try await self.withDetectionTimeout(seconds: timeout, operation: operation)
    }

    private func withDetectionTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T) async throws -> T
    {
        guard seconds > 0 else {
            throw CaptureError.detectionTimedOut(seconds)
        }

        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CaptureError.detectionTimedOut(seconds)
            }

            do {
                guard let result = try await group.next() else {
                    throw CaptureError.detectionTimedOut(seconds)
                }
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    private func writeOutputIfNeeded(
        capture: CaptureResult,
        elements: ElementDetectionResult?,
        options: DesktopObservationOutputOptions,
        tracer: DesktopObservationTraceRecorder) async throws -> DesktopObservationFiles
    {
        guard options.saveRawScreenshot || options.saveAnnotatedScreenshot || options.saveSnapshot else {
            return DesktopObservationFiles(rawScreenshotPath: capture.savedPath)
        }

        let output = try await tracer.span("output.write") {
            try await self.outputWriter.write(capture: capture, elements: elements, options: options)
        }
        tracer.append(output.spans)
        return output.files
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

    private static func captureBounds(from capture: CaptureResult) -> CGRect {
        if let windowBounds = capture.metadata.windowInfo?.bounds {
            return windowBounds
        }
        if let displayBounds = capture.metadata.displayInfo?.bounds {
            return displayBounds
        }
        return CGRect(origin: .zero, size: capture.metadata.size)
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

    private static func targetDiagnostics(
        for request: DesktopObservationTargetRequest,
        resolved target: ResolvedObservationTarget) -> DesktopObservationTargetDiagnostics
    {
        let requestDetails = Self.requestDiagnostics(for: request)
        return DesktopObservationTargetDiagnostics(
            requestedKind: requestDetails.kind,
            resolvedKind: Self.resolvedKindName(target.kind),
            source: Self.targetSource(for: request, resolved: target),
            hints: requestDetails.hints,
            openIfNeeded: requestDetails.openIfNeeded,
            clickHint: requestDetails.clickHint,
            windowID: target.window?.windowID,
            bounds: target.bounds,
            captureScaleHint: target.captureScaleHint)
    }

    private static func requestDiagnostics(
        for request: DesktopObservationTargetRequest)
        -> (kind: String, hints: [String], openIfNeeded: Bool, clickHint: String?)
    {
        switch request {
        case .screen:
            ("screen", [], false, nil)
        case .allScreens:
            ("all-screens", [], false, nil)
        case .frontmost:
            ("frontmost", [], false, nil)
        case .app:
            ("app", [], false, nil)
        case .pid:
            ("pid", [], false, nil)
        case .windowID:
            ("window-id", [], false, nil)
        case .area:
            ("area", [], false, nil)
        case .menubar:
            ("menubar", [], false, nil)
        case let .menubarPopover(hints, openIfNeeded):
            (
                "menubar-popover",
                hints,
                openIfNeeded != nil,
                openIfNeeded?.clickHint?.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func targetSource(
        for request: DesktopObservationTargetRequest,
        resolved target: ResolvedObservationTarget) -> String
    {
        switch target.kind {
        case .menubar:
            "primary-screen"
        case .menubarPopover where target.window != nil:
            "window-list"
        case .menubarPopover:
            if case let .menubarPopover(_, openIfNeeded) = request, openIfNeeded != nil {
                "click-location-area-fallback"
            } else {
                "area-fallback"
            }
        case .screen:
            "screen"
        case .frontmost:
            "frontmost-application"
        case .appWindow:
            "application-window"
        case .windowID:
            "window-id"
        case .area:
            "area"
        }
    }

    private static func resolvedKindName(_ kind: ResolvedObservationKind) -> String {
        switch kind {
        case .screen:
            "screen"
        case .frontmost:
            "frontmost"
        case .appWindow:
            "app-window"
        case .windowID:
            "window-id"
        case .area:
            "area"
        case .menubar:
            "menubar"
        case .menubarPopover:
            "menubar-popover"
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

    func append(_ spans: [ObservationSpan]) {
        self.spans.append(contentsOf: spans)
    }

    private func record(_ name: String, start: ContinuousClock.Instant, metadata: [String: String] = [:]) {
        let duration = start.duration(to: ContinuousClock.now)
        let milliseconds = Double(duration.components.seconds * 1000)
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000
        self.spans.append(ObservationSpan(name: name, durationMS: milliseconds, metadata: metadata))
    }
}
