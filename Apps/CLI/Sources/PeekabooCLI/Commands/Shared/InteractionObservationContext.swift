import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

enum InteractionSnapshotSource: String {
    case explicit
    case latest
    case none
}

@MainActor
struct InteractionObservationContext {
    let explicitSnapshotId: String?
    let snapshotId: String?
    let source: InteractionSnapshotSource

    var hasSnapshot: Bool {
        self.snapshotId != nil
    }

    func focusSnapshotId(for target: InteractionTargetOptions) -> String? {
        if self.source == .explicit || !target.hasAnyTarget {
            return self.snapshotId
        }
        return nil
    }

    func requireSnapshot(message: String = "No snapshot found") throws -> String {
        guard let snapshotId else {
            throw PeekabooError.snapshotNotFound(message)
        }
        return snapshotId
    }

    func validateIfExplicit(using snapshots: any SnapshotManagerProtocol) async throws {
        if let explicitSnapshotId {
            _ = try await SnapshotValidation.requireDetectionResult(
                snapshotId: explicitSnapshotId,
                snapshots: snapshots
            )
        }
    }

    func requireDetectionResult(using snapshots: any SnapshotManagerProtocol) async throws -> ElementDetectionResult {
        let snapshotId = try self.requireSnapshot()
        return try await SnapshotValidation.requireDetectionResult(snapshotId: snapshotId, snapshots: snapshots)
    }

    @discardableResult
    func invalidateAfterMutation(using snapshots: any SnapshotManagerProtocol) async throws -> String? {
        guard self.source == .latest, let snapshotId else {
            return nil
        }

        try await snapshots.cleanSnapshot(snapshotId: snapshotId)
        return snapshotId
    }

    static func invalidateLatestSnapshot(using snapshots: any SnapshotManagerProtocol) async throws -> String? {
        guard let latestSnapshotId = await snapshots.getMostRecentSnapshot() else {
            return nil
        }

        try await snapshots.cleanSnapshot(snapshotId: latestSnapshotId)
        return latestSnapshotId
    }

    static func resolve(
        explicitSnapshot rawSnapshot: String?,
        fallbackToLatest: Bool,
        snapshots: any SnapshotManagerProtocol
    ) async -> InteractionObservationContext {
        if let explicitSnapshotId = normalizedSnapshotId(rawSnapshot) {
            return InteractionObservationContext(
                explicitSnapshotId: explicitSnapshotId,
                snapshotId: explicitSnapshotId,
                source: .explicit
            )
        }

        guard fallbackToLatest else {
            return InteractionObservationContext(explicitSnapshotId: nil, snapshotId: nil, source: .none)
        }

        if let latestSnapshotId = await snapshots.getMostRecentSnapshot() {
            return InteractionObservationContext(
                explicitSnapshotId: nil,
                snapshotId: latestSnapshotId,
                source: .latest
            )
        }

        return InteractionObservationContext(explicitSnapshotId: nil, snapshotId: nil, source: .none)
    }

    private static func normalizedSnapshotId(_ snapshotId: String?) -> String? {
        let trimmed = snapshotId?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

@MainActor
struct InteractionObservationRefreshDependencies {
    let desktopObservation: any DesktopObservationServiceProtocol
    let snapshots: any SnapshotManagerProtocol
}

@MainActor
enum InteractionObservationRefresher {
    static func refreshForMissingElementsIfNeeded(
        _ observation: InteractionObservationContext,
        elementIds: [String?],
        target: InteractionTargetOptions,
        services: any PeekabooServiceProviding,
        logger: Logger
    ) async throws -> InteractionObservationContext {
        var refreshed = observation
        for elementId in elementIds.compactMap(\.self) {
            refreshed = try await self.refreshForMissingElementIfNeeded(
                refreshed,
                elementId: elementId,
                target: target,
                services: services,
                logger: logger
            )
        }
        return refreshed
    }

    static func refreshForMissingQueryIfNeeded(
        _ observation: InteractionObservationContext,
        query: String,
        target: InteractionTargetOptions,
        services: any PeekabooServiceProviding,
        logger: Logger
    ) async throws -> InteractionObservationContext {
        try await self.refreshForMissingQueryIfNeeded(
            observation,
            query: query,
            target: target,
            dependencies: InteractionObservationRefreshDependencies(
                desktopObservation: services.desktopObservation,
                snapshots: services.snapshots
            ),
            logger: logger
        )
    }

    static func refreshForMissingQueryIfNeeded(
        _ observation: InteractionObservationContext,
        query: String,
        target: InteractionTargetOptions,
        dependencies: InteractionObservationRefreshDependencies,
        logger: Logger
    ) async throws -> InteractionObservationContext {
        guard observation.source == .latest else {
            return observation
        }

        if let snapshotId = observation.snapshotId,
           let detectionResult = try await dependencies.snapshots.getDetectionResult(snapshotId: snapshotId),
           containsElement(matching: query, in: detectionResult) {
            return observation
        }

        return try await self.refreshObservation(
            observation,
            reason: "missing query '\(query)'",
            target: target,
            dependencies: dependencies,
            logger: logger
        )
    }

    static func refreshForMissingElementIfNeeded(
        _ observation: InteractionObservationContext,
        elementId: String,
        target: InteractionTargetOptions,
        services: any PeekabooServiceProviding,
        logger: Logger
    ) async throws -> InteractionObservationContext {
        try await self.refreshForMissingElementIfNeeded(
            observation,
            elementId: elementId,
            target: target,
            dependencies: InteractionObservationRefreshDependencies(
                desktopObservation: services.desktopObservation,
                snapshots: services.snapshots
            ),
            logger: logger
        )
    }

    static func refreshForMissingElementIfNeeded(
        _ observation: InteractionObservationContext,
        elementId: String,
        target: InteractionTargetOptions,
        dependencies: InteractionObservationRefreshDependencies,
        logger: Logger
    ) async throws -> InteractionObservationContext {
        guard observation.source != .explicit else {
            return observation
        }

        if let snapshotId = observation.snapshotId,
           let detectionResult = try await dependencies.snapshots.getDetectionResult(snapshotId: snapshotId),
           detectionResult.elements.findById(elementId) != nil {
            return observation
        }

        return try await self.refreshObservation(
            observation,
            reason: "missing element '\(elementId)'",
            target: target,
            dependencies: dependencies,
            logger: logger
        )
    }

    private static func refreshObservation(
        _ observation: InteractionObservationContext,
        reason: String,
        target: InteractionTargetOptions,
        dependencies: InteractionObservationRefreshDependencies,
        logger: Logger
    ) async throws -> InteractionObservationContext {
        let requestTarget = try target.observationTargetRequest()
        let result = try await dependencies.desktopObservation.observe(DesktopObservationRequest(
            target: requestTarget,
            capture: DesktopCaptureOptions(
                engine: .auto,
                scale: .logical1x,
                visualizerMode: .screenshotFlash
            ),
            detection: DesktopDetectionOptions(mode: .accessibility, allowWebFocusFallback: true),
            output: DesktopObservationOutputOptions(saveSnapshot: true)
        ))

        guard let refreshedSnapshotId = result.elements?.snapshotId else {
            return observation
        }

        logger.debug(
            "Refreshed implicit observation snapshot '\(refreshedSnapshotId)' for \(reason)"
        )
        return InteractionObservationContext(
            explicitSnapshotId: nil,
            snapshotId: refreshedSnapshotId,
            source: .latest
        )
    }

    private static func containsElement(
        matching query: String,
        in detectionResult: ElementDetectionResult
    ) -> Bool {
        let queryLower = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !queryLower.isEmpty else { return false }

        return detectionResult.elements.all.contains { element in
            guard element.isEnabled else { return false }
            let candidates = [
                element.id,
                element.label,
                element.value,
                element.attributes["identifier"],
                element.attributes["title"],
                element.attributes["description"],
                element.attributes["role"],
                element.type.rawValue,
            ].compactMap { $0?.lowercased() }

            return candidates.contains { $0.contains(queryLower) }
        }
    }
}

@MainActor
enum InteractionTargetPointResolver {
    static func elementCenterResolution(
        element: DetectedElement,
        elementId: String,
        snapshotId: String?,
        snapshots: any SnapshotManagerProtocol
    ) async throws -> InteractionTargetPointResolution {
        let originalPoint = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
        return try await self.resolve(
            originalPoint: originalPoint,
            source: .element,
            elementId: elementId,
            snapshotId: snapshotId,
            snapshots: snapshots
        )
    }

    static func elementCenter(
        elementId: String,
        snapshotId: String?,
        snapshots: any SnapshotManagerProtocol
    ) async throws -> CGPoint? {
        guard let snapshotId,
              let detectionResult = try await snapshots.getDetectionResult(snapshotId: snapshotId),
              let element = detectionResult.elements.findById(elementId)
        else {
            return nil
        }

        return try await self.elementCenterResolution(
            element: element,
            elementId: elementId,
            snapshotId: snapshotId,
            snapshots: snapshots
        ).point
    }

    static func coordinate(
        _ point: CGPoint,
        source: InteractionTargetPointSource
    ) -> InteractionTargetPointResolution {
        InteractionTargetPointResolution(
            point: point,
            diagnostics: InteractionTargetPointDiagnostics(
                source: source.rawValue,
                elementId: nil,
                snapshotId: nil,
                original: InteractionPoint(point),
                resolved: InteractionPoint(point),
                windowAdjustment: nil
            )
        )
    }

    private static func resolve(
        originalPoint: CGPoint,
        source: InteractionTargetPointSource,
        elementId: String?,
        snapshotId: String?,
        snapshots: any SnapshotManagerProtocol
    ) async throws -> InteractionTargetPointResolution {
        guard let snapshotId,
              let snapshot = try await snapshots.getUIAutomationSnapshot(snapshotId: snapshotId)
        else {
            return InteractionTargetPointResolution(
                point: originalPoint,
                diagnostics: InteractionTargetPointDiagnostics(
                    source: source.rawValue,
                    elementId: elementId,
                    snapshotId: snapshotId,
                    original: InteractionPoint(originalPoint),
                    resolved: InteractionPoint(originalPoint),
                    windowAdjustment: nil
                )
            )
        }

        // Keep diagnostics next to the same `WindowMovementTracking.adjustPoint` decision
        // that guards against moved, resized, or disappeared snapshot windows.
        switch WindowMovementTracking.adjustPoint(originalPoint, snapshot: snapshot) {
        case let .unchanged(point):
            return InteractionTargetPointResolution(
                point: point,
                diagnostics: InteractionTargetPointDiagnostics(
                    source: source.rawValue,
                    elementId: elementId,
                    snapshotId: snapshotId,
                    original: InteractionPoint(originalPoint),
                    resolved: InteractionPoint(point),
                    windowAdjustment: InteractionWindowAdjustmentDiagnostics(
                        status: "unchanged",
                        delta: nil
                    )
                )
            )
        case let .adjusted(point, delta):
            return InteractionTargetPointResolution(
                point: point,
                diagnostics: InteractionTargetPointDiagnostics(
                    source: source.rawValue,
                    elementId: elementId,
                    snapshotId: snapshotId,
                    original: InteractionPoint(originalPoint),
                    resolved: InteractionPoint(point),
                    windowAdjustment: InteractionWindowAdjustmentDiagnostics(
                        status: "adjusted",
                        delta: InteractionPoint(delta)
                    )
                )
            )
        case let .stale(message):
            throw PeekabooError.snapshotStale(message)
        }
    }
}

enum InteractionTargetPointSource: String {
    case element
    case coordinates
    case screenCenter = "screen_center"
    case application
    case pointer
}

struct InteractionTargetPointResolution {
    let point: CGPoint
    let diagnostics: InteractionTargetPointDiagnostics
}

struct InteractionTargetPointDiagnostics: Codable, Equatable {
    let source: String
    let elementId: String?
    let snapshotId: String?
    let original: InteractionPoint
    let resolved: InteractionPoint
    let windowAdjustment: InteractionWindowAdjustmentDiagnostics?
}

struct InteractionWindowAdjustmentDiagnostics: Codable, Equatable {
    let status: String
    let delta: InteractionPoint?
}

struct InteractionPoint: Codable, Equatable {
    let x: Double
    let y: Double

    init(_ point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }
}

extension InteractionTargetOptions {
    func observationTargetRequest() throws -> DesktopObservationTargetRequest {
        if let windowId {
            return .windowID(CGWindowID(windowId))
        }

        let windowSelection: WindowSelection? = if let windowIndex {
            .index(windowIndex)
        } else if let windowTitle {
            .title(windowTitle)
        } else {
            nil
        }

        if let pid {
            return .pid(pid, window: windowSelection)
        }

        if let app {
            return .app(identifier: app, window: windowSelection)
        }

        return .frontmost
    }
}

@MainActor
enum InteractionObservationInvalidator {
    static func invalidateAfterMutation(
        _ observation: InteractionObservationContext,
        snapshots: any SnapshotManagerProtocol,
        logger: Logger,
        reason: String
    ) async {
        do {
            if let invalidatedSnapshotId = try await observation.invalidateAfterMutation(using: snapshots) {
                logger.debug(
                    "Invalidated implicit latest snapshot '\(invalidatedSnapshotId)' after \(reason)"
                )
            }
        } catch {
            logger.warn(
                "Failed to invalidate implicit latest snapshot after \(reason): \(error.localizedDescription)"
            )
        }
    }

    static func invalidateAfterMutationOrLatest(
        _ observation: InteractionObservationContext,
        snapshots: any SnapshotManagerProtocol,
        logger: Logger,
        reason: String
    ) async {
        switch observation.source {
        case .explicit:
            return
        case .latest:
            await self.invalidateAfterMutation(
                observation,
                snapshots: snapshots,
                logger: logger,
                reason: reason
            )
        case .none:
            await self.invalidateLatestSnapshot(
                using: snapshots,
                logger: logger,
                reason: reason
            )
        }
    }

    static func invalidateLatestSnapshot(
        using snapshots: any SnapshotManagerProtocol,
        logger: Logger,
        reason: String
    ) async {
        do {
            if let invalidatedSnapshotId = try await InteractionObservationContext.invalidateLatestSnapshot(
                using: snapshots
            ) {
                logger.debug(
                    "Invalidated latest snapshot '\(invalidatedSnapshotId)' after \(reason)"
                )
            }
        } catch {
            logger.warn(
                "Failed to invalidate latest snapshot after \(reason): \(error.localizedDescription)"
            )
        }
    }
}
