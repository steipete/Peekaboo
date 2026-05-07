import CoreGraphics
import Foundation

public enum CaptureEnginePreference: String, Codable, Sendable, Equatable {
    case auto
    case modern
    case legacy
}

public enum WindowSelection: Sendable, Equatable {
    case automatic
    case index(Int)
    case title(String)
    case id(CGWindowID)
}

public enum DesktopObservationTargetRequest: Sendable, Equatable {
    case screen(index: Int?)
    case allScreens
    case frontmost
    case app(identifier: String, window: WindowSelection?)
    case pid(Int32, window: WindowSelection?)
    case windowID(CGWindowID)
    case area(CGRect)
    case menubar
    case menubarPopover(hints: [String])
}

public enum ResolvedObservationKind: Sendable, Equatable {
    case screen(index: Int?)
    case frontmost
    case appWindow
    case windowID(CGWindowID)
    case area(CGRect)
    case menubar
    case menubarPopover
}

public struct ApplicationIdentity: Sendable, Codable, Equatable {
    public let processIdentifier: Int32
    public let bundleIdentifier: String?
    public let name: String

    public init(processIdentifier: Int32, bundleIdentifier: String?, name: String) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }

    init(_ app: ServiceApplicationInfo) {
        self.init(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            name: app.name)
    }
}

public struct WindowIdentity: Sendable, Codable, Equatable {
    public let windowID: Int
    public let title: String
    public let bounds: CGRect
    public let index: Int

    public init(windowID: Int, title: String, bounds: CGRect, index: Int) {
        self.windowID = windowID
        self.title = title
        self.bounds = bounds
        self.index = index
    }

    init(_ window: ServiceWindowInfo) {
        self.init(
            windowID: window.windowID,
            title: window.title,
            bounds: window.bounds,
            index: window.index)
    }
}

public struct ResolvedObservationTarget: Sendable, Equatable {
    public let kind: ResolvedObservationKind
    public let app: ApplicationIdentity?
    public let window: WindowIdentity?
    public let bounds: CGRect?
    public let detectionContext: WindowContext?
    public let captureScaleHint: CGFloat?

    public init(
        kind: ResolvedObservationKind,
        app: ApplicationIdentity? = nil,
        window: WindowIdentity? = nil,
        bounds: CGRect? = nil,
        detectionContext: WindowContext? = nil,
        captureScaleHint: CGFloat? = nil)
    {
        self.kind = kind
        self.app = app
        self.window = window
        self.bounds = bounds
        self.detectionContext = detectionContext
        self.captureScaleHint = captureScaleHint
    }

    public static func == (lhs: ResolvedObservationTarget, rhs: ResolvedObservationTarget) -> Bool {
        lhs.kind == rhs.kind
            && lhs.app == rhs.app
            && lhs.window == rhs.window
            && lhs.bounds == rhs.bounds
            && lhs.captureScaleHint == rhs.captureScaleHint
            && lhs.detectionContext?.applicationName == rhs.detectionContext?.applicationName
            && lhs.detectionContext?.applicationBundleId == rhs.detectionContext?.applicationBundleId
            && lhs.detectionContext?.applicationProcessId == rhs.detectionContext?.applicationProcessId
            && lhs.detectionContext?.windowTitle == rhs.detectionContext?.windowTitle
            && lhs.detectionContext?.windowID == rhs.detectionContext?.windowID
            && lhs.detectionContext?.windowBounds == rhs.detectionContext?.windowBounds
            && lhs.detectionContext?.shouldFocusWebContent == rhs.detectionContext?.shouldFocusWebContent
    }
}

public struct DesktopCaptureOptions: Sendable, Equatable {
    public var engine: CaptureEnginePreference
    public var scale: CaptureScalePreference
    public var focus: CaptureFocus
    public var visualizerMode: CaptureVisualizerMode
    public var includeMenuBar: Bool

    public init(
        engine: CaptureEnginePreference = .auto,
        scale: CaptureScalePreference = .logical1x,
        focus: CaptureFocus = .auto,
        visualizerMode: CaptureVisualizerMode = .screenshotFlash,
        includeMenuBar: Bool = false)
    {
        self.engine = engine
        self.scale = scale
        self.focus = focus
        self.visualizerMode = visualizerMode
        self.includeMenuBar = includeMenuBar
    }
}

public enum DetectionMode: Sendable, Equatable {
    case none
    case accessibility
    case accessibilityAndOCR
}

public struct AXTraversalBudget: Sendable, Equatable {
    public var maxDepth: Int
    public var maxElementCount: Int
    public var maxChildrenPerNode: Int

    public init(maxDepth: Int = 12, maxElementCount: Int = 400, maxChildrenPerNode: Int = 50) {
        self.maxDepth = maxDepth
        self.maxElementCount = maxElementCount
        self.maxChildrenPerNode = maxChildrenPerNode
    }
}

public struct DesktopDetectionOptions: Sendable, Equatable {
    public var mode: DetectionMode
    public var allowWebFocusFallback: Bool
    public var includeMenuBarElements: Bool
    public var preferOCR: Bool
    public var traversalBudget: AXTraversalBudget

    public init(
        mode: DetectionMode = .accessibility,
        allowWebFocusFallback: Bool = true,
        includeMenuBarElements: Bool = true,
        preferOCR: Bool = false,
        traversalBudget: AXTraversalBudget = AXTraversalBudget())
    {
        self.mode = mode
        self.allowWebFocusFallback = allowWebFocusFallback
        self.includeMenuBarElements = includeMenuBarElements
        self.preferOCR = preferOCR
        self.traversalBudget = traversalBudget
    }
}

public struct DesktopObservationOutputOptions: Sendable, Equatable {
    public var path: String?
    public var format: ImageFormat
    public var saveRawScreenshot: Bool
    public var saveAnnotatedScreenshot: Bool
    public var snapshotID: String?

    public init(
        path: String? = nil,
        format: ImageFormat = .png,
        saveRawScreenshot: Bool = false,
        saveAnnotatedScreenshot: Bool = false,
        snapshotID: String? = nil)
    {
        self.path = path
        self.format = format
        self.saveRawScreenshot = saveRawScreenshot
        self.saveAnnotatedScreenshot = saveAnnotatedScreenshot
        self.snapshotID = snapshotID
    }
}

public struct DesktopObservationTimeouts: Sendable, Equatable {
    public var overall: TimeInterval?
    public var detection: TimeInterval?

    public init(overall: TimeInterval? = nil, detection: TimeInterval? = nil) {
        self.overall = overall
        self.detection = detection
    }
}

public struct DesktopObservationRequest: Sendable, Equatable {
    public var target: DesktopObservationTargetRequest
    public var capture: DesktopCaptureOptions
    public var detection: DesktopDetectionOptions
    public var output: DesktopObservationOutputOptions
    public var timeout: DesktopObservationTimeouts

    public init(
        target: DesktopObservationTargetRequest,
        capture: DesktopCaptureOptions = DesktopCaptureOptions(),
        detection: DesktopDetectionOptions = DesktopDetectionOptions(),
        output: DesktopObservationOutputOptions = DesktopObservationOutputOptions(),
        timeout: DesktopObservationTimeouts = DesktopObservationTimeouts())
    {
        self.target = target
        self.capture = capture
        self.detection = detection
        self.output = output
        self.timeout = timeout
    }
}

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

public struct DesktopObservationDiagnostics: Sendable, Codable, Equatable {
    public let warnings: [String]

    public init(warnings: [String] = []) {
        self.warnings = warnings
    }
}

public struct DesktopObservationResult: Sendable {
    public let target: ResolvedObservationTarget
    public let capture: CaptureResult
    public let elements: ElementDetectionResult?
    public let files: DesktopObservationFiles
    public let timings: ObservationTimings
    public let diagnostics: DesktopObservationDiagnostics

    public init(
        target: ResolvedObservationTarget,
        capture: CaptureResult,
        elements: ElementDetectionResult?,
        files: DesktopObservationFiles = DesktopObservationFiles(),
        timings: ObservationTimings = ObservationTimings(),
        diagnostics: DesktopObservationDiagnostics = DesktopObservationDiagnostics())
    {
        self.target = target
        self.capture = capture
        self.elements = elements
        self.files = files
        self.timings = timings
        self.diagnostics = diagnostics
    }
}

public enum DesktopObservationError: Error, LocalizedError, Equatable {
    case unsupportedTarget(String)
    case targetNotFound(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedTarget(target):
            "Desktop observation target is not supported yet: \(target)"
        case let .targetNotFound(target):
            "Desktop observation target was not found: \(target)"
        }
    }
}
