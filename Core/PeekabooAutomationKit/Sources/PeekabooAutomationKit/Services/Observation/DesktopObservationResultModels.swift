import CoreGraphics
import Foundation

public struct ObservationSpan: Sendable, Codable, Equatable {
    public let name: String
    public let durationMS: Double
    public let metadata: [String: String]

    public init(name: String, durationMS: Double, metadata: [String: String] = [:]) {
        self.name = name
        self.durationMS = durationMS
        self.metadata = metadata
    }
}

public struct ObservationTimings: Sendable, Codable, Equatable {
    public let spans: [ObservationSpan]

    public init(spans: [ObservationSpan] = []) {
        self.spans = spans
    }
}

public struct DesktopObservationFiles: Sendable, Codable, Equatable {
    public let rawScreenshotPath: String?
    public let annotatedScreenshotPath: String?

    public init(rawScreenshotPath: String? = nil, annotatedScreenshotPath: String? = nil) {
        self.rawScreenshotPath = rawScreenshotPath
        self.annotatedScreenshotPath = annotatedScreenshotPath
    }
}

public struct DesktopObservationOutputWriteResult: Sendable, Equatable {
    public let files: DesktopObservationFiles
    public let spans: [ObservationSpan]

    public init(files: DesktopObservationFiles, spans: [ObservationSpan] = []) {
        self.files = files
        self.spans = spans
    }
}

public struct DesktopObservationTargetDiagnostics: Sendable, Codable, Equatable {
    public let requestedKind: String
    public let resolvedKind: String
    public let source: String
    public let hints: [String]
    public let openIfNeeded: Bool
    public let clickHint: String?
    public let windowID: Int?
    public let bounds: CGRect?
    public let captureScaleHint: CGFloat?

    public init(
        requestedKind: String,
        resolvedKind: String,
        source: String,
        hints: [String] = [],
        openIfNeeded: Bool = false,
        clickHint: String? = nil,
        windowID: Int? = nil,
        bounds: CGRect? = nil,
        captureScaleHint: CGFloat? = nil)
    {
        self.requestedKind = requestedKind
        self.resolvedKind = resolvedKind
        self.source = source
        self.hints = hints
        self.openIfNeeded = openIfNeeded
        self.clickHint = clickHint
        self.windowID = windowID
        self.bounds = bounds
        self.captureScaleHint = captureScaleHint
    }
}

public struct DesktopObservationDiagnostics: Sendable, Codable, Equatable {
    public let warnings: [String]
    public let stateSnapshot: DesktopStateSnapshotSummary?
    public let target: DesktopObservationTargetDiagnostics?

    public init(
        warnings: [String] = [],
        stateSnapshot: DesktopStateSnapshotSummary? = nil,
        target: DesktopObservationTargetDiagnostics? = nil)
    {
        self.warnings = warnings
        self.stateSnapshot = stateSnapshot
        self.target = target
    }
}

public struct DesktopObservationResult: Sendable {
    public let target: ResolvedObservationTarget
    public let capture: CaptureResult
    public let elements: ElementDetectionResult?
    public let ocr: OCRTextResult?
    public let files: DesktopObservationFiles
    public let timings: ObservationTimings
    public let diagnostics: DesktopObservationDiagnostics

    public init(
        target: ResolvedObservationTarget,
        capture: CaptureResult,
        elements: ElementDetectionResult?,
        ocr: OCRTextResult? = nil,
        files: DesktopObservationFiles = DesktopObservationFiles(),
        timings: ObservationTimings = ObservationTimings(),
        diagnostics: DesktopObservationDiagnostics = DesktopObservationDiagnostics())
    {
        self.target = target
        self.capture = capture
        self.elements = elements
        self.ocr = ocr
        self.files = files
        self.timings = timings
        self.diagnostics = diagnostics
    }
}
