import Algorithms
import AppKit
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation
import UniformTypeIdentifiers

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
            try await requireScreenRecordingPermission(services: self.services)
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
        let result = try await ImageCaptureBridge.captureWindowById(
            services: self.services,
            windowId: windowId,
            scale: self.captureScale
        )

        let title = result.metadata.windowInfo?.title
        let preferredName = if let title, !title.isEmpty {
            title
        } else {
            "window-\(windowId)"
        }

        let saved = try self.saveCaptureResult(result, preferredName: preferredName, index: nil)
        return [saved]
    }

    private func captureScreens() async throws -> [SavedFile] {
        if let index = self.screenIndex {
            let result = try await ImageCaptureBridge.captureScreen(
                services: self.services,
                displayIndex: index,
                scale: self.captureScale
            )
            let saved = try self.saveCaptureResult(result, preferredName: "screen\(index)", index: nil)
            return [saved]
        }

        let screens = self.services.screens.listScreens()
        let indexes = screens.isEmpty ? [0] : Array(screens.indices)

        var savedFiles: [SavedFile] = []
        for (ordinal, displayIndex) in indexes.indexed() {
            let result = try await ImageCaptureBridge.captureScreen(
                services: self.services,
                displayIndex: displayIndex,
                scale: self.captureScale
            )
            let saved = try self.saveCaptureResult(result, preferredName: "screen\(displayIndex)", index: ordinal)
            savedFiles.append(saved)
        }

        return savedFiles
    }

    private func captureApplicationWindow(_ identifier: String) async throws -> [SavedFile] {
        try await self.focusIfNeeded(appIdentifier: identifier)
        let resolvedWindow = try await self.resolveWindow(for: identifier)
        let result = if let resolvedWindow {
            try await ImageCaptureBridge.captureWindowById(
                services: self.services,
                windowId: resolvedWindow.windowID,
                scale: self.captureScale
            )
        } else {
            try await ImageCaptureBridge.captureWindow(
                services: self.services,
                appIdentifier: identifier,
                windowIndex: nil,
                scale: self.captureScale
            )
        }

        let saved = try self.saveCaptureResult(
            result,
            preferredName: self.windowTitle ?? identifier,
            index: nil,
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

        let filtered = self.filterRenderableWindows(windows, appIdentifier: identifier)

        guard !filtered.isEmpty else {
            throw PeekabooError.windowNotFound(criteria: "No shareable windows for \(identifier)")
        }

        var savedFiles: [SavedFile] = []
        for (ordinal, window) in filtered.indexed() {
            let result = try await ImageCaptureBridge.captureWindowById(
                services: self.services,
                windowId: window.windowID,
                scale: self.captureScale
            )

            let saved = try self.saveCaptureResult(
                result,
                preferredName: window.title,
                index: ordinal,
                windowIndex: window.index
            )
            savedFiles.append(saved)
        }

        return savedFiles
    }

    private func captureFrontmost() async throws -> [SavedFile] {
        let result = try await ImageCaptureBridge.captureFrontmost(
            services: self.services,
            scale: self.captureScale
        )
        let saved = try self.saveCaptureResult(result, preferredName: "frontmost", index: nil)
        return [saved]
    }

    private func captureMenuBar() async throws -> [SavedFile] {
        guard let screen = self.services.screens.primaryScreen else {
            throw CaptureError.captureFailure("Unable to determine main screen for menu bar capture")
        }

        let calculatedHeight = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        let menuBarHeight: CGFloat = calculatedHeight > 0 ? calculatedHeight : 24
        let originY = screen.frame.maxY - menuBarHeight
        let rect = CGRect(x: screen.frame.minX, y: originY, width: screen.frame.width, height: menuBarHeight)

        let result = try await ImageCaptureBridge.captureArea(
            services: self.services,
            rect: rect,
            scale: self.captureScale
        )
        let saved = try self.saveCaptureResult(result, preferredName: "menubar", index: nil)
        return [saved]
    }

    private func analyzeImage(at path: String, with prompt: String) async throws -> ImageAnalysisData {
        let aiService = PeekabooAIService()
        let response = try await aiService.analyzeImageFileDetailed(at: path, question: prompt, model: nil)
        return ImageAnalysisData(provider: response.provider, model: response.model, text: response.text)
    }

    private func saveCaptureResult(
        _ result: CaptureResult,
        preferredName: String?,
        index: Int?,
        windowIndex: Int? = nil
    ) throws -> SavedFile {
        let url = self.makeOutputURL(preferredName: preferredName, index: index)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let data = try self.encodeImageData(result.imageData)
        try data.write(to: url, options: .atomic)

        let windowInfo = result.metadata.windowInfo

        return SavedFile(
            path: url.path,
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

    private func encodeImageData(_ data: Data) throws -> Data {
        switch self.format {
        case .png:
            return data
        case .jpg:
            guard let image = NSImage(data: data),
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
            else {
                throw CaptureError.captureFailure("Failed to convert screenshot to JPEG")
            }
            return jpeg
        }
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
            if self.windowTitle == nil, Self.isAlreadyFrontmost(appIdentifier: appIdentifier) {
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

    private static func isAlreadyFrontmost(appIdentifier: String) -> Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let target = fastRunningApplication(for: appIdentifier)
        else {
            return false
        }

        return frontmost.processIdentifier == target.processIdentifier
    }

    private func resolveFocusIdentifier(appIdentifier: String) async -> String {
        guard let app = Self.fastRunningApplication(for: appIdentifier) else {
            return appIdentifier
        }
        return "PID:\(app.processIdentifier)"
    }

    private static func fastRunningApplication(for identifier: String) -> NSRunningApplication? {
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let runningApps = NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }

        if let pid = Self.parsePID(trimmedIdentifier) {
            return runningApps.first { $0.processIdentifier == pid }
        }

        if let bundleMatch = runningApps.first(where: { $0.bundleIdentifier == trimmedIdentifier }) {
            return bundleMatch
        }

        if let exactName = runningApps.first(where: {
            guard let name = $0.localizedName else { return false }
            return name.compare(trimmedIdentifier, options: .caseInsensitive) == .orderedSame
        }) {
            return exactName
        }

        return runningApps.compactMap { app -> (app: NSRunningApplication, score: Int)? in
            guard app.activationPolicy != .prohibited,
                  let name = app.localizedName,
                  name.localizedCaseInsensitiveContains(trimmedIdentifier)
            else { return nil }

            var score = 0
            if name.lowercased().hasPrefix(trimmedIdentifier.lowercased()) {
                score += 100
            }
            if app.activationPolicy == .regular {
                score += 50
            }
            score -= name.count
            return (app, score)
        }
        .max(by: { $0.score < $1.score })?
        .app
    }

    private static func parsePID(_ identifier: String) -> Int32? {
        guard identifier.uppercased().hasPrefix("PID:") else { return nil }
        return Int32(identifier.dropFirst(4))
    }

    private func resolveWindow(for identifier: String) async throws -> ServiceWindowInfo? {
        // `try?` is intentional: an explicit title/index miss on the CG-only list should fall back
        // to the existing AX-enriched path so users keep the detailed selector error behavior.
        if let fastWindows = Self.fastCGWindows(for: identifier),
           let fastWindow = try? self.selectWindow(from: fastWindows, appIdentifier: identifier) {
            return fastWindow
        }

        do {
            let windows = try await WindowServiceBridge.listWindows(
                windows: self.services.windows,
                target: .application(identifier)
            )

            guard !windows.isEmpty else {
                return nil
            }

            return try self.selectWindow(from: windows, appIdentifier: identifier)
        } catch let error as PeekabooError {
            switch error {
            case .permissionDeniedAccessibility:
                self.logger.debug(
                    "Window enumeration unavailable; falling back to capture heuristics",
                    metadata: ["reason": error.localizedDescription]
                )
                return nil
            default:
                throw error
            }
        } catch {
            self.logger.debug(
                "Window enumeration failed; falling back to capture heuristics",
                metadata: ["reason": error.localizedDescription]
            )
            return nil
        }
    }

    private static func fastCGWindows(for appIdentifier: String) -> [ServiceWindowInfo]? {
        guard let app = self.fastRunningApplication(for: appIdentifier),
              let windowList = CGWindowListCopyWindowInfo(
                  [.optionAll, .excludeDesktopElements],
                  kCGNullWindowID
              ) as? [[String: Any]]
        else {
            return nil
        }

        var index = 0
        let windows = windowList.compactMap { windowInfo -> ServiceWindowInfo? in
            guard self.pidValue(windowInfo[kCGWindowOwnerPID as String]) == app.processIdentifier,
                  let windowID = self.intValue(windowInfo[kCGWindowNumber as String]),
                  let bounds = self.bounds(from: windowInfo[kCGWindowBounds as String])
            else {
                return nil
            }

            defer { index += 1 }

            let layer = self.intValue(windowInfo[kCGWindowLayer as String]) ?? 0
            let alpha = self.cgFloatValue(windowInfo[kCGWindowAlpha as String]) ?? 1.0
            let isOnScreen = self.boolValue(windowInfo[kCGWindowIsOnscreen as String]) ?? true
            let sharingState = self.intValue(windowInfo[kCGWindowSharingState as String])
                .flatMap(WindowSharingState.init(rawValue:))
            let title = windowInfo[kCGWindowName as String] as? String ?? ""

            // Screenshot selection only needs CG window ids and geometry. Avoid the full window service here:
            // it may enrich untitled helper windows through AX, which is expensive for Electron/Tauri apps.
            return ServiceWindowInfo(
                windowID: windowID,
                title: title,
                bounds: bounds,
                isMinimized: bounds.origin.x < -10000 || bounds.origin.y < -10000,
                isMainWindow: index == 0,
                windowLevel: layer,
                alpha: alpha,
                index: index,
                layer: layer,
                isOnScreen: isOnScreen,
                sharingState: sharingState
            )
        }

        return windows.isEmpty ? nil : windows
    }

    private static func bounds(from value: Any?) -> CGRect? {
        // CoreGraphics window dictionaries are CF-backed; accepting NSNumber plus native Swift
        // numeric bridges keeps this fast path resilient across OS releases.
        guard let dictionary = value as? [String: Any],
              let x = self.cgFloatValue(dictionary["X"]),
              let y = self.cgFloatValue(dictionary["Y"]),
              let width = self.cgFloatValue(dictionary["Width"]),
              let height = self.cgFloatValue(dictionary["Height"])
        else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func pidValue(_ value: Any?) -> pid_t? {
        self.intValue(value).map(pid_t.init)
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        return (value as? NSNumber)?.intValue
    }

    private static func cgFloatValue(_ value: Any?) -> CGFloat? {
        if let cgFloat = value as? CGFloat {
            return cgFloat
        }
        if let double = value as? Double {
            return CGFloat(double)
        }
        return (value as? NSNumber).map { CGFloat($0.doubleValue) }
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        return (value as? NSNumber)?.boolValue
    }

    private func selectWindow(from windows: [ServiceWindowInfo], appIdentifier: String) throws -> ServiceWindowInfo? {
        if let explicitIndex = self.windowIndex {
            guard let explicitWindow = windows.first(where: { $0.index == explicitIndex }) else {
                throw PeekabooError.windowNotFound(criteria: "No window at index \(explicitIndex)")
            }
            guard WindowFiltering.isRenderable(explicitWindow) else {
                throw PeekabooError.windowNotFound(criteria: "Window \(explicitIndex) is not shareable")
            }
            return explicitWindow
        }

        let filtered = self.filterRenderableWindows(windows, appIdentifier: appIdentifier)

        guard !filtered.isEmpty else {
            throw PeekabooError.windowNotFound(criteria: "No shareable windows for \(appIdentifier)")
        }

        if let title = self.windowTitle {
            guard let match = filtered.first(where: { window in
                window.title.localizedCaseInsensitiveContains(title)
            }) else {
                throw PeekabooError.windowNotFound(
                    criteria: "title containing '\(title)' in \(appIdentifier)"
                )
            }
            return match
        }

        if let preferred = Self.preferredWindow(from: filtered) {
            return preferred
        }

        return filtered.first
    }

    private func filterRenderableWindows(
        _ windows: [ServiceWindowInfo],
        appIdentifier: String
    ) -> [ServiceWindowInfo] {
        WindowFilterHelper.filter(
            windows: windows,
            appIdentifier: appIdentifier,
            mode: .capture,
            logger: self.logger
        )
    }

    static func preferredWindow(from windows: [ServiceWindowInfo]) -> ServiceWindowInfo? {
        guard !windows.isEmpty else {
            return nil
        }

        let visibleWindows = windows.filter { window in
            window.alpha > 0.05 && !window.isMinimized && !window.isOffScreen
        }

        if let ranked = visibleWindows.min(by: Self.compareWindows) {
            return ranked
        }

        return windows.min { $0.index < $1.index }
    }

    private static func compareWindows(_ lhs: ServiceWindowInfo, _ rhs: ServiceWindowInfo) -> Bool {
        let lhsScore = Self.windowScore(lhs)
        let rhsScore = Self.windowScore(rhs)
        if lhsScore == rhsScore {
            return lhs.index < rhs.index
        }
        return lhsScore > rhsScore
    }

    private static func windowScore(_ window: ServiceWindowInfo) -> Double {
        var score = 0.0

        if window.isMainWindow {
            score += 2000
        }

        if window.windowLevel == 0 {
            score += 500
        }

        if window.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score -= 500
        } else {
            score += 2500
        }

        if !window.isMinimized {
            score += 300
        }

        let area = window.bounds.width * window.bounds.height
        if area > .zero {
            score += min(Double(area) / 150.0, 4000)
        }

        score += max(0, 600 - Double(window.index) * 40)

        let minimumWidth: CGFloat = 200
        let minimumHeight: CGFloat = 150
        if window.bounds.width < minimumWidth || window.bounds.height < minimumHeight {
            score -= 400
        }

        return score
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

// MARK: - Capture Bridge

private enum ImageCaptureBridge {
    static func captureScreen(
        services: any PeekabooServiceProviding,
        displayIndex: Int?,
        scale: CaptureScalePreference
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureScreen(
                displayIndex: displayIndex,
                visualizerMode: .screenshotFlash,
                scale: scale
            )
        }.value
    }

    static func captureWindow(
        services: any PeekabooServiceProviding,
        appIdentifier: String,
        windowIndex: Int?,
        scale: CaptureScalePreference
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureWindow(
                appIdentifier: appIdentifier,
                windowIndex: windowIndex,
                visualizerMode: .screenshotFlash,
                scale: scale
            )
        }.value
    }

    static func captureWindowById(
        services: any PeekabooServiceProviding,
        windowId: Int,
        scale: CaptureScalePreference
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureWindow(
                windowID: CGWindowID(windowId),
                visualizerMode: .screenshotFlash,
                scale: scale
            )
        }.value
    }

    static func captureFrontmost(
        services: any PeekabooServiceProviding,
        scale: CaptureScalePreference
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureFrontmost(
                visualizerMode: .screenshotFlash,
                scale: scale
            )
        }.value
    }

    static func captureArea(
        services: any PeekabooServiceProviding,
        rect: CGRect,
        scale: CaptureScalePreference
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureArea(
                rect,
                visualizerMode: .screenshotFlash,
                scale: scale
            )
        }.value
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
