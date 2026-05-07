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
}
