import CoreGraphics
import Foundation

@MainActor
public protocol ObservationTargetResolving: Sendable {
    func resolve(_ target: DesktopObservationTargetRequest) async throws -> ResolvedObservationTarget
}

@MainActor
public final class ObservationTargetResolver: ObservationTargetResolving {
    private let applications: any ApplicationServiceProtocol

    public init(applications: any ApplicationServiceProtocol) {
        self.applications = applications
    }

    public func resolve(_ target: DesktopObservationTargetRequest) async throws -> ResolvedObservationTarget {
        switch target {
        case let .screen(index):
            ResolvedObservationTarget(kind: .screen(index: index))

        case .allScreens:
            ResolvedObservationTarget(kind: .screen(index: nil))

        case .frontmost:
            try await self.resolveFrontmost()

        case let .app(identifier, selection):
            try await self.resolveApplication(identifier: identifier, selection: selection)

        case let .pid(pid, selection):
            try await self.resolvePID(pid, selection: selection)

        case let .windowID(windowID):
            ResolvedObservationTarget(kind: .windowID(windowID))

        case let .area(rect):
            ResolvedObservationTarget(kind: .area(rect), bounds: rect)

        case .menubar:
            ResolvedObservationTarget(kind: .menubar)

        case .menubarPopover:
            ResolvedObservationTarget(kind: .menubarPopover)
        }
    }

    private func resolveFrontmost() async throws -> ResolvedObservationTarget {
        let app = try await self.applications.getFrontmostApplication()
        return try await self.resolveApplication(app, selection: .automatic)
    }

    private func resolvePID(_ pid: Int32, selection: WindowSelection?) async throws -> ResolvedObservationTarget {
        let applications = try await self.applications.listApplications().data.applications
        guard let app = applications.first(where: { $0.processIdentifier == pid }) else {
            throw DesktopObservationError.targetNotFound("pid \(pid)")
        }
        return try await self.resolveApplication(app, selection: selection ?? .automatic)
    }

    private func resolveApplication(
        identifier: String,
        selection: WindowSelection?) async throws -> ResolvedObservationTarget
    {
        let app = try await self.applications.findApplication(identifier: identifier)
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

    static func bestWindow(from windows: [ServiceWindowInfo]) -> ServiceWindowInfo? {
        let visible = windows.filter { window in
            !window.isMinimized
                && !window.isOffScreen
                && window.isOnScreen
                && window.layer == 0
                && window.alpha > 0
                && window.isShareableWindow
                && !window.isExcludedFromWindowsMenu
        }

        return visible.max { lhs, rhs in
            let lhsArea = lhs.bounds.width * lhs.bounds.height
            let rhsArea = rhs.bounds.width * rhs.bounds.height
            if lhsArea == rhsArea {
                return lhs.index > rhs.index
            }
            return lhsArea < rhsArea
        }
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
