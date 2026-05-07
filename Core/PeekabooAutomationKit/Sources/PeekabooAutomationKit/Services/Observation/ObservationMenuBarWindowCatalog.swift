import CoreGraphics
import Foundation

public struct ObservationMenuBarPopoverSnapshot: Sendable {
    public let candidates: [ObservationMenuBarPopoverCandidate]
    public let windowInfoByID: [Int: ObservationMenuBarPopoverWindowInfo]

    public init(
        candidates: [ObservationMenuBarPopoverCandidate],
        windowInfoByID: [Int: ObservationMenuBarPopoverWindowInfo])
    {
        self.candidates = candidates
        self.windowInfoByID = windowInfoByID
    }
}

public enum ObservationMenuBarWindowCatalog {
    public static func currentPopoverSnapshot(
        screens: [ScreenInfo],
        ownerPID: pid_t? = nil,
        includeOffscreen: Bool = false) -> ObservationMenuBarPopoverSnapshot
    {
        self.snapshot(
            windowList: self.currentWindowList(includeOffscreen: includeOffscreen),
            screens: screens,
            ownerPID: ownerPID)
    }

    public static func currentBandCandidates(
        preferredX: CGFloat,
        screens: [ScreenInfo]) -> [ObservationMenuBarPopoverCandidate]
    {
        self.bandCandidates(
            windowList: self.currentWindowList(),
            preferredX: preferredX,
            screens: screens)
    }

    public static func currentWindowIDs(ownerPID: pid_t) -> [Int] {
        self.windowIDsForPID(
            ownerPID: ownerPID,
            windowList: self.currentWindowList(includeOffscreen: true))
    }

    public static func currentWindowIDs(matchingOwnerNameOrTitle name: String) -> [Int] {
        self.windowIDsMatchingOwnerNameOrTitle(
            name,
            windowList: self.currentWindowList(includeOffscreen: true))
    }

    static func snapshot(
        windowList: [[String: Any]],
        screens: [ScreenInfo],
        ownerPID: pid_t? = nil) -> ObservationMenuBarPopoverSnapshot
    {
        let candidates = ObservationMenuBarPopoverResolver.candidates(
            windowList: windowList,
            screens: screens)
        let filteredCandidates = if let ownerPID {
            candidates.filter { $0.ownerPID == ownerPID }
        } else {
            candidates
        }

        return ObservationMenuBarPopoverSnapshot(
            candidates: filteredCandidates,
            windowInfoByID: self.windowInfoByID(from: windowList))
    }

    static func bandCandidates(
        windowList: [[String: Any]],
        preferredX: CGFloat,
        screens: [ScreenInfo]) -> [ObservationMenuBarPopoverCandidate]
    {
        let bandHalfWidth: CGFloat = 260
        var candidates: [ObservationMenuBarPopoverCandidate] = []

        for windowInfo in windowList {
            guard let bounds = self.bounds(from: windowInfo) else { continue }
            let windowID = self.windowID(from: windowInfo[kCGWindowNumber as String])
            if windowID == 0 { continue }

            if bounds.width < 40 || bounds.height < 40 { continue }
            if bounds.maxX < preferredX - bandHalfWidth || bounds.minX > preferredX + bandHalfWidth { continue }

            let screen = self.screenContaining(bounds: bounds, screens: screens)
            if let screen {
                let menuBarHeight = self.menuBarHeight(for: screen)
                let maxHeight = screen.frame.height * 0.85
                if bounds.height > maxHeight { continue }

                let topEdge = screen.visibleFrame.maxY
                if bounds.maxY < topEdge - 48, bounds.minY > menuBarHeight + 48 { continue }
            }

            candidates.append(ObservationMenuBarPopoverCandidate(
                windowID: windowID,
                ownerPID: self.pid(from: windowInfo[kCGWindowOwnerPID as String]),
                ownerName: windowInfo[kCGWindowOwnerName as String] as? String,
                title: windowInfo[kCGWindowName as String] as? String,
                bounds: bounds,
                layer: self.int(from: windowInfo[kCGWindowLayer as String]) ?? 0))
        }

        return candidates
    }

    static func windowIDsForPID(ownerPID: pid_t, windowList: [[String: Any]]) -> [Int] {
        windowList.compactMap { windowInfo in
            guard self.pid(from: windowInfo[kCGWindowOwnerPID as String]) == ownerPID else {
                return nil
            }
            return Int(self.windowID(from: windowInfo[kCGWindowNumber as String]))
        }
        .filter { $0 != 0 }
    }

    static func windowIDsMatchingOwnerNameOrTitle(_ name: String, windowList: [[String: Any]]) -> [Int] {
        let normalized = name.lowercased()
        return windowList.compactMap { windowInfo in
            let ownerName = (windowInfo[kCGWindowOwnerName as String] as? String)?.lowercased() ?? ""
            let title = (windowInfo[kCGWindowName as String] as? String)?.lowercased() ?? ""
            guard ownerName.contains(normalized) || title.contains(normalized) else {
                return nil
            }
            return Int(self.windowID(from: windowInfo[kCGWindowNumber as String]))
        }
        .filter { $0 != 0 }
    }

    private static func currentWindowList(includeOffscreen: Bool = false) -> [[String: Any]] {
        let options: CGWindowListOption = includeOffscreen
            ? [.optionAll, .excludeDesktopElements]
            : [.optionOnScreenOnly, .excludeDesktopElements]
        return CGWindowListCopyWindowInfo(
            options,
            kCGNullWindowID) as? [[String: Any]] ?? []
    }

    private static func windowInfoByID(from windowList: [[String: Any]])
        -> [Int: ObservationMenuBarPopoverWindowInfo]
    {
        var info: [Int: ObservationMenuBarPopoverWindowInfo] = [:]
        for windowInfo in windowList {
            let windowID = Int(self.windowID(from: windowInfo[kCGWindowNumber as String]))
            if windowID == 0 { continue }
            info[windowID] = ObservationMenuBarPopoverWindowInfo(
                ownerName: windowInfo[kCGWindowOwnerName as String] as? String,
                title: windowInfo[kCGWindowName as String] as? String)
        }
        return info
    }

    private static func screenContaining(bounds: CGRect, screens: [ScreenInfo]) -> ScreenInfo? {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if let screen = screens.first(where: { $0.frame.contains(center) }) {
            return screen
        }

        var bestScreen: ScreenInfo?
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

    private static func menuBarHeight(for screen: ScreenInfo) -> CGFloat {
        let height = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        return height > 0 ? height : 24
    }

    private static func bounds(from windowInfo: [String: Any]) -> CGRect? {
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = self.cgFloat(from: boundsDict["X"]),
              let y = self.cgFloat(from: boundsDict["Y"]),
              let width = self.cgFloat(from: boundsDict["Width"]),
              let height = self.cgFloat(from: boundsDict["Height"])
        else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func windowID(from value: Any?) -> CGWindowID {
        if let number = value as? NSNumber {
            return CGWindowID(number.uint32Value)
        }
        if let intValue = value as? Int {
            return CGWindowID(intValue)
        }
        if let cgWindowID = value as? CGWindowID {
            return cgWindowID
        }
        return 0
    }

    private static func pid(from value: Any?) -> pid_t {
        if let number = value as? NSNumber {
            return pid_t(number.intValue)
        }
        if let intValue = value as? Int {
            return pid_t(intValue)
        }
        if let pidValue = value as? pid_t {
            return pidValue
        }
        return -1
    }

    private static func int(from value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        return value as? Int
    }

    private static func cgFloat(from value: Any?) -> CGFloat? {
        if let number = value as? NSNumber {
            return CGFloat(number.doubleValue)
        }
        return value as? CGFloat
    }
}
