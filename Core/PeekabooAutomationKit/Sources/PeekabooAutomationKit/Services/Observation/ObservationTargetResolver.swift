import CoreGraphics
import Foundation

@MainActor
public protocol ObservationTargetResolving: Sendable {
    func resolve(
        _ target: DesktopObservationTargetRequest,
        snapshot: DesktopStateSnapshot) async throws -> ResolvedObservationTarget
}

@MainActor
public final class ObservationTargetResolver: ObservationTargetResolving {
    private let applications: any ApplicationServiceProtocol

    public init(applications: any ApplicationServiceProtocol) {
        self.applications = applications
    }

    public func resolve(
        _ target: DesktopObservationTargetRequest,
        snapshot: DesktopStateSnapshot) async throws -> ResolvedObservationTarget
    {
        switch target {
        case let .screen(index):
            ResolvedObservationTarget(kind: .screen(index: index))

        case .allScreens:
            ResolvedObservationTarget(kind: .screen(index: nil))

        case .frontmost:
            try await self.resolveFrontmost(snapshot: snapshot)

        case let .app(identifier, selection):
            try await self.resolveApplication(identifier: identifier, selection: selection, snapshot: snapshot)

        case let .pid(pid, selection):
            try await self.resolvePID(pid, selection: selection, snapshot: snapshot)

        case let .windowID(windowID):
            self.resolveWindowID(windowID)

        case let .area(rect):
            ResolvedObservationTarget(kind: .area(rect), bounds: rect)

        case .menubar:
            ResolvedObservationTarget(kind: .menubar)

        case .menubarPopover:
            ResolvedObservationTarget(kind: .menubarPopover)
        }
    }

    private func resolveFrontmost(snapshot: DesktopStateSnapshot) async throws -> ResolvedObservationTarget {
        let app = if let frontmost = snapshot.frontmostApplication {
            Self.serviceApplicationInfo(from: frontmost)
        } else {
            try await self.applications.getFrontmostApplication()
        }
        return try await self.resolveApplication(app, selection: .automatic)
    }

    private func resolvePID(
        _ pid: Int32,
        selection: WindowSelection?,
        snapshot: DesktopStateSnapshot) async throws -> ResolvedObservationTarget
    {
        let app: ServiceApplicationInfo? = if let snapshotApp = snapshot.runningApplications
            .first(where: { $0.processIdentifier == pid })
        {
            Self.serviceApplicationInfo(from: snapshotApp)
        } else {
            try await self.fallbackApplication(pid: pid)
        }

        guard let app else {
            throw DesktopObservationError.targetNotFound("pid \(pid)")
        }
        return try await self.resolveApplication(app, selection: selection ?? .automatic)
    }

    private func resolveWindowID(_ windowID: CGWindowID) -> ResolvedObservationTarget {
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

    private func resolveApplication(
        identifier: String,
        selection: WindowSelection?,
        snapshot: DesktopStateSnapshot) async throws -> ResolvedObservationTarget
    {
        let app: ServiceApplicationInfo = if let snapshotApp = Self.application(
            matching: identifier,
            in: snapshot.runningApplications)
        {
            Self.serviceApplicationInfo(from: snapshotApp)
        } else {
            try await self.applications.findApplication(identifier: identifier)
        }
        return try await self.resolveApplication(app, selection: selection ?? .automatic)
    }

    private func resolveApplication(
        _ app: ServiceApplicationInfo,
        selection: WindowSelection) async throws -> ResolvedObservationTarget
    {
        let lookupIdentifier = app.bundleIdentifier ?? app.name
        let windows = try await self.applications.listWindows(for: lookupIdentifier, timeout: 2).data.windows
        let selectedWindow = try self.selectWindow(from: windows, selection: selection)
        let context = WindowContext(
            applicationName: app.name,
            applicationBundleId: app.bundleIdentifier,
            applicationProcessId: app.processIdentifier,
            windowTitle: selectedWindow?.title,
            windowID: selectedWindow?.windowID,
            windowBounds: selectedWindow?.bounds)

        return ResolvedObservationTarget(
            kind: selectedWindow.map { .windowID(CGWindowID($0.windowID)) } ?? .appWindow,
            app: ApplicationIdentity(app),
            window: selectedWindow.map(WindowIdentity.init),
            bounds: selectedWindow?.bounds,
            detectionContext: context)
    }

    private func selectWindow(
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

    private func fallbackApplication(pid: Int32) async throws -> ServiceApplicationInfo? {
        let applications = try await self.applications.listApplications().data.applications
        return applications.first(where: { $0.processIdentifier == pid })
    }

    private static func application(
        matching identifier: String,
        in applications: [ApplicationIdentity]) -> ApplicationIdentity?
    {
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let uppercasedIdentifier = trimmedIdentifier.uppercased()
        if uppercasedIdentifier.hasPrefix("PID:"),
           let pid = Int32(trimmedIdentifier.dropFirst("PID:".count)),
           let match = applications.first(where: { $0.processIdentifier == pid })
        {
            return match
        }

        if let bundleMatch = applications.first(where: { $0.bundleIdentifier == trimmedIdentifier }) {
            return bundleMatch
        }

        if let exactName = applications.first(where: {
            $0.name.compare(trimmedIdentifier, options: .caseInsensitive) == .orderedSame
        }) {
            return exactName
        }

        return applications.first(where: {
            $0.name.localizedCaseInsensitiveContains(trimmedIdentifier)
        })
    }

    private static func serviceApplicationInfo(from identity: ApplicationIdentity) -> ServiceApplicationInfo {
        ServiceApplicationInfo(
            processIdentifier: identity.processIdentifier,
            bundleIdentifier: identity.bundleIdentifier,
            name: identity.name,
            windowCount: 0)
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
