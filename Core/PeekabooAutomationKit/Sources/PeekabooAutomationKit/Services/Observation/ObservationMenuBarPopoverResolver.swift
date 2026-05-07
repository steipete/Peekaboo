import CoreGraphics
import Foundation

public struct ObservationMenuBarPopoverCandidate: Sendable, Equatable {
    public let windowID: CGWindowID
    public let ownerPID: pid_t
    public let ownerName: String?
    public let title: String?
    public let bounds: CGRect
    public let layer: Int

    public init(
        windowID: CGWindowID,
        ownerPID: pid_t,
        ownerName: String?,
        title: String?,
        bounds: CGRect,
        layer: Int)
    {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.title = title
        self.bounds = bounds
        self.layer = layer
    }
}

public struct ObservationMenuBarPopoverWindowInfo: Sendable, Equatable {
    public let ownerName: String?
    public let title: String?

    public init(ownerName: String?, title: String?) {
        self.ownerName = ownerName
        self.title = title
    }
}

enum ObservationMenuBarPopoverResolver {
    static func resolve(
        hints: [String],
        windowList: [[String: Any]],
        screens: [ScreenInfo]) -> ObservationMenuBarPopoverCandidate?
    {
        let normalizedHints = Self.normalizedHints(hints)
        let candidates = Self.candidates(windowList: windowList, screens: screens)
        return Self.selectCandidate(candidates: candidates, hints: normalizedHints)
    }

    static func candidates(
        windowList: [[String: Any]],
        screens: [ScreenInfo]) -> [ObservationMenuBarPopoverCandidate]
    {
        windowList.compactMap { Self.candidate(from: $0, screens: screens) }
    }

    private static func candidate(
        from windowInfo: [String: Any],
        screens: [ScreenInfo]) -> ObservationMenuBarPopoverCandidate?
    {
        guard let bounds = Self.bounds(from: windowInfo) else { return nil }
        let windowID = Self.cgWindowID(from: windowInfo[kCGWindowNumber as String])
        guard windowID != 0 else { return nil }

        let ownerPID = Self.pid(from: windowInfo[kCGWindowOwnerPID as String])
        let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
        let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? true
        let alpha = Self.cgFloat(from: windowInfo[kCGWindowAlpha as String]) ?? 1
        guard isOnScreen, alpha >= 0.05 else { return nil }

        let ownerName = windowInfo[kCGWindowOwnerName as String] as? String
        let title = windowInfo[kCGWindowName as String] as? String
        if ownerName == "Window Server", title == "Menubar" { return nil }
        if bounds.width < 40 || bounds.height < 40 { return nil }

        let screen = Self.screenContaining(bounds: bounds, screens: screens)
        let menuBarHeight = Self.menuBarHeight(for: screen)
        if layer == 24 || layer == 25, bounds.height <= menuBarHeight + 4 { return nil }

        if let screen {
            let maxHeight = screen.frame.height * 0.8
            guard bounds.height <= maxHeight else { return nil }
            guard Self.isNearMenuBar(bounds: bounds, screen: screen, menuBarHeight: menuBarHeight) else {
                return nil
            }
        }

        return ObservationMenuBarPopoverCandidate(
            windowID: windowID,
            ownerPID: ownerPID,
            ownerName: ownerName,
            title: title,
            bounds: bounds,
            layer: layer)
    }

    private static func selectCandidate(
        candidates: [ObservationMenuBarPopoverCandidate],
        hints: [String]) -> ObservationMenuBarPopoverCandidate?
    {
        guard !candidates.isEmpty else { return nil }

        let hintedCandidates = Self.filterByHints(candidates: candidates, hints: hints)
        if !hints.isEmpty, hintedCandidates.isEmpty {
            return nil
        }

        let ranked = Self.rank(candidates: hintedCandidates.isEmpty ? candidates : hintedCandidates)
        return ranked.first
    }

    private static func filterByHints(
        candidates: [ObservationMenuBarPopoverCandidate],
        hints: [String]) -> [ObservationMenuBarPopoverCandidate]
    {
        guard !hints.isEmpty else { return [] }

        let exact = candidates.filter { candidate in
            hints.contains { hint in
                candidate.ownerName?.compare(hint, options: .caseInsensitive) == .orderedSame ||
                    candidate.title?.compare(hint, options: .caseInsensitive) == .orderedSame
            }
        }
        if !exact.isEmpty {
            return exact
        }

        return candidates.filter { candidate in
            hints.contains { hint in
                candidate.ownerName?.localizedCaseInsensitiveContains(hint) == true ||
                    candidate.title?.localizedCaseInsensitiveContains(hint) == true
            }
        }
    }

    private static func rank(
        candidates: [ObservationMenuBarPopoverCandidate]) -> [ObservationMenuBarPopoverCandidate]
    {
        candidates.sorted { lhs, rhs in
            if lhs.bounds.maxY != rhs.bounds.maxY {
                return lhs.bounds.maxY > rhs.bounds.maxY
            }
            let lhsArea = lhs.bounds.width * lhs.bounds.height
            let rhsArea = rhs.bounds.width * rhs.bounds.height
            if lhsArea != rhsArea {
                return lhsArea > rhsArea
            }
            return lhs.windowID < rhs.windowID
        }
    }

    private static func isNearMenuBar(
        bounds: CGRect,
        screen: ScreenInfo,
        menuBarHeight: CGFloat) -> Bool
    {
        let topLeftCheck = bounds.minY <= menuBarHeight + 8
        let bottomLeftCheck = bounds.maxY >= screen.visibleFrame.maxY - 8
        return topLeftCheck || bottomLeftCheck
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

    private static func menuBarHeight(for screen: ScreenInfo?) -> CGFloat {
        guard let screen else { return 24 }
        let height = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        return height > 0 ? height : 24
    }

    private static func normalizedHints(_ hints: [String]) -> [String] {
        hints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func bounds(from windowInfo: [String: Any]) -> CGRect? {
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = cgFloat(from: boundsDict["X"]),
              let y = cgFloat(from: boundsDict["Y"]),
              let width = cgFloat(from: boundsDict["Width"]),
              let height = cgFloat(from: boundsDict["Height"])
        else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func cgWindowID(from value: Any?) -> CGWindowID {
        if let number = value as? NSNumber {
            return CGWindowID(number.uint32Value)
        }
        if let intValue = value as? Int {
            return CGWindowID(intValue)
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
        return -1
    }

    private static func cgFloat(from value: Any?) -> CGFloat? {
        if let number = value as? NSNumber {
            return CGFloat(number.doubleValue)
        }
        return value as? CGFloat
    }
}
