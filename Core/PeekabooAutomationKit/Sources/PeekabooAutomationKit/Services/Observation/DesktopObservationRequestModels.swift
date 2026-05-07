import Foundation

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
    public var saveSnapshot: Bool
    public var snapshotID: String?

    public init(
        path: String? = nil,
        format: ImageFormat = .png,
        saveRawScreenshot: Bool = false,
        saveAnnotatedScreenshot: Bool = false,
        saveSnapshot: Bool = false,
        snapshotID: String? = nil)
    {
        self.path = path
        self.format = format
        self.saveRawScreenshot = saveRawScreenshot
        self.saveAnnotatedScreenshot = saveAnnotatedScreenshot
        self.saveSnapshot = saveSnapshot
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
