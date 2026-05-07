import CoreGraphics
import Foundation

extension ObservationTargetResolver {
    func resolveWindowID(_ windowID: CGWindowID) -> ResolvedObservationTarget {
        let windowInfo = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]]
        guard let info = windowInfo?.first else {
            return ResolvedObservationTarget(kind: .windowID(windowID))
        }

        let title = info[kCGWindowName as String] as? String ?? ""
        let bounds = Self.bounds(from: info)
        let pid = info[kCGWindowOwnerPID as String] as? Int32
        let appName = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
        let app = pid.map {
            ApplicationIdentity(
                processIdentifier: $0,
                bundleIdentifier: nil,
                name: appName)
        }
        let window = bounds.map {
            WindowIdentity(
                windowID: Int(windowID),
                title: title,
                bounds: $0,
                index: 0)
        }
        let context = WindowContext(
            applicationName: app?.name,
            applicationBundleId: app?.bundleIdentifier,
            applicationProcessId: app?.processIdentifier,
            windowTitle: window?.title,
            windowID: Int(windowID),
            windowBounds: window?.bounds)

        return ResolvedObservationTarget(
            kind: .windowID(windowID),
            app: app,
            window: window,
            bounds: bounds,
            detectionContext: context)
    }

    func selectWindow(
        from windows: [ServiceWindowInfo],
        selection: WindowSelection) throws -> ServiceWindowInfo?
    {
        switch selection {
        case .automatic:
            return Self.bestWindow(from: windows)

        case let .index(index):
            guard let window = windows.first(where: { $0.index == index }) ?? windows[safe: index] else {
                throw DesktopObservationError.targetNotFound("window index \(index)")
            }
            return window

        case let .title(title):
            guard let window = windows.first(where: { $0.title.localizedCaseInsensitiveContains(title) }) else {
                throw DesktopObservationError.targetNotFound("window title \(title)")
            }
            return window

        case let .id(windowID):
            guard let window = windows.first(where: { $0.windowID == Int(windowID) }) else {
                throw DesktopObservationError.targetNotFound("window id \(windowID)")
            }
            return window
        }
    }

    private static func bounds(from window: [String: Any]) -> CGRect? {
        guard
            let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
            let x = boundsDict["X"] as? CGFloat,
            let y = boundsDict["Y"] as? CGFloat,
            let width = boundsDict["Width"] as? CGFloat,
            let height = boundsDict["Height"] as? CGFloat
        else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    public nonisolated static func bestWindow(from windows: [ServiceWindowInfo]) -> ServiceWindowInfo? {
        let visible = self.captureCandidates(from: windows)

        return visible.max { lhs, rhs in
            let lhsScore = self.windowScore(lhs)
            let rhsScore = self.windowScore(rhs)
            if lhsScore == rhsScore {
                return lhs.index > rhs.index
            }
            return lhsScore < rhsScore
        }
    }

    public nonisolated static func captureCandidates(from windows: [ServiceWindowInfo]) -> [ServiceWindowInfo] {
        self.filteredWindows(from: windows, mode: .capture)
    }

    public nonisolated static func filteredWindows(
        from windows: [ServiceWindowInfo],
        mode: WindowFiltering.Mode) -> [ServiceWindowInfo]
    {
        self.deduplicate(windows.filter { WindowFiltering.isRenderable($0, mode: mode) })
    }

    private nonisolated static func windowScore(_ window: ServiceWindowInfo) -> Double {
        // Prefer the window a human would expect: titled, normal-level, non-minimized, large, and early in AX order.
        var score = 0.0

        if window.isMainWindow {
            score += 2000
        }

        if window.windowLevel == 0 {
            score += 500
        }

        if window.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score -= 500
        } else {
            score += 2500
        }

        if !window.isMinimized {
            score += 300
        }

        let area = window.bounds.width * window.bounds.height
        if area > .zero {
            score += min(Double(area) / 150.0, 4000)
        }

        score += max(0, 600 - Double(window.index) * 40)

        return score
    }

    private nonisolated static func deduplicate(_ windows: [ServiceWindowInfo]) -> [ServiceWindowInfo] {
        var seenWindowIDs = Set<Int>()
        var deduplicated: [ServiceWindowInfo] = []
        deduplicated.reserveCapacity(windows.count)

        for window in windows where seenWindowIDs.insert(window.windowID).inserted {
            deduplicated.append(window)
        }

        return deduplicated
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
