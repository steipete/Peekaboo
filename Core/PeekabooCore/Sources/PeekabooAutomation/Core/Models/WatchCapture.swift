import CoreGraphics
import Foundation

/// Target scope for watch captures.
public struct WatchScope: Codable, Sendable, Equatable {
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

/// Options controlling watch capture behavior.
public struct WatchCaptureOptions: Sendable, Equatable {
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

public struct WatchFrameInfo: Codable, Sendable, Equatable {
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

public struct WatchMotionInterval: Codable, Sendable, Equatable {
    public let startFrameIndex: Int
    public let endFrameIndex: Int
    public let startMs: Int
    public let endMs: Int
    public let maxChangePercent: Double
}

public struct WatchStats: Codable, Sendable, Equatable {
    public let durationMs: Int
    public let fpsIdle: Double
    public let fpsActive: Double
    public let fpsEffective: Double
    public let framesKept: Int
    public let framesDropped: Int
    public let maxFramesHit: Bool
    public let maxMbHit: Bool
}

public struct WatchContactSheet: Codable, Sendable, Equatable {
    public let path: String
    public let file: String
    public let columns: Int
    public let rows: Int
    public let thumbSize: CGSize
    public let sampledFrameIndexes: [Int]
}

public struct WatchWarning: Codable, Sendable, Equatable {
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

public struct WatchOptionsSnapshot: Codable, Sendable, Equatable {
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
    public let diffStrategy: WatchCaptureOptions.DiffStrategy
    public let diffBudgetMs: Int?
}

public struct WatchCaptureResult: Codable, Sendable, Equatable {
    public let frames: [WatchFrameInfo]
    public let contactSheet: WatchContactSheet
    public let metadataFile: String
    public let stats: WatchStats
    public let scope: WatchScope
    public let diffAlgorithm: String
    public let diffScale: String
    public let options: WatchOptionsSnapshot
    public let warnings: [WatchWarning]

    // Convenience: denormalized contact sheet info for agent/CLI surfaces
    public var contactColumns: Int { self.contactSheet.columns }
    public var contactRows: Int { self.contactSheet.rows }
    public var contactSampledIndexes: [Int] { self.contactSheet.sampledFrameIndexes }
    public var contactThumbSize: CGSize { self.contactSheet.thumbSize }
}

/// Shared summary for emitting watch metadata across CLI and MCP surfaces.
public struct WatchMetaSummary: Sendable, Equatable {
    public let frames: [String]
    public let contactPath: String
    public let metadataPath: String
    public let diffAlgorithm: String
    public let diffScale: String
    public let contactColumns: Int
    public let contactRows: Int
    public let contactThumbSize: CGSize
    public let contactSampledIndexes: [Int]

    public static func make(from result: WatchCaptureResult) -> Self {
        Self(
            frames: result.frames.map(\.path),
            contactPath: result.contactSheet.path,
            metadataPath: result.metadataFile,
            diffAlgorithm: result.diffAlgorithm,
            diffScale: result.diffScale,
            contactColumns: result.contactColumns,
            contactRows: result.contactRows,
            contactThumbSize: result.contactThumbSize,
            contactSampledIndexes: result.contactSampledIndexes)
    }
}
