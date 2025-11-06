import AppKit
import CoreGraphics
import Foundation

extension ApplicationService {
    /// Alternative window listing using CGWindowList API which doesn't hang
    @MainActor
    // Enumerate and normalize window metadata using the CGWindowList API for reliability.
    func listWindowsUsingCGWindowList(for appIdentifier: String) async throws
    -> UnifiedToolOutput<ServiceWindowListData> {
        let startTime = Date()
        self.logger.info("Listing windows for application using CGWindowList: \(appIdentifier)")
        let app = try await findApplication(identifier: appIdentifier)

        // Get windows using CGWindowList API
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return UnifiedToolOutput(
                data: ServiceWindowListData(windows: [], targetApplication: app),
                summary: UnifiedToolOutput.Summary(
                    brief: "No windows found for \(app.name)",
                    status: .success,
                    counts: ["windows": 0]),
                metadata: UnifiedToolOutput.Metadata(
                    duration: Date().timeIntervalSince(startTime),
                    hints: ["Application may not have any open windows"]))
        }

        // Filter windows for this application
        var windows: [ServiceWindowInfo] = []
        var windowIndex = 0

        for windowInfo in windowList {
            // Check if window belongs to our app
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == app.processIdentifier
            else {
                continue
            }

            // Skip windows without a title or that are not on screen
            guard let windowTitle = windowInfo[kCGWindowName as String] as? String,
                  !windowTitle.isEmpty,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat
            else {
                continue
            }

            let bounds = CGRect(x: x, y: y, width: width, height: height)
            let windowID = windowInfo[kCGWindowNumber as String] as? Int ?? windowIndex
            let windowLevel = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat ?? 1.0

            // Determine if minimized based on bounds
            let isMinimized = bounds.origin.x < -10000 || bounds.origin.y < -10000

            // Get space information
            let spaceService = SpaceManagementService()
            let spaces = spaceService.getSpacesForWindow(windowID: CGWindowID(windowID))
            let (spaceID, spaceName) = spaces.first.map { ($0.id, $0.name) } ?? (nil, nil)

            // Detect which screen this window is on
            let screenService = ScreenService()
            let screenInfo = screenService.screenContainingWindow(bounds: bounds)

            let windowInfo = ServiceWindowInfo(
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

            windows.append(windowInfo)
            windowIndex += 1
        }

        self.logger.debug("Found \(windows.count) windows for \(app.name) using CGWindowList")

        // Build highlights
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
