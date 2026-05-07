import Foundation
import MCP
import PeekabooAutomation
import PeekabooFoundation
import TachikomaMCP

/// MCP tool for live/video capture (frames + contact sheet).
public struct CaptureTool: MCPTool {
    private let context: MCPToolContext

    public let name = "capture"

    public var description: String {
        """
        Capture live screens/windows/regions or ingest a video file and return kept PNG frames,
        a contact sheet, and metadata (diff stats, warnings, grid info).
        """
    }

    public var inputSchema: Value {
        // Source selection + options split by source
        SchemaBuilder.object(
            properties: [
                "source": SchemaBuilder.string(
                    description: "live|video (default live)",
                    enum: ["live", "video"],
                    default: "live"),

                // Live targeting
                "mode": SchemaBuilder.string(
                    description: "screen|window|frontmost|area (region alias)",
                    enum: ["screen", "window", "frontmost", "area", "region"]),
                "app": SchemaBuilder.string(description: "Optional app/bundle/PID target for window mode"),
                "pid": SchemaBuilder.number(description: "Optional process ID target for window mode"),
                "window_title": SchemaBuilder.string(description: "Optional window title filter"),
                "window_index": SchemaBuilder.number(description: "Optional window index"),
                "screen_index": SchemaBuilder.number(description: "Optional screen index"),
                "region": SchemaBuilder.string(description: "x,y,width,height for area mode"),
                "capture_focus": SchemaBuilder.string(
                    description: "auto|background|foreground",
                    enum: ["auto", "background", "foreground"]),

                // Live cadence
                "duration_seconds": SchemaBuilder.number(description: "Duration seconds (default 60, max 180)"),
                "idle_fps": SchemaBuilder.number(description: "Idle FPS (default 2, min 0.1, max 5)"),
                "active_fps": SchemaBuilder.number(description: "Active FPS (default 8, max 15)"),
                "threshold_percent": SchemaBuilder.number(description: "Change threshold percent (default 2.5)"),
                "heartbeat_sec": SchemaBuilder
                    .number(description: "Heartbeat interval seconds (default 5, 0 disables)"),
                "quiet_ms": SchemaBuilder.number(description: "Calm period before returning to idle (default 1000)"),

                // Video sampling
                "input": SchemaBuilder.string(description: "Video file path (required for source=video)"),
                "sample_fps": SchemaBuilder.number(description: "Sample FPS (default 2). Exclusive with every_ms."),
                "every_ms": SchemaBuilder.number(description: "Sample every N ms. Exclusive with sample_fps."),
                "start_ms": SchemaBuilder.number(description: "Trim start in ms"),
                "end_ms": SchemaBuilder.number(description: "Trim end in ms"),
                "no_diff": SchemaBuilder.boolean(description: "Keep all sampled frames (disable diff filtering)"),

                // Shared caps/output
                "highlight_changes": SchemaBuilder.boolean(description: "Overlay motion boxes on frames"),
                "max_frames": SchemaBuilder.number(description: "Soft frame cap (default 800)"),
                "max_mb": SchemaBuilder.number(description: "Soft size cap MB (optional)"),
                "resolution_cap": SchemaBuilder.number(description: "Cap longest side px (default 1440)"),
                "diff_strategy": SchemaBuilder.string(
                    description: "fast|quality (default fast)",
                    enum: ["fast", "quality"],
                    default: "fast"),
                "diff_budget_ms": SchemaBuilder
                    .number(description: "Diff time budget ms before falling back to fast (default 30 for quality)"),
                "output_dir": SchemaBuilder.string(description: "Optional absolute directory for outputs"),
                "autoclean_minutes": SchemaBuilder.number(description: "Minutes to keep temp outputs (default 120)"),
                "video_out": SchemaBuilder.string(description: "Optional MP4 output path"),
            ],
            required: [])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let request = try await CaptureRequest(arguments: arguments)
        let dependencies = WatchCaptureDependencies(
            screenCapture: self.context.screenCapture,
            screenService: self.context.screens,
            frameSource: request.frameSource)
        let configuration = WatchCaptureConfiguration(
            scope: request.scope,
            options: request.options,
            outputRoot: request.outputDirectory,
            autoclean: WatchAutocleanConfig(
                minutes: request.autocleanMinutes,
                managed: request.usesDefaultOutput),
            sourceKind: request.source,
            videoIn: request.videoIn,
            videoOut: request.videoOut,
            keepAllFrames: request.keepAllFrames,
            videoOptions: request.videoOptions)
        let session = WatchCaptureSession(
            dependencies: dependencies,
            configuration: configuration)
        let result = try await session.run()

        let summary = """
        capture kept \(result.stats.framesKept) frames (dropped \(result.stats.framesDropped)),
        contact sheet \(result.contactSheet.path)
        """
        let meta = ToolEventSummary(
            actionDescription: "Capture",
            notes: summary)

        let metaSummary = CaptureMetaSummary.make(from: result)
        return ToolResponse.text(
            summary,
            meta: ToolEventSummary.merge(
                summary: meta,
                into: CaptureMetaBuilder.buildMeta(from: metaSummary)))
    }
}

// MARK: - Request parsing

enum CaptureToolArgumentResolver {
    static func source(from rawValue: String?) throws -> CaptureSessionResult.Source {
        let normalized = self.normalized(rawValue) ?? "live"
        guard let source = CaptureSessionResult.Source(rawValue: normalized) else {
            throw PeekabooError.invalidInput("Unsupported capture source '\(rawValue ?? "")'. Use live or video.")
        }
        return source
    }

    static func mode(
        from rawValue: String?,
        hasRegion: Bool,
        hasWindowTarget: Bool) throws -> CaptureMode
    {
        if let normalized = self.normalized(rawValue) {
            if normalized == "region" { return .area }
            guard let mode = CaptureMode(rawValue: normalized) else {
                throw PeekabooError.invalidInput(
                    "Unsupported capture mode '\(rawValue ?? "")'. Use screen, window, frontmost, or area.")
            }
            return mode
        }
        if hasRegion { return .area }
        if hasWindowTarget { return .window }
        return .frontmost
    }

    static func applicationIdentifier(app: String?, pid: Int?) -> String {
        if let app = app?.trimmingCharacters(in: .whitespacesAndNewlines), !app.isEmpty {
            return app
        }
        if let pid {
            return "PID:\(pid)"
        }
        return "frontmost"
    }

    static func region(from rawValue: String?) throws -> CGRect {
        guard let rawValue else {
            throw PeekabooError.invalidInput("region is required when mode=area")
        }

        let parts = rawValue.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 4 else {
            throw PeekabooError.invalidInput("region must be x,y,width,height")
        }

        let values = try parts.map { part in
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard let value = Double(trimmed), value.isFinite else {
                throw PeekabooError.invalidInput("region must contain numeric x,y,width,height values")
            }
            return value
        }

        guard values[2] > 0, values[3] > 0 else {
            throw PeekabooError.invalidInput("region width and height must be greater than zero")
        }

        return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }

    static func diffStrategy(from rawValue: String?) throws -> CaptureOptions.DiffStrategy {
        let normalized = self.normalized(rawValue) ?? "fast"
        guard let strategy = CaptureOptions.DiffStrategy(rawValue: normalized) else {
            throw PeekabooError.invalidInput("Unsupported diff_strategy '\(rawValue ?? "")'. Use fast or quality.")
        }
        return strategy
    }

    static func captureFocus(from rawValue: String?) throws -> CaptureFocus {
        let normalized = self.normalized(rawValue) ?? "auto"
        guard let focus = CaptureFocus(rawValue: normalized) else {
            throw PeekabooError.invalidInput(
                "Unsupported capture_focus '\(rawValue ?? "")'. Use auto, background, or foreground.")
        }
        return focus
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed.lowercased()
    }
}

private struct CaptureRequest {
    let source: CaptureSessionResult.Source
    let scope: CaptureScope
    let options: CaptureOptions
    let outputDirectory: URL
    let autocleanMinutes: Int
    let usesDefaultOutput: Bool
    let frameSource: (any CaptureFrameSource)?
    let keepAllFrames: Bool
    let videoOptions: CaptureVideoOptionsSnapshot?
    let videoIn: String?
    let videoOut: String?

    init(arguments: ToolArguments) async throws {
        let input = try arguments.decode(CaptureInput.self)
        self.source = try CaptureToolArgumentResolver.source(from: input.source)

        // Shared caps/output
        let maxFrames = input.maxFrames ?? 800
        let maxMb = input.maxMb
        let resolutionCap = input.resolutionCap ?? 1440
        let diffStrategy = try CaptureToolArgumentResolver.diffStrategy(from: input.diffStrategy)
        let diffBudget = input.diffBudgetMs ?? (diffStrategy == .quality ? 30 : nil)
        let highlight = input.highlightChanges ?? false
        let constraints = CaptureConstraints(
            highlight: highlight,
            maxFrames: maxFrames,
            maxMb: maxMb,
            resolutionCap: resolutionCap,
            diffStrategy: diffStrategy,
            diffBudget: diffBudget)

        let outputDir = if let dir = input.output_dir {
            CaptureToolPathResolver.outputDirectory(from: dir)
        } else {
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("peekaboo/capture-sessions/capture-\(UUID().uuidString)", isDirectory: true)
        }
        self.outputDirectory = outputDir
        self.autocleanMinutes = input.autocleanMinutes ?? 120
        self.usesDefaultOutput = input.output_dir == nil
        self.videoOut = CaptureToolPathResolver.filePath(from: input.videoOut)

        switch self.source {
        case .live:
            let scope = try CaptureRequest.resolveScope(from: input)
            self.scope = scope
            self.frameSource = nil
            let opts = try CaptureRequest.buildLiveOptions(
                from: input,
                constraints: constraints)
            self.options = opts
            self.keepAllFrames = false
            self.videoOptions = nil
            self.videoIn = nil
        case .video:
            guard let inputPath = input.input else {
                throw PeekabooError.invalidInput("input is required when source=video")
            }
            let videoURL = CaptureToolPathResolver.fileURL(from: inputPath)
            let sampleFps = input.sampleFps
            let everyMs = input.everyMs
            if sampleFps != nil, everyMs != nil {
                throw PeekabooError.invalidInput("sample_fps and every_ms are mutually exclusive")
            }
            let frameSource = try await VideoFrameSource(
                url: videoURL,
                sampleFps: sampleFps,
                everyMs: everyMs,
                startMs: input.startMs,
                endMs: input.endMs,
                resolutionCap: resolutionCap)
            self.frameSource = frameSource
            self.scope = CaptureScope(kind: .frontmost)
            self.keepAllFrames = input.noDiff ?? false
            self.videoIn = videoURL.path
            self.videoOptions = CaptureVideoOptionsSnapshot(
                sampleFps: everyMs == nil ? sampleFps ?? 2.0 : nil,
                everyMs: everyMs,
                effectiveFps: frameSource.effectiveFPS,
                startMs: input.startMs,
                endMs: input.endMs,
                keepAllFrames: self.keepAllFrames)
            let opts = CaptureRequest.buildVideoOptions(constraints: constraints)
            self.options = opts
        }
    }
}

enum CaptureToolPathResolver {
    static func outputDirectory(from path: String) -> URL {
        URL(fileURLWithPath: self.expandedPath(path), isDirectory: true)
    }

    static func fileURL(from path: String) -> URL {
        URL(fileURLWithPath: self.expandedPath(path))
    }

    static func filePath(from path: String?) -> String? {
        path.map(self.expandedPath)
    }

    private static func expandedPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}

private struct CaptureInput: Codable {
    let source: String?
    let mode: String?
    let app: String?
    let pid: Int?
    let window_title: String?
    let window_index: Int?
    let screen_index: Int?
    let region: String?
    let capture_focus: String?

    let durationSeconds: Double?
    let idleFps: Double?
    let activeFps: Double?
    let thresholdPercent: Double?
    let heartbeatSec: Double?
    let quietMs: Double?

    let input: String?
    let sampleFps: Double?
    let everyMs: Int?
    let startMs: Int?
    let endMs: Int?
    let noDiff: Bool?

    let highlightChanges: Bool?
    let maxFrames: Int?
    let maxMb: Int?
    let resolutionCap: Double?
    let diffStrategy: String?
    let diffBudgetMs: Int?
    let output_dir: String?
    let autocleanMinutes: Int?
    let videoOut: String?
}

extension CaptureRequest {
    fileprivate static func resolveScope(from input: CaptureInput) throws -> CaptureScope {
        let modeStr = input.mode
        let explicitApp = input.app
        let windowTitle = input.window_title
        let windowIndex = input.window_index

        let mode = try CaptureToolArgumentResolver.mode(
            from: modeStr,
            hasRegion: input.region != nil,
            hasWindowTarget: explicitApp != nil || input.pid != nil || windowTitle != nil || windowIndex != nil)

        switch mode {
        case .screen:
            let screenIndex = input.screen_index
            return CaptureScope(
                kind: .screen,
                screenIndex: screenIndex,
                displayUUID: nil,
                windowId: nil,
                applicationIdentifier: nil,
                windowIndex: nil,
                region: nil)
        case .frontmost:
            return CaptureScope(kind: .frontmost)
        case .window:
            let appIdentifier = CaptureToolArgumentResolver.applicationIdentifier(app: explicitApp, pid: input.pid)
            return CaptureScope(kind: .window, applicationIdentifier: appIdentifier, windowIndex: windowIndex)
        case .area:
            let region = try CaptureToolArgumentResolver.region(from: input.region)
            return CaptureScope(
                kind: .region,
                region: region)
        case .multi:
            throw PeekabooError.invalidInput("mode multi not supported for capture")
        }
    }

    fileprivate struct CaptureConstraints {
        let highlight: Bool
        let maxFrames: Int
        let maxMb: Int?
        let resolutionCap: CGFloat
        let diffStrategy: CaptureOptions.DiffStrategy
        let diffBudget: Int?
    }

    fileprivate static func buildLiveOptions(
        from input: CaptureInput,
        constraints: CaptureConstraints) throws -> CaptureOptions
    {
        let duration = max(1, min(input.durationSeconds ?? 60, 180))
        let idle = min(max(input.idleFps ?? 2, 0.1), 5)
        let active = min(max(input.activeFps ?? 8, 0.5), 15)
        let threshold = min(max(input.thresholdPercent ?? 2.5, 0), 100)
        let heartbeat = max(input.heartbeatSec ?? 5, 0)
        let quiet = max(Int(input.quietMs ?? 1000), 0)
        let maxFrames = max(constraints.maxFrames, 1)
        let maxMbAdjusted = constraints.maxMb.flatMap { $0 > 0 ? $0 : nil }
        let focus = try CaptureToolArgumentResolver.captureFocus(from: input.capture_focus)

        return CaptureOptions(
            duration: duration,
            idleFps: idle,
            activeFps: active,
            changeThresholdPercent: threshold,
            heartbeatSeconds: heartbeat,
            quietMsToIdle: quiet,
            maxFrames: maxFrames,
            maxMegabytes: maxMbAdjusted,
            highlightChanges: constraints.highlight,
            captureFocus: focus,
            resolutionCap: constraints.resolutionCap,
            diffStrategy: constraints.diffStrategy,
            diffBudgetMs: constraints.diffBudget)
    }

    fileprivate static func buildVideoOptions(
        constraints: CaptureConstraints) -> CaptureOptions
    {
        let maxFrames = max(constraints.maxFrames, 1)
        let maxMbAdjusted = constraints.maxMb.flatMap { $0 > 0 ? $0 : nil }
        return CaptureOptions(
            duration: 3600,
            idleFps: 60,
            activeFps: 60,
            changeThresholdPercent: 2.5,
            heartbeatSeconds: 5,
            quietMsToIdle: 1000,
            maxFrames: maxFrames,
            maxMegabytes: maxMbAdjusted,
            highlightChanges: constraints.highlight,
            captureFocus: .auto,
            resolutionCap: constraints.resolutionCap,
            diffStrategy: constraints.diffStrategy,
            diffBudgetMs: constraints.diffBudget)
    }
}

// MARK: - Meta builder

private enum CaptureMetaBuilder {
    static func buildMeta(from summary: CaptureMetaSummary) -> Value {
        let meta: [String: Value] = [
            "frames": .array(summary.frames.map { .string($0) }),
            "contact": .string(summary.contactPath),
            "metadata": .string(summary.metadataPath),
            "diff_algorithm": .string(summary.diffAlgorithm),
            "diff_scale": .string(summary.diffScale),
            "contact_columns": .string("\(summary.contactColumns)"),
            "contact_rows": .string("\(summary.contactRows)"),
            "contact_thumb_width": .string("\(summary.contactThumbSize.width)"),
            "contact_thumb_height": .string("\(summary.contactThumbSize.height)"),
            "contact_sampled_indexes": .array(summary.contactSampledIndexes.map { .string("\($0)") }),
        ]
        return .object(meta)
    }
}
