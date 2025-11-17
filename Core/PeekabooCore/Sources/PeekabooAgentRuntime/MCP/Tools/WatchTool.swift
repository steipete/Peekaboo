import Foundation
import MCP
import PeekabooAutomation
import PeekabooFoundation
import TachikomaMCP

/// MCP tool for adaptive PNG capture
public struct WatchTool: MCPTool {
    private let context: MCPToolContext

    public let name = "watch"

    public var description: String {
        """
        Watch a screen/window/region for changes and save PNG frames plus a contact sheet.
        Useful when motion happens mid-run: quiet periods use a low FPS, motion uses higher FPS.
        Returns frame paths, contact sheet, and metadata.
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "mode": SchemaBuilder.string(
                    description: "screen|window|frontmost|region",
                    default: "frontmost"),
                "app": SchemaBuilder.string(
                    description: "Optional app/bundle/PID target for window mode"),
                "window_title": SchemaBuilder.string(description: "Optional window title filter"),
                "window_index": SchemaBuilder.number(description: "Optional window index"),
                "screen_index": SchemaBuilder.number(description: "Optional screen index"),
                "region": SchemaBuilder.string(description: "x,y,width,height for region mode"),
                "duration_seconds": SchemaBuilder.number(description: "Duration seconds (default 60, max 180)"),
                "idle_fps": SchemaBuilder.number(description: "Idle FPS (default 2)"),
                "active_fps": SchemaBuilder.number(description: "Active FPS (default 8, max 15)"),
                "threshold_percent": SchemaBuilder.number(description: "Change threshold percent (default 2.5)"),
                "heartbeat_sec": SchemaBuilder.number(description: "Heartbeat interval seconds (default 5, 0 disables)"),
                "quiet_ms": SchemaBuilder.number(description: "Calm period before dropping to idle (default 1000)"),
                "highlight_changes": SchemaBuilder.boolean(description: "Overlay motion boxes on frames"),
                "max_frames": SchemaBuilder.number(description: "Soft frame cap (default 800)"),
                "max_mb": SchemaBuilder.number(description: "Soft size cap in MB (optional)"),
                "resolution_cap": SchemaBuilder.number(description: "Cap longest side in px (default 1440)"),
                "diff_strategy": SchemaBuilder.string(
                    description: "fast|quality diffing (default fast)",
                    enum: ["fast", "quality"],
                    default: "fast"),
                "diff_budget_ms": SchemaBuilder.number(description: "Diff time budget before falling back to fast (default 30 for quality)"),
                "output_dir": SchemaBuilder.string(description: "Optional absolute directory for outputs"),
                "autoclean_minutes": SchemaBuilder.number(description: "Minutes to keep temp outputs (default 120)")
            ],
            required: [])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let request = try WatchRequest(arguments: arguments)
        let session = WatchCaptureSession(
            screenCapture: self.context.screenCapture,
            screenService: self.context.screens,
            scope: request.scope,
            options: request.options,
            outputRoot: request.outputDirectory,
            autocleanMinutes: request.autocleanMinutes)
        let result = try await session.run()

        let summary = """
        watch kept \(result.stats.framesKept) frames (dropped \(result.stats.framesDropped)), contact sheet \(result.contactSheet.path)
        """
        let meta = ToolEventSummary(
            actionDescription: "Watch Capture",
            notes: summary)

        return ToolResponse.text(summary, meta: ToolEventSummary.merge(summary: meta, into: .object([
            "frames": .array(result.frames.map { .string($0.path) }),
            "contact": .string(result.contactSheet.path),
            "metadata": .string(result.metadataFile),
            "diff_algorithm": .string(result.diffAlgorithm),
            "diff_scale": .string(result.diffScale),
            "contact_columns": .string("\(result.contactColumns)"),
            "contact_rows": .string("\(result.contactRows)"),
            "contact_sampled_indexes": .array(result.contactSampledIndexes.map { .string("\($0)") })
        ])))
    }
}

// MARK: - Request parsing

private struct WatchRequest {
    let scope: WatchScope
    let options: WatchCaptureOptions
    let outputDirectory: URL
    let autocleanMinutes: Int

    init(arguments: ToolArguments) throws {
        let input = try arguments.decode(WatchInput.self)
        let modeString = input.mode?.lowercased() ?? "frontmost"
        let mode = CaptureMode(rawValue: modeString) ?? (modeString == "region" ? .area : .frontmost)

        let duration = max(1, min(input.durationSeconds ?? 60, 180))
        let idle = min(max(input.idleFps ?? 2, 0.1), 5)
        let active = min(max(input.activeFps ?? 8, 0.5), 15)
        let threshold = min(max(input.thresholdPercent ?? 2.5, 0), 100)
        let heartbeat = max(input.heartbeatSec ?? 5, 0)
        let quiet = max(Int(input.quietMs ?? 1000), 0)
        let highlight = input.highlightChanges ?? false
        let maxFrames = max(input.maxFrames ?? 800, 1)
        let maxMb = (input.maxMb ?? 0) > 0 ? input.maxMb : nil
        let resolutionCap = input.resolutionCap ?? 1440
        let diff = WatchCaptureOptions.DiffStrategy(rawValue: input.diffStrategy ?? "fast") ?? .fast
        let autoclean = Int(input.autocleanMinutes ?? 120)
        let diffBudgetMs = input.diffBudgetMs ?? (diff == .quality ? 30 : nil)

        let scope: WatchScope
        switch mode {
        case .screen:
            scope = WatchScope(kind: .screen, screenIndex: input.screenIndex, displayUUID: nil, windowId: nil, applicationIdentifier: nil, windowIndex: nil, region: nil)
        case .window:
            let app = input.app ?? "frontmost"
            scope = WatchScope(kind: .window, screenIndex: nil, displayUUID: nil, windowId: nil, applicationIdentifier: app, windowIndex: input.windowIndex, region: nil)
        case .area:
            let rect = try WatchRequest.parseRegion(input.region)
            scope = WatchScope(kind: .region, screenIndex: nil, displayUUID: nil, windowId: nil, applicationIdentifier: nil, windowIndex: nil, region: rect)
        case .frontmost, .multi:
            scope = WatchScope(kind: .frontmost, screenIndex: nil, displayUUID: nil, windowId: nil, applicationIdentifier: nil, windowIndex: nil, region: nil)
        }

        let outputDir = WatchRequest.resolveOutputDirectory(input.outputDir)

        self.scope = scope
        self.options = WatchCaptureOptions(
            duration: duration,
            idleFps: idle,
            activeFps: active,
            changeThresholdPercent: threshold,
            heartbeatSeconds: heartbeat,
            quietMsToIdle: quiet,
            maxFrames: maxFrames,
            maxMegabytes: maxMb,
            highlightChanges: highlight,
            captureFocus: .auto,
            resolutionCap: resolutionCap,
            diffStrategy: diff,
            diffBudgetMs: diffBudgetMs)
        self.outputDirectory = outputDir
        self.autocleanMinutes = autoclean
    }

    private static func parseRegion(_ value: String?) throws -> CGRect {
        guard let value else {
            throw PeekabooError.invalidInput("region is required for region mode")
        }
        let parts = value.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else {
            throw PeekabooError.invalidInput("region must be x,y,width,height")
        }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    private static func resolveOutputDirectory(_ custom: String?) -> URL {
        if let custom {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        let temp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("peekaboo")
            .appendingPathComponent("watch-sessions", isDirectory: true)
            .appendingPathComponent("watch-\(UUID().uuidString)", isDirectory: true)
        return temp
    }
}

private struct WatchInput: Codable {
    let mode: String?
    let app: String?
    let windowTitle: String?
    let windowIndex: Int?
    let screenIndex: Int?
    let region: String?
    let durationSeconds: Double?
    let idleFps: Double?
    let activeFps: Double?
    let thresholdPercent: Double?
    let heartbeatSec: Double?
    let quietMs: Double?
    let highlightChanges: Bool?
    let maxFrames: Int?
    let maxMb: Int?
    let resolutionCap: Double?
    let diffStrategy: String?
    let diffBudgetMs: Int?
    let outputDir: String?
    let autocleanMinutes: Double?
}
