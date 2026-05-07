import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

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

    var jsonOutput: Bool {
        self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput
    }

    var verbose: Bool {
        self.runtime?.configuration.verbose ?? self.runtimeOptions.verbose
    }

    var logger: Logger {
        self.resolvedRuntime.logger
    }

    var services: any PeekabooServiceProviding {
        self.resolvedRuntime.services
    }

    var outputLogger: Logger {
        self.logger
    }

    var configuredCaptureEnginePreference: String? {
        self.resolvedRuntime.configuration.captureEnginePreference
    }

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
            try await CrossProcessOperationGate.withExclusiveOperation(named: "see-command") {
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
            // ScreenCaptureService performs the authoritative permission check inside each capture path.
            // Avoid duplicating that TCC probe here; `see` is often called in latency-sensitive loops.

            // Perform capture and element detection
            logger.verbose("Starting capture and detection phase", category: "Capture")
            let captureResult = try await performCaptureWithDetection()
            logger.verbose("Capture completed successfully", category: "Capture", metadata: [
                "snapshotId": captureResult.snapshotId,
                "elementCount": captureResult.elements.all.count,
                "screenshotSize": self.getFileSize(captureResult.screenshotPath) ?? 0,
            ])

            // Generate annotated screenshot if requested
            var annotatedPath = captureResult.annotatedPath
            if self.annotate, annotatedPath == nil {
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
            if self.annotate, annotatedPath == nil, !self.jsonOutput {
                print("\(AgentDisplayTokens.Status.warning)  No interactive UI elements found to annotate")
            } else if self.annotate, let annotatedPath, !self.jsonOutput {
                let interactableElements = captureResult.elements.all.filter(\.isEnabled)
                print("📝 Created annotated screenshot with \(interactableElements.count) interactive elements")
                self.logger.verbose("Annotated screenshot path: \(annotatedPath)")
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
                executionTime: executionTime,
                observation: captureResult.observation
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

    func getFileSize(_ path: String) -> Int? {
        try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int
    }

    private func performCaptureWithDetection() async throws -> CaptureAndDetectionResult {
        if let observationResult = try await self.performObservationCaptureWithDetectionIfPossible() {
            return observationResult
        }

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
            SnapshotScreenshotRequest(
                snapshotId: detectionResult.snapshotId,
                screenshotPath: outputPath,
                applicationBundleId: captureResult.metadata.applicationInfo?.bundleIdentifier,
                applicationProcessId: captureResult.metadata.applicationInfo.map { Int32($0.processIdentifier) },
                applicationName: windowContext.applicationName,
                windowTitle: windowContext.windowTitle,
                windowBounds: windowContext.windowBounds
            )
        )

        // Store the result in snapshot
        try await self.services.snapshots.storeDetectionResult(
            snapshotId: detectionResult.snapshotId,
            result: resultWithPath
        )

        return CaptureAndDetectionResult(
            snapshotId: detectionResult.snapshotId,
            screenshotPath: outputPath,
            annotatedPath: nil,
            elements: detectionResult.elements,
            metadata: detectionResult.metadata,
            observation: nil
        )
    }

    private func performObservationCaptureWithDetectionIfPossible() async throws -> CaptureAndDetectionResult? {
        guard let target = try self.observationTargetForCaptureWithDetectionIfPossible() else {
            return nil
        }

        self.logger.verbose("Using desktop observation pipeline", category: "Capture", metadata: [
            "target": self.observationTargetDescription(target)
        ])
        let mode = self.determineMode()
        self.logger.operationStart("capture_phase", metadata: ["mode": mode.rawValue])

        let observation: DesktopObservationResult
        do {
            observation = try await self.services.desktopObservation
                .observe(self.makeObservationRequest(target: target))
        } catch DesktopObservationError.targetNotFound(_) where self.menubar {
            self.logger.verbose("No observation-backed menu bar popover found; falling back", category: "Capture")
            self.logger.operationComplete("capture_phase", success: false, metadata: [
                "mode": mode.rawValue,
                "fallback": "legacy_menubar",
            ])
            return nil
        }

        self.logger.operationComplete("capture_phase", metadata: [
            "mode": mode.rawValue
        ])

        self.logObservationSpans(observation.timings)

        guard let outputPath = observation.files.rawScreenshotPath else {
            throw CaptureError.captureFailure("Observation completed without a saved screenshot path")
        }
        guard let detectionResult = observation.elements else {
            throw CaptureError.captureFailure("Observation completed without element detection")
        }

        return CaptureAndDetectionResult(
            snapshotId: detectionResult.snapshotId,
            screenshotPath: outputPath,
            annotatedPath: observation.files.annotatedScreenshotPath,
            elements: detectionResult.elements,
            metadata: detectionResult.metadata,
            observation: SeeObservationDiagnostics(
                timings: observation.timings,
                diagnostics: observation.diagnostics
            )
        )
    }

    private func logObservationSpans(_ timings: ObservationTimings) {
        for span in timings.spans {
            self.logger.verbose("Desktop observation span", category: "Performance", metadata: [
                "span": span.name,
                "duration_ms": Int(span.durationMS.rounded()),
            ])
        }
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
                        command: "peekaboo see --json --annotate --path /tmp/see.png",
                        description: "Capture the frontmost window, print structured output, and save annotations."
                    ),
                    CommandUsageExample(
                        command: "peekaboo see --app Safari --window-title \"Login\" --json",
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
