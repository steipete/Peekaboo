import Foundation
import MCP
import PeekabooAutomation
import PeekabooAutomationKit
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
                "window_index": SchemaBuilder.number(description: "Optional window index; requires app or pid"),
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
        let request = try await CaptureRequest(arguments: arguments, windows: self.context.windows)
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
