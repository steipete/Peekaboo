import CoreGraphics
import Foundation

// MARK: - Image capture primitives (shared with screenshot paths)

public struct SavedFile: Codable, Sendable {
    public let path: String
    public let item_label: String?
    public let window_title: String?
    public let window_id: UInt32?
    public let window_index: Int?
    public let mime_type: String

    public init(
        path: String,
        item_label: String? = nil,
        window_title: String? = nil,
        window_id: UInt32? = nil,
        window_index: Int? = nil,
        mime_type: String)
    {
        self.path = path
        self.item_label = item_label
        self.window_title = window_title
        self.window_id = window_id
        self.window_index = window_index
        self.mime_type = mime_type
    }
}

public struct ImageCaptureData: Codable, Sendable {
    public let saved_files: [SavedFile]

    public init(saved_files: [SavedFile]) {
        self.saved_files = saved_files
    }
}

public enum CaptureMode: String, CaseIterable, Codable, Sendable {
    case screen
    case window
    case multi
    case frontmost
    case area
}

public enum ImageFormat: String, CaseIterable, Codable, Sendable {
    case png
    case jpg
}

public enum CaptureFocus: String, CaseIterable, Codable, Sendable {
    case background
    case auto
    case foreground
}

/// Target scope for capture sessions.
public struct CaptureScope: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case screen
        case window
        case frontmost
        case region
    }

    public let kind: Kind
    public let screenIndex: Int?
    public let displayUUID: String?
    public let windowId: UInt32?
    public let applicationIdentifier: String?
    public let windowIndex: Int?
    public let region: CGRect?

    public init(
        kind: Kind,
        screenIndex: Int? = nil,
        displayUUID: String? = nil,
        windowId: UInt32? = nil,
        applicationIdentifier: String? = nil,
        windowIndex: Int? = nil,
        region: CGRect? = nil)
    {
        self.kind = kind
        self.screenIndex = screenIndex
        self.displayUUID = displayUUID
        self.windowId = windowId
        self.applicationIdentifier = applicationIdentifier
        self.windowIndex = windowIndex
        self.region = region
    }
}

/// Options controlling live capture behavior.
public struct CaptureOptions: Sendable, Equatable {
    public let duration: TimeInterval
    public let idleFps: Double
    public let activeFps: Double
    public let changeThresholdPercent: Double
    public let heartbeatSeconds: TimeInterval
    public let quietMsToIdle: Int
    public let maxFrames: Int
    public let maxMegabytes: Int?
    public let highlightChanges: Bool
    public let captureFocus: CaptureFocus
    public let resolutionCap: CGFloat?
    public let diffStrategy: DiffStrategy
    public let diffBudgetMs: Int?

    public enum DiffStrategy: String, Codable, Sendable {
        case fast
        case quality
    }

    public init(
        duration: TimeInterval,
        idleFps: Double,
        activeFps: Double,
        changeThresholdPercent: Double,
        heartbeatSeconds: TimeInterval,
        quietMsToIdle: Int,
        maxFrames: Int,
        maxMegabytes: Int?,
        highlightChanges: Bool,
        captureFocus: CaptureFocus,
        resolutionCap: CGFloat?,
        diffStrategy: DiffStrategy,
        diffBudgetMs: Int?)
    {
        self.duration = duration
        self.idleFps = idleFps
        self.activeFps = activeFps
        self.changeThresholdPercent = changeThresholdPercent
        self.heartbeatSeconds = heartbeatSeconds
        self.quietMsToIdle = quietMsToIdle
        self.maxFrames = maxFrames
        self.maxMegabytes = maxMegabytes
        self.highlightChanges = highlightChanges
        self.captureFocus = captureFocus
        self.resolutionCap = resolutionCap
        self.diffStrategy = diffStrategy
        self.diffBudgetMs = diffBudgetMs
    }
}

public struct CaptureFrameInfo: Codable, Sendable, Equatable {
    public enum Reason: String, Codable, Sendable {
        case first
        case motion
        case heartbeat
        case cap
    }

    public let index: Int
    public let path: String
    public let file: String
    public let timestampMs: Int
    public let changePercent: Double
    public let reason: Reason
    public let motionBoxes: [CGRect]?
}

public struct CaptureMotionInterval: Codable, Sendable, Equatable {
    public let startFrameIndex: Int
    public let endFrameIndex: Int
    public let startMs: Int
    public let endMs: Int
    public let maxChangePercent: Double
}

public struct CaptureStats: Codable, Sendable, Equatable {
    public let durationMs: Int
    public let fpsIdle: Double
    public let fpsActive: Double
    public let fpsEffective: Double
    public let framesKept: Int
    public let framesDropped: Int
    public let maxFramesHit: Bool
    public let maxMbHit: Bool
}

public struct CaptureContactSheet: Codable, Sendable, Equatable {
    public let path: String
    public let file: String
    public let columns: Int
    public let rows: Int
    public let thumbSize: CGSize
    public let sampledFrameIndexes: [Int]
}

public struct CaptureWarning: Codable, Sendable, Equatable {
    public enum Code: String, Codable, Sendable {
        case noMotion
        case sizeCap
        case frameCap
        case windowClosed
        case displayChanged
        case lowFps
        case diffDowngraded
        case autoclean
    }

    public let code: Code
    public let message: String
    public let details: [String: String]?

    public init(code: Code, message: String, details: [String: String]? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

public struct CaptureOptionsSnapshot: Codable, Sendable, Equatable {
    public let duration: TimeInterval
    public let idleFps: Double
    public let activeFps: Double
    public let changeThresholdPercent: Double
    public let heartbeatSeconds: TimeInterval
    public let quietMsToIdle: Int
    public let maxFrames: Int
    public let maxMegabytes: Int?
    public let highlightChanges: Bool
    public let captureFocus: CaptureFocus
    public let resolutionCap: CGFloat?
    public let diffStrategy: CaptureOptions.DiffStrategy
    public let diffBudgetMs: Int?
}

public struct CaptureSessionResult: Codable, Sendable, Equatable {
    public enum Source: String, Codable, Sendable { case live, video }

    public let source: Source
    public let videoIn: String?
    public let videoOut: String?

    public let frames: [CaptureFrameInfo]
    public let contactSheet: CaptureContactSheet
    public let metadataFile: String
    public let stats: CaptureStats
    public let scope: CaptureScope
    public let diffAlgorithm: String
    public let diffScale: String
    public let options: CaptureOptionsSnapshot
    public let warnings: [CaptureWarning]

    // Convenience: denormalized contact sheet info for agent/CLI surfaces
    public var contactColumns: Int { self.contactSheet.columns }
    public var contactRows: Int { self.contactSheet.rows }
    public var contactSampledIndexes: [Int] { self.contactSheet.sampledFrameIndexes }
    public var contactThumbSize: CGSize { self.contactSheet.thumbSize }
}

/// Shared summary for emitting capture metadata across CLI and MCP surfaces.
public struct CaptureMetaSummary: Sendable, Equatable {
    public let frames: [String]
    public let contactPath: String
    public let metadataPath: String
    public let diffAlgorithm: String
    public let diffScale: String
    public let contactColumns: Int
    public let contactRows: Int
    public let contactThumbSize: CGSize
    public let contactSampledIndexes: [Int]

    public static func make(from result: CaptureSessionResult) -> CaptureMetaSummary {
        CaptureMetaSummary(
            frames: result.frames.map { $0.path },
            contactPath: result.contactSheet.path,
            metadataPath: result.metadataFile,
            diffAlgorithm: result.diffAlgorithm,
            diffScale: result.diffScale,
            contactColumns: result.contactSheet.columns,
            contactRows: result.contactSheet.rows,
            contactThumbSize: result.contactSheet.thumbSize,
            contactSampledIndexes: result.contactSheet.sampledFrameIndexes)
    }
}

// Back-compat typealiases (temporary; remove after downstream migration)
public typealias WatchScope = CaptureScope
public typealias WatchCaptureOptions = CaptureOptions
public typealias WatchFrameInfo = CaptureFrameInfo
public typealias WatchMotionInterval = CaptureMotionInterval
public typealias WatchStats = CaptureStats
public typealias WatchContactSheet = CaptureContactSheet
public typealias WatchWarning = CaptureWarning
public typealias WatchOptionsSnapshot = CaptureOptionsSnapshot
public typealias WatchCaptureResult = CaptureSessionResult
public typealias WatchMetaSummary = CaptureMetaSummary
