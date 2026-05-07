import CoreGraphics
import Foundation
import PeekabooCore

@MainActor
extension ImageCommand {
    var observationWindowSelection: WindowSelection {
        if let windowIndex {
            return .index(windowIndex)
        }
        if let windowTitle {
            return .title(windowTitle)
        }
        return .automatic
    }

    func makeObservationRequest(
        target: DesktopObservationTargetRequest,
        outputURL: URL
    ) -> DesktopObservationRequest {
        DesktopObservationRequest(
            target: target,
            capture: DesktopCaptureOptions(
                engine: self.observationCaptureEnginePreference,
                scale: self.captureScale,
                focus: self.captureFocus,
                visualizerMode: .screenshotFlash
            ),
            detection: DesktopDetectionOptions(mode: .none),
            output: DesktopObservationOutputOptions(
                path: outputURL.path,
                format: self.format,
                saveRawScreenshot: true
            )
        )
    }

    private var captureScale: CaptureScalePreference {
        self.retina ? .native : .logical1x
    }

    private var observationCaptureEnginePreference: CaptureEnginePreference {
        let value = (self.captureEngine ?? self.configuredCaptureEnginePreference)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch value {
        case "modern", "modern-only", "sckit", "sc", "screen-capture-kit", "sck":
            return .modern
        case "classic", "cg", "legacy", "legacy-only", "false", "0", "no":
            return .legacy
        default:
            return .auto
        }
    }
}
