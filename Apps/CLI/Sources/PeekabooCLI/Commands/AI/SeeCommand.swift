import Algorithms
import AppKit
import AXorcist
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation
import ScreenCaptureKit

private enum ScreenCaptureBridge {
    static func captureFrontmost(services: any PeekabooServiceProviding) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureFrontmost()
        }.value
    }

    static func captureWindow(
        services: any PeekabooServiceProviding,
        appIdentifier: String,
        windowIndex: Int?
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureWindow(appIdentifier: appIdentifier, windowIndex: windowIndex)
        }.value
    }

    static func captureWindowById(
        services: any PeekabooServiceProviding,
        windowId: Int
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureWindow(windowID: CGWindowID(windowId))
        }.value
    }

    static func captureArea(services: any PeekabooServiceProviding, rect: CGRect) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureArea(rect)
        }.value
    }

    static func captureScreen(
        services: any PeekabooServiceProviding,
        displayIndex: Int?
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureScreen(displayIndex: displayIndex)
        }.value
    }
}

/// Capture a screenshot and build an interactive UI map
@available(macOS 14.0, *)
struct SeeCommand: ApplicationResolvable, ErrorHandlingCommand, RuntimeOptionsConfigurable {
    @Option(help: "Application name to capture, or special values: 'menubar', 'frontmost'")
    var app: String?

    @Option(name: .long, help: "Target application by process ID")
    var pid: Int32?

    @Option(help: "Specific window title to capture")
    var windowTitle: String?

    @Option(
        name: .long,
        help: "Target window by CoreGraphics window id (window_id from `peekaboo window list --json`)"
    )
    var windowId: Int?

    @Option(help: "Capture mode (screen, window, frontmost)")
    var mode: PeekabooCore.CaptureMode?

    @Option(
        names: [.automatic, .customLong("save"), .customLong("output"), .customShort("o", allowingJoined: false)],
        help: "Output path for screenshot (aliases: --save, --output, -o)"
    )
    var path: String?

    @Option(
        name: .long,
        help: "Specific screen index to capture (0-based). If not specified, captures all screens when in screen mode"
    )
    var screenIndex: Int?

    @Flag(help: "Generate annotated screenshot with interaction markers")
    var annotate = false

    @Flag(name: .long, help: "Capture menu bar popovers via window list + OCR")
    var menubar = false

    @Option(help: "Analyze captured content with AI")
    var analyze: String?

    @Option(
        name: .long,
        help: """
        Overall timeout in seconds (default: 20, or 60 when --analyze is set).
        Increase this if element detection regularly times out for large/complex windows.
        """
    )
    var timeoutSeconds: Int?

    @Option(
        name: .long,
        help: """
        Capture engine: auto|modern|sckit|classic|cg (default: auto).
        modern/sckit force ScreenCaptureKit; classic/cg force CGWindowList;
        auto tries SC then falls back when allowed.
        """
    )
    var captureEngine: String?

    @Flag(help: "Skip web-content focus fallback when no text fields are detected")
    var noWebFocus = false
    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }
    var verbose: Bool { self.runtime?.configuration.verbose ?? self.runtimeOptions.verbose }

    private var logger: Logger { self.resolvedRuntime.logger }
    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    var outputLogger: Logger { self.logger }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let startTime = Date()
        let logger = self.logger
        let overallTimeout = TimeInterval(self.timeoutSeconds ?? ((self.analyze == nil) ? 20 : 60))

        logger.operationStart("see_command", metadata: [
            "app": self.app ?? "none",
            "mode": self.mode?.rawValue ?? "auto",
            "annotate": self.annotate,
            "menubar": self.menubar,
            "hasAnalyzePrompt": self.analyze != nil,
        ])

        let commandCopy = self

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await commandCopy.runImpl(startTime: startTime, logger: logger)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(overallTimeout * 1_000_000_000))
                    throw CaptureError.detectionTimedOut(overallTimeout)
                }

                do {
                    _ = try await group.next()
                    group.cancelAll()
                } catch {
                    group.cancelAll()
                    throw error
                }
            }
        } catch {
            logger.operationComplete(
                "see_command",
                success: false,
                metadata: [
                    "error": error.localizedDescription,
                ]
            )
            throw error
        }
    }

    private func runImpl(startTime: Date, logger: Logger) async throws {
        do {
            // Check permissions
            logger.verbose("Checking screen recording permissions", category: "Permissions")
            try await requireScreenRecordingPermission(services: self.services)
            logger.verbose("Screen recording permission granted", category: "Permissions")

            // Perform capture and element detection
            logger.verbose("Starting capture and detection phase", category: "Capture")
            let captureResult = try await performCaptureWithDetection()
            logger.verbose("Capture completed successfully", category: "Capture", metadata: [
                "snapshotId": captureResult.snapshotId,
                "elementCount": captureResult.elements.all.count,
                "screenshotSize": self.getFileSize(captureResult.screenshotPath) ?? 0,
            ])

            // Generate annotated screenshot if requested
            var annotatedPath: String?
            if self.annotate {
                logger.operationStart("generate_annotations")
                annotatedPath = try await self.generateAnnotatedScreenshot(
                    snapshotId: captureResult.snapshotId,
                    originalPath: captureResult.screenshotPath
                )
                if let annotatedPath,
                   annotatedPath != captureResult.screenshotPath {
                    try await self.services.snapshots.storeAnnotatedScreenshot(
                        snapshotId: captureResult.snapshotId,
                        annotatedScreenshotPath: annotatedPath
                    )
                }
                logger.operationComplete("generate_annotations", metadata: [
                    "annotatedPath": annotatedPath ?? "none",
                ])
            }

            // Perform AI analysis if requested
            var analysisResult: SeeAnalysisData?
            if let prompt = analyze {
                // Pre-analysis diagnostics
                let fileSize = (try? FileManager.default
                    .attributesOfItem(atPath: captureResult.screenshotPath)[.size] as? Int) ?? 0
                logger.verbose(
                    "Starting AI analysis",
                    category: "AI",
                    metadata: [
                        "imagePath": captureResult.screenshotPath,
                        "imageSizeBytes": fileSize,
                        "promptLength": prompt.count
                    ]
                )
                logger.operationStart("ai_analysis", metadata: ["promptPreview": String(prompt.prefix(80))])
                logger.startTimer("ai_generate")
                analysisResult = try await self.performAnalysisDetailed(
                    imagePath: captureResult.screenshotPath,
                    prompt: prompt
                )
                logger.stopTimer("ai_generate")
                logger.operationComplete(
                    "ai_analysis",
                    success: analysisResult != nil,
                    metadata: [
                        "provider": analysisResult?.provider ?? "unknown",
                        "model": analysisResult?.model ?? "unknown"
                    ]
                )
            }

            // Output results
            let executionTime = Date().timeIntervalSince(startTime)
            logger.operationComplete("see_command", metadata: [
                "executionTimeMs": Int(executionTime * 1000),
                "success": true,
            ])

            let context = SeeCommandRenderContext(
                snapshotId: captureResult.snapshotId,
                screenshotPath: captureResult.screenshotPath,
                annotatedPath: annotatedPath,
                metadata: captureResult.metadata,
                elements: captureResult.elements,
                analysis: analysisResult,
                executionTime: executionTime
            )
            await self.renderResults(context: context)

        } catch {
            logger.operationComplete("see_command", success: false, metadata: [
                "error": error.localizedDescription,
            ])
            self.handleError(error) // Use protocol's error handling
            throw ExitCode.failure
        }
    }

    private func getFileSize(_ path: String) -> Int? {
        try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int
    }

    private func renderResults(context: SeeCommandRenderContext) async {
        if self.jsonOutput {
            await self.outputJSONResults(context: context)
        } else {
            await self.outputTextResults(context: context)
        }
    }

    private func performCaptureWithDetection() async throws -> CaptureAndDetectionResult {
        let captureContext = try await self.resolveCaptureContext()
        let captureResult = captureContext.captureResult

        // Save screenshot
        self.logger.startTimer("file_write")
        let outputPath = try saveScreenshot(captureResult.imageData)
        self.logger.stopTimer("file_write")

        // Create window context from capture metadata
        let windowContext = WindowContext(
            applicationName: captureResult.metadata.applicationInfo?.name,
            applicationBundleId: captureResult.metadata.applicationInfo?.bundleIdentifier,
            applicationProcessId: captureResult.metadata.applicationInfo?.processIdentifier,
            windowTitle: captureResult.metadata.windowInfo?.title,
            windowID: captureContext.windowIdOverride ?? captureResult.metadata.windowInfo?.windowID,
            windowBounds: captureContext.captureBounds ?? captureResult.metadata.windowInfo?.bounds,
            shouldFocusWebContent: self.noWebFocus ? false : true
        )

        let detectionStart = Date()
        let detectionResult: ElementDetectionResult
        if captureContext.prefersOCR {
            self.logger.verbose("Running OCR for menu bar popover", category: "Capture")
            let ocrElements = try self.ocrElements(
                imageData: captureResult.imageData,
                windowBounds: captureContext.captureBounds ?? captureResult.metadata.windowInfo?.bounds
            )

            let warnings = ocrElements.isEmpty ? ["OCR produced no elements"] : []
            let metadata = DetectionMetadata(
                detectionTime: Date().timeIntervalSince(detectionStart),
                elementCount: ocrElements.count,
                method: captureContext.ocrMethod ?? "OCR",
                warnings: warnings,
                windowContext: windowContext,
                isDialog: false
            )
            detectionResult = ElementDetectionResult(
                snapshotId: UUID().uuidString,
                screenshotPath: "",
                elements: DetectedElements(other: ocrElements),
                metadata: metadata
            )
        } else {
            detectionResult = try await self.detectElements(
                imageData: captureResult.imageData,
                windowContext: windowContext
            )
        }

        // Update the result with the correct screenshot path
        let resultWithPath = ElementDetectionResult(
            snapshotId: detectionResult.snapshotId,
            screenshotPath: outputPath,
            elements: detectionResult.elements,
            metadata: detectionResult.metadata
        )

        try await self.services.snapshots.storeScreenshot(
            snapshotId: detectionResult.snapshotId,
            screenshotPath: outputPath,
            applicationBundleId: captureResult.metadata.applicationInfo?.bundleIdentifier,
            applicationProcessId: captureResult.metadata.applicationInfo.map { Int32($0.processIdentifier) },
            applicationName: windowContext.applicationName,
            windowTitle: windowContext.windowTitle,
            windowBounds: windowContext.windowBounds
        )

        // Store the result in snapshot
        try await self.services.snapshots.storeDetectionResult(
            snapshotId: detectionResult.snapshotId,
            result: resultWithPath
        )

        return CaptureAndDetectionResult(
            snapshotId: detectionResult.snapshotId,
            screenshotPath: outputPath,
            elements: detectionResult.elements,
            metadata: detectionResult.metadata
        )
    }

    private func detectElements(
        imageData: Data,
        windowContext: WindowContext?
    ) async throws -> ElementDetectionResult {
        self.logger.operationStart("element_detection")
        defer { self.logger.operationComplete("element_detection") }

        do {
            return try await Self.withWallClockTimeout(seconds: 20.0) {
                try await AutomationServiceBridge.detectElements(
                    automation: self.services.automation,
                    imageData: imageData,
                    snapshotId: nil,
                    windowContext: windowContext
                )
            }
        } catch is TimeoutError {
            throw CaptureError.detectionTimedOut(20.0)
        }
    }

    private func resolveCaptureContext() async throws -> CaptureContext {
        if self.menubar {
            if let popover = try await self.captureMenuBarPopover() {
                return CaptureContext(
                    captureResult: popover.captureResult,
                    captureBounds: popover.windowBounds,
                    prefersOCR: true,
                    ocrMethod: "OCR",
                    windowIdOverride: popover.windowId
                )
            }

            if let appHint = self.menuBarAppHint() {
                self.logger.verbose("Attempting to open menu extra for capture", category: "Capture", metadata: [
                    "app": appHint
                ])
                let clickResult = try? await MenuServiceBridge.clickMenuBarItem(
                    named: appHint,
                    menu: self.services.menu
                )
                try? await Task.sleep(nanoseconds: 350_000_000)
                if let preferredX = clickResult?.location?.x,
                   let quickAreaCapture = try await self.captureMenuBarPopoverByArea(
                       preferredX: preferredX,
                       hint: appHint,
                       ownerHint: appHint
                   ) {
                    return CaptureContext(
                        captureResult: quickAreaCapture.captureResult,
                        captureBounds: quickAreaCapture.windowBounds,
                        prefersOCR: true,
                        ocrMethod: "OCR",
                        windowIdOverride: quickAreaCapture.windowId
                    )
                }
                if let popover = try await self.captureMenuBarPopover(allowAreaFallback: true) {
                    return CaptureContext(
                        captureResult: popover.captureResult,
                        captureBounds: popover.windowBounds,
                        prefersOCR: true,
                        ocrMethod: "OCR",
                        windowIdOverride: popover.windowId
                    )
                }
            }

            self.logger.verbose("No menu bar popover detected; capturing menu bar area", category: "Capture")
            let rect = try self.menuBarRect()
            let result = try await ScreenCaptureBridge.captureArea(services: self.services, rect: rect)
            return CaptureContext(
                captureResult: result,
                captureBounds: rect,
                prefersOCR: true,
                ocrMethod: "OCR",
                windowIdOverride: nil
            )
        }

        if let appName = self.app?.lowercased() {
            switch appName {
            case "menubar":
                self.logger.verbose("Capturing menu bar area", category: "Capture")
                let rect = try self.menuBarRect()
                let result = try await ScreenCaptureBridge.captureArea(services: self.services, rect: rect)
                return CaptureContext(
                    captureResult: result,
                    captureBounds: rect,
                    prefersOCR: false,
                    ocrMethod: nil,
                    windowIdOverride: nil
                )
            case "frontmost":
                self.logger.verbose("Capturing frontmost window (via --app frontmost)", category: "Capture")
                let result = try await ScreenCaptureBridge.captureFrontmost(services: self.services)
                return CaptureContext(
                    captureResult: result,
                    captureBounds: nil,
                    prefersOCR: false,
                    ocrMethod: nil,
                    windowIdOverride: nil
                )
            default:
                let result = try await self.performStandardCapture()
                return CaptureContext(
                    captureResult: result,
                    captureBounds: nil,
                    prefersOCR: false,
                    ocrMethod: nil,
                    windowIdOverride: nil
                )
            }
        }

        let result = try await self.performStandardCapture()
        return CaptureContext(
            captureResult: result,
            captureBounds: nil,
            prefersOCR: false,
            ocrMethod: nil,
            windowIdOverride: nil
        )
    }

    private func performStandardCapture() async throws -> CaptureResult {
        let effectiveMode = self.determineMode()
        self.logger.verbose(
            "Determined capture mode",
            category: "Capture",
            metadata: ["mode": effectiveMode.rawValue]
        )

        self.logger.operationStart("capture_phase", metadata: ["mode": effectiveMode.rawValue])
        switch effectiveMode {
        case .screen:
            // Handle screen capture with multi-screen support
            let result = try await self.performScreenCapture()
            self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
            return result

        case .multi:
            // Commander currently treats multi captures as multi-display screen grabs
            let result = try await self.performScreenCapture()
            self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
            return result

        case .window:
            if let windowId = self.windowId {
                self.logger.verbose("Initiating window capture (by id)", category: "Capture", metadata: [
                    "windowId": windowId,
                ])

                self.logger.startTimer("window_capture")
                let result = try await ScreenCaptureBridge.captureWindowById(
                    services: self.services,
                    windowId: windowId
                )
                self.logger.stopTimer("window_capture")
                self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
                return result
            } else if self.app != nil || self.pid != nil {
                let appIdentifier = try self.resolveApplicationIdentifier()
                self.logger.verbose("Initiating window capture", category: "Capture", metadata: [
                    "app": appIdentifier,
                    "windowTitle": self.windowTitle ?? "any",
                ])

                if let resolvedWindowId = try await self.resolveWindowId(
                    appIdentifier: appIdentifier,
                    titleFragment: self.windowTitle
                ) {
                    self.logger.verbose("Resolved window id for capture", category: "Capture", metadata: [
                        "windowId": resolvedWindowId
                    ])

                    self.logger.startTimer("window_capture")
                    let result = try await ScreenCaptureBridge.captureWindowById(
                        services: self.services,
                        windowId: resolvedWindowId
                    )
                    self.logger.stopTimer("window_capture")
                    self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
                    return result
                }

                let windowIndex = try await self.resolveSeeWindowIndex(
                    appIdentifier: appIdentifier,
                    titleFragment: self.windowTitle
                )

                self.logger.startTimer("window_capture")
                let result = try await ScreenCaptureBridge.captureWindow(
                    services: self.services,
                    appIdentifier: appIdentifier,
                    windowIndex: windowIndex
                )
                self.logger.stopTimer("window_capture")
                self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
                return result
            } else {
                throw ValidationError("Provide --window-id, or --app/--pid for window mode")
            }

        case .frontmost:
            self.logger.verbose("Capturing frontmost window")
            let result = try await ScreenCaptureBridge.captureFrontmost(services: self.services)
            self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
            return result

        case .area:
            throw ValidationError("Area capture mode is not supported for 'see' yet. Use --mode screen or window")
        }
    }

    private func captureMenuBar() async throws -> CaptureResult {
        let rect = try self.menuBarRect()
        return try await ScreenCaptureBridge.captureArea(services: self.services, rect: rect)
    }

    private func captureMenuBarPopover(allowAreaFallback: Bool = false) async throws -> MenuBarPopoverCapture? {
        let extras = try await self.services.menu.listMenuExtras()
        let ownerPidSet = Set(extras.compactMap(\.ownerPID))
        let canFilterByOwnerPid = !ownerPidSet.isEmpty

        let appHint = self.menuBarAppHint()
        let hintExtra = self.resolveMenuExtraHint(appHint: appHint, extras: extras)
        let openExtra = try await self.resolveOpenMenuExtra(from: extras)

        let preferredExtra = appHint != nil ? (hintExtra ?? openExtra) : (openExtra ?? hintExtra)
        let preferredOwnerName = appHint ?? preferredExtra?.ownerName ?? preferredExtra?.title
        let preferredX = preferredExtra?.position.x
        if let openExtra, let openPid = openExtra.ownerPID {
            self.logger.verbose(
                "Detected open menu extra",
                category: "Capture",
                metadata: [
                    "title": openExtra.title,
                    "ownerPID": openPid
                ]
            )
        }

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let filteredWindowList: [[String: Any]] = if canFilterByOwnerPid {
            windowList.filter { info in
                guard let ownerPID = self.ownerPid(from: info) else { return false }
                return ownerPidSet.contains(ownerPID)
            }
        } else {
            windowList
        }

        let preferredOwnerPid = preferredExtra?.ownerPID
        let usedFilteredWindowList = canFilterByOwnerPid &&
            !filteredWindowList.isEmpty &&
            filteredWindowList.count != windowList.count
        var candidatesWindowList = usedFilteredWindowList ? filteredWindowList : windowList
        var candidates = self.menuBarPopoverCandidates(
            windowList: candidatesWindowList,
            ownerPID: preferredOwnerPid
        )

        if candidates.isEmpty, preferredOwnerPid != nil {
            candidates = self.menuBarPopoverCandidates(
                windowList: candidatesWindowList,
                ownerPID: nil
            )
        }

        let shouldRelaxFilter = openExtra != nil || appHint != nil
        if candidates.isEmpty, shouldRelaxFilter, usedFilteredWindowList {
            self.logger.debug("Relaxing menu bar popover filter to full window list")
            candidates = self.menuBarPopoverCandidates(
                windowList: windowList,
                ownerPID: preferredOwnerPid
            )
            if candidates.isEmpty, preferredOwnerPid != nil {
                candidates = self.menuBarPopoverCandidates(
                    windowList: windowList,
                    ownerPID: nil
                )
            }
        }

        if let preferredOwnerName, !preferredOwnerName.isEmpty, usedFilteredWindowList {
            let windowInfoMap = self.windowInfoById(from: candidatesWindowList)
            let normalized = preferredOwnerName.lowercased()
            let ownerMatches = candidates.filter { candidate in
                let ownerName = windowInfoMap[candidate.windowId]?.ownerName?.lowercased() ?? ""
                return ownerName == normalized || ownerName.contains(normalized)
            }
            if ownerMatches.isEmpty {
                candidatesWindowList = windowList
                candidates = self.menuBarPopoverCandidates(
                    windowList: candidatesWindowList,
                    ownerPID: preferredOwnerPid
                )
                if candidates.isEmpty, preferredOwnerPid != nil {
                    candidates = self.menuBarPopoverCandidates(
                        windowList: candidatesWindowList,
                        ownerPID: nil
                    )
                }
            }
        }

        if candidates.isEmpty {
            if let openMenuCapture = try await self.captureMenuBarPopoverFromOpenMenu(
                openExtra: openExtra ?? hintExtra,
                appHint: appHint
            ) {
                return openMenuCapture
            }
            if let preferredX {
                let bandCandidates = self.menuBarPopoverCandidatesByBand(
                    windowList: windowList,
                    preferredX: preferredX
                )
                if !bandCandidates.isEmpty {
                    candidatesWindowList = windowList
                    candidates = bandCandidates
                }
            }
            if candidates.isEmpty {
                return nil
            }
        }

        let hintName = appHint ?? preferredExtra?.title ?? preferredExtra?.ownerName
        let windowInfoMap = self.windowInfoById(from: candidatesWindowList)
        if let hintName, candidates.count > 1 {
            if let ocrCapture = try await self.captureMenuBarPopoverByOCR(
                candidates: candidates,
                windowInfoById: windowInfoMap,
                hint: hintName,
                preferredOwnerName: preferredOwnerName,
                preferredX: preferredX
            ) {
                return ocrCapture
            }
        }

        if openExtra != nil || allowAreaFallback,
           let preferredX,
           let areaCapture = try await self.captureMenuBarPopoverByArea(
               preferredX: preferredX,
               hint: hintName,
               ownerHint: preferredOwnerName
           ) {
            return areaCapture
        }

        var selectionCandidates = candidates
        if let preferredOwnerName, !preferredOwnerName.isEmpty {
            let normalized = preferredOwnerName.lowercased()
            let ownerMatches = candidates.filter { candidate in
                let ownerName = windowInfoMap[candidate.windowId]?.ownerName?.lowercased() ?? ""
                return ownerName == normalized || ownerName.contains(normalized)
            }
            if !ownerMatches.isEmpty {
                selectionCandidates = ownerMatches
            } else if openExtra == nil {
                return nil
            }
        }

        guard let selected = MenuBarPopoverSelector.selectCandidate(
            candidates: selectionCandidates,
            windowInfoById: windowInfoMap,
            preferredOwnerName: nil,
            preferredX: preferredX
        ) else {
            return nil
        }

        if let info = windowInfoMap[selected.windowId] {
            self.logger.verbose(
                "Selected menu bar popover window",
                category: "Capture",
                metadata: [
                    "windowId": selected.windowId,
                    "owner": info.ownerName ?? "unknown",
                    "title": info.title ?? ""
                ]
            )
        }

        let captureResult = try await ScreenCaptureBridge.captureWindowById(
            services: self.services,
            windowId: selected.windowId
        )

        return MenuBarPopoverCapture(
            captureResult: captureResult,
            windowBounds: selected.bounds,
            windowId: selected.windowId
        )
    }

    private func captureMenuBarPopoverByOCR(
        candidates: [MenuBarPopoverCandidate],
        windowInfoById: [Int: MenuBarPopoverWindowInfo],
        hint: String,
        preferredOwnerName: String?,
        preferredX: CGFloat?
    ) async throws -> MenuBarPopoverCapture? {
        let normalized = hint.lowercased()
        let ranked = MenuBarPopoverSelector.rankCandidates(
            candidates: candidates,
            windowInfoById: windowInfoById,
            preferredOwnerName: preferredOwnerName,
            preferredX: preferredX
        )
        for candidate in ranked {
            let captureResult = try await ScreenCaptureBridge.captureWindowById(
                services: self.services,
                windowId: candidate.windowId
            )
            guard let ocr = try? OCRService.recognizeText(in: captureResult.imageData) else { continue }
            let text = ocr.observations.map(\.text).joined(separator: " ").lowercased()
            if text.contains(normalized) {
                self.logger.verbose(
                    "Selected menu bar popover via OCR",
                    category: "Capture",
                    metadata: [
                        "windowId": candidate.windowId,
                        "hint": hint
                    ]
                )
                return MenuBarPopoverCapture(
                    captureResult: captureResult,
                    windowBounds: candidate.bounds,
                    windowId: candidate.windowId
                )
            }
        }
        return nil
    }

    private func captureMenuBarPopoverByArea(
        preferredX: CGFloat,
        hint: String?,
        ownerHint: String?
    ) async throws -> MenuBarPopoverCapture? {
        guard let screen = self.screenForMenuBarX(preferredX) else { return nil }
        let menuBarHeight = self.menuBarHeight(for: screen)
        let maxHeight = max(120, min(700, screen.frame.height - menuBarHeight))
        let width: CGFloat = 420
        let menuBarTop = screen.frame.maxY - menuBarHeight
        var rect = CGRect(
            x: preferredX - (width / 2.0),
            y: menuBarTop - maxHeight,
            width: width,
            height: maxHeight
        )
        rect.origin.x = max(screen.frame.minX, min(rect.origin.x, screen.frame.maxX - rect.width))
        rect.origin.y = max(screen.frame.minY, rect.origin.y)

        let captureResult = try await ScreenCaptureBridge.captureArea(
            services: self.services,
            rect: rect
        )

        if let ocr = try? OCRService.recognizeText(in: captureResult.imageData),
           self.ocrMatchesHints(ocr, hint: hint, ownerHint: ownerHint) {
            self.logger.verbose(
                "Selected menu bar popover via area capture",
                category: "Capture",
                metadata: [
                    "rect": "\(rect)"
                ]
            )
            return MenuBarPopoverCapture(
                captureResult: captureResult,
                windowBounds: rect,
                windowId: nil
            )
        }

        return nil
    }

    private func captureMenuBarPopoverFromOpenMenu(
        openExtra: MenuExtraInfo?,
        appHint: String?
    ) async throws -> MenuBarPopoverCapture? {
        let ownerPID: pid_t? = {
            guard let openExtra else { return nil }
            return self.resolveMenuExtraOwnerPID(openExtra)
        }()
        let titles = [
            openExtra?.title,
            openExtra?.ownerName,
            openExtra?.rawTitle,
            appHint,
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }

        for candidate in titles where !candidate.isEmpty {
            if let frame = try? await self.services.menu.menuExtraOpenMenuFrame(
                title: candidate,
                ownerPID: ownerPID
            ),
                let capture = try await self.captureMenuBarPopoverByFrame(
                    frame,
                    hint: appHint ?? openExtra?.title,
                    ownerHint: openExtra?.ownerName
                ) {
                return capture
            }
        }

        return nil
    }

    private func captureMenuBarPopoverByFrame(
        _ frame: CGRect,
        hint: String?,
        ownerHint: String?
    ) async throws -> MenuBarPopoverCapture? {
        let padded = frame.insetBy(dx: -8, dy: -8)
        guard let clamped = self.clampRectToScreens(padded) else { return nil }

        let captureResult = try await ScreenCaptureBridge.captureArea(
            services: self.services,
            rect: clamped
        )

        if let ocr = try? OCRService.recognizeText(in: captureResult.imageData),
           self.ocrMatchesHints(ocr, hint: hint, ownerHint: ownerHint) {
            self.logger.verbose(
                "Selected menu bar popover via AX menu frame",
                category: "Capture",
                metadata: [
                    "rect": "\(clamped)"
                ]
            )
            return MenuBarPopoverCapture(
                captureResult: captureResult,
                windowBounds: clamped,
                windowId: nil
            )
        }

        return nil
    }

    private func ocrMatchesHints(
        _ ocr: OCRTextResult,
        hint: String?,
        ownerHint: String?
    ) -> Bool {
        let hints = [hint, ownerHint]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !hints.isEmpty else { return !ocr.observations.isEmpty }
        let text = ocr.observations.map(\.text).joined(separator: " ").lowercased()
        return hints.contains { hint in
            text.contains(hint.lowercased())
        }
    }

    private func clampRectToScreens(_ rect: CGRect) -> CGRect? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        for screen in screens where screen.frame.intersects(rect) {
            return rect.intersection(screen.frame)
        }
        return rect
    }

    private func screenForMenuBarX(_ x: CGFloat) -> NSScreen? {
        if let screen = NSScreen.screens.first(where: { $0.frame.minX <= x && x <= $0.frame.maxX }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func menuBarPopoverCandidates(
        windowList: [[String: Any]],
        ownerPID: pid_t?
    ) -> [MenuBarPopoverCandidate] {
        let screens = NSScreen.screens.map { screen in
            MenuBarPopoverDetector.ScreenBounds(
                frame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
        }

        return MenuBarPopoverDetector.candidates(
            windowList: windowList,
            screens: screens,
            ownerPID: ownerPID
        )
    }

    private func menuBarPopoverCandidatesByBand(
        windowList: [[String: Any]],
        preferredX: CGFloat
    ) -> [MenuBarPopoverCandidate] {
        let screens = NSScreen.screens.map { screen in
            MenuBarPopoverDetector.ScreenBounds(
                frame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
        }
        let bandHalfWidth: CGFloat = 260
        var candidates: [MenuBarPopoverCandidate] = []

        for windowInfo in windowList {
            guard let bounds = self.windowBounds(from: windowInfo) else { continue }
            let windowId = windowInfo[kCGWindowNumber as String] as? Int ?? 0
            if windowId == 0 { continue }

            if bounds.width < 40 || bounds.height < 40 { continue }
            if bounds.maxX < preferredX - bandHalfWidth || bounds.minX > preferredX + bandHalfWidth { continue }

            let screen = self.screenContainingWindow(bounds: bounds, screens: screens)
            if let screen {
                let menuBarHeight = self.menuBarHeight(for: screen)
                let maxHeight = screen.frame.height * 0.85
                if bounds.height > maxHeight { continue }

                let topEdge = screen.visibleFrame.maxY
                if bounds.maxY < topEdge - 48 && bounds.minY > menuBarHeight + 48 { continue }
            }

            let ownerPID = self.ownerPid(from: windowInfo) ?? -1
            candidates.append(
                MenuBarPopoverCandidate(
                    windowId: windowId,
                    ownerPID: ownerPID,
                    bounds: bounds
                )
            )
        }

        return candidates
    }

    private func screenContainingWindow(
        bounds: CGRect,
        screens: [MenuBarPopoverDetector.ScreenBounds]
    ) -> MenuBarPopoverDetector.ScreenBounds? {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if let screen = screens.first(where: { $0.frame.contains(center) }) {
            return screen
        }

        var bestScreen: MenuBarPopoverDetector.ScreenBounds?
        var maxOverlap: CGFloat = 0
        for screen in screens {
            let intersection = screen.frame.intersection(bounds)
            let overlapArea = intersection.width * intersection.height
            if overlapArea > maxOverlap {
                maxOverlap = overlapArea
                bestScreen = screen
            }
        }

        return bestScreen
    }

    private func windowInfoById(from windowList: [[String: Any]]) -> [Int: MenuBarPopoverWindowInfo] {
        var info: [Int: MenuBarPopoverWindowInfo] = [:]
        for windowInfo in windowList {
            let windowId = windowInfo[kCGWindowNumber as String] as? Int ?? 0
            if windowId == 0 { continue }
            info[windowId] = MenuBarPopoverWindowInfo(
                ownerName: windowInfo[kCGWindowOwnerName as String] as? String,
                title: windowInfo[kCGWindowName as String] as? String
            )
        }
        return info
    }

    private func ownerPid(from windowInfo: [String: Any]) -> pid_t? {
        if let number = windowInfo[kCGWindowOwnerPID as String] as? NSNumber {
            return pid_t(number.intValue)
        }
        if let intValue = windowInfo[kCGWindowOwnerPID as String] as? Int {
            return pid_t(intValue)
        }
        if let pidValue = windowInfo[kCGWindowOwnerPID as String] as? pid_t {
            return pidValue
        }
        return nil
    }

    private func menuBarAppHint() -> String? {
        guard let app = self.app?.trimmingCharacters(in: .whitespacesAndNewlines),
              !app.isEmpty else {
            return nil
        }
        let lower = app.lowercased()
        if lower == "menubar" || lower == "frontmost" {
            return nil
        }
        return app
    }

    private func resolveMenuExtraHint(
        appHint: String?,
        extras: [MenuExtraInfo]
    ) -> MenuExtraInfo? {
        guard let appHint else { return nil }
        let normalized = appHint.lowercased()
        return extras.first { extra in
            let candidates = [
                extra.title,
                extra.rawTitle,
                extra.ownerName,
                extra.bundleIdentifier,
                extra.identifier
            ].compactMap { $0?.lowercased() }
            return candidates.contains(where: { $0 == normalized }) ||
                candidates.contains(where: { $0.contains(normalized) })
        }
    }

    private func resolveOpenMenuExtra(from extras: [MenuExtraInfo]) async throws -> MenuExtraInfo? {
        for extra in extras {
            let candidates = [
                extra.title,
                extra.ownerName,
                extra.rawTitle,
                extra.identifier,
                extra.bundleIdentifier,
            ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }

            for candidate in candidates where !candidate.isEmpty {
                let ownerPID = extra.ownerPID ?? self.resolveMenuExtraOwnerPID(extra)
                let isOpen = await (try? self.services.menu.isMenuExtraMenuOpen(
                    title: candidate,
                    ownerPID: ownerPID
                )) ?? false
                if isOpen {
                    return extra
                }
            }
        }
        return nil
    }

    private func resolveMenuExtraOwnerPID(_ extra: MenuExtraInfo) -> pid_t? {
        if let ownerPID = extra.ownerPID {
            return ownerPID
        }
        let runningApps = NSWorkspace.shared.runningApplications
        if let bundleIdentifier = extra.bundleIdentifier,
           let match = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return match.processIdentifier
        }
        if let ownerName = extra.ownerName {
            if let match = runningApps.first(where: { $0.localizedName == ownerName }) {
                return match.processIdentifier
            }
            let normalizedOwner = ownerName.lowercased()
            if let match = runningApps.first(where: {
                ($0.bundleIdentifier ?? "").lowercased().contains(normalizedOwner)
            }) {
                return match.processIdentifier
            }
        }
        return nil
    }

    private func menuBarRect() throws -> CGRect {
        guard let mainScreen = NSScreen.main ?? NSScreen.screens.first else {
            throw PeekabooError.captureFailed("No main screen found")
        }

        let menuBarHeight = self.menuBarHeight(for: mainScreen)
        return CGRect(
            x: mainScreen.frame.origin.x,
            y: mainScreen.frame.origin.y + mainScreen.frame.height - menuBarHeight,
            width: mainScreen.frame.width,
            height: menuBarHeight
        )
    }

    private func menuBarHeight(for screen: NSScreen?) -> CGFloat {
        guard let screen else { return 24.0 }
        let height = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        return height > 0 ? height : 24.0
    }

    private func menuBarHeight(for screen: MenuBarPopoverDetector.ScreenBounds) -> CGFloat {
        let height = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        return height > 0 ? height : 24.0
    }

    private func windowBounds(from windowInfo: [String: Any]) -> CGRect? {
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat
        else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func ocrElements(imageData: Data, windowBounds: CGRect?) throws -> [DetectedElement] {
        guard let windowBounds else { return [] }
        let result = try OCRService.recognizeText(in: imageData)
        return self.buildOCRElements(from: result, windowBounds: windowBounds)
    }

    private func buildOCRElements(from result: OCRTextResult, windowBounds: CGRect) -> [DetectedElement] {
        let minConfidence: Float = 0.3
        var elements: [DetectedElement] = []
        var index = 1

        for observation in result.observations where observation.confidence >= minConfidence {
            let rect = self.screenRect(
                from: observation.boundingBox,
                imageSize: result.imageSize,
                windowBounds: windowBounds
            )

            guard rect.width > 2, rect.height > 2 else { continue }

            let attributes = [
                "description": "ocr",
                "confidence": String(format: "%.2f", observation.confidence)
            ]

            elements.append(
                DetectedElement(
                    id: "ocr_\(index)",
                    type: .staticText,
                    label: observation.text,
                    value: nil,
                    bounds: rect,
                    isEnabled: true,
                    isSelected: nil,
                    attributes: attributes
                )
            )
            index += 1
        }

        return elements
    }

    private func screenRect(
        from normalizedBox: CGRect,
        imageSize: CGSize,
        windowBounds: CGRect
    ) -> CGRect {
        let width = normalizedBox.width * imageSize.width
        let height = normalizedBox.height * imageSize.height
        let x = normalizedBox.origin.x * imageSize.width
        let y = (1.0 - normalizedBox.origin.y - normalizedBox.height) * imageSize.height
        return CGRect(
            x: windowBounds.origin.x + x,
            y: windowBounds.origin.y + y,
            width: width,
            height: height
        )
    }

    private func saveScreenshot(_ imageData: Data) throws -> String {
        let outputPath: String

        if let providedPath = path {
            outputPath = NSString(string: providedPath).expandingTildeInPath
        } else {
            let timestamp = Date().timeIntervalSince1970
            let filename = "peekaboo_see_\(Int(timestamp)).png"
            let defaultPath = ConfigurationManager.shared.getDefaultSavePath(cliValue: nil)
            outputPath = (defaultPath as NSString).appendingPathComponent(filename)
        }

        // Create directory if needed
        let directory = (outputPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        // Save the image
        try imageData.write(to: URL(fileURLWithPath: outputPath))
        self.logger.verbose("Saved screenshot to: \(outputPath)")

        return outputPath
    }

    private func resolveSeeWindowIndex(appIdentifier: String, titleFragment: String?) async throws -> Int? {
        // IMPORTANT: ScreenCaptureService's modern path interprets `windowIndex` as an index into the
        // ScreenCaptureKit window list (SCShareableContent.windows filtered by PID), not the
        // Accessibility/WindowManagementService ordering. Resolve indices against SC first to avoid
        // capturing the wrong window when apps have hidden/auxiliary windows (e.g. Playground).
        //
        // When no title is provided, prefer `nil` so the capture service can auto-pick a renderable window.
        guard let fragment = titleFragment, !fragment.isEmpty else {
            return nil
        }

        let appInfo = try await self.services.applications.findApplication(identifier: appIdentifier)

        let content = try await AXTimeoutHelper.withTimeout(seconds: 5.0) {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        }

        let appWindows = content.windows.filter { window in
            window.owningApplication?.processID == appInfo.processIdentifier
        }

        guard !appWindows.isEmpty else {
            throw CaptureError.windowNotFound
        }

        // Prefer matching via CGWindowList title -> windowID, then map to SCWindow.windowID.
        if let targetWindowID = self.resolveCGWindowID(
            forPID: appInfo.processIdentifier,
            titleFragment: fragment
        ) {
            if let index = appWindows.firstIndex(where: { Int($0.windowID) == Int(targetWindowID) }) {
                return index
            }
        }

        // Fallback: some windows may not expose a CG title; try SCWindow.title directly.
        if let index = appWindows.firstIndex(where: { window in
            (window.title ?? "").localizedCaseInsensitiveContains(fragment)
        }) {
            return index
        }

        throw CaptureError.windowNotFound
    }

    private func resolveCGWindowID(forPID pid: Int32, titleFragment: String) -> CGWindowID? {
        let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32, ownerPID == pid else { continue }
            let title = info[kCGWindowName as String] as? String ?? ""
            guard title.localizedCaseInsensitiveContains(titleFragment) else { continue }
            if let windowID = info[kCGWindowNumber as String] as? CGWindowID {
                return windowID
            }
        }

        return nil
    }

    private func resolveWindowId(appIdentifier: String, titleFragment: String?) async throws -> Int? {
        guard let fragment = titleFragment, !fragment.isEmpty else {
            return nil
        }

        let windows = try await self.services.windows.listWindows(
            target: .applicationAndTitle(app: appIdentifier, title: fragment)
        )
        return windows.first?.windowID
    }

    // swiftlint:disable function_body_length
    private func generateAnnotatedScreenshot(
        snapshotId: String,
        originalPath: String
    ) async throws -> String {
        // Get detection result from snapshot
        guard let detectionResult = try await self.services.snapshots.getDetectionResult(snapshotId: snapshotId)
        else {
            self.logger.info("No detection result found for snapshot")
            return originalPath
        }

        // Create annotated image
        let annotatedPath = (originalPath as NSString).deletingPathExtension + "_annotated.png"

        // Load original image
        guard let nsImage = NSImage(contentsOfFile: originalPath) else {
            throw CaptureError.fileIOError("Failed to load image from \(originalPath)")
        }

        // Get image size
        let imageSize = nsImage.size

        // Create bitmap context
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(imageSize.width),
            pixelsHigh: Int(imageSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        else {
            throw CaptureError.captureFailure("Failed to create bitmap representation")
        }

        // Draw into context
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            self.logger.error("Failed to create graphics context")
            throw CaptureError.captureFailure("Failed to create graphics context")
        }
        NSGraphicsContext.current = context
        self.logger.verbose("Graphics context created successfully")

        // Draw original image
        nsImage.draw(in: NSRect(origin: .zero, size: imageSize))
        self.logger.verbose("Original image drawn")

        // Configure text attributes - smaller font for less occlusion
        let fontSize: CGFloat = 8
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]

        // Role-based colors from spec
        let roleColors: [ElementType: NSColor] = [
            .button: NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
            .textField: NSColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1.0), // #34C759
            .link: NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
            .checkbox: NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0), // #8E8E93
            .slider: NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0), // #8E8E93
            .menu: NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
        ]

        // Draw UI elements
        let enabledElements = detectionResult.elements.all.filter(\.isEnabled)

        if enabledElements.isEmpty {
            self.logger.info("No enabled elements to annotate. Total elements: \(detectionResult.elements.all.count)")
            print("\(AgentDisplayTokens.Status.warning)  No interactive UI elements found to annotate")
            return originalPath // Return original image if no elements to annotate
        }

        self.logger.info(
            "Annotating \(enabledElements.count) enabled elements out of \(detectionResult.elements.all.count) total"
        )
        self.logger.verbose("Image size: \(imageSize)")

        // Calculate window origin from element bounds if we have elements
        var windowOrigin = CGPoint.zero
        if !detectionResult.elements.all.isEmpty {
            // Find the leftmost and topmost element to estimate window origin
            let minX = detectionResult.elements.all.map(\.bounds.minX).min() ?? 0
            let minY = detectionResult.elements.all.map(\.bounds.minY).min() ?? 0
            windowOrigin = CGPoint(x: minX, y: minY)
            self.logger.verbose("Estimated window origin from elements: \(windowOrigin)")
        }

        // Convert all element bounds to window-relative coordinates and flip Y
        var elementRects: [(element: DetectedElement, rect: NSRect)] = []
        for element in enabledElements {
            let elementFrame = CGRect(
                x: element.bounds.origin.x - windowOrigin.x,
                y: element.bounds.origin.y - windowOrigin.y,
                width: element.bounds.width,
                height: element.bounds.height
            )

            let rect = NSRect(
                x: elementFrame.origin.x,
                y: imageSize.height - elementFrame.origin.y - elementFrame.height, // Flip Y coordinate
                width: elementFrame.width,
                height: elementFrame.height
            )

            elementRects.append((element: element, rect: rect))
        }

        // Create smart label placer for intelligent label positioning
        let labelPlacer = SmartLabelPlacer(
            image: nsImage,
            fontSize: fontSize,
            debugMode: self.verbose,
            logger: self.logger
        )

        // Draw elements and calculate label positions
        var labelPositions: [(rect: NSRect, connection: NSPoint?, element: DetectedElement)] = []

        for (element, rect) in elementRects {
            let drawingDetails = [
                "Drawing element: \(element.id)",
                "type: \(element.type)",
                "original bounds: \(element.bounds)",
                "window rect: \(rect)"
            ].joined(separator: ", ")
            self.logger.verbose(drawingDetails)

            // Get color for element type
            let color = roleColors[element.type] ?? NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)

            // Draw bounding box
            color.withAlphaComponent(0.5).setFill()
            rect.fill()

            color.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 2
            path.stroke()

            // Calculate label size
            let idString = NSAttributedString(string: element.id, attributes: textAttributes)
            let textSize = idString.size()
            let labelPadding: CGFloat = 4
            let labelSize = NSSize(width: textSize.width + labelPadding * 2, height: textSize.height + labelPadding)

            // Use smart label placer to find best position
            if let placement = labelPlacer.findBestLabelPosition(
                for: element,
                elementRect: rect,
                labelSize: labelSize,
                existingLabels: labelPositions.map { ($0.rect, $0.element) },
                allElements: elementRects
            ) {
                labelPositions.append((
                    rect: placement.labelRect,
                    connection: placement.connectionPoint,
                    element: element
                ))
            }
        }

        // NOTE: Old placement code removed - now using SmartLabelPlacer

        // [OLD CODE REMOVED - lines 483-785 contained the old placement logic]

        // Draw all labels and connection lines
        for (labelRect, connectionPoint, element) in labelPositions {
            // Draw connection line if label is outside - make it more subtle
            if let connection = connectionPoint {
                NSColor.black.withAlphaComponent(0.3).setStroke()
                let linePath = NSBezierPath()
                linePath.lineWidth = 0.5

                // Draw line from connection point to nearest edge of label
                linePath.move(to: connection)

                // Find the closest point on label rectangle to the connection point
                let closestX = max(labelRect.minX, min(connection.x, labelRect.maxX))
                let closestY = max(labelRect.minY, min(connection.y, labelRect.maxY))
                linePath.line(to: NSPoint(x: closestX, y: closestY))

                linePath.stroke()
            }

            // Draw label background - more transparent to show content beneath
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 1, yRadius: 1).fill()

            // Draw label border (same color as element) - thinner for less occlusion
            let color = roleColors[element.type] ?? NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)
            color.withAlphaComponent(0.8).setStroke()
            let borderPath = NSBezierPath(roundedRect: labelRect, xRadius: 1, yRadius: 1)
            borderPath.lineWidth = 0.5
            borderPath.stroke()

            // Draw label text
            let idString = NSAttributedString(string: element.id, attributes: textAttributes)
            idString.draw(at: NSPoint(x: labelRect.origin.x + 4, y: labelRect.origin.y + 2))
        }

        NSGraphicsContext.restoreGraphicsState()

        // Save annotated image
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw CaptureError.captureFailure("Failed to create PNG data")
        }

        try pngData.write(to: URL(fileURLWithPath: annotatedPath))
        self.logger.verbose("Created annotated screenshot: \(annotatedPath)")

        // Log annotation info only in non-JSON mode
        if !self.jsonOutput {
            let interactableElements = detectionResult.elements.all.filter(\.isEnabled)
            print("📝 Created annotated screenshot with \(interactableElements.count) interactive elements")
        }

        return annotatedPath
    }
    // swiftlint:enable function_body_length

    // [OLD CODE REMOVED - massive cleanup of duplicate placement logic]
}

// MARK: - Supporting Types

private struct CaptureContext {
    let captureResult: CaptureResult
    let captureBounds: CGRect?
    let prefersOCR: Bool
    let ocrMethod: String?
    let windowIdOverride: Int?
}

private struct MenuBarPopoverCapture {
    let captureResult: CaptureResult
    let windowBounds: CGRect
    let windowId: Int?
}

private struct CaptureAndDetectionResult {
    let snapshotId: String
    let screenshotPath: String
    let elements: DetectedElements
    let metadata: DetectionMetadata
}

private struct SnapshotPaths {
    let raw: String
    let annotated: String
    let map: String
}

private struct SeeCommandRenderContext {
    let snapshotId: String
    let screenshotPath: String
    let annotatedPath: String?
    let metadata: DetectionMetadata
    let elements: DetectedElements
    let analysis: SeeAnalysisData?
    let executionTime: TimeInterval
}

// MARK: - JSON Output Structure (matching original)

struct UIElementSummary: Codable {
    let id: String
    let role: String
    let title: String?
    let label: String?
    let description: String?
    let role_description: String?
    let help: String?
    let identifier: String?
    let is_actionable: Bool
    let keyboard_shortcut: String?
}

struct SeeAnalysisData: Codable {
    let provider: String
    let model: String
    let text: String
}

struct SeeResult: Codable {
    let snapshot_id: String
    let screenshot_raw: String
    let screenshot_annotated: String
    let ui_map: String
    let application_name: String?
    let window_title: String?
    let is_dialog: Bool
    let element_count: Int
    let interactable_count: Int
    let capture_mode: String
    let analysis: SeeAnalysisData?
    let execution_time: TimeInterval
    let ui_elements: [UIElementSummary]
    let menu_bar: MenuBarSummary?
    var success: Bool = true
}

struct MenuBarSummary: Codable {
    let menus: [MenuSummary]

    struct MenuSummary: Codable {
        let title: String
        let item_count: Int
        let enabled: Bool
        let items: [MenuItemSummary]
    }

    struct MenuItemSummary: Codable {
        let title: String
        let enabled: Bool
        let keyboard_shortcut: String?
    }
}

// MARK: - Format Helpers Extension

extension SeeCommand {
    /// Fetches the menu bar summary only when verbose output is requested, with a short timeout.
    private func fetchMenuBarSummaryIfEnabled() async -> MenuBarSummary? {
        guard self.verbose else { return nil }

        do {
            return try await Self.withWallClockTimeout(seconds: 2.5) {
                try Task.checkCancellation()
                return await self.getMenuBarItemsSummary()
            }
        } catch {
            self.logger.debug(
                "Skipping menu bar summary",
                category: "Menu",
                metadata: ["reason": error.localizedDescription]
            )
            return nil
        }
    }

    /// Timeout helper that is not MainActor-bound, so it can still fire if the main actor is blocked.
    static func withWallClockTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CaptureError.detectionTimedOut(seconds)
            }

            guard let result = try await group.next() else {
                throw CaptureError.detectionTimedOut(seconds)
            }
            group.cancelAll()
            return result
        }
    }

    private func performAnalysisDetailed(imagePath: String, prompt: String) async throws -> SeeAnalysisData {
        // Use PeekabooCore AI service which is configured via ConfigurationManager/Tachikoma
        let ai = PeekabooAIService()
        let res = try await ai.analyzeImageFileDetailed(at: imagePath, question: prompt, model: nil)
        return SeeAnalysisData(provider: res.provider, model: res.model, text: res.text)
    }

    private func buildMenuSummaryIfNeeded() async -> MenuBarSummary? {
        // Placeholder for future UI summary generation; currently unused.
        nil
    }

    private func determineMode() -> PeekabooCore.CaptureMode {
        if let mode = self.mode {
            mode
        } else if self.app != nil || self.pid != nil || self.windowTitle != nil || self.windowId != nil {
            // If app or window title is specified, default to window mode
            .window
        } else {
            // Otherwise default to frontmost
            .frontmost
        }
    }

    // MARK: - Output Methods

    private func outputJSONResults(context: SeeCommandRenderContext) async {
        let uiElements: [UIElementSummary] = context.elements.all.map { element in
            UIElementSummary(
                id: element.id,
                role: element.type.rawValue,
                title: element.attributes["title"],
                label: element.label,
                description: element.attributes["description"],
                role_description: element.attributes["roleDescription"],
                help: element.attributes["help"],
                identifier: element.attributes["identifier"],
                is_actionable: element.isEnabled,
                keyboard_shortcut: element.attributes["keyboardShortcut"]
            )
        }

        let snapshotPaths = self.snapshotPaths(for: context)

        // Menu bar enumeration can be slow or hang on some setups. Only attempt it in verbose
        // mode and bound it with a short timeout so JSON output is responsive by default.
        let menuSummary = await self.fetchMenuBarSummaryIfEnabled()

        let output = SeeResult(
            snapshot_id: context.snapshotId,
            screenshot_raw: snapshotPaths.raw,
            screenshot_annotated: snapshotPaths.annotated,
            ui_map: snapshotPaths.map,
            application_name: context.metadata.windowContext?.applicationName,
            window_title: context.metadata.windowContext?.windowTitle,
            is_dialog: context.metadata.isDialog,
            element_count: context.metadata.elementCount,
            interactable_count: context.elements.all.count { $0.isEnabled },
            capture_mode: self.determineMode().rawValue,
            analysis: context.analysis,
            execution_time: context.executionTime,
            ui_elements: uiElements,
            menu_bar: menuSummary
        )

        outputSuccessCodable(data: output, logger: self.outputLogger)
    }

    private func getMenuBarItemsSummary() async -> MenuBarSummary {
        // Get menu bar items from service
        var menuExtras: [MenuExtraInfo] = []

        do {
            menuExtras = try await self.services.menu.listMenuExtras()
        } catch {
            // If there's an error, just return empty array
            menuExtras = []
        }

        // Group items into menu categories
        // For now, we'll create a simplified view showing each menu bar item as a "menu"
        let menus = menuExtras.map { extra in
            MenuBarSummary.MenuSummary(
                title: extra.title,
                item_count: 1, // Each menu bar item is treated as a single menu
                enabled: true,
                items: [
                    MenuBarSummary.MenuItemSummary(
                        title: extra.title,
                        enabled: true,
                        keyboard_shortcut: nil
                    )
                ]
            )
        }

        return MenuBarSummary(menus: menus)
    }

    private func outputTextResults(context: SeeCommandRenderContext) async {
        print("🖼️  Screenshot saved to: \(context.screenshotPath)")
        if let annotatedPath = context.annotatedPath {
            print("📝 Annotated screenshot: \(annotatedPath)")
        }

        if let appName = context.metadata.windowContext?.applicationName {
            print("📱 Application: \(appName)")
        }
        if let windowTitle = context.metadata.windowContext?.windowTitle {
            let windowType = context.metadata.isDialog ? "Dialog" : "Window"
            let icon = context.metadata.isDialog ? "🗨️" : "[win]"
            print("\(icon) \(windowType): \(windowTitle)")
        }
        print("🧊 Detection method: \(context.metadata.method)")
        print("📊 UI elements detected: \(context.metadata.elementCount)")
        print("⚙️  Interactable elements: \(context.elements.all.count { $0.isEnabled })")
        let formattedDuration = String(format: "%.2f", context.executionTime)
        print("⏱️  Execution time: \(formattedDuration)s")

        if let analysis = context.analysis {
            print("\n🤖 AI Analysis\n\(analysis.text)")
        }

        if context.metadata.elementCount > 0 {
            print("\n🔍 Element Summary")
            for element in context.elements.all.prefix(10) {
                let summaryLabel = element.label ?? element.attributes["title"] ?? element.value ?? "Untitled"
                print("• \(element.id) (\(element.type.rawValue)) - \(summaryLabel)")
            }

            if context.metadata.elementCount > 10 {
                print("  ...and \(context.metadata.elementCount - 10) more elements")
            }
        }

        if self.annotate {
            print("\n📝 Annotated screenshot created")
        }

        if let menuSummary = await self.buildMenuSummaryIfNeeded() {
            print("\n🧭 Menu Bar Summary")
            for menu in menuSummary.menus {
                print("- \(menu.title) (\(menu.enabled ? "Enabled" : "Disabled"))")
                for item in menu.items.prefix(5) {
                    let shortcut = item.keyboard_shortcut.map { " [\($0)]" } ?? ""
                    print("    • \(item.title)\(shortcut)")
                }
            }
        }

        print("\nSnapshot ID: \(context.snapshotId)")

        let terminalCapabilities = TerminalDetector.detectCapabilities()
        if terminalCapabilities.recommendedOutputMode == .minimal {
            print("Agent: Use a tool like view_image to inspect it.")
        }
    }

    private func snapshotPaths(for context: SeeCommandRenderContext) -> SnapshotPaths {
        SnapshotPaths(
            raw: context.screenshotPath,
            annotated: context.annotatedPath ?? context.screenshotPath,
            map: self.services.snapshots.getSnapshotStoragePath() + "/\(context.snapshotId)/snapshot.json"
        )
    }
}

// MARK: - Multi-Screen Support

extension SeeCommand {
    private func performScreenCapture() async throws -> CaptureResult {
        // Log warning if annotation was requested for full screen captures
        if self.annotate {
            self.logger.info("Annotation is disabled for full screen captures due to performance constraints")
        }

        self.logger.verbose("Initiating screen capture", category: "Capture")
        self.logger.startTimer("screen_capture")

        defer {
            self.logger.stopTimer("screen_capture")
        }

        if let index = self.screenIndex ?? (self.analyze != nil ? 0 : nil) {
            // Capture specific screen
            self.logger.verbose("Capturing specific screen", category: "Capture", metadata: ["screenIndex": index])
            let result = try await ScreenCaptureBridge.captureScreen(services: self.services, displayIndex: index)

            // Add display info to output
            if let displayInfo = result.metadata.displayInfo {
                self.printScreenDisplayInfo(
                    index: index,
                    displayInfo: displayInfo,
                    indent: "",
                    suffix: nil
                )
            }

            self.logger.verbose("Screen capture completed", category: "Capture", metadata: [
                "mode": "screen-index",
                "screenIndex": index,
                "imageBytes": result.imageData.count
            ])
            return result
        } else {
            // Capture all screens
            self.logger.verbose("Capturing all screens", category: "Capture")
            let results = try await self.captureAllScreens()

            if results.isEmpty {
                throw CaptureError.captureFailure("Failed to capture any screens")
            }

            // Save all screenshots except the first (which will be saved by the normal flow)
            print("📸 Captured \(results.count) screen(s):")

            for (index, result) in results.indexed() {
                if index > 0 {
                    // Save additional screenshots
                    let screenPath: String
                    if let basePath = self.path {
                        // User specified a path - add screen index to filename
                        let directory = (basePath as NSString).deletingLastPathComponent
                        let filename = (basePath as NSString).lastPathComponent
                        let nameWithoutExt = (filename as NSString).deletingPathExtension
                        let ext = (filename as NSString).pathExtension

                        screenPath = (directory as NSString)
                            .appendingPathComponent("\(nameWithoutExt)_screen\(index).\(ext)")
                    } else {
                        // Default path with screen index
                        let timestamp = ISO8601DateFormatter().string(from: Date())
                        screenPath = "screenshot_\(timestamp)_screen\(index).png"
                    }

                    // Save the screenshot
                    try result.imageData.write(to: URL(fileURLWithPath: screenPath))

                    // Display info about this screen
                    if let displayInfo = result.metadata.displayInfo {
                        let fileSize = self.getFileSize(screenPath) ?? 0
                        let suffix = "\(screenPath) (\(self.formatFileSize(Int64(fileSize))))"
                        self.printScreenDisplayInfo(
                            index: index,
                            displayInfo: displayInfo,
                            indent: "   ",
                            suffix: suffix
                        )
                    }
                } else {
                    // First screen will be saved by the normal flow, just show info
                    if let displayInfo = result.metadata.displayInfo {
                        self.printScreenDisplayInfo(
                            index: index,
                            displayInfo: displayInfo,
                            indent: "   ",
                            suffix: "(primary)"
                        )
                    }
                }
            }

            // Return the primary screen result (first one)
            self.logger.verbose("Multi-screen capture completed", category: "Capture", metadata: [
                "count": results.count,
                "primaryBytes": results.first?.imageData.count ?? 0
            ])
            return results[0]
        }
    }
}

// MARK: - Multi-Screen Support

extension SeeCommand {
    private func captureAllScreens() async throws -> [CaptureResult] {
        var results: [CaptureResult] = []

        // Get available displays from the screen capture service
        let content = try await SCShareableContent.current
        let displays = content.displays

        self.logger.info("Found \(displays.count) display(s) to capture")

        for (index, display) in displays.indexed() {
            self.logger.verbose("Capturing display \(index)", category: "MultiScreen", metadata: [
                "displayID": display.displayID,
                "width": display.width,
                "height": display.height
            ])

            do {
                let result = try await ScreenCaptureBridge.captureScreen(services: self.services, displayIndex: index)

                // Update path to include screen index if capturing multiple screens
                if displays.count > 1 {
                    let updatedResult = self.updateCaptureResultPath(result, screenIndex: index, displayInfo: display)
                    results.append(updatedResult)
                } else {
                    results.append(result)
                }
            } catch {
                self.logger.error("Failed to capture display \(index): \(error)")
                // Continue capturing other screens even if one fails
            }
        }

        if results.isEmpty {
            throw CaptureError.captureFailure("Failed to capture any screens")
        }

        return results
    }

    private func updateCaptureResultPath(
        _ result: CaptureResult,
        screenIndex: Int,
        displayInfo: SCDisplay
    ) -> CaptureResult {
        // Since CaptureResult is immutable and doesn't have a path property,
        // we can't update the path. Just return the original result.
        // The saved path is already included in result.savedPath if it was saved.
        result
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

@MainActor
extension SeeCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            let definition = VisionToolDefinitions.see.commandConfiguration
            return CommandDescription(
                commandName: definition.commandName,
                abstract: definition.abstract,
                discussion: definition.discussion,
                usageExamples: [
                    CommandUsageExample(
                        command: "peekaboo see --json-output --annotate --path /tmp/see.png",
                        description: "Capture the frontmost window, print structured output, and save annotations."
                    ),
                    CommandUsageExample(
                        command: "peekaboo see --app Safari --window-title \"Login\" --json-output",
                        description: "Target a specific Safari window to collect stable element IDs."
                    ),
                    CommandUsageExample(
                        command: "peekaboo see --mode screen --screen-index 0 --analyze 'Summarize the dashboard'",
                        description: "Capture a display and immediately send it to the configured AI provider."
                    )
                ],
                showHelpOnEmptyInvocation: true
            )
        }
    }
}

extension SeeCommand: AsyncRuntimeCommand {}

@MainActor
extension SeeCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = values.singleOption("app")
        self.pid = try values.decodeOption("pid", as: Int32.self)
        self.windowTitle = values.singleOption("windowTitle")
        self.windowId = try values.decodeOption("windowId", as: Int.self)
        if let parsedMode: PeekabooCore.CaptureMode = try values.decodeOptionEnum("mode", caseInsensitive: false) {
            self.mode = parsedMode
        }
        self.path = values.singleOption("path")
        self.screenIndex = try values.decodeOption("screenIndex", as: Int.self)
        self.annotate = values.flag("annotate")
        self.analyze = values.singleOption("analyze")
        self.noWebFocus = values.flag("noWebFocus")
        self.menubar = values.flag("menubar")
    }
}

extension SeeCommand {
    private func screenDisplayBaseText(index: Int, displayInfo: DisplayInfo) -> String {
        let displayName = displayInfo.name ?? "Display \(index)"
        let bounds = displayInfo.bounds
        let resolution = "(\(Int(bounds.width))×\(Int(bounds.height)))"
        return "[scrn]️  Display \(index): \(displayName) \(resolution)"
    }

    private func printScreenDisplayInfo(
        index: Int,
        displayInfo: DisplayInfo,
        indent: String = "",
        suffix: String? = nil
    ) {
        var line = self.screenDisplayBaseText(index: index, displayInfo: displayInfo)
        if let suffix {
            line += " → \(suffix)"
        }
        print("\(indent)\(line)")
    }
}
