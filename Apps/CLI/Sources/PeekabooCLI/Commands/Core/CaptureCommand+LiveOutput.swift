import Foundation
import PeekabooCore

@MainActor
extension CaptureLiveCommand {
    func output(_ result: LiveCaptureSessionResult) {
        let meta = CaptureMetaSummary.make(from: result)
        if self.jsonOutput {
            outputSuccessCodable(data: result, logger: self.outputLogger)
            return
        }
        print("""
        🎥 capture kept \(result.stats.framesKept) frames (dropped \(result.stats.framesDropped)),
        contact sheet: \(meta.contactPath), diff: \(meta.diffAlgorithm) @ \(meta.diffScale),
        grid \(meta.contactColumns)x\(meta
            .contactRows) thumb \(Int(meta.contactThumbSize.width))x\(Int(meta.contactThumbSize.height))
        """)
        for frame in result.frames {
            print(
                "🖼️  \(frame.reason.rawValue) t=\(frame.timestampMs)ms "
                    + "Δ=\(String(format: "%.2f", frame.changePercent))% → \(frame.path)"
            )
        }
        for warning in result.warnings {
            print("⚠️  \(warning.code.rawValue): \(warning.message)")
        }
    }
}
