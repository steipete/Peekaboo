import Algorithms
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

struct ImageAnalysisData: Codable {
    let provider: String
    let model: String
    let text: String
}

private typealias CaptureMode = PeekabooCore.CaptureMode
private typealias ImageFormat = PeekabooCore.ImageFormat
private typealias CaptureFocus = PeekabooCore.CaptureFocus

@MainActor

struct ImageCommand: ApplicationResolvable, ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
    @Option(name: .long, help: "Target application name, bundle ID, 'PID:12345', 'menubar', or 'frontmost'")
    var app: String?

    @Option(name: .long, help: "Target application by process ID")
    var pid: Int32?

    @Option(name: .long, help: "Output path for saved image")
    var path: String?

    @Option(name: .long, help: "Capture mode (screen, window, frontmost)")
    var mode: PeekabooCore.CaptureMode?

    @Option(name: .long, help: "Capture window with specific title")
    var windowTitle: String?

    @Option(name: .long, help: "Window index to capture")
    var windowIndex: Int?

    @Option(
        name: .long,
        help: "Target window by CoreGraphics window id (window_id from `peekaboo window list --json`)"
    )
    var windowId: Int?

    @Option(name: .long, help: "Screen index for screen captures")
    var screenIndex: Int?

    @Flag(name: .long, help: "Capture at native Retina scale (default stores 1x logical resolution)")
    var retina: Bool = false

    @Option(
        name: .long,
        help: """
        Capture engine: auto|modern|sckit|classic|cg (default: auto).
        modern/sckit force ScreenCaptureKit; classic/cg force CGWindowList;
        auto tries SC then falls back when allowed.
        """
    )
    var captureEngine: String?

    @Option(name: .long, help: "Image format: png or jpg")
    var format: PeekabooCore.ImageFormat = .png

    @Option(name: .long, help: "Window focus behavior")
    var captureFocus: PeekabooCore.CaptureFocus = .auto

    @Option(name: .long, help: "Analyze the captured image with AI")
    var analyze: String?
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
        self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput
    }

    var outputLogger: Logger {
        self.logger
    }

    private var captureScale: CaptureScalePreference {
        self.retina ? .native : .logical1x
    }

    private var observationCaptureOptions: DesktopCaptureOptions {
        DesktopCaptureOptions(
            engine: self.observationCaptureEnginePreference,
            scale: self.captureScale,
            focus: self.captureFocus,
            visualizerMode: .screenshotFlash
        )
    }

    private var observationCaptureEnginePreference: CaptureEnginePreference {
        let value = (self.captureEngine ?? self.resolvedRuntime.configuration.captureEnginePreference)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch value {
        case "modern", "modern-only", "sckit", "sc", "screen-capture-kit", "sck":
            return .modern
        case "classic", "cg", "legacy", "legacy-only", "false", "0", "no":
            return .legacy
        default:
            return .auto
        }
    }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)
        let startMetadata: [String: Any] = [
            "mode": self.mode?.rawValue ?? "auto",
            "app": self.app ?? "none",
            "pid": self.pid ?? 0,
            "hasAnalyzePrompt": self.analyze != nil
        ]
        self.logger.operationStart("image_command", metadata: startMetadata)

        do {
            // ScreenCaptureService performs the authoritative permission check inside each capture path.
            // Avoid preflighting here too; it adds fixed latency to every one-shot screenshot.
            let savedFiles = try await self.performCapture()

            if let prompt = self.analyze, let firstFile = savedFiles.first {
                let analysis = try await self.analyzeImage(at: firstFile.path, with: prompt)
                self.outputResultsWithAnalysis(savedFiles, analysis: analysis)
            } else {
                self.outputResults(savedFiles)
            }

            self.logger.operationComplete("image_command", success: true)
        } catch {
            self.handleError(error)
            self.logger.operationComplete(
                "image_command",
                success: false,
                metadata: ["error": error.localizedDescription]
            )
            throw ExitCode(1)
        }
    }

    private func performCapture() async throws -> [SavedFile] {
        if let appName = self.app?.lowercased() {
            switch appName {
            case "menubar":
                return try await self.captureMenuBar()
            case "frontmost":
                return try await self.captureFrontmost()
            default:
                break
            }
        }

        let captureMode = self.determineMode()
        var results: [SavedFile] = []

        switch captureMode {
        case .screen:
            results = try await self.captureScreens()
        case .window:
            if let windowId = self.windowId {
                results = try await self.captureWindowById(windowId)
            } else {
                let identifier = try self.resolveApplicationIdentifier()
                results = try await self.captureApplicationWindow(identifier)
            }
        case .multi:
            if self.app != nil || self.pid != nil {
                let identifier = try self.resolveApplicationIdentifier()
                results = try await self.captureAllApplicationWindows(identifier)
            } else {
                results = try await self.captureScreens()
            }
        case .frontmost:
            results = try await self.captureFrontmost()
        case .area:
            throw ValidationError("Area capture mode is not implemented. Use --mode screen or --mode window instead.")
        }

        return results
    }

    private func outputResults(_ files: [SavedFile]) {
        let output = ImageCaptureResult(files: files)
        if self.jsonOutput {
            outputSuccessCodable(data: output, logger: self.outputLogger)
        } else {
            files.forEach { print("📸 \(self.describeSavedFile($0))") }
        }
    }

    private func outputResultsWithAnalysis(_ files: [SavedFile], analysis: ImageAnalysisData) {
        let output = ImageAnalyzeResult(files: files, analysis: analysis)
        if self.jsonOutput {
            outputSuccessCodable(data: output, logger: self.outputLogger)
        } else {
            files.forEach { print("📸 \(self.describeSavedFile($0))") }
            print("\n🤖 Analysis (\(analysis.provider)) - \(analysis.model):")
            print(analysis.text)
        }
    }
}

// MARK: - Supporting Types & Helpers

struct ImageCaptureResult: Codable {
    let files: [SavedFile]
}

struct ImageAnalyzeResult: Codable {
    let files: [SavedFile]
    let analysis: ImageAnalysisData
}

// MARK: - Capture Helpers

extension ImageCommand {
    private func determineMode() -> CaptureMode {
        if let mode {
            return mode
        }

        if self.app != nil || self.pid != nil || self.windowTitle != nil || self.windowIndex != nil || self
            .windowId != nil {
            return .window
        }

        return .frontmost
    }

    private func captureWindowById(_ windowId: Int) async throws -> [SavedFile] {
        let observation = try await self.captureObservation(
            target: .windowID(CGWindowID(windowId)),
            preferredName: "window-\(windowId)",
            index: nil
        )

        let title = observation.capture.metadata.windowInfo?.title
        let preferredName = if let title, !title.isEmpty {
            title
        } else {
            "window-\(windowId)"
        }

        return try [
            self.savedFile(
                from: observation,
                preferredName: preferredName,
                windowIndex: nil
            ),
        ]
    }

    private func captureScreens() async throws -> [SavedFile] {
        if let index = self.screenIndex {
            let observation = try await self.captureObservation(
                target: .screen(index: index),
                preferredName: "screen\(index)",
                index: nil
            )
            return try [
                self.savedFile(
                    from: observation,
                    preferredName: "screen\(index)",
                    windowIndex: nil
                ),
            ]
        }

        let screens = self.services.screens.listScreens()
        let indexes = screens.isEmpty ? [0] : Array(screens.indices)

        var savedFiles: [SavedFile] = []
        for (ordinal, displayIndex) in indexes.indexed() {
            let observation = try await self.captureObservation(
                target: .screen(index: displayIndex),
                preferredName: "screen\(displayIndex)",
                index: ordinal
            )
            try savedFiles.append(self.savedFile(
                from: observation,
                preferredName: "screen\(displayIndex)",
                windowIndex: nil
            ))
        }

        return savedFiles
    }

    private func captureApplicationWindow(_ identifier: String) async throws -> [SavedFile] {
        try await self.focusIfNeeded(appIdentifier: identifier)
        let observation = try await self.captureObservation(
            target: .app(identifier: identifier, window: self.observationWindowSelection),
            preferredName: identifier,
            index: nil
        )
        let resolvedWindow = observation.target.window
        let resolvedTitle = resolvedWindow?.title.trimmingCharacters(in: .whitespacesAndNewlines)

        let saved = try self.savedFile(
            from: observation,
            preferredName: self.windowTitle ?? (resolvedTitle?.isEmpty == false ? resolvedTitle : nil) ?? identifier,
            windowIndex: resolvedWindow?.index
        )

        return [saved]
    }

    private func captureAllApplicationWindows(_ identifier: String) async throws -> [SavedFile] {
        try await self.focusIfNeeded(appIdentifier: identifier)

        let windows = try await WindowServiceBridge.listWindows(
            windows: self.services.windows,
            target: .application(identifier)
        )

        let filtered = ObservationTargetResolver.captureCandidates(from: windows)

        guard !filtered.isEmpty else {
            throw PeekabooError.windowNotFound(criteria: "No shareable windows for \(identifier)")
        }

        var savedFiles: [SavedFile] = []
        for (ordinal, window) in filtered.indexed() {
            let observation = try await self.captureObservation(
                target: .windowID(CGWindowID(window.windowID)),
                preferredName: window.title,
                index: ordinal
            )

            let saved = try self.savedFile(
                from: observation,
                preferredName: window.title,
                windowIndex: window.index
            )
            savedFiles.append(saved)
        }

        return savedFiles
    }

    private func captureFrontmost() async throws -> [SavedFile] {
        let observation = try await self.captureObservation(
            target: .frontmost,
            preferredName: "frontmost",
            index: nil
        )
        return try [
            self.savedFile(
                from: observation,
                preferredName: "frontmost",
                windowIndex: nil
            ),
        ]
    }

    private func captureMenuBar() async throws -> [SavedFile] {
        let observation = try await self.captureObservation(
            target: .menubar,
            preferredName: "menubar",
            index: nil
        )
        return try [
            self.savedFile(
                from: observation,
                preferredName: "menubar",
                windowIndex: nil
            ),
        ]
    }

    private func analyzeImage(at path: String, with prompt: String) async throws -> ImageAnalysisData {
        let aiService = PeekabooAIService()
        let response = try await aiService.analyzeImageFileDetailed(at: path, question: prompt, model: nil)
        return ImageAnalysisData(provider: response.provider, model: response.model, text: response.text)
    }

    private func captureObservation(
        target: DesktopObservationTargetRequest,
        preferredName: String?,
        index: Int?
    ) async throws -> DesktopObservationResult {
        let url = self.makeOutputURL(preferredName: preferredName, index: index)

        return try await self.services.desktopObservation.observe(DesktopObservationRequest(
            target: target,
            capture: self.observationCaptureOptions,
            detection: DesktopDetectionOptions(mode: .none),
            output: DesktopObservationOutputOptions(
                path: url.path,
                format: self.format,
                saveRawScreenshot: true
            )
        ))
    }

    private func savedFile(
        from observation: DesktopObservationResult,
        preferredName: String?,
        windowIndex: Int?
    ) throws -> SavedFile {
        guard let path = observation.files.rawScreenshotPath else {
            throw CaptureError.captureFailure("Observation completed without a saved screenshot path")
        }

        let windowInfo = observation.capture.metadata.windowInfo
        return SavedFile(
            path: path,
            item_label: preferredName ?? windowInfo?.title,
            window_title: windowInfo?.title,
            window_id: windowInfo.map { UInt32($0.windowID) },
            window_index: windowIndex ?? windowInfo?.index,
            mime_type: self.format.mimeType
        )
    }

    private func makeOutputURL(preferredName: String?, index: Int?) -> URL {
        if let explicit = self.path {
            let expanded = (explicit as NSString).expandingTildeInPath
            var url = URL(fileURLWithPath: expanded)
            let directory = url.deletingLastPathComponent()
            var stem = url.deletingPathExtension().lastPathComponent
            var ext = url.pathExtension

            if ext.isEmpty {
                ext = self.format.fileExtension
            }

            if let index, index > 0 {
                stem += "_\(index)"
            }

            url = directory.appendingPathComponent(stem).appendingPathExtension(ext)
            return url
        }

        let timestamp = Self.filenameDateFormatter.string(from: Date())
        var components: [String] = []
        if let preferred = preferredName {
            components.append(self.sanitizeFilenameComponent(preferred))
        } else if let appName = self.app {
            components.append(self.sanitizeFilenameComponent(appName))
        } else if let mode = self.mode {
            components.append(mode.rawValue)
        } else {
            components.append("capture")
        }
        components.append(timestamp)
        if let index, index > 0 {
            components.append(String(index))
        }

        let filename = components.joined(separator: "_") + ".\(self.format.fileExtension)"
        let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return base.appendingPathComponent(filename)
    }

    private func describeSavedFile(_ file: SavedFile) -> String {
        var segments: [String] = []
        if let label = file.item_label ?? file.window_title {
            segments.append(label)
        } else if let index = file.window_index {
            segments.append("window \(index)")
        }
        segments.append("→ \(file.path)")
        return segments.joined(separator: " ")
    }

    private func sanitizeFilenameComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private func focusIfNeeded(appIdentifier: String) async throws {
        switch self.captureFocus {
        case .background:
            return
        case .auto:
            if self.windowTitle == nil, await self.isAlreadyFrontmost(appIdentifier: appIdentifier) {
                return
            }
            let focusIdentifier = await self.resolveFocusIdentifier(appIdentifier: appIdentifier)
            let options = FocusOptions(autoFocus: true, spaceSwitch: false, bringToCurrentSpace: false)
            try await ensureFocused(
                applicationName: focusIdentifier,
                windowTitle: self.windowTitle,
                options: options,
                services: self.services
            )
        case .foreground:
            let focusIdentifier = await self.resolveFocusIdentifier(appIdentifier: appIdentifier)
            let options = FocusOptions(autoFocus: true, spaceSwitch: true, bringToCurrentSpace: true)
            try await ensureFocused(
                applicationName: focusIdentifier,
                windowTitle: self.windowTitle,
                options: options,
                services: self.services
            )
        }
    }

    private func isAlreadyFrontmost(appIdentifier: String) async -> Bool {
        guard let frontmost = try? await self.services.applications.getFrontmostApplication(),
              let target = try? await self.services.applications.findApplication(identifier: appIdentifier)
        else {
            return false
        }

        return frontmost.processIdentifier == target.processIdentifier
    }

    private func resolveFocusIdentifier(appIdentifier: String) async -> String {
        guard let app = try? await self.services.applications.findApplication(identifier: appIdentifier) else {
            return appIdentifier
        }
        return "PID:\(app.processIdentifier)"
    }

    private var observationWindowSelection: WindowSelection {
        if let windowIndex {
            return .index(windowIndex)
        }
        if let windowTitle {
            return .title(windowTitle)
        }
        return .automatic
    }

    private static let filenameDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

// MARK: - Format Helpers

extension ImageFormat {
    fileprivate var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpg: "jpg"
        }
    }

    fileprivate var mimeType: String {
        switch self {
        case .png: "image/png"
        case .jpg: "image/jpeg"
        }
    }
}

@MainActor
extension ImageCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "image",
                abstract: "Capture screenshots",
                version: "1.0.0"
            )
        }
    }
}

extension ImageCommand: AsyncRuntimeCommand {}

@MainActor
extension ImageCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = values.singleOption("app")
        self.pid = try values.decodeOption("pid", as: Int32.self)
        self.path = values.singleOption("path")
        if let parsedMode: CaptureMode = try values.decodeOptionEnum("mode") {
            self.mode = parsedMode
        }
        self.windowTitle = values.singleOption("windowTitle")
        self.windowIndex = try values.decodeOption("windowIndex", as: Int.self)
        self.windowId = try values.decodeOption("windowId", as: Int.self)
        self.screenIndex = try values.decodeOption("screenIndex", as: Int.self)
        let parsedFormat: ImageFormat? = try values.decodeOptionEnum("format")
        if let parsedFormat {
            self.format = parsedFormat
        }
        if let path = self.path?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            let expanded = (path as NSString).expandingTildeInPath
            let ext = URL(fileURLWithPath: expanded).pathExtension.lowercased()
            let inferred: ImageFormat? = if ext == "jpg" || ext == "jpeg" {
                .jpg
            } else if ext == "png" {
                .png
            } else {
                nil
            }
            if let parsedFormat, let inferred, parsedFormat != inferred {
                throw CommanderBindingError.invalidArgument(
                    label: "path",
                    value: path,
                    reason: "Conflicts with --format \(parsedFormat.rawValue). " +
                        "Use a .\(parsedFormat.fileExtension) path (or omit --format)."
                )
            }
            if parsedFormat == nil, let inferred {
                self.format = inferred
            }
        }
        if let parsedFocus: CaptureFocus = try values.decodeOptionEnum("captureFocus") {
            self.captureFocus = parsedFocus
        }
        self.analyze = values.singleOption("analyze")
        self.retina = values.flag("retina")
    }
}
