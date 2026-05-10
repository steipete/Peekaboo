import CoreGraphics
import Foundation
import PeekabooCore

struct ImageWindowObservationTarget {
    let target: DesktopObservationTargetRequest
    let focusIdentifier: String
    let preferredName: String
}

@MainActor
extension ImageCommand {
    var observationWindowSelection: WindowSelection {
        if let windowTitle {
            return .title(windowTitle)
        }
        if let windowIndex {
            return .index(windowIndex)
        }
        return .automatic
    }

    func observationApplicationTargetForWindowCapture() throws -> ImageWindowObservationTarget {
        if let pid = try self.resolveExplicitPIDObservationTarget() {
            let identifier = "PID:\(pid)"
            return ImageWindowObservationTarget(
                target: .pid(pid, window: self.observationWindowSelection),
                focusIdentifier: identifier,
                preferredName: identifier
            )
        }

        let identifier = try self.resolveApplicationIdentifier()
        return ImageWindowObservationTarget(
            target: .app(identifier: identifier, window: self.observationWindowSelection),
            focusIdentifier: identifier,
            preferredName: identifier
        )
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
        ObservationCommandSupport.captureEnginePreference(
            cliValue: self.captureEngine,
            configuredValue: self.configuredCaptureEnginePreference
        )
    }
}
