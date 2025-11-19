import AVFoundation
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

typealias LiveCaptureMode = PeekabooCore.CaptureMode
typealias LiveCaptureFocus = PeekabooCore.CaptureFocus
typealias LiveCaptureSessionResult = PeekabooCore.CaptureSessionResult

@MainActor
struct CaptureCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "capture",
                abstract: "Capture live screens/windows or ingest a video and extract frames",
                subcommands: [CaptureLiveCommand.self, CaptureVideoCommand.self, CaptureWatchAlias.self],
                showHelpOnEmptyInvocation: true
            )
        }
    }
}

// MARK: Live capture

@MainActor
struct CaptureLiveCommand: ApplicationResolvable, ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable, CaptureEngineConfigurable {
    // Targeting
    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'") var app: String?
    @Option(name: .long, help: "Target application by process ID") var pid: Int32?
    @Option(name: .long, help: "Capture mode (screen, window, frontmost, region)") var mode: String?
    @Option(name: .long, help: "Capture window with specific title") var windowTitle: String?
    @Option(name: .long, help: "Window index to capture") var windowIndex: Int?
    @Option(name: .long, help: "Screen index for screen captures") var screenIndex: Int?
    @Option(name: .long, help: "Region to capture as x,y,width,height (global display coordinates)") var region: String?
    @Option(name: .long, help: "Window focus behavior") var captureFocus: LiveCaptureFocus = .auto
    @Option(
        name: .long,
        help: "Capture engine: auto|modern|sckit|classic|cg (default: auto). modern/sckit force ScreenCaptureKit; classic/cg force CGWindowList; auto tries SC then falls back when allowed."
    ) var captureEngine: String?

    // Behavior
    @Option(name: .long, help: "Duration in seconds (default 60, max 180)") var duration: Double?
    @Option(name: .long, help: "Idle FPS during quiet periods (default 2)") var idleFps: Double?
    @Option(name: .long, help: "Active FPS during motion (default 8, max 15)") var activeFps: Double?
    @Option(name: .long, help: "Change threshold percent to enter active mode (default 2.5)") var threshold: Double?
    @Option(
        name: .long,
        help: "Heartbeat keyframe interval in seconds (default 5, 0 disables)"
    ) var heartbeatSec: Double?
    @Option(name: .long, help: "Calm period in milliseconds before returning to idle (default 1000)") var quietMs: Int?
    @Flag(name: .long, help: "Overlay motion boxes on kept frames") var highlightChanges = false
    @Option(name: .long, help: "Max frames before stopping (soft cap, default 800)") var maxFrames: Int?
    @Option(name: .long, help: "Max megabytes before stopping (soft cap, optional)") var maxMb: Int?
    @Option(name: .long, help: "Resolution cap (largest dimension, default 1440)") var resolutionCap: Double?
    @Option(name: .long, help: "Diff strategy: fast|quality (default fast)") var diffStrategy: String?
    @Option(
        name: .long,
        help: "Diff time budget in milliseconds before falling back to fast (default 30 when quality)"
    ) var diffBudgetMs: Int?

    // Output
    @Option(name: .long, help: "Output directory (defaults to temp capture session)") var path: String?
    @Option(name: .long, help: "Minutes before temp sessions auto-clean (default 120)") var autocleanMinutes: Int?
    @Option(name: .long, help: "Optional MP4 output path (built from kept frames)") var videoOut: String?

    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var logger: Logger { self.resolvedRuntime.logger }
    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }
    var outputLogger: Logger { self.logger }

    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)
        self.logger.operationStart("capture_live", metadata: ["mode": self.mode ?? "auto"])

        do {
            try await requireScreenRecordingPermission(services: self.services)
            let scope = try await self.resolveScope()
            let options = try self.buildOptions()
            if scope.kind == .window, let identifier = scope.applicationIdentifier {
                try await self.focusIfNeeded(appIdentifier: identifier)
            }
            let outputDir = try self.resolveOutputDirectory()
            let deps = WatchCaptureDependencies(
                screenCapture: self.services.screenCapture,
                screenService: self.services.screens,
                frameSource: nil
            )
            let config = WatchCaptureConfiguration(
                scope: scope,
                options: options,
                outputRoot: outputDir,
                autoclean: WatchAutocleanConfig(minutes: self.autocleanMinutes ?? 120, managed: self.path == nil),
                sourceKind: .live,
                videoIn: nil,
                videoOut: self.videoOut,
                keepAllFrames: false
            )
            let session = WatchCaptureSession(dependencies: deps, configuration: config)
            let result = try await session.run()
            self.output(result)
            self.logger.operationComplete(
                "capture_live",
                success: true,
                metadata: ["frames_kept": result.stats.framesKept]
            )
        } catch {
            self.handleError(error)
            self.logger.operationComplete(
                "capture_live",
                success: false,
                metadata: ["error": error.localizedDescription]
            )
            throw ExitCode(1)
        }
    }

    private func resolveScope() async throws -> CaptureScope {
        let mode = self.resolveMode()
        switch mode {
        case .screen:
            let displayInfo = try await self.displayInfo(for: self.screenIndex)
            return CaptureScope(
                kind: .screen,
                screenIndex: displayInfo?.index,
                displayUUID: displayInfo?.uuid,
                windowId: nil,
                applicationIdentifier: nil,
                windowIndex: nil,
                region: nil
            )
        case .frontmost:
            return CaptureScope(
                kind: .frontmost,
                screenIndex: nil,
                displayUUID: nil,
                windowId: nil,
                applicationIdentifier: nil,
                windowIndex: nil,
                region: nil
            )
        case .window:
            let identifier = try self.resolveApplicationIdentifier()
            let windowIdx = try await self.resolveWindowIndex(for: identifier)
            return CaptureScope(
                kind: .window,
                screenIndex: nil,
                displayUUID: nil,
                windowId: nil,
                applicationIdentifier: identifier,
                windowIndex: windowIdx,
                region: nil
            )
        case .area:
            let rect = try self.parseRegion()
            return CaptureScope(kind: .region, region: rect)
        case .multi:
            throw ValidationError("capture live does not support multi-mode captures")
        }
    }

    // Exposed internally for tests.
    func resolveMode() -> LiveCaptureMode {
        if let explicit = self.mode {
            if explicit.lowercased() == "region" { return .area }
            return LiveCaptureMode(rawValue: explicit) ?? .frontmost
        }
        if self.app != nil || self.pid != nil || self.windowTitle != nil { return .window }
        return .frontmost
    }

    private func displayInfo(for index: Int?) async throws -> (index: Int, uuid: String)? {
        guard let index else { return nil }
        let screens = self.services.screens.listScreens()
        guard let match = screens.first(where: { $0.index == index }) else {
            throw PeekabooError.invalidInput("Screen index \(index) not found")
        }
        return (index, "\(match.displayID)")
    }

    private func resolveWindowIndex(for identifier: String) async throws -> Int? {
        if let explicitIndex = self.windowIndex { return explicitIndex }
        do {
            let windows = try await WindowServiceBridge.listWindows(
                windows: self.services.windows,
                target: .application(identifier)
            )
            let renderable = WindowFilterHelper.filter(
                windows: windows,
                appIdentifier: identifier,
                mode: .capture,
                logger: self.logger
            )
            if let title = self.windowTitle,
               let match = renderable.first(where: { $0.title.localizedCaseInsensitiveContains(title) }) {
                return match.index
            }
            if let preferred = ImageCommand.preferredWindow(from: renderable) { return preferred.index }
            return renderable.first?.index
        } catch { return nil }
    }

    private func parseRegion() throws -> CGRect {
        guard let region else { throw PeekabooError.invalidInput("Region must be provided when --mode region is set") }
        let parts = region.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else { throw PeekabooError.invalidInput("Region must be x,y,width,height") }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    private func buildOptions() throws -> CaptureOptions {
        let duration = max(1, min(self.duration ?? 60, 180))
        let idle = min(max(self.idleFps ?? 2, 0.1), 5)
        let active = min(max(self.activeFps ?? 8, 0.5), 15)
        let threshold = min(max(self.threshold ?? 2.5, 0), 100)
        let heartbeat = max(self.heartbeatSec ?? 5, 0)
        let quiet = max(self.quietMs ?? 1000, 0)
        let maxFrames = max(self.maxFrames ?? 800, 1)
        let resolutionCap = self.resolutionCap ?? 1440
        let diffStrategy = CaptureOptions.DiffStrategy(rawValue: self.diffStrategy ?? "fast") ?? .fast
        let diffBudgetMs = self.diffBudgetMs ?? (diffStrategy == .quality ? 30 : nil)
        let maxMb = self.maxMb.flatMap { $0 > 0 ? $0 : nil }

        return CaptureOptions(
            duration: duration,
            idleFps: idle,
            activeFps: active,
            changeThresholdPercent: threshold,
            heartbeatSeconds: heartbeat,
            quietMsToIdle: quiet,
            maxFrames: maxFrames,
            maxMegabytes: maxMb,
            highlightChanges: self.highlightChanges,
            captureFocus: self.captureFocus,
            resolutionCap: resolutionCap,
            diffStrategy: diffStrategy,
            diffBudgetMs: diffBudgetMs
        )
    }

    private func resolveOutputDirectory() throws -> URL {
        if let path { return URL(fileURLWithPath: path, isDirectory: true) }
        let temp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("peekaboo")
            .appendingPathComponent("capture-sessions", isDirectory: true)
            .appendingPathComponent("capture-\(UUID().uuidString)", isDirectory: true)
        return temp
    }

    private func output(_ result: LiveCaptureSessionResult) {
        let meta = CaptureMetaSummary.make(from: result)
        if self.jsonOutput {
            outputSuccessCodable(data: result, logger: self.outputLogger)
            return
        }
        print("""
        🎥 capture kept \(result.stats.framesKept) frames (dropped \(result.stats.framesDropped)),
        contact sheet: \(meta.contactPath), diff: \(meta.diffAlgorithm) @ \(meta.diffScale),
        grid \(meta.contactColumns)x\(meta
            .contactRows) thumb \(Int(meta.contactThumbSize.width))x\(Int(meta.contactThumbSize.height))
        """)
        for frame in result.frames {
            print(
                "🖼️  \(frame.reason.rawValue) t=\(frame.timestampMs)ms "
                    + "Δ=\(String(format: "%.2f", frame.changePercent))% → \(frame.path)"
            )
        }
        for warning in result.warnings {
            print("⚠️  \(warning.code.rawValue): \(warning.message)")
        }
    }

    private func focusIfNeeded(appIdentifier: String) async throws {
        switch self.captureFocus {
        case .background: return
        case .auto:
            let options = FocusOptions(
                autoFocus: true,
                focusTimeout: nil,
                focusRetryCount: nil,
                spaceSwitch: false,
                bringToCurrentSpace: false
            )
            try await ensureFocused(
                applicationName: appIdentifier,
                windowTitle: self.windowTitle,
                options: options,
                services: self.services
            )
        case .foreground:
            let options = FocusOptions(
                autoFocus: true,
                focusTimeout: nil,
                focusRetryCount: nil,
                spaceSwitch: true,
                bringToCurrentSpace: true
            )
            try await ensureFocused(
                applicationName: appIdentifier,
                windowTitle: self.windowTitle,
                options: options,
                services: self.services
            )
        }
    }
}

extension CaptureLiveCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "live",
                abstract: "Capture live screen/window/region with change-aware sampling",
                version: "1.0.0"
            )
        }
    }
}

extension CaptureLiveCommand: AsyncRuntimeCommand {}

@MainActor
extension CaptureLiveCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = values.singleOption("app")
        self.pid = try values.decodeOption("pid", as: Int32.self)
        self.mode = values.singleOption("mode")
        self.windowTitle = values.singleOption("windowTitle")
        self.windowIndex = try values.decodeOption("windowIndex", as: Int.self)
        self.screenIndex = try values.decodeOption("screenIndex", as: Int.self)
        self.region = values.singleOption("region")
        if let parsedFocus: LiveCaptureFocus = try values
            .decodeOptionEnum("captureFocus") { self.captureFocus = parsedFocus }
        self.duration = try values.decodeOption("duration", as: Double.self)
        self.idleFps = try values.decodeOption("idleFps", as: Double.self)
        self.activeFps = try values.decodeOption("activeFps", as: Double.self)
        self.threshold = try values.decodeOption("threshold", as: Double.self)
        self.heartbeatSec = try values.decodeOption("heartbeatSec", as: Double.self)
        self.quietMs = try values.decodeOption("quietMs", as: Int.self)
        self.maxFrames = try values.decodeOption("maxFrames", as: Int.self)
        self.maxMb = try values.decodeOption("maxMb", as: Int.self)
        self.resolutionCap = try values.decodeOption("resolutionCap", as: Double.self)
        self.diffStrategy = values.singleOption("diffStrategy")
        self.diffBudgetMs = try values.decodeOption("diffBudgetMs", as: Int.self)
        if values.flag("highlightChanges") { self.highlightChanges = true }
        self.path = values.singleOption("path")
        self.autocleanMinutes = try values.decodeOption("autocleanMinutes", as: Int.self)
        self.videoOut = values.singleOption("videoOut")
    }
}

// MARK: Video capture

@MainActor
struct CaptureVideoCommand: ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
    @Argument(help: "Input video file") var input: String
    @Option(name: .long, help: "Sample FPS (default 2). Mutually exclusive with --every-ms") var sampleFps: Double?
    @Option(name: .long, help: "Sample every N milliseconds (mutually exclusive with --sample-fps)") var everyMs: Int?
    @Option(name: .long, help: "Trim start in ms") var startMs: Int?
    @Option(name: .long, help: "Trim end in ms") var endMs: Int?
    @Flag(name: .long, help: "Keep all sampled frames (disable diff/keep filtering)") var noDiff = false
    @Option(name: .long, help: "Max frames before stopping") var maxFrames: Int?
    @Option(name: .long, help: "Max megabytes before stopping") var maxMb: Int?
    @Option(name: .long, help: "Resolution cap (largest dimension, default 1440)") var resolutionCap: Double?
    @Option(name: .long, help: "Diff strategy: fast|quality (default fast)") var diffStrategy: String?
    @Option(name: .long, help: "Diff time budget ms before falling back to fast") var diffBudgetMs: Int?
    @Option(name: .long, help: "Output directory") var path: String?
    @Option(name: .long, help: "Minutes before temp sessions auto-clean (default 120)") var autocleanMinutes: Int?
    @Option(name: .long, help: "Optional MP4 output path (built from kept frames)") var videoOut: String?

    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var logger: Logger { self.resolvedRuntime.logger }
    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }
    var outputLogger: Logger { self.logger }

    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)
        self.logger.operationStart("capture_video", metadata: ["input": self.input])

        do {
            if self.sampleFps != nil && self.everyMs != nil {
                throw ValidationError("--sample-fps and --every-ms are mutually exclusive")
            }
            let outputDir = try self.resolveOutputDirectory()
            let options = self.buildOptions()
            let videoURL = URL(fileURLWithPath: self.input)
            let frameSource = try VideoFrameSource(
                url: videoURL,
                sampleFps: self.sampleFps,
                everyMs: self.everyMs,
                startMs: self.startMs,
                endMs: self.endMs,
                resolutionCap: self.resolutionCap.map { CGFloat($0) }
            )

            let deps = WatchCaptureDependencies(
                screenCapture: self.services.screenCapture,
                screenService: self.services.screens,
                frameSource: frameSource
            )
            let config = WatchCaptureConfiguration(
                scope: CaptureScope(kind: .frontmost),
                options: options,
                outputRoot: outputDir,
                autoclean: WatchAutocleanConfig(minutes: self.autocleanMinutes ?? 120, managed: self.path == nil),
                sourceKind: .video,
                videoIn: videoURL.path,
                videoOut: self.videoOut,
                keepAllFrames: self.noDiff
            )
            let session = WatchCaptureSession(dependencies: deps, configuration: config)
            let result = try await session.run()
            self.output(result)
            self.logger.operationComplete(
                "capture_video",
                success: true,
                metadata: ["frames_kept": result.stats.framesKept]
            )
        } catch {
            self.handleError(error)
            self.logger.operationComplete(
                "capture_video",
                success: false,
                metadata: ["error": error.localizedDescription]
            )
            throw ExitCode(1)
        }
    }

    private func buildOptions() -> CaptureOptions {
        let maxFrames = max(self.maxFrames ?? 10000, 1)
        let resolutionCap = self.resolutionCap ?? 1440
        let diffStrategy = CaptureOptions.DiffStrategy(rawValue: self.diffStrategy ?? "fast") ?? .fast
        let diffBudgetMs = self.diffBudgetMs ?? (diffStrategy == .quality ? 30 : nil)
        let maxMb = self.maxMb.flatMap { $0 > 0 ? $0 : nil }
        return CaptureOptions(
            duration: 3600,
            idleFps: 60,
            activeFps: 60,
            changeThresholdPercent: 2.5,
            heartbeatSeconds: 5,
            quietMsToIdle: 1000,
            maxFrames: maxFrames,
            maxMegabytes: maxMb,
            highlightChanges: false,
            captureFocus: .auto,
            resolutionCap: resolutionCap,
            diffStrategy: diffStrategy,
            diffBudgetMs: diffBudgetMs
        )
    }

    private func resolveOutputDirectory() throws -> URL {
        if let path { return URL(fileURLWithPath: path, isDirectory: true) }
        let temp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("peekaboo")
            .appendingPathComponent("capture-sessions", isDirectory: true)
            .appendingPathComponent("capture-\(UUID().uuidString)", isDirectory: true)
        return temp
    }

    private func output(_ result: LiveCaptureSessionResult) {
        let meta = CaptureMetaSummary.make(from: result)
        if self.jsonOutput {
            outputSuccessCodable(data: result, logger: self.outputLogger)
            return
        }
        print("""
        🎥 capture(video) kept \(result.stats.framesKept) frames (dropped \(result.stats
            .framesDropped)), contact sheet: \(meta.contactPath)
        """)
        for frame in result.frames {
            print("🖼️  \(frame.reason.rawValue) t=\(frame.timestampMs)ms → \(frame.path)")
        }
        for warning in result.warnings {
            print("⚠️  \(warning.code.rawValue): \(warning.message)")
        }
    }
}

extension CaptureVideoCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "video",
                abstract: "Ingest a video, sample frames, and build contact sheet",
                version: "1.0.0"
            )
        }
    }
}

extension CaptureVideoCommand: AsyncRuntimeCommand {}

@MainActor
extension CaptureVideoCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.sampleFps = try values.decodeOption("sampleFps", as: Double.self)
        self.everyMs = try values.decodeOption("everyMs", as: Int.self)
        self.startMs = try values.decodeOption("startMs", as: Int.self)
        self.endMs = try values.decodeOption("endMs", as: Int.self)
        if values.flag("noDiff") { self.noDiff = true }
        self.maxFrames = try values.decodeOption("maxFrames", as: Int.self)
        self.maxMb = try values.decodeOption("maxMb", as: Int.self)
        self.resolutionCap = try values.decodeOption("resolutionCap", as: Double.self)
        self.diffStrategy = values.singleOption("diffStrategy")
        self.diffBudgetMs = try values.decodeOption("diffBudgetMs", as: Int.self)
        self.path = values.singleOption("path")
        self.autocleanMinutes = try values.decodeOption("autocleanMinutes", as: Int.self)
        self.videoOut = values.singleOption("videoOut")
    }
}

// MARK: Hidden alias

@MainActor
struct CaptureWatchAlias: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(commandName: "watch", abstract: "Alias for capture live", version: "1.0.0")
        }
    }

    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions: CommandRuntimeOptions {
        get { self.live.runtimeOptions }
        set { self.live.runtimeOptions = newValue }
    }

    private var live = CaptureLiveCommand()

    mutating func run(using runtime: CommandRuntime) async throws {
        try await self.live.run(using: runtime)
    }
}

extension CaptureWatchAlias: AsyncRuntimeCommand {}

@MainActor
extension CaptureWatchAlias: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        try self.live.applyCommanderValues(values)
    }
}

// Back-compat alias for tests/agents
typealias WatchCommand = CaptureLiveCommand
