import CoreGraphics
import Foundation

@MainActor
struct WindowCGInfoLookup {
    private let windowIdentityService: WindowIdentityService

    init(windowIdentityService: WindowIdentityService = WindowIdentityService()) {
        self.windowIdentityService = windowIdentityService
    }

    func serviceWindowInfo(windowID: Int) -> ServiceWindowInfo? {
        // Exact ID refreshes happen after mutations and snapshot focus; keep them on the CG fast path
        // instead of walking every app's AX window list.
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionIncludingWindow, .excludeDesktopElements],
            CGWindowID(windowID)) as? [[String: Any]],
            let windowInfo = windowList.first(where: { Self.intValue($0[kCGWindowNumber as String]) == windowID }),
            let bounds = Self.bounds(from: windowInfo)
        else {
            return nil
        }

        let layer = Self.intValue(windowInfo[kCGWindowLayer as String]) ?? 0
        let alpha = Self.cgFloatValue(windowInfo[kCGWindowAlpha as String]) ?? 1.0
        let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? true
        let sharingRaw = Self.intValue(windowInfo[kCGWindowSharingState as String])
        let sharingState = sharingRaw.flatMap { WindowSharingState(rawValue: $0) }

        return ServiceWindowInfo(
            windowID: windowID,
            title: (windowInfo[kCGWindowName as String] as? String) ?? "",
            bounds: bounds,
            isMinimized: bounds.origin.x < -10000 || bounds.origin.y < -10000,
            isMainWindow: self.windowIdentityService.isTopmostRenderableWindow(windowID: CGWindowID(windowID)),
            windowLevel: layer,
            alpha: alpha,
            index: 0,
            isOffScreen: !isOnScreen,
            layer: layer,
            isOnScreen: isOnScreen,
            sharingState: sharingState)
    }

    private nonisolated static func bounds(from windowInfo: [String: Any]) -> CGRect? {
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = cgFloatValue(boundsDict["X"]),
              let y = cgFloatValue(boundsDict["Y"]),
              let width = cgFloatValue(boundsDict["Width"]),
              let height = cgFloatValue(boundsDict["Height"])
        else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private nonisolated static func intValue(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let int32Value = value as? Int32 {
            return Int(int32Value)
        }
        if let int64Value = value as? Int64 {
            return Int(int64Value)
        }
        if let doubleValue = value as? Double {
            return Int(doubleValue)
        }
        if let numberValue = value as? NSNumber {
            return numberValue.intValue
        }
        return nil
    }

    private nonisolated static func cgFloatValue(_ value: Any?) -> CGFloat? {
        if let cgFloatValue = value as? CGFloat {
            return cgFloatValue
        }
        if let doubleValue = value as? Double {
            return CGFloat(doubleValue)
        }
        if let intValue = value as? Int {
            return CGFloat(intValue)
        }
        if let numberValue = value as? NSNumber {
            return CGFloat(truncating: numberValue)
        }
        return nil
    }
}
