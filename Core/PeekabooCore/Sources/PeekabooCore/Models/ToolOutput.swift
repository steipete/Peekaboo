import Foundation
import CoreGraphics

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
            highlights: [Highlight] = []
        ) {
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
                case primary    // The main item (e.g., active app)
                case warning    // Something needing attention
                case info       // Additional context
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
            hints: [String] = []
        ) {
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
    
    public init(sessionId: String, screenshot: ScreenshotInfo? = nil, elements: [DetectedUIElement]) {
        self.sessionId = sessionId
        self.screenshot = screenshot
        self.elements = elements
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
        public let role: String
        public let label: String?
        public let bounds: CGRect
        public let isEnabled: Bool
        public let isActionable: Bool
        
        public init(id: String, role: String, label: String?, bounds: CGRect, isEnabled: Bool, isActionable: Bool = true) {
            self.id = id
            self.role = role
            self.label = label
            self.bounds = bounds
            self.isEnabled = isEnabled
            self.isActionable = isActionable
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