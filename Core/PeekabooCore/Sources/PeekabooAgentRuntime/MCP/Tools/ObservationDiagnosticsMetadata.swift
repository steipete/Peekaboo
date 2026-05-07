import CoreGraphics
import Foundation
import MCP
import PeekabooAutomationKit

enum ObservationDiagnosticsMetadata {
    static func value(for observation: DesktopObservationResult) -> Value {
        var payload: [String: Value] = [
            "timings": self.timingsValue(observation.timings),
            "warnings": .array(observation.diagnostics.warnings.map(Value.string)),
        ]

        if let stateSnapshot = observation.diagnostics.stateSnapshot {
            payload["state_snapshot"] = self.stateSnapshotValue(stateSnapshot)
        }
        if let target = observation.diagnostics.target {
            payload["target"] = self.targetValue(target)
        }

        return .object(payload)
    }

    static func merge(_ observation: DesktopObservationResult?, into metadata: Value) -> Value {
        guard let observation else { return metadata }
        var payload: [String: Value] = [:]
        if case let .object(existing) = metadata {
            payload = existing
        }
        payload["observation"] = self.value(for: observation)
        return .object(payload)
    }

    private static func timingsValue(_ timings: ObservationTimings) -> Value {
        .object([
            "total_duration_ms": .double(timings.spans.reduce(0) { $0 + $1.durationMS }),
            "spans": .array(timings.spans.map(self.spanValue)),
        ])
    }

    private static func spanValue(_ span: ObservationSpan) -> Value {
        .object([
            "name": .string(span.name),
            "duration_ms": .double(span.durationMS),
            "metadata": .object(span.metadata.mapValues(Value.string)),
        ])
    }

    private static func stateSnapshotValue(_ snapshot: DesktopStateSnapshotSummary) -> Value {
        var payload: [String: Value] = [
            "captured_at": .string(ISO8601DateFormatter().string(from: snapshot.capturedAt)),
            "display_count": .double(Double(snapshot.displayCount)),
            "running_application_count": .double(Double(snapshot.runningApplicationCount)),
            "window_count": .double(Double(snapshot.windowCount)),
        ]

        if let app = snapshot.frontmostApplication {
            payload["frontmost_application"] = .object([
                "pid": .double(Double(app.processIdentifier)),
                "bundle_identifier": app.bundleIdentifier.map(Value.string) ?? .null,
                "name": .string(app.name),
            ])
        }

        if let window = snapshot.frontmostWindow {
            payload["frontmost_window"] = .object([
                "window_id": .double(Double(window.windowID)),
                "title": .string(window.title),
                "index": .double(Double(window.index)),
            ])
        }

        return .object(payload)
    }

    private static func targetValue(_ target: DesktopObservationTargetDiagnostics) -> Value {
        var payload: [String: Value] = [
            "requested_kind": .string(target.requestedKind),
            "resolved_kind": .string(target.resolvedKind),
            "source": .string(target.source),
            "hints": .array(target.hints.map(Value.string)),
            "open_if_needed": .bool(target.openIfNeeded),
        ]

        payload["click_hint"] = target.clickHint.map(Value.string) ?? .null
        payload["window_id"] = target.windowID.map { .double(Double($0)) } ?? .null
        payload["bounds"] = target.bounds.map(self.rectValue) ?? .null
        payload["capture_scale_hint"] = target.captureScaleHint.map { .double(Double($0)) } ?? .null
        return .object(payload)
    }

    private static func rectValue(_ rect: CGRect) -> Value {
        .object([
            "x": .double(Double(rect.origin.x)),
            "y": .double(Double(rect.origin.y)),
            "width": .double(Double(rect.width)),
            "height": .double(Double(rect.height)),
        ])
    }
}
