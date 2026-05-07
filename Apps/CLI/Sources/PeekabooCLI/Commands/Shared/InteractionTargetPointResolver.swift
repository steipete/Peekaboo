import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

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

        // Keep diagnostics next to the same movement-adjustment decision used by execution.
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
