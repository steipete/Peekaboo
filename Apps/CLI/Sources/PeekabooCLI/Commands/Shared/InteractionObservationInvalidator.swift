import PeekabooCore
import PeekabooFoundation

@MainActor
extension InteractionObservationContext {
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
