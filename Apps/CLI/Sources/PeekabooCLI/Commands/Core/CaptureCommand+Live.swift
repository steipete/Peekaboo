import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
struct CaptureLiveCommand: ApplicationResolvable, ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
    // Targeting
    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'") var app: String?
    @Option(name: .long, help: "Target application by process ID") var pid: Int32?
    @Option(
        name: .long,
        help: "Capture mode (screen, window, frontmost, area; region alias accepted)"
    ) var mode: String?
    @Option(name: .long, help: "Capture window with specific title") var windowTitle: String?
    @Option(name: .long, help: "Window index to capture") var windowIndex: Int?
    @Option(name: .long, help: "Screen index for screen captures") var screenIndex: Int?
    @Option(name: .long, help: "Region to capture as x,y,width,height (global display coordinates)") var region: String?
    @Option(name: .long, help: "Window focus behavior") var captureFocus: LiveCaptureFocus = .auto
    @Option(
        name: .long,
        help: """
        Capture engine: auto|modern|sckit|classic|cg (default: auto).
        modern/sckit force ScreenCaptureKit; classic/cg force CGWindowList;
        auto tries SC then falls back when allowed.
        """
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

    private var logger: Logger {
        self.resolvedRuntime.logger
    }

    private var services: any PeekabooServiceProviding {
        self.resolvedRuntime.services
    }

    var jsonOutput: Bool {
        self.resolvedRuntime.configuration.jsonOutput
    }

    var outputLogger: Logger {
        self.logger
    }

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
                videoOut: CaptureCommandPathResolver.filePath(from: self.videoOut),
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
        let mode = try self.resolveMode()
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
            let windowReference = try await self.resolveWindowReference(for: identifier)
            return CaptureScope(
                kind: .window,
                screenIndex: nil,
                displayUUID: nil,
                windowId: windowReference.windowID,
                applicationIdentifier: identifier,
                windowIndex: windowReference.windowIndex,
                region: nil
            )
        case .area:
            let rect = try self.parseRegion()
            return CaptureScope(kind: .region, region: rect)
        case .multi:
            throw ValidationError("capture live does not support multi-mode captures")
        }
    }

    /// Exposed internally for tests.
    func resolveMode() throws -> LiveCaptureMode {
        if let explicit = self.mode {
            let normalized = explicit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "region" { return .area }
            guard let mode = LiveCaptureMode(rawValue: normalized) else {
                throw ValidationError(
                    "Unsupported capture live mode '\(explicit)'. Use screen, window, frontmost, or area."
                )
            }
            return mode
        }
        if self.region != nil { return .area }
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

    private func resolveWindowReference(for identifier: String) async throws -> (windowID: UInt32?, windowIndex: Int?) {
        guard self.windowTitle != nil || self.windowIndex != nil else {
            return (nil, nil)
        }

        let windows = try await WindowServiceBridge.listWindows(
            windows: self.services.windows,
            target: .application(identifier)
        )
        let renderable = ObservationTargetResolver.captureCandidates(from: windows)

        let selectedWindow: ServiceWindowInfo? = if let title = self.windowTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !title.isEmpty {
            renderable.first { $0.title.localizedCaseInsensitiveContains(title) }
        } else if let explicitIndex = self.windowIndex {
            renderable.first { $0.index == explicitIndex }
        } else {
            nil
        }

        guard let selectedWindow else {
            let criteria = self.windowTitle.map { "window title '\($0)' for \(identifier)" }
                ?? self.windowIndex.map { "window index \($0) for \(identifier)" }
                ?? "window for \(identifier)"
            throw PeekabooError.windowNotFound(criteria: criteria)
        }

        return (
            windowID: UInt32(exactly: selectedWindow.windowID),
            windowIndex: selectedWindow.index
        )
    }

    func parseRegion() throws -> CGRect {
        guard let region = self.region?.trimmingCharacters(in: .whitespacesAndNewlines),
              !region.isEmpty
        else {
            throw PeekabooError.invalidInput("Region must be provided when --mode area is set")
        }
        let parts = region
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 4,
              let x = Double(parts[0]),
              let y = Double(parts[1]),
              let width = Double(parts[2]),
              let height = Double(parts[3])
        else {
            throw PeekabooError.invalidInput("Region must be x,y,width,height")
        }
        guard width > 0, height > 0 else {
            throw PeekabooError.invalidInput("Region width and height must be greater than zero")
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    func buildOptions() throws -> CaptureOptions {
        let duration = max(1, min(self.duration ?? 60, 180))
        let idle = min(max(self.idleFps ?? 2, 0.1), 5)
        let active = min(max(self.activeFps ?? 8, 0.5), 15)
        let threshold = min(max(self.threshold ?? 2.5, 0), 100)
        let heartbeat = max(self.heartbeatSec ?? 5, 0)
        let quiet = max(self.quietMs ?? 1000, 0)
        let maxFrames = max(self.maxFrames ?? 800, 1)
        let resolutionCap = self.resolutionCap ?? 1440
        let diffStrategy = try CaptureCommandOptionParser.diffStrategy(self.diffStrategy)
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

    func resolveOutputDirectory() throws -> URL {
        CaptureCommandPathResolver.outputDirectory(from: self.path)
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
        self.captureEngine = values.singleOption("captureEngine")
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
