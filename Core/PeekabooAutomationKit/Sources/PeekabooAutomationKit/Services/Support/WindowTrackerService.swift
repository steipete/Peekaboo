import AppKit
import AXorcist
import CoreGraphics
import Foundation
import os.log

public struct WindowTrackerStatus: Sendable, Codable {
    public let trackedWindows: Int
    public let lastEventAt: Date?
    public let lastPollAt: Date?
    public let axObserverCount: Int
    public let cgPollIntervalMs: Int

    public init(
        trackedWindows: Int,
        lastEventAt: Date?,
        lastPollAt: Date?,
        axObserverCount: Int,
        cgPollIntervalMs: Int)
    {
        self.trackedWindows = trackedWindows
        self.lastEventAt = lastEventAt
        self.lastPollAt = lastPollAt
        self.axObserverCount = axObserverCount
        self.cgPollIntervalMs = cgPollIntervalMs
    }
}

public struct WindowTrackerConfiguration: Sendable {
    public let pollInterval: TimeInterval
    public let useAXNotifications: Bool

    public init(pollInterval: TimeInterval = 1.0, useAXNotifications: Bool = true) {
        self.pollInterval = pollInterval
        self.useAXNotifications = useAXNotifications
    }
}

@MainActor
public final class WindowTrackerService: WindowTrackingProviding {
    private struct TrackedWindow: Sendable {
        let info: WindowIdentityInfo
        var lastEventAt: Date?
        var lastUpdatedAt: Date?
    }

    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "WindowTracker")
    private let config: WindowTrackerConfiguration
    private let windowIdentityService = WindowIdentityService()

    private var windows: [CGWindowID: TrackedWindow] = [:]
    private var watchers: [NotificationWatcher] = []
    private var pollTask: Task<Void, Never>?
    private var lastEventAt: Date?
    private var lastPollAt: Date?

    public init(configuration: WindowTrackerConfiguration = WindowTrackerConfiguration()) {
        self.config = configuration
    }

    public func start() {
        guard self.pollTask == nil else { return }

        if self.config.useAXNotifications {
            self.installAXObservers()
        }

        self.pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    public func stop() {
        self.pollTask?.cancel()
        self.pollTask = nil

        for watcher in self.watchers {
            watcher.stop()
        }
        self.watchers.removeAll()
    }

    public func windowBounds(for windowID: CGWindowID) -> CGRect? {
        self.windows[windowID]?.info.bounds
    }

    public func status() -> WindowTrackerStatus {
        WindowTrackerStatus(
            trackedWindows: self.windows.count,
            lastEventAt: self.lastEventAt,
            lastPollAt: self.lastPollAt,
            axObserverCount: self.watchers.count,
            cgPollIntervalMs: Int(self.config.pollInterval * 1000.0))
    }

    private func installAXObservers() {
        let notifications: [AXNotification] = [
            .windowCreated,
            .windowMoved,
            .windowResized,
            .windowMinimized,
            .windowDeminiaturized,
            .uiElementDestroyed,
            .mainWindowChanged,
            .focusedWindowChanged,
        ]

        for notification in notifications {
            let watcher = NotificationWatcher(globalNotification: notification) { [weak self] pid, event, raw, info in
                self?.handleNotification(pid: pid, notification: event, rawElement: raw, userInfo: info)
            }

            do {
                try watcher.start()
                self.watchers.append(watcher)
            } catch {
                self.logger.warning("Failed to register AX notification \(notification.rawValue): \(error)")
            }
        }
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            let start = Date()
            self.refreshAllWindows()
            self.lastPollAt = Date()
            let elapsed = Date().timeIntervalSince(start)
            let sleepSeconds = max(0.05, self.config.pollInterval - elapsed)
            try? await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
        }
    }

    private func handleNotification(
        pid: pid_t,
        notification: AXNotification,
        rawElement: AXUIElement,
        userInfo: [String: Any]?)
    {
        self.lastEventAt = Date()

        let element = Element(rawElement)
        if let windowID = self.windowIdentityService.getWindowID(from: element) {
            self.refreshWindow(windowID: windowID)
            return
        }

        if let userInfo,
           let attr = userInfo[AXAttributeNames.kAXWindowAttribute],
           let windowID = self.windowIdentityService.windowIDFromAttribute(attr)
        {
            self.refreshWindow(windowID: windowID)
            return
        }

        self.logger.debug("Window tracker event missing window ID pid=\(pid) notification=\(notification.rawValue)")
    }

    private func refreshWindow(windowID: CGWindowID) {
        guard let info = self.windowIdentityService.getWindowInfo(windowID: windowID) else { return }

        let now = Date()
        var tracked = self.windows[windowID] ?? TrackedWindow(info: info, lastEventAt: nil, lastUpdatedAt: nil)
        tracked.lastEventAt = now
        tracked.lastUpdatedAt = now
        self.windows[windowID] = tracked
    }

    private func refreshAllWindows() {
        guard let windowInfo = WindowInfoHelper.getVisibleWindows() else {
            return
        }

        var newWindows: [CGWindowID: TrackedWindow] = [:]
        let now = Date()

        for entry in windowInfo {
            guard let windowID = entry[kCGWindowNumber as String] as? Int else { continue }
            guard let info = self.buildIdentityInfo(from: entry, windowID: windowID) else { continue }

            let previous = self.windows[CGWindowID(windowID)]
            newWindows[CGWindowID(windowID)] = TrackedWindow(
                info: info,
                lastEventAt: previous?.lastEventAt,
                lastUpdatedAt: now)
        }

        self.windows = newWindows
    }

    private func buildIdentityInfo(from dict: [String: Any], windowID: Int) -> WindowIdentityInfo? {
        guard let boundsDict = dict[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }

        let bounds = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0)

        let ownerPID = dict[kCGWindowOwnerPID as String] as? Int ?? 0
        let app = NSRunningApplication(processIdentifier: pid_t(ownerPID))
        let title = dict[kCGWindowName as String] as? String
        let layer = dict[kCGWindowLayer as String] as? Int ?? 0
        let alpha = dict[kCGWindowAlpha as String] as? CGFloat ?? 1.0

        return WindowIdentityInfo(
            windowID: CGWindowID(windowID),
            title: title,
            bounds: bounds,
            ownerPID: pid_t(ownerPID),
            applicationName: app?.localizedName,
            bundleIdentifier: app?.bundleIdentifier,
            layer: layer,
            alpha: alpha,
            axIdentifier: nil)
    }
}
