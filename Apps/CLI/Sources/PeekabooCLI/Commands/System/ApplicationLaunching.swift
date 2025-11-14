import AppKit
import Foundation
import PeekabooCore

// MARK: - Running Application Handle

@MainActor
protocol RunningApplicationHandle {
    var localizedName: String? { get }
    var bundleIdentifier: String? { get }
    var processIdentifier: Int32 { get }
    var isFinishedLaunching: Bool { get }
    var isActive: Bool { get }

    @discardableResult
    func activate(options: NSApplication.ActivationOptions) -> Bool
}

@MainActor
extension NSRunningApplication: RunningApplicationHandle {}

// MARK: - Launcher abstraction

@MainActor
protocol ApplicationLaunching {
    func launchApplication(at url: URL, activates: Bool) async throws -> any RunningApplicationHandle
    func launchApplication(_ url: URL, opening documents: [URL], activates: Bool) async throws
        -> any RunningApplicationHandle
    func openTarget(_ targetURL: URL, handlerURL: URL?, activates: Bool) async throws -> any RunningApplicationHandle
}

@MainActor
enum ApplicationLaunchEnvironment {
    static var launcher: any ApplicationLaunching = NSWorkspaceApplicationLauncher()
}

@MainActor
final class NSWorkspaceApplicationLauncher: ApplicationLaunching {
    func launchApplication(at url: URL, activates: Bool) async throws -> any RunningApplicationHandle {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        return try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    func launchApplication(
        _ url: URL,
        opening documents: [URL],
        activates: Bool
    ) async throws -> any RunningApplicationHandle {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        return try await NSWorkspace.shared.open(documents, withApplicationAt: url, configuration: configuration)
    }

    func openTarget(_ targetURL: URL, handlerURL: URL?, activates: Bool) async throws -> any RunningApplicationHandle {
        if let handlerURL {
            return try await self.launchApplication(handlerURL, opening: [targetURL], activates: activates)
        } else {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = activates
            return try await NSWorkspace.shared.open(targetURL, configuration: configuration)
        }
    }
}

// MARK: - Application URL resolver

@MainActor
protocol ApplicationURLResolving {
    func resolveApplication(appIdentifier: String, bundleId: String?) throws -> URL
    func resolveBundleIdentifier(_ bundleId: String) throws -> URL
}

@MainActor
enum ApplicationURLResolverEnvironment {
    static var resolver: any ApplicationURLResolving = DefaultApplicationURLResolver()
}

@MainActor
final class DefaultApplicationURLResolver: ApplicationURLResolving {
    func resolveApplication(appIdentifier: String, bundleId: String?) throws -> URL {
        if let bundleId {
            return try self.resolveBundleIdentifier(bundleId)
        }

        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appIdentifier) {
            return bundleURL
        }

        if let namedURL = self.findApplicationByName(appIdentifier) {
            return namedURL
        }

        if appIdentifier.contains("/") {
            return URL(fileURLWithPath: appIdentifier)
        }

        throw NotFoundError.application(appIdentifier)
    }

    func resolveBundleIdentifier(_ bundleId: String) throws -> URL {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            throw NotFoundError.application("Bundle ID: \(bundleId)")
        }
        return url
    }

    private func findApplicationByName(_ name: String) -> URL? {
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "~/Applications",
            "/Applications/Utilities"
        ].map { NSString(string: $0).expandingTildeInPath }

        for path in searchPaths {
            let appPath = "\(path)/\(name).app"
            if FileManager.default.fileExists(atPath: appPath) {
                return URL(fileURLWithPath: appPath)
            }
        }
        return nil
    }
}
