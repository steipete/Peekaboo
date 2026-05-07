import AppKit
import AXorcist
import Foundation
import os.log
import PeekabooFoundation

@MainActor
extension ApplicationService {
    public func listWindows(
        for appIdentifier: String,
        timeout: Float? = nil) async throws -> UnifiedToolOutput<ServiceWindowListData>
    {
        let startTime = Date()
        self.logger.info("Listing windows for application: \(appIdentifier)")
        let app = try await findApplication(identifier: appIdentifier)
        let hasScreenRecording = self.permissions.checkScreenRecordingPermission()

        let context = WindowEnumerationContext(
            service: self,
            app: app,
            startTime: startTime,
            axTimeout: timeout ?? Self.axTimeout,
            hasScreenRecording: hasScreenRecording,
            logger: self.logger)
        return await context.run()
    }

    static func normalizeWindowIndices(_ windows: [ServiceWindowInfo]) -> [ServiceWindowInfo] {
        windows.enumerated().map { index, window in
            ServiceWindowInfo(
                windowID: window.windowID,
                title: window.title,
                bounds: window.bounds,
                isMinimized: window.isMinimized,
                isMainWindow: window.isMainWindow,
                windowLevel: window.windowLevel,
                alpha: window.alpha,
                index: index,
                spaceID: window.spaceID,
                spaceName: window.spaceName,
                screenIndex: window.screenIndex,
                screenName: window.screenName,
                layer: window.layer,
                isOnScreen: window.isOnScreen,
                sharingState: window.sharingState,
                isExcludedFromWindowsMenu: window.isExcludedFromWindowsMenu)
        }
    }

    fileprivate func createWindowInfo(from window: Element, index: Int) async -> ServiceWindowInfo? {
        guard let title = window.title() else { return nil }

        let bounds = self.windowBounds(for: window)
        let screen = self.screenInfo(for: bounds)
        let windowID = self.resolveWindowID(for: window, title: title, bounds: bounds, fallbackIndex: index)
        let spaces = self.spaceInfo(for: windowID)
        let level = self.windowLevel(for: windowID)

        return ServiceWindowInfo(
            windowID: Int(windowID),
            title: title,
            bounds: bounds,
            isMinimized: window.isMinimized() ?? false,
            isMainWindow: window.isMain() ?? false,
            windowLevel: level,
            index: index,
            spaceID: spaces.spaceID,
            spaceName: spaces.spaceName,
            screenIndex: screen.index,
            screenName: screen.name,
            layer: 0,
            isOnScreen: true)
    }

    private func windowBounds(for window: Element) -> CGRect {
        let position = window.position() ?? .zero
        let size = window.size() ?? .zero
        return CGRect(origin: position, size: size)
    }

    fileprivate func screenInfo(for bounds: CGRect) -> (index: Int?, name: String?) {
        let screenService = ScreenService()
        let screenInfo = screenService.screenContainingWindow(bounds: bounds)
        return (screenInfo?.index, screenInfo?.name)
    }

    private func resolveWindowID(for window: Element, title: String, bounds: CGRect, fallbackIndex: Int) -> CGWindowID {
        let windowIdentityService = WindowIdentityService()
        if let identifier = windowIdentityService.getWindowID(from: window) {
            return identifier
        }

        if let pid = window.pid(), let matched = matchWindowID(pid: pid, title: title, bounds: bounds) {
            return matched
        }

        let missingIdentifierMessage =
            "Failed to get actual window ID for window '\(title)', using index \(fallbackIndex) as fallback"
        self.logger.warning("\(missingIdentifierMessage)")
        return CGWindowID(fallbackIndex)
    }

    private func matchWindowID(pid: pid_t, title: String, bounds: CGRect) -> CGWindowID? {
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in windowList {
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let windowTitle = windowInfo[kCGWindowName as String] as? String,
                  windowTitle == title,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat
            else {
                continue
            }

            let cgBounds = CGRect(x: x, y: y, width: width, height: height)

            let withinTolerance = abs(cgBounds.origin.x - bounds.origin.x) < 5 &&
                abs(cgBounds.origin.y - bounds.origin.y) < 5 &&
                abs(cgBounds.size.width - bounds.size.width) < 5 &&
                abs(cgBounds.size.height - bounds.size.height) < 5

            if withinTolerance, let windowNumber = windowInfo[kCGWindowNumber as String] as? Int {
                self.logger.debug("Found window ID \(windowNumber) via CGWindowList for '\(title)'")
                return CGWindowID(windowNumber)
            }
        }

        return nil
    }

    private func spaceInfo(for windowID: CGWindowID) -> (spaceID: UInt64?, spaceName: String?) {
        let spaceService = SpaceManagementService()
        let spaces = spaceService.getSpacesForWindow(windowID: windowID)
        guard let firstSpace = spaces.first else {
            return (nil, nil)
        }
        return (firstSpace.id, firstSpace.name)
    }

    fileprivate func windowLevel(for windowID: CGWindowID) -> Int {
        let spaceService = SpaceManagementService()
        return spaceService.getWindowLevel(windowID: windowID).map { Int($0) } ?? 0
    }

    fileprivate func buildWindowListOutput(
        windows: [ServiceWindowInfo],
        app: ServiceApplicationInfo,
        startTime: Date,
        warnings: [String]) -> UnifiedToolOutput<ServiceWindowListData>
    {
        let normalizedWindows = ApplicationService.normalizeWindowIndices(windows)
        let processedCount = normalizedWindows.count

        // Build highlights
        var highlights: [UnifiedToolOutput<ServiceWindowListData>.Summary.Highlight] = []
        let minimizedCount = normalizedWindows.count(where: { $0.isMinimized })
        let offScreenCount = normalizedWindows.count(where: { $0.isOffScreen })

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
            data: ServiceWindowListData(windows: normalizedWindows, targetApplication: app),
            summary: UnifiedToolOutput.Summary(
                brief: "Found \(processedCount) window\(processedCount == 1 ? "" : "s") for \(app.name)",
                status: .success,
                counts: [
                    "windows": processedCount,
                    "minimized": minimizedCount,
                    "offScreen": offScreenCount,
                ],
                highlights: highlights),
            metadata: UnifiedToolOutput.Metadata(
                duration: Date().timeIntervalSince(startTime),
                warnings: warnings,
                hints: ["Use window title or index to target specific window"]))
    }
}

@MainActor
private struct WindowEnumerationContext {
    struct CGSnapshot {
        let windows: [ServiceWindowInfo]
        let windowsByTitle: [String: ServiceWindowInfo]
    }

    struct AXWindowResult {
        let windows: [Element]
        let timedOut: Bool
    }

    unowned let service: ApplicationService
    let app: ServiceApplicationInfo
    let startTime: Date
    let axTimeout: Float
    let hasScreenRecording: Bool
    let logger: Logger

    func run() async -> UnifiedToolOutput<ServiceWindowListData> {
        let snapshot = self.hasScreenRecording ? self.collectCGSnapshot() : nil
        if let snapshot, let fast = fastPath(using: snapshot) {
            return fast
        }

        guard self.isApplicationRunning else {
            return self.terminatedOutput()
        }

        let axWindows = self.fetchAXWindows()
        if let snapshot {
            return await self.mergeWithSnapshot(snapshot, axResult: axWindows)
        }

        return await self.buildAXOnlyResult(from: axWindows)
    }

    private var isApplicationRunning: Bool {
        NSRunningApplication(processIdentifier: self.app.processIdentifier)?.isTerminated == false
    }

    private func collectCGSnapshot() -> CGSnapshot? {
        self.logger.debug("Using hybrid approach: CGWindowList + selective AX enrichment")
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        var windowIndex = 0
        var windows: [ServiceWindowInfo] = []
        var windowsByTitle: [String: ServiceWindowInfo] = [:]
        let screenService = ScreenService()
        let spaceService = SpaceManagementService()

        for windowInfo in windowList {
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == app.processIdentifier
            else {
                continue
            }

            guard let windowInfo = snapshotWindowInfo(
                from: windowInfo,
                index: windowIndex,
                screenService: screenService,
                spaceService: spaceService)
            else {
                continue
            }

            windows.append(windowInfo)
            if !windowInfo.title.isEmpty {
                windowsByTitle[windowInfo.title] = windowInfo
            } else {
                let missingTitleMessage =
                    "Window \(windowInfo.windowID) has no title in CGWindowList, will need AX enrichment"
                self.logger.debug("\(missingTitleMessage)")
            }
            windowIndex += 1
        }

        guard !windows.isEmpty else {
            return nil
        }

        self.logger.debug("CGWindowList found \(windows.count) windows for \(self.app.name)")
        return CGSnapshot(windows: windows, windowsByTitle: windowsByTitle)
    }

    private func snapshotWindowInfo(
        from windowInfo: [String: Any],
        index: Int,
        screenService: ScreenService,
        spaceService: SpaceManagementService) -> ServiceWindowInfo?
    {
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat
        else {
            return nil
        }

        let bounds = CGRect(x: x, y: y, width: width, height: height)
        let windowID = windowInfo[kCGWindowNumber as String] as? Int ?? index
        let windowLevel = windowInfo[kCGWindowLayer as String] as? Int ?? 0
        let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat ?? 1.0
        let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? true
        let sharingRaw = windowInfo[kCGWindowSharingState as String] as? Int
        let sharingState = sharingRaw.flatMap { WindowSharingState(rawValue: $0) }
        let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t
        let windowTitle = (windowInfo[kCGWindowName as String] as? String) ?? ""
        let isMinimized = bounds.origin.x < -10000 || bounds.origin.y < -10000
        let spaces = spaceService.getSpacesForWindow(windowID: CGWindowID(windowID))
        let (spaceID, spaceName) = spaces.first.map { ($0.id, $0.name) } ?? (nil, nil)
        let screenInfo = screenService.screenContainingWindow(bounds: bounds)
        let excludedFromMenu: Bool = if ownerPID == getpid(),
                                        let window = NSApp.window(withWindowNumber: windowID)
        {
            window.isExcludedFromWindowsMenu
        } else {
            false
        }

        return ServiceWindowInfo(
            windowID: windowID,
            title: windowTitle,
            bounds: bounds,
            isMinimized: isMinimized,
            isMainWindow: index == 0,
            windowLevel: windowLevel,
            alpha: alpha,
            index: index,
            spaceID: spaceID,
            spaceName: spaceName,
            screenIndex: screenInfo?.index,
            screenName: screenInfo?.name,
            layer: windowLevel,
            isOnScreen: isOnScreen,
            sharingState: sharingState,
            isExcludedFromWindowsMenu: excludedFromMenu)
    }

    private func fastPath(using snapshot: CGSnapshot) -> UnifiedToolOutput<ServiceWindowListData>? {
        guard snapshot.windows.allSatisfy({ !$0.title.isEmpty }) else {
            return nil
        }

        self.logger.debug("All windows have titles from CGWindowList, using fast path")
        return self.service.buildWindowListOutput(
            windows: snapshot.windows,
            app: self.app,
            startTime: self.startTime,
            warnings: [])
    }

    private func terminatedOutput() -> UnifiedToolOutput<ServiceWindowListData> {
        self.logger.warning("Application \(self.app.name) appears to have terminated")
        return UnifiedToolOutput(
            data: ServiceWindowListData(windows: [], targetApplication: self.app),
            summary: UnifiedToolOutput.Summary(
                brief: "Application \(self.app.name) has no windows (app terminated)",
                status: .failed,
                counts: ["windows": 0]),
            metadata: UnifiedToolOutput.Metadata(
                duration: Date().timeIntervalSince(self.startTime),
                warnings: ["Application appears to have terminated"]))
    }

    private func fetchAXWindows() -> AXWindowResult {
        guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            return AXWindowResult(windows: [], timedOut: false)
        }
        let appElement = AXApp(runningApp).element
        appElement.setMessagingTimeout(self.axTimeout)
        defer { appElement.setMessagingTimeout(0) }

        let windowStartTime = Date()
        let windows = appElement.windowsWithTimeout(timeout: self.axTimeout) ?? []
        let timedOut = Date().timeIntervalSince(windowStartTime) >= Double(self.axTimeout)
        return AXWindowResult(windows: windows, timedOut: timedOut)
    }

    private func mergeWithSnapshot(
        _ snapshot: CGSnapshot,
        axResult: AXWindowResult) async -> UnifiedToolOutput<ServiceWindowListData>
    {
        var enrichedWindows: [ServiceWindowInfo] = []
        var warnings: [String] = []

        for (index, axWindow) in axResult.windows.indexed() {
            if Date().timeIntervalSince(self.startTime) > Double(self.axTimeout * 2) {
                warnings.append("Stopped enrichment after timeout")
                break
            }

            guard let axTitle = axWindow.title(), !axTitle.isEmpty else {
                continue
            }

            if let cgWindow = snapshot.windowsByTitle[axTitle] {
                enrichedWindows.append(cgWindow)
            } else if let windowInfo = await service.createWindowInfo(from: axWindow, index: index) {
                enrichedWindows.append(windowInfo)
            }
        }

        for cgWindow in snapshot.windows where !enrichedWindows.contains(where: { $0.windowID == cgWindow.windowID }) {
            if cgWindow.title.isEmpty {
                logger.debug("CGWindow \(cgWindow.windowID) has no title, including as-is")
            }
            enrichedWindows.append(cgWindow)
        }

        if axResult.timedOut {
            warnings.append("Window enumeration timed out after \(self.axTimeout)s, results may be incomplete")
        }

        return self.service.buildWindowListOutput(
            windows: enrichedWindows,
            app: self.app,
            startTime: self.startTime,
            warnings: warnings)
    }

    private func buildAXOnlyResult(from axResult: AXWindowResult) async -> UnifiedToolOutput<ServiceWindowListData> {
        self.logger.debug("Using pure AX approach (no screen recording permission)")
        var warnings: [String] = []
        var windowInfos: [ServiceWindowInfo] = []
        let maxWindowsToProcess = 100
        let limitedWindows = Array(axResult.windows.prefix(maxWindowsToProcess))

        if axResult.windows.count > maxWindowsToProcess {
            let warning =
                "Application \(app.name) has \(axResult.windows.count) windows, " +
                "processing only first \(maxWindowsToProcess)"
            self.logger.warning("\(warning)")
        }

        for (index, window) in limitedWindows.indexed() {
            if Date().timeIntervalSince(self.startTime) > Double(self.axTimeout) {
                warnings.append("Stopped processing after \(self.axTimeout)s timeout")
                break
            }

            if let windowInfo = await service.createWindowInfo(from: window, index: index) {
                windowInfos.append(windowInfo)
            }
        }

        if axResult.timedOut {
            warnings.append("Window enumeration timed out, results may be incomplete")
        }

        if axResult.windows.count > maxWindowsToProcess {
            let processedWarning =
                "Only processed first \(maxWindowsToProcess) of \(axResult.windows.count) windows"
            warnings.append(processedWarning)
        }

        if !self.hasScreenRecording {
            warnings.append("Screen recording permission not granted - window listing may be slower")
        }

        return self.service.buildWindowListOutput(
            windows: windowInfos,
            app: self.app,
            startTime: self.startTime,
            warnings: warnings)
    }
}
