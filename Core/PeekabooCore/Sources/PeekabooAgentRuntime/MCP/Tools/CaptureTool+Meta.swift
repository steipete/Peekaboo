import MCP
import PeekabooAutomationKit

enum CaptureMetaBuilder {
    static func buildMeta(from summary: CaptureMetaSummary) -> Value {
        let meta: [String: Value] = [
            "frames": .array(summary.frames.map { .string($0) }),
            "contact": .string(summary.contactPath),
            "metadata": .string(summary.metadataPath),
            "diff_algorithm": .string(summary.diffAlgorithm),
            "diff_scale": .string(summary.diffScale),
            "contact_columns": .string("\(summary.contactColumns)"),
            "contact_rows": .string("\(summary.contactRows)"),
            "contact_thumb_width": .string("\(summary.contactThumbSize.width)"),
            "contact_thumb_height": .string("\(summary.contactThumbSize.height)"),
            "contact_sampled_indexes": .array(summary.contactSampledIndexes.map { .string("\($0)") }),
        ]
        return .object(meta)
    }
}
