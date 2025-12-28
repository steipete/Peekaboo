import AppKit
import CoreGraphics
import Foundation

struct MenuBarPopoverCandidate {
    let windowId: Int
    let ownerPID: pid_t
    let bounds: CGRect
}

enum MenuBarPopoverDetector {
    struct ScreenBounds {
        let frame: CGRect
        let visibleFrame: CGRect
    }

    static func candidates(
        windowList: [[String: Any]],
        screens: [ScreenBounds],
        ownerPID: pid_t?
    ) -> [MenuBarPopoverCandidate] {
        var candidates: [MenuBarPopoverCandidate] = []

        for windowInfo in windowList {
            guard let bounds = windowBounds(from: windowInfo) else { continue }
            let windowId = windowInfo[kCGWindowNumber as String] as? Int ?? 0
            if windowId == 0 { continue }

            let ownerPIDValue: pid_t = {
                if let number = windowInfo[kCGWindowOwnerPID as String] as? NSNumber {
                    return pid_t(number.intValue)
                }
                if let intValue = windowInfo[kCGWindowOwnerPID as String] as? Int {
                    return pid_t(intValue)
                }
                return -1
            }()
            if let ownerPID, ownerPIDValue != ownerPID { continue }

            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? true
            let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat ?? 1.0
            if !isOnScreen || alpha < 0.05 { continue }

            let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let title = windowInfo[kCGWindowName as String] as? String ?? ""
            if ownerName == "Window Server", title == "Menubar" { continue }

            if bounds.width < 40 || bounds.height < 40 { continue }

            let screen = screenContainingWindow(bounds: bounds, screens: screens)
            let menuBarHeight = menuBarHeight(for: screen)
            if layer == 24 || layer == 25, bounds.height <= menuBarHeight + 4 { continue }

            if let screen {
                let maxHeight = screen.frame.height * 0.8
                if bounds.height > maxHeight { continue }

                if !isNearMenuBar(bounds: bounds, screen: screen, menuBarHeight: menuBarHeight) { continue }
            }

            candidates.append(
                MenuBarPopoverCandidate(
                    windowId: windowId,
                    ownerPID: ownerPIDValue,
                    bounds: bounds
                )
            )
        }

        return candidates
    }

    private static func isNearMenuBar(bounds: CGRect, screen: ScreenBounds, menuBarHeight: CGFloat) -> Bool {
        let topLeftCheck = bounds.minY <= menuBarHeight + 8
        let bottomLeftCheck = bounds.maxY >= screen.visibleFrame.maxY - 8
        return topLeftCheck || bottomLeftCheck
    }

    private static func windowBounds(from windowInfo: [String: Any]) -> CGRect? {
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat
        else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func menuBarHeight(for screen: ScreenBounds?) -> CGFloat {
        guard let screen else { return 24.0 }
        let height = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        return height > 0 ? height : 24.0
    }

    private static func screenContainingWindow(bounds: CGRect, screens: [ScreenBounds]) -> ScreenBounds? {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if let screen = screens.first(where: { $0.frame.contains(center) }) {
            return screen
        }

        var bestScreen: ScreenBounds?
        var maxOverlap: CGFloat = 0
        for screen in screens {
            let intersection = screen.frame.intersection(bounds)
            let overlapArea = intersection.width * intersection.height
            if overlapArea > maxOverlap {
                maxOverlap = overlapArea
                bestScreen = screen
            }
        }

        return bestScreen
    }
}
