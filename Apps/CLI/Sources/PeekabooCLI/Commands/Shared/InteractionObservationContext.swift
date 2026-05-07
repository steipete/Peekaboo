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
            "Refreshed implicit observation snapshot '\(refreshedSnapshotId)' for missing element '\(elementId)'"
        )
        return InteractionObservationContext(
            explicitSnapshotId: nil,
            snapshotId: refreshedSnapshotId,
            source: .latest
        )
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
