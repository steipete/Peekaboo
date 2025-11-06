import CoreGraphics
import Foundation
import PeekabooFoundation

/// Unified output structure for all Peekaboo tools
/// Used by CLI, Agent, macOS app, and MCP server
public struct UnifiedToolOutput<T: Codable>: Codable, Sendable where T: Sendable {
    /// The actual data returned by the tool
    public let data: T

    /// Human and agent-readable summary information
    public let summary: Summary

    /// Metadata about the tool execution
    public let metadata: Metadata

    public init(data: T, summary: Summary, metadata: Metadata) {
        self.data = data
        self.summary = summary
        self.metadata = metadata
    }

    /// Summary information for quick understanding of results
    public struct Summary: Codable, Sendable {
        /// One-line summary of the result (e.g., "Found 5 apps")
        public let brief: String

        /// Optional detailed description
        public let detail: String?

        /// Execution status
        public let status: Status

        /// Key counts from the operation
        public let counts: [String: Int]

        /// Important items to highlight
        public let highlights: [Highlight]

        public init(
            brief: String,
            detail: String? = nil,
            status: Status,
            counts: [String: Int] = [:],
            highlights: [Highlight] = [])
        {
            self.brief = brief
            self.detail = detail
            self.status = status
            self.counts = counts
            self.highlights = highlights
        }

        public enum Status: String, Codable, Sendable {
            case success
            case partial
            case failed
        }

        public struct Highlight: Codable, Sendable {
            public let label: String
            public let value: String
            public let kind: HighlightKind

            public init(label: String, value: String, kind: HighlightKind) {
                self.label = label
                self.value = value
                self.kind = kind
            }

            public enum HighlightKind: String, Codable, Sendable {
                case primary // The main item (e.g., active app)
                case warning // Something needing attention
                case info // Additional context
            }
        }
    }

    /// Metadata about the tool execution
    public struct Metadata: Codable, Sendable {
        /// Execution duration in seconds
        public let duration: Double

        /// Any warnings generated during execution
        public let warnings: [String]

        /// Helpful hints for next actions
        public let hints: [String]

        public init(
            duration: Double,
            warnings: [String] = [],
            hints: [String] = [])
        {
            self.duration = duration
            self.warnings = warnings
            self.hints = hints
        }
    }
}

// MARK: - Convenience Extensions

extension UnifiedToolOutput {
    /// Convert to JSON string for CLI output
    public func toJSON(prettyPrinted: Bool = true) throws -> String {
        // Convert to JSON string for CLI output
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Specific Tool Data Types

/// Data structure for application list results
public struct ServiceApplicationListData: Codable, Sendable {
    public let applications: [ServiceApplicationInfo]

    public init(applications: [ServiceApplicationInfo]) {
        self.applications = applications
    }
}

/// Data structure for window list results
public struct ServiceWindowListData: Codable, Sendable {
    public let windows: [ServiceWindowInfo]
    public let targetApplication: ServiceApplicationInfo?

    public init(windows: [ServiceWindowInfo], targetApplication: ServiceApplicationInfo? = nil) {
        self.windows = windows
        self.targetApplication = targetApplication
    }
}

/// Data structure for UI analysis results
public struct UIAnalysisData: Codable, Sendable {
    public let sessionId: String
    public let screenshot: ScreenshotInfo?
    public let elements: [DetectedUIElement]
    public let elementsByType: ElementsByType?
    public let metadata: DetectionMetadata?

    public init(
        sessionId: String,
        screenshot: ScreenshotInfo? = nil,
        elements: [DetectedUIElement],
        elementsByType: ElementsByType? = nil,
        metadata: DetectionMetadata? = nil)
    {
        self.sessionId = sessionId
        self.screenshot = screenshot
        self.elements = elements
        self.elementsByType = elementsByType
        self.metadata = metadata
    }

    /// Convenience initializer from ElementDetectionResult
    public init(from detectionResult: ElementDetectionResult) {
        self.sessionId = detectionResult.sessionId
        self.screenshot = ScreenshotInfo(
            path: detectionResult.screenshotPath,
            size: CGSize(width: 0, height: 0) // Size not available from ElementDetectionResult
        )

        // Convert all elements to DetectedUIElement
        let allElements = detectionResult.elements.all
        self.elements = allElements.map { element in
            DetectedUIElement(
                id: element.id,
                type: element.type.rawValue,
                label: element.label,
                value: element.value,
                bounds: element.bounds,
                isEnabled: element.isEnabled,
                isSelected: element.isSelected,
                isActionable: element.isEnabled, // Assume enabled elements are actionable
                attributes: element.attributes)
        }

        // Create ElementsByType from DetectedElements
        self.elementsByType = ElementsByType(
            buttons: detectionResult.elements.buttons.map(\.id),
            textFields: detectionResult.elements.textFields.map(\.id),
            links: detectionResult.elements.links.map(\.id),
            images: detectionResult.elements.images.map(\.id),
            groups: detectionResult.elements.groups.map(\.id),
            sliders: detectionResult.elements.sliders.map(\.id),
            checkboxes: detectionResult.elements.checkboxes.map(\.id),
            menus: detectionResult.elements.menus.map(\.id),
            other: detectionResult.elements.other.map(\.id))

        // Convert metadata
        self.metadata = DetectionMetadata(
            detectionTime: detectionResult.metadata.detectionTime,
            elementCount: detectionResult.metadata.elementCount,
            method: detectionResult.metadata.method,
            warnings: detectionResult.metadata.warnings,
            windowContext: detectionResult.metadata.windowContext.map { context in
                WindowContext(
                    applicationName: context.applicationName,
                    windowTitle: context.windowTitle,
                    windowBounds: context.windowBounds)
            },
            isDialog: detectionResult.metadata.isDialog)
    }

    public struct ScreenshotInfo: Codable, Sendable {
        public let path: String
        public let size: CGSize

        public init(path: String, size: CGSize) {
            self.path = path
            self.size = size
        }
    }

    public struct DetectedUIElement: Codable, Sendable {
        public let id: String
        public let type: String // Changed from 'role' to 'type' to match ElementType
        public let label: String?
        public let value: String? // Added to match DetectedElement
        public let bounds: CGRect
        public let isEnabled: Bool
        public let isSelected: Bool? // Added to match DetectedElement
        public let isActionable: Bool
        public let attributes: [String: String] // Added to match DetectedElement

        /// Backward compatibility - computed property for 'role'
        public var role: String {
            self.type
        }

        public init(
            id: String,
            type: String,
            label: String?,
            value: String? = nil,
            bounds: CGRect,
            isEnabled: Bool,
            isSelected: Bool? = nil,
            isActionable: Bool = true,
            attributes: [String: String] = [:])
        {
            self.id = id
            self.type = type
            self.label = label
            self.value = value
            self.bounds = bounds
            self.isEnabled = isEnabled
            self.isSelected = isSelected
            self.isActionable = isActionable
            self.attributes = attributes
        }

        /// Backward compatibility initializer
        public init(
            id: String,
            role: String,
            label: String?,
            bounds: CGRect,
            isEnabled: Bool,
            isActionable: Bool = true)
        {
            self.init(
                id: id,
                type: role,
                label: label,
                value: nil,
                bounds: bounds,
                isEnabled: isEnabled,
                isSelected: nil,
                isActionable: isActionable,
                attributes: [:])
        }
    }

    /// Elements organized by type (contains element IDs)
    public struct ElementsByType: Codable, Sendable {
        public let buttons: [String]
        public let textFields: [String]
        public let links: [String]
        public let images: [String]
        public let groups: [String]
        public let sliders: [String]
        public let checkboxes: [String]
        public let menus: [String]
        public let other: [String]

        public init(
            buttons: [String] = [],
            textFields: [String] = [],
            links: [String] = [],
            images: [String] = [],
            groups: [String] = [],
            sliders: [String] = [],
            checkboxes: [String] = [],
            menus: [String] = [],
            other: [String] = [])
        {
            self.buttons = buttons
            self.textFields = textFields
            self.links = links
            self.images = images
            self.groups = groups
            self.sliders = sliders
            self.checkboxes = checkboxes
            self.menus = menus
            self.other = other
        }
    }

    /// Detection metadata
    public struct DetectionMetadata: Codable, Sendable {
        public let detectionTime: TimeInterval
        public let elementCount: Int
        public let method: String
        public let warnings: [String]
        public let windowContext: WindowContext?
        public let isDialog: Bool

        public init(
            detectionTime: TimeInterval,
            elementCount: Int,
            method: String,
            warnings: [String] = [],
            windowContext: WindowContext? = nil,
            isDialog: Bool = false)
        {
            self.detectionTime = detectionTime
            self.elementCount = elementCount
            self.method = method
            self.warnings = warnings
            self.windowContext = windowContext
            self.isDialog = isDialog
        }
    }

    /// Window context information
    public struct WindowContext: Codable, Sendable {
        public let applicationName: String?
        public let windowTitle: String?
        public let windowBounds: CGRect?

        public init(
            applicationName: String? = nil,
            windowTitle: String? = nil,
            windowBounds: CGRect? = nil)
        {
            self.applicationName = applicationName
            self.windowTitle = windowTitle
            self.windowBounds = windowBounds
        }
    }
}

/// Data structure for interaction results
public struct InteractionResultData: Codable, Sendable {
    public let action: String
    public let target: String?
    public let success: Bool
    public let details: [String: String]

    public init(action: String, target: String? = nil, success: Bool, details: [String: String] = [:]) {
        self.action = action
        self.target = target
        self.success = success
        self.details = details
    }
}
