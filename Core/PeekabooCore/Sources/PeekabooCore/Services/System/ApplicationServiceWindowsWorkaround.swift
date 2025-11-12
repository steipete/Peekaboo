import AppKit
import CoreGraphics
import Foundation

extension ApplicationService {
    /// Alternative window listing using CGWindowList API which doesn't hang
    @MainActor
    func listWindowsUsingCGWindowList(for appIdentifier: String) async throws
    -> UnifiedToolOutput<ServiceWindowListData> {
        let startTime = Date()
        self.logger.info("Listing windows for application using CGWindowList: \(appIdentifier)")
        let app = try await findApplication(identifier: appIdentifier)

        // Get windows using CGWindowList API
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return makeEmptyWindowResult(for: app, startTime: startTime)
        }

        let windows = buildWindowList(
            from: windowList,
            app: app
        )

        self.logger.debug("Found \(windows.count) windows for \(app.name) using CGWindowList")

        let highlights = makeWindowHighlights(windows: windows)

        return makeWindowListOutput(
            app: app,
            windows: windows,
            highlights: highlights,
            startTime: startTime
        )
    }

    private func makeEmptyWindowResult(
        for app: ServiceApplicationInfo,
        startTime: Date
    ) -> UnifiedToolOutput<ServiceWindowListData> {
        UnifiedToolOutput(
            data: ServiceWindowListData(windows: [], targetApplication: app),
            summary: UnifiedToolOutput.Summary(
                brief: "No windows found for \(app.name)",
                status: .success,
                counts: ["windows": 0]),
            metadata: UnifiedToolOutput.Metadata(
                duration: Date().timeIntervalSince(startTime),
                hints: ["Application may not have any open windows"]))
    }

    private func buildWindowList(
        from windowList: [[String: Any]],
        app: ServiceApplicationInfo
    ) -> [ServiceWindowInfo] {
        var windows: [ServiceWindowInfo] = []
        var windowIndex = 0
        let spaceService = SpaceManagementService()
        let screenService = ScreenService()

        for windowInfo in windowList {
            guard let windowDetails = buildWindowInfo(
                from: windowInfo,
                app: app,
                windowIndex: windowIndex,
                spaceService: spaceService,
                screenService: screenService
            ) else {
                continue
            }

            windows.append(windowDetails.info)
            windowIndex = windowDetails.nextIndex
        }

        return windows
    }

    private func buildWindowInfo(
        from windowInfo: [String: Any],
        app: ServiceApplicationInfo,
        windowIndex: Int,
        spaceService: SpaceManagementService,
        screenService: ScreenService
    ) -> (info: ServiceWindowInfo, nextIndex: Int)? {
        guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
              ownerPID == app.processIdentifier
        else {
            return nil
        }

        guard let windowTitle = windowInfo[kCGWindowName as String] as? String,
              !windowTitle.isEmpty,
              let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let bounds = makeBounds(from: boundsDict)
        else {
            return nil
        }

        let windowID = windowInfo[kCGWindowNumber as String] as? Int ?? windowIndex
        let windowLevel = windowInfo[kCGWindowLayer as String] as? Int ?? 0
        let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat ?? 1.0
        let isMinimized = bounds.origin.x < -10000 || bounds.origin.y < -10000

        let spaces = spaceService.getSpacesForWindow(windowID: CGWindowID(windowID))
        let (spaceID, spaceName) = spaces.first.map { ($0.id, $0.name) } ?? (nil, nil)
        let screenInfo = screenService.screenContainingWindow(bounds: bounds)

        let info = ServiceWindowInfo(
            windowID: windowID,
            title: windowTitle,
            bounds: bounds,
            isMinimized: isMinimized,
            isMainWindow: windowIndex == 0,
            windowLevel: windowLevel,
            alpha: alpha,
            index: windowIndex,
            spaceID: spaceID,
            spaceName: spaceName,
            screenIndex: screenInfo?.index,
            screenName: screenInfo?.name)

        return (info: info, nextIndex: windowIndex + 1)
    }

    private func makeBounds(from dictionary: [String: Any]) -> CGRect? {
        guard let x = dictionary["X"] as? CGFloat,
              let y = dictionary["Y"] as? CGFloat,
              let width = dictionary["Width"] as? CGFloat,
              let height = dictionary["Height"] as? CGFloat
        else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func makeWindowHighlights(
        windows: [ServiceWindowInfo]
    ) -> [UnifiedToolOutput<ServiceWindowListData>.Summary.Highlight] {
        var highlights: [UnifiedToolOutput<ServiceWindowListData>.Summary.Highlight] = []
        let minimizedCount = windows.count(where: { $0.isMinimized })
        let offScreenCount = windows.count(where: { $0.isOffScreen })

        if minimizedCount > 0 {
            highlights.append(.init(
                label: "Minimized",
                value: "\(minimizedCount) window\(minimizedCount == 1 ? "" : "s")",
                kind: .info))
        }

        if offScreenCount > 0 {
            highlights.append(.init(
                label: "Off-screen",
                value: "\(offScreenCount) window\(offScreenCount == 1 ? "" : "s")",
                kind: .warning))
        }

        return highlights
    }

    private func makeWindowListOutput(
        app: ServiceApplicationInfo,
        windows: [ServiceWindowInfo],
        highlights: [UnifiedToolOutput<ServiceWindowListData>.Summary.Highlight],
        startTime: Date
    ) -> UnifiedToolOutput<ServiceWindowListData> {
        let minimizedCount = windows.count(where: { $0.isMinimized })
        let offScreenCount = windows.count(where: { $0.isOffScreen })

        return UnifiedToolOutput(
            data: ServiceWindowListData(windows: windows, targetApplication: app),
            summary: UnifiedToolOutput.Summary(
                brief: "Found \(windows.count) window\(windows.count == 1 ? "" : "s") for \(app.name)",
                status: .success,
                counts: [
                    "windows": windows.count,
                    "minimized": minimizedCount,
                    "offScreen": offScreenCount,
                ],
                highlights: highlights),
            metadata: UnifiedToolOutput.Metadata(
                duration: Date().timeIntervalSince(startTime),
                hints: ["Use window title or index to target specific window"]))
    }
}
