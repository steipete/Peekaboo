import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
struct WatchCommand: ApplicationResolvable, ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
    // Targeting
    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String?

    @Option(name: .long, help: "Target application by process ID")
    var pid: Int32?

    @Option(name: .long, help: "Capture mode (screen, window, frontmost, region)")
    var mode: String?

    @Option(name: .long, help: "Capture window with specific title")
    var windowTitle: String?

    @Option(name: .long, help: "Window index to capture")
    var windowIndex: Int?

    @Option(name: .long, help: "Screen index for screen captures")
    var screenIndex: Int?

    @Option(name: .long, help: "Region to capture as x,y,width,height (global display coordinates)")
    var region: String?

    @Option(name: .long, help: "Window focus behavior")
    var captureFocus: CaptureFocus = .auto

    // Behavior
    @Option(name: .long, help: "Duration in seconds (default 60, max 180)")
    var duration: Double?

    @Option(name: .long, help: "Idle FPS during quiet periods (default 2)")
    var idleFps: Double?

    @Option(name: .long, help: "Active FPS during motion (default 8, max 15)")
    var activeFps: Double?

    @Option(name: .long, help: "Change threshold percent to enter active mode (default 2.5)")
    var threshold: Double?

    @Option(name: .long, help: "Heartbeat keyframe interval in seconds (default 5, 0 disables)")
    var heartbeatSec: Double?

    @Option(name: .long, help: "Calm period in milliseconds before returning to idle (default 1000)")
    var quietMs: Int?

    @Flag(name: .long, help: "Overlay motion boxes on kept frames")
    var highlightChanges = false

    @Option(name: .long, help: "Max frames before stopping (soft cap, default 800)")
    var maxFrames: Int?

    @Option(name: .long, help: "Max megabytes before stopping (soft cap, optional)")
    var maxMb: Int?

    @Option(name: .long, help: "Resolution cap (largest dimension, default 1440)")
    var resolutionCap: Double?

    @Option(name: .long, help: "Diff strategy: fast|quality (default fast)")
    var diffStrategy: String?

    // Output
    @Option(name: .long, help: "Output directory (defaults to temp watch session)")
    var path: String?

    @Option(name: .long, help: "Minutes before temp sessions auto-clean (default 120)")
    var autocleanMinutes: Int?

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
    var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }
    var outputLogger: Logger { self.logger }

    // MARK: - Entry

    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)
        self.logger.operationStart(
            "watch_command",
            metadata: [
                "mode": self.mode ?? "auto",
                "app": self.app ?? "none",
                "duration": self.duration ?? 60,
                "idle_fps": self.idleFps ?? 2,
                "active_fps": self.activeFps ?? 8
            ])

        do {
            try await requireScreenRecordingPermission(services: self.services)
            let scope = try await self.resolveScope()
            let options = try self.buildOptions()

            if scope.kind == .window, let identifier = scope.applicationIdentifier {
                try await self.focusIfNeeded(appIdentifier: identifier)
            }

            let outputDir = try self.resolveOutputDirectory()
            let session = WatchCaptureSession(
                screenCapture: self.services.screenCapture,
                scope: scope,
                options: options,
                outputRoot: outputDir,
                autocleanMinutes: self.autocleanMinutes ?? 120)
            let result = try await session.run()

            self.output(result)
            self.logger.operationComplete(
                "watch_command",
                success: true,
                metadata: [
                    "frames_kept": result.stats.framesKept,
                    "frames_dropped": result.stats.framesDropped,
                    "fps_effective": result.stats.fpsEffective
                ])
        } catch {
            self.handleError(error)
            self.logger.operationComplete(
                "watch_command",
                success: false,
                metadata: ["error": error.localizedDescription])
            throw ExitCode(1)
        }
    }

    // MARK: - Resolution helpers

    private func resolveScope() async throws -> WatchScope {
        let mode = self.resolveMode()
        switch mode {
        case .screen:
            let displayInfo = try await self.displayInfo(for: self.screenIndex)
            return WatchScope(kind: .screen, screenIndex: displayInfo?.index, displayUUID: displayInfo?.uuid, windowId: nil, applicationIdentifier: nil, windowIndex: nil, region: nil)
        case .frontmost:
            return WatchScope(kind: .frontmost, screenIndex: nil, displayUUID: nil, windowId: nil, applicationIdentifier: nil, windowIndex: nil, region: nil)
        case .window:
            let identifier = try self.resolveApplicationIdentifier()
            let windowIdx = try await self.resolveWindowIndex(for: identifier)
            return WatchScope(
                kind: .window,
                screenIndex: nil,
                displayUUID: nil,
                windowId: nil,
                applicationIdentifier: identifier,
                windowIndex: windowIdx,
                region: nil)
        case .area:
            let rect = try self.parseRegion()
            return WatchScope(kind: .region, screenIndex: nil, displayUUID: nil, windowId: nil, applicationIdentifier: nil, windowIndex: nil, region: rect)
        case .multi:
            throw ValidationError("watch does not support multi-mode captures")
        }
    }

    private func resolveMode() -> CaptureMode {
        if let explicit = self.mode {
            if explicit.lowercased() == "region" { return .area }
            return CaptureMode(rawValue: explicit) ?? .frontmost
        }

        if self.app != nil || self.pid != nil || self.windowTitle != nil {
            return .window
        }
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
        if let explicitIndex = self.windowIndex {
            return explicitIndex
        }
        do {
            let windows = try await WindowServiceBridge.listWindows(
                windows: self.services.windows,
                target: .application(identifier))
            return windows.first?.index
        } catch {
            return nil
        }
    }

    private func parseRegion() throws -> CGRect {
        guard let region else {
            throw PeekabooError.invalidInput("Region must be provided when --mode region is set")
        }
        let parts = region.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else {
            throw PeekabooError.invalidInput("Region must be x,y,width,height")
        }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    private func buildOptions() throws -> WatchCaptureOptions {
        let duration = max(1, min(self.duration ?? 60, 180))
        let idle = min(max(self.idleFps ?? 2, 0.1), 5)
        let active = min(max(self.activeFps ?? 8, 0.5), 15)
        let threshold = min(max(self.threshold ?? 2.5, 0), 100)
        let heartbeat = max(self.heartbeatSec ?? 5, 0)
        let quiet = max(self.quietMs ?? 1000, 0)
        let maxFrames = max(self.maxFrames ?? 800, 1)
        let resolutionCap = self.resolutionCap ?? 1440
        let diffStrategy = WatchCaptureOptions.DiffStrategy(rawValue: (self.diffStrategy ?? "fast")) ?? .fast

        let maxMb = self.maxMb.flatMap { $0 > 0 ? $0 : nil }

        return WatchCaptureOptions(
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
            diffStrategy: diffStrategy)
    }

    private func resolveOutputDirectory() throws -> URL {
        if let path {
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        let temp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("peekaboo")
            .appendingPathComponent("watch-sessions", isDirectory: true)
            .appendingPathComponent("watch-\(UUID().uuidString)", isDirectory: true)
        return temp
    }

    private func output(_ result: WatchCaptureResult) {
        if self.jsonOutput {
            outputSuccessCodable(data: result, logger: self.outputLogger)
            return
        }

        print("🎥 watch captured \(result.stats.framesKept) frames (dropped \(result.stats.framesDropped)), contact sheet: \(result.contactSheet.path)")
        for frame in result.frames {
            print("🖼️  \(frame.reason.rawValue) t=\(frame.timestampMs)ms Δ=\(String(format: "%.2f", frame.changePercent))% → \(frame.path)")
        }
        for warning in result.warnings {
            print("⚠️  \(warning.code.rawValue): \(warning.message)")
        }
    }

    private func focusIfNeeded(appIdentifier: String) async throws {
        switch self.captureFocus {
        case .background:
            return
        case .auto:
            let options = FocusOptions(
                autoFocus: true,
                focusTimeout: nil,
                focusRetryCount: nil,
                spaceSwitch: false,
                bringToCurrentSpace: false)
            try await ensureFocused(
                applicationName: appIdentifier,
                windowTitle: self.windowTitle,
                options: options,
                services: self.services)
        case .foreground:
            let options = FocusOptions(
                autoFocus: true,
                focusTimeout: nil,
                focusRetryCount: nil,
                spaceSwitch: true,
                bringToCurrentSpace: true)
            try await ensureFocused(
                applicationName: appIdentifier,
                windowTitle: self.windowTitle,
                options: options,
                services: self.services)
        }
    }
}

// MARK: - Commander plumbing

extension WatchCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "watch",
                abstract: "Watch a screen/window/region and save PNG frames when things change",
                version: "1.0.0"
            )
        }
    }
}

extension WatchCommand: AsyncRuntimeCommand {}

@MainActor
extension WatchCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = values.singleOption("app")
        self.pid = try values.decodeOption("pid", as: Int32.self)
        self.mode = values.singleOption("mode")
        self.windowTitle = values.singleOption("windowTitle")
        self.windowIndex = try values.decodeOption("windowIndex", as: Int.self)
        self.screenIndex = try values.decodeOption("screenIndex", as: Int.self)
        self.region = values.singleOption("region")
        if let parsedFocus: CaptureFocus = try values.decodeOptionEnum("captureFocus") {
            self.captureFocus = parsedFocus
        }
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
        if values.flag("highlightChanges") { self.highlightChanges = true }
        self.path = values.singleOption("path")
        self.autocleanMinutes = try values.decodeOption("autocleanMinutes", as: Int.self)
    }
}
