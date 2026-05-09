import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Click on UI elements identified in the current snapshot using intelligent element finding and smart waiting.
@available(macOS 14.0, *)
@MainActor
struct ClickCommand: ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
    @Argument(help: "Element text or query to click")
    var query: String?

    @Option(help: "Snapshot ID (uses latest if not specified)")
    var snapshot: String?

    @Option(help: "Element ID to click (e.g., B1, T2)")
    var on: String?

    @Option(name: .customLong("id"), help: "Element ID to click (alias for --on)")
    var id: String?

    @OptionGroup var target: InteractionTargetOptions

    @Option(help: "Click at coordinates (x,y)")
    var coords: String?

    @Option(help: "Maximum milliseconds to wait for element")
    var waitFor: Int = 5000

    @Flag(help: "Double-click instead of single click")
    var double = false

    @Flag(help: "Right-click (secondary click)")
    var right = false

    @OptionGroup var focusOptions: FocusCommandOptions

    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    var services: any PeekabooServiceProviding {
        self.resolvedRuntime.services
    }

    private var logger: Logger {
        self.resolvedRuntime.logger
    }

    var outputLogger: Logger {
        self.logger
    }

    var jsonOutput: Bool {
        self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput
    }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)
        let startTime = Date()

        do {
            try self.validate()

            // Determine click target first to check if we need a snapshot
            let clickTarget: ClickTarget
            let waitResult: WaitForElementResult
            var activeSnapshotId: String
            var observationForInvalidation: InteractionObservationContext?

            // Check if we're clicking by coordinates (doesn't need snapshot)
            if let coordString = coords {
                // Click by coordinates (no snapshot needed)
                guard let point = Self.parseCoordinates(coordString) else {
                    throw ValidationError("Invalid coordinates format. Use: x,y")
                }
                clickTarget = .coordinates(point)
                waitResult = WaitForElementResult(found: true, element: nil, waitTime: 0)
                activeSnapshotId = "" // Not needed for coordinate clicks
                try await self.focusApplicationIfNeeded(snapshotId: nil)

                // Verify target app is actually frontmost after focus attempt.
                // InputDriver.click() sends a CGEvent at screen-absolute coordinates,
                // so if the target window is not frontmost, the click will land on
                // whatever window is at that position (see #90).
                try await self.verifyFocusForCoordinateClick()

            } else {
                // `click` keeps using the latest observation for element lookup even when
                // a target app is supplied; only focus skips the snapshot for explicit targets.
                var observation = await InteractionObservationContext.resolve(
                    explicitSnapshot: self.snapshot,
                    fallbackToLatest: true,
                    snapshots: self.services.snapshots
                )
                try await observation.validateIfExplicit(using: self.services.snapshots)

                try await self.focusApplicationIfNeeded(snapshotId: observation.focusSnapshotId(for: self.target))

                // Use whichever element ID parameter was provided
                let elementId = self.on ?? self.id

                if let elementId {
                    observation = try await InteractionObservationRefresher.refreshForMissingElementsIfNeeded(
                        observation,
                        elementIds: [elementId],
                        target: self.target,
                        services: self.services,
                        logger: self.logger
                    )
                    observationForInvalidation = observation
                    activeSnapshotId = observation.snapshotId ?? ""

                    // Click by element ID with auto-wait
                    clickTarget = .elementId(elementId)
                    waitResult = try await AutomationServiceBridge.waitForElement(
                        automation: self.services.automation,
                        target: clickTarget,
                        timeout: TimeInterval(self.waitFor) / 1000.0,
                        snapshotId: activeSnapshotId.isEmpty ? nil : activeSnapshotId
                    )

                    if !waitResult.found {
                        throw PeekabooError.elementNotFound(Self.elementNotFoundMessage(elementId))
                    }

                } else if let searchQuery = query {
                    observation = try await self.refreshObservationIfQueryMissing(observation, query: searchQuery)
                    observationForInvalidation = observation
                    activeSnapshotId = observation.snapshotId ?? ""

                    // Find element by query with auto-wait
                    clickTarget = .query(searchQuery)
                    waitResult = try await AutomationServiceBridge.waitForElement(
                        automation: self.services.automation,
                        target: clickTarget,
                        timeout: TimeInterval(self.waitFor) / 1000.0,
                        snapshotId: activeSnapshotId.isEmpty ? nil : activeSnapshotId
                    )

                    if !waitResult.found {
                        let message = Self.queryNotFoundMessage(
                            searchQuery,
                            waitFor: self.waitFor
                        )
                        throw PeekabooError.elementNotFound(message)
                    }

                } else {
                    // This case should not be reachable due to the validate() method
                    throw ValidationError("No target specified for click.")
                }
            }

            // Determine click type
            let clickType: ClickType = self.right ? .right : (self.double ? .double : .single)
            try await self.performClick(clickTarget, clickType: clickType, snapshotId: activeSnapshotId)

            // Brief delay to ensure click is processed
            try await Task.sleep(nanoseconds: 20_000_000) // 0.02 seconds

            // Report the frontmost app after the click through the application service boundary.
            let appName = await self.frontmostApplicationName()

            // Prepare result
            let clickLocation: CGPoint
            let clickedElement: String?
            let targetPointDiagnostics: InteractionTargetPointDiagnostics?

            switch clickTarget {
            case let .elementId(id):
                if let element = waitResult.element {
                    let resolution = try await InteractionTargetPointResolver.elementCenterResolution(
                        element: element,
                        elementId: id,
                        snapshotId: activeSnapshotId.isEmpty ? nil : activeSnapshotId,
                        snapshots: self.services.snapshots
                    )
                    clickLocation = resolution.point
                    targetPointDiagnostics = resolution.diagnostics
                    clickedElement = self.formatElementInfo(element)
                } else {
                    // Shouldn't happen but handle gracefully
                    clickLocation = .zero
                    targetPointDiagnostics = nil
                    clickedElement = "Element ID: \(id)"
                }

            case let .coordinates(point):
                clickLocation = point
                targetPointDiagnostics = InteractionTargetPointResolver.coordinate(point, source: .coordinates)
                    .diagnostics
                clickedElement = nil

            case let .query(query):
                if let element = waitResult.element {
                    let resolution = try await InteractionTargetPointResolver.elementCenterResolution(
                        element: element,
                        elementId: element.id,
                        snapshotId: activeSnapshotId.isEmpty ? nil : activeSnapshotId,
                        snapshots: self.services.snapshots
                    )
                    clickLocation = resolution.point
                    targetPointDiagnostics = resolution.diagnostics
                    clickedElement = self.formatElementInfo(element)
                } else {
                    // Use a default description
                    clickLocation = .zero
                    targetPointDiagnostics = nil
                    clickedElement = "Element matching: \(query)"
                }
            }

            // Output results
            let result = ClickResult(
                success: true,
                clickedElement: clickedElement,
                clickLocation: clickLocation,
                waitTime: waitResult.waitTime,
                executionTime: Date().timeIntervalSince(startTime),
                targetApp: appName,
                targetPoint: targetPointDiagnostics
            )

            if let observationForInvalidation {
                await InteractionObservationInvalidator.invalidateAfterMutation(
                    observationForInvalidation,
                    snapshots: self.services.snapshots,
                    logger: self.logger,
                    reason: "click"
                )
            }

            output(result) {
                print("✅ Click successful")
                print("🎯 App: \(appName)")
                if let info = clickedElement {
                    print("📱 Clicked: \(info)")
                }
                print("📍 Location: (\(Int(clickLocation.x)), \(Int(clickLocation.y)))")
                if waitResult.waitTime > 0 {
                    print("⏳ Waited: \(String(format: "%.1f", waitResult.waitTime))s")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    private func frontmostApplicationName() async -> String {
        await (try? self.services.applications.getFrontmostApplication().name) ?? "Unknown"
    }

    private func refreshObservationIfQueryMissing(
        _ observation: InteractionObservationContext,
        query: String
    ) async throws -> InteractionObservationContext {
        try await InteractionObservationRefresher.refreshForMissingQueryIfNeeded(
            observation,
            query: query,
            target: self.target,
            services: self.services,
            logger: self.logger
        )
    }

    private func performClick(_ target: ClickTarget, clickType: ClickType, snapshotId: String) async throws {
        let effectiveSnapshotId: String? = if case .coordinates = target {
            nil
        } else {
            snapshotId.isEmpty ? nil : snapshotId
        }

        try await AutomationServiceBridge.click(
            automation: self.services.automation,
            target: target,
            clickType: clickType,
            snapshotId: effectiveSnapshotId
        )
    }

    private func focusApplicationIfNeeded(snapshotId: String?) async throws {
        guard self.focusOptions.autoFocus else {
            return
        }

        if snapshotId == nil, !self.target.hasAnyTarget {
            return
        }

        try await ensureFocused(
            snapshotId: snapshotId,
            target: self.target,
            options: self.focusOptions,
            services: self.services
        )

        // Brief delay to ensure focus is complete before interacting
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    // Error handling is provided by ErrorHandlingCommand protocol
}
