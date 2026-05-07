import Foundation

extension DesktopObservationService {
    static func targetDiagnostics(
        for request: DesktopObservationTargetRequest,
        resolved target: ResolvedObservationTarget) -> DesktopObservationTargetDiagnostics
    {
        let requestDetails = Self.requestDiagnostics(for: request)
        return DesktopObservationTargetDiagnostics(
            requestedKind: requestDetails.kind,
            resolvedKind: Self.resolvedKindName(target.kind),
            source: Self.targetSource(for: request, resolved: target),
            hints: requestDetails.hints,
            openIfNeeded: requestDetails.openIfNeeded,
            clickHint: requestDetails.clickHint,
            windowID: target.window?.windowID,
            bounds: target.bounds,
            captureScaleHint: target.captureScaleHint)
    }

    private static func requestDiagnostics(
        for request: DesktopObservationTargetRequest)
        -> (kind: String, hints: [String], openIfNeeded: Bool, clickHint: String?)
    {
        switch request {
        case .screen:
            ("screen", [], false, nil)
        case .allScreens:
            ("all-screens", [], false, nil)
        case .frontmost:
            ("frontmost", [], false, nil)
        case .app:
            ("app", [], false, nil)
        case .pid:
            ("pid", [], false, nil)
        case .windowID:
            ("window-id", [], false, nil)
        case .area:
            ("area", [], false, nil)
        case .menubar:
            ("menubar", [], false, nil)
        case let .menubarPopover(hints, openIfNeeded):
            (
                "menubar-popover",
                hints,
                openIfNeeded != nil,
                openIfNeeded?.clickHint?.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func targetSource(
        for request: DesktopObservationTargetRequest,
        resolved target: ResolvedObservationTarget) -> String
    {
        switch target.kind {
        case .menubar:
            "primary-screen"
        case .menubarPopover where target.window != nil:
            "window-list"
        case .menubarPopover:
            if case let .menubarPopover(_, openIfNeeded) = request, openIfNeeded != nil {
                "click-location-area-fallback"
            } else {
                "area-fallback"
            }
        case .screen:
            "screen"
        case .frontmost:
            "frontmost-application"
        case .appWindow:
            "application-window"
        case .windowID:
            "window-id"
        case .area:
            "area"
        }
    }

    private static func resolvedKindName(_ kind: ResolvedObservationKind) -> String {
        switch kind {
        case .screen:
            "screen"
        case .frontmost:
            "frontmost"
        case .appWindow:
            "app-window"
        case .windowID:
            "window-id"
        case .area:
            "area"
        case .menubar:
            "menubar"
        case .menubarPopover:
            "menubar-popover"
        }
    }
}
