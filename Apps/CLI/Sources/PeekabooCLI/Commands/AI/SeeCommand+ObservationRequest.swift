import CoreGraphics
import Foundation
import PeekabooCore

@available(macOS 14.0, *)
@MainActor
extension SeeCommand {
    func observationTargetForCaptureWithDetectionIfPossible() throws -> DesktopObservationTargetRequest? {
        if self.menubar {
            let hint = self.menuBarAppHint()
            return .menubarPopover(
                hints: MenuBarPopoverResolverContext.normalizedHints([hint]),
                openIfNeeded: MenuBarPopoverOpenOptions(clickHint: hint)
            )
        }

        switch self.determineMode() {
        case .window:
            if let windowId {
                return .windowID(CGWindowID(windowId))
            }

            if let appValue = self.app?.lowercased() {
                switch appValue {
                case "menubar":
                    return nil
                case "frontmost":
                    return .frontmost
                default:
                    break
                }
            }

            if let pid, self.app == nil {
                return .pid(pid, window: self.seeWindowSelection)
            }

            if self.app != nil || self.pid != nil {
                return try .app(identifier: self.resolveApplicationIdentifier(), window: self.seeWindowSelection)
            }

            return nil

        case .frontmost:
            return .frontmost

        case .screen, .multi, .area:
            return nil
        }
    }

    func makeObservationRequest(target: DesktopObservationTargetRequest) -> DesktopObservationRequest {
        DesktopObservationRequest(
            target: target,
            capture: DesktopCaptureOptions(
                engine: self.observationCaptureEnginePreference,
                scale: .logical1x,
                visualizerMode: .screenshotFlash
            ),
            detection: self.observationDetectionOptions(for: target),
            output: DesktopObservationOutputOptions(
                path: self.screenshotOutputPath(),
                saveRawScreenshot: true,
                saveAnnotatedScreenshot: self.annotate,
                saveSnapshot: true
            )
        )
    }

    func observationTargetDescription(_ target: DesktopObservationTargetRequest) -> String {
        switch target {
        case let .screen(index):
            "screen:\(index.map(String.init) ?? "primary")"
        case .allScreens:
            "all-screens"
        case .frontmost:
            "frontmost"
        case let .app(identifier, _):
            "app:\(identifier)"
        case let .pid(pid, _):
            "pid:\(pid)"
        case let .windowID(windowID):
            "window-id:\(windowID)"
        case let .area(rect):
            "area:\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width))x\(Int(rect.height))"
        case .menubar:
            "menubar"
        case .menubarPopover:
            "menubar-popover"
        }
    }

    private var seeWindowSelection: WindowSelection {
        if let windowTitle {
            return .title(windowTitle)
        }
        return .automatic
    }

    private func observationDetectionOptions(for target: DesktopObservationTargetRequest) -> DesktopDetectionOptions {
        switch target {
        case .menubarPopover:
            DesktopDetectionOptions(
                mode: .none,
                allowWebFocusFallback: false,
                preferOCR: true
            )
        default:
            DesktopDetectionOptions(
                mode: .accessibility,
                allowWebFocusFallback: !self.noWebFocus
            )
        }
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
