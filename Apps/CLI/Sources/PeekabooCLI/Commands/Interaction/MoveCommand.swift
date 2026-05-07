import AppKit
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Moves the mouse cursor to specific coordinates or UI elements.
@available(macOS 14.0, *)
@MainActor
struct MoveCommand: ErrorHandlingCommand, OutputFormattable {
    @Argument(help: "Coordinates as x,y (e.g., 100,200)")
    var coordinates: String?

    @Option(name: .customLong("coords"), help: "Coordinates as x,y (alias for the positional argument)")
    var coords: String?

    @Option(help: "Move to element by text/label")
    var to: String?

    @Option(help: "Element ID to move to (e.g., B1, T2)")
    var on: String?

    @Option(name: .customLong("id"), help: "Element ID to move to (alias for --on)")
    var id: String?

    @OptionGroup var target: InteractionTargetOptions
    @OptionGroup var focusOptions: FocusCommandOptions

    @Flag(help: "Move to screen center")
    var center = false

    @Flag(help: "Use smooth movement animation")
    var smooth = false

    @Option(help: "Movement duration in milliseconds (default: 500 for smooth, 0 for instant)")
    var duration: Int?

    @Option(help: "Number of steps for smooth movement (default: 20)")
    var steps: Int = 20

    @Option(help: "Movement profile: linear (default) or human.")
    var profile: String?

    @Option(help: "Snapshot ID for element resolution")
    var snapshot: String?
    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: any PeekabooServiceProviding {
        self.resolvedRuntime.services
    }

    private var logger: Logger {
        self.resolvedRuntime.logger
    }

    var outputLogger: Logger {
        self.logger
    }

    var jsonOutput: Bool {
        self.resolvedRuntime.configuration.jsonOutput
    }

    private var resolvedCoordinates: String? {
        self.coordinates ?? self.coords
    }

    mutating func validate() throws {
        try self.target.validate()
        let targetCount = [
            self.center ? 1 : 0,
            self.resolvedCoordinates == nil ? 0 : 1,
            self.to == nil ? 0 : 1,
            self.on == nil ? 0 : 1,
            self.id == nil ? 0 : 1,
        ].reduce(0, +)

        guard targetCount >= 1 else {
            throw ValidationError("Specify coordinates, --coords, --to, --on/--id, or --center")
        }

        guard targetCount == 1 else {
            throw ValidationError("Specify exactly one target: coordinates, --coords, --to, --on/--id, or --center")
        }

        // Validate coordinates format if provided
        if let coordString = self.resolvedCoordinates {
            let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2,
                  Double(parts[0]) != nil,
                  Double(parts[1]) != nil else {
                throw ValidationError("Invalid coordinates format. Use: x,y")
            }
        }

        if let profileName = self.profile?.lowercased(),
           MovementProfileSelection(rawValue: profileName) == nil {
            throw ValidationError("Invalid profile '\(profileName)'. Use 'linear' or 'human'.")
        }
    }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let startTime = Date()
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            try self.validate()
            let resolvedTarget = try await self.resolveTarget()
            let targetLocation = resolvedTarget.location
            let targetDescription = resolvedTarget.description

            // Get current mouse location for distance calculation
            let currentLocation = CGEvent(source: nil)?.location ?? CGPoint.zero
            let distance = hypot(
                targetLocation.x - currentLocation.x,
                targetLocation.y - currentLocation.y
            )

            let movement = self.resolveMovementParameters(
                profileSelection: self.selectedProfile,
                distance: distance
            )

            // Perform the movement
            try await AutomationServiceBridge.moveMouse(
                automation: self.services.automation,
                to: targetLocation,
                duration: movement.duration,
                steps: movement.steps,
                profile: movement.profile
            )
            AutomationEventLogger.log(
                .cursor,
                "move target=\(targetDescription) duration=\(movement.duration)ms steps=\(movement.steps) "
                    + "profile=\(movement.profileName)"
            )

            // Output results
            let result = MoveResult(
                success: true,
                targetLocation: targetLocation,
                targetDescription: targetDescription,
                fromLocation: currentLocation,
                distance: distance,
                duration: movement.duration,
                smooth: movement.smooth,
                profile: movement.profileName,
                targetPoint: resolvedTarget.diagnostics,
                executionTime: Date().timeIntervalSince(startTime)
            )
            output(result) {
                print("✅ Mouse moved successfully")
                print("🎯 Target: \(targetDescription)")
                print("📍 Location: (\(Int(targetLocation.x)), \(Int(targetLocation.y)))")
                print("📏 Distance: \(Int(distance)) pixels")
                print("🧭 Profile: \(movement.profileName.capitalized)")
                if movement.smooth {
                    print("🎬 Animation: \(movement.duration)ms with \(movement.steps) steps")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    private func resolveTarget() async throws -> MoveTargetResolution {
        if self.center {
            try await self.focusForCoordinateTarget()
            guard let mainScreen = NSScreen.main else {
                throw ValidationError("No main screen found")
            }
            let screenFrame = mainScreen.frame
            let location = CGPoint(x: screenFrame.midX, y: screenFrame.midY)
            return MoveTargetResolution(
                location: location,
                description: "Screen center",
                diagnostics: InteractionTargetPointResolver.coordinate(
                    location,
                    source: .screenCenter
                ).diagnostics
            )
        }

        if let coordString = self.resolvedCoordinates {
            try await self.focusForCoordinateTarget()
            let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let x = Double(parts[0])!
            let y = Double(parts[1])!
            let location = CGPoint(x: x, y: y)
            return MoveTargetResolution(
                location: location,
                description: "Coordinates (\(Int(x)), \(Int(y)))",
                diagnostics: InteractionTargetPointResolver.coordinate(
                    location,
                    source: .coordinates
                ).diagnostics
            )
        }

        if let elementId = on ?? id {
            return try await self.resolveElementTarget(elementId: elementId)
        }

        if let query = to {
            return try await self.resolveQueryTarget(query: query)
        }

        throw ValidationError("Specify coordinates, --coords, --to, --on/--id, or --center")
    }

    private func focusForCoordinateTarget() async throws {
        try await ensureFocused(
            snapshotId: nil,
            target: self.target,
            options: self.focusOptions,
            services: self.services
        )
    }

    private func resolveElementTarget(elementId: String) async throws -> MoveTargetResolution {
        var observation = await InteractionObservationContext.resolve(
            explicitSnapshot: self.snapshot,
            fallbackToLatest: true,
            snapshots: self.services.snapshots
        )
        observation = try await InteractionObservationRefresher.refreshForMissingElementsIfNeeded(
            observation,
            elementIds: [elementId],
            target: self.target,
            services: self.services,
            logger: self.logger
        )
        try await ensureFocused(
            snapshotId: observation.focusSnapshotId(for: self.target),
            target: self.target,
            options: self.focusOptions,
            services: self.services
        )

        let detectionResult = try await observation.requireDetectionResult(using: self.services.snapshots)
        guard let element = detectionResult.elements.findById(elementId) else {
            throw PeekabooError.elementNotFound("Element with ID '\(elementId)' not found")
        }

        let resolution = try await InteractionTargetPointResolver.elementCenterResolution(
            element: element,
            elementId: elementId,
            snapshotId: observation.snapshotId,
            snapshots: self.services.snapshots
        )
        return MoveTargetResolution(
            location: resolution.point,
            description: self.formatElementInfo(element),
            diagnostics: resolution.diagnostics
        )
    }

    private func resolveQueryTarget(query: String) async throws -> MoveTargetResolution {
        var observation = await InteractionObservationContext.resolve(
            explicitSnapshot: self.snapshot,
            fallbackToLatest: true,
            snapshots: self.services.snapshots
        )
        observation = try await InteractionObservationRefresher.refreshForMissingQueryIfNeeded(
            observation,
            query: query,
            target: self.target,
            services: self.services,
            logger: self.logger
        )
        let activeSnapshotId = try observation.requireSnapshot()
        try await ensureFocused(
            snapshotId: observation.focusSnapshotId(for: self.target),
            target: self.target,
            options: self.focusOptions,
            services: self.services
        )

        try await observation.validateIfExplicit(using: self.services.snapshots)

        let waitResult = try await AutomationServiceBridge.waitForElement(
            automation: self.services.automation,
            target: .query(query),
            timeout: 5.0,
            snapshotId: activeSnapshotId
        )

        guard waitResult.found, let element = waitResult.element else {
            throw PeekabooError.elementNotFound("No element found matching '\(query)'")
        }

        let resolution = try await InteractionTargetPointResolver.elementCenterResolution(
            element: element,
            elementId: element.id,
            snapshotId: activeSnapshotId,
            snapshots: self.services.snapshots
        )
        return MoveTargetResolution(
            location: resolution.point,
            description: self.formatElementInfo(element),
            diagnostics: resolution.diagnostics
        )
    }

    private func formatElementInfo(_ element: DetectedElement) -> String {
        let roleDescription = element.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        let label = element.label ?? element.value ?? element.id
        return "\(roleDescription): \(label)"
    }

    private var selectedProfile: MovementProfileSelection {
        guard let profileName = self.profile?.lowercased(),
              let selection = MovementProfileSelection(rawValue: profileName) else {
            return .linear
        }
        return selection
    }

    private func resolveMovementParameters(
        profileSelection: MovementProfileSelection,
        distance: CGFloat
    ) -> MovementParameters {
        switch profileSelection {
        case .linear:
            let wantsSmooth = self.smooth || (self.duration ?? 0) > 0
            let resolvedDuration: Int = if let customDuration = self.duration {
                customDuration
            } else {
                wantsSmooth ? 500 : 0
            }
            let resolvedSteps = wantsSmooth ? max(self.steps, 1) : 1
            return MovementParameters(
                profile: .linear,
                duration: resolvedDuration,
                steps: resolvedSteps,
                smooth: wantsSmooth,
                profileName: profileSelection.rawValue
            )
        case .human:
            let resolvedDuration = self.duration ?? self.defaultHumanDuration(for: distance)
            let resolvedSteps = max(self.steps, self.defaultHumanSteps(for: distance))
            return MovementParameters(
                profile: .human(),
                duration: resolvedDuration,
                steps: resolvedSteps,
                smooth: true,
                profileName: profileSelection.rawValue
            )
        }
    }

    private func defaultHumanDuration(for distance: CGFloat) -> Int {
        let distanceFactor = log2(Double(distance) + 1) * 90
        let perPixel = Double(distance) * 0.45
        let estimate = 240 + distanceFactor + perPixel
        return min(max(Int(estimate), 280), 1700)
    }

    private func defaultHumanSteps(for distance: CGFloat) -> Int {
        let scaled = Int(distance * 0.35)
        return min(max(scaled, 30), 120)
    }
}

// MARK: - Conformances

@MainActor
extension MoveCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "move",
                abstract: "Move the mouse cursor to coordinates or UI elements",
                discussion: """
                    The 'move' command positions the mouse cursor at specific locations or
                    on UI elements detected by 'see'. Supports instant and smooth movement.

                    EXAMPLES:
                      peekaboo move 100,200                 # Move to coordinates
                      peekaboo move --to "Submit Button"    # Move to element by text
                      peekaboo move --on B3                 # Move to element by ID
                      peekaboo move 500,300 --smooth        # Smooth movement
                      peekaboo move --center                # Move to screen center

                    MOVEMENT MODES:
                      - Instant (default): Immediate cursor positioning
                      - Smooth: Animated movement with configurable duration
                      - Human: Natural arcs with eased velocity, enable via '--profile human'

                    ELEMENT TARGETING:
                      When targeting elements, the cursor moves to the element's center.
                      Use element IDs from 'see' output for precise targeting.
                """,

                showHelpOnEmptyInvocation: true
            )
        }
    }
}

extension MoveCommand: AsyncRuntimeCommand {}

@MainActor
extension MoveCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.coordinates = try values.decodeOptionalPositional(0, label: "coordinates")
        self.coords = values.singleOption("coords")
        self.to = values.singleOption("to")
        self.on = values.singleOption("on")
        self.id = values.singleOption("id")
        self.target = try values.makeInteractionTargetOptions()
        self.center = values.flag("center")
        self.smooth = values.flag("smooth")
        if let duration: Int = try values.decodeOption("duration", as: Int.self) {
            self.duration = duration
        }
        if let steps: Int = try values.decodeOption("steps", as: Int.self) {
            self.steps = steps
        }
        self.snapshot = values.singleOption("snapshot")
        self.profile = values.singleOption("profile")
        self.focusOptions = try values.makeFocusOptions()
    }
}
