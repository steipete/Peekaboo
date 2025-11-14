import AppKit
import Foundation
import PeekabooCore
@testable import PeekabooCLI

@MainActor
final class StubRunningApplication: RunningApplicationHandle {
    var localizedName: String?
    var bundleIdentifier: String?
    var processIdentifier: Int32
    private(set) var isActiveState: Bool
    private let requiredReadyChecks: Int
    private var readyCheckCount = 0
    private(set) var activateCalls: [NSApplication.ActivationOptions] = []

    init(
        localizedName: String? = "StubApp",
        bundleIdentifier: String? = "com.example.stub",
        processIdentifier: Int32 = 42,
        startActive: Bool = false,
        readyAfterChecks: Int = 1
    ) {
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.isActiveState = startActive
        self.requiredReadyChecks = readyAfterChecks
    }

    var isFinishedLaunching: Bool {
        self.readyCheckCount += 1
        return self.readyCheckCount >= self.requiredReadyChecks
    }

    var isActive: Bool { self.isActiveState }

    @discardableResult
    func activate(options: NSApplication.ActivationOptions) -> Bool {
        self.activateCalls.append(options)
        self.isActiveState = true
        return true
    }
}

@MainActor
final class StubApplicationLauncher: ApplicationLaunching {
    struct LaunchCall: Equatable {
        let appURL: URL
        let activates: Bool
    }

    struct LaunchWithDocsCall: Equatable {
        let appURL: URL
        let documentURLs: [URL]
        let activates: Bool
    }

    struct OpenCall: Equatable {
        let target: URL
        let handler: URL?
        let activates: Bool
    }

    var launchCalls: [LaunchCall] = []
    var launchWithDocsCalls: [LaunchWithDocsCall] = []
    var openCalls: [OpenCall] = []

    var launchResponses: [StubRunningApplication] = []
    var launchWithDocsResponses: [StubRunningApplication] = []
    var openResponses: [StubRunningApplication] = []

    func launchApplication(at url: URL, activates: Bool) async throws -> any RunningApplicationHandle {
        self.launchCalls.append(.init(appURL: url, activates: activates))
        if !self.launchResponses.isEmpty {
            return self.launchResponses.removeFirst()
        }
        return StubRunningApplication()
    }

    func launchApplication(
        _ url: URL,
        opening documents: [URL],
        activates: Bool
    ) async throws -> any RunningApplicationHandle {
        self.launchWithDocsCalls.append(.init(appURL: url, documentURLs: documents, activates: activates))
        if !self.launchWithDocsResponses.isEmpty {
            return self.launchWithDocsResponses.removeFirst()
        }
        return StubRunningApplication()
    }

    func openTarget(
        _ targetURL: URL,
        handlerURL: URL?,
        activates: Bool
    ) async throws -> any RunningApplicationHandle {
        self.openCalls.append(.init(target: targetURL, handler: handlerURL, activates: activates))
        if !self.openResponses.isEmpty {
            return self.openResponses.removeFirst()
        }
        return StubRunningApplication()
    }
}

@MainActor
final class StubApplicationURLResolver: ApplicationURLResolving {
    var applicationMap: [String: URL] = [:]
    var bundleMap: [String: URL] = [:]

    func resolveApplication(appIdentifier: String, bundleId: String?) throws -> URL {
        if let bundleId, let url = self.bundleMap[bundleId] {
            return url
        }
        if let url = self.applicationMap[appIdentifier] {
            return url
        }
        throw NotFoundError.application(appIdentifier)
    }

    func resolveBundleIdentifier(_ bundleId: String) throws -> URL {
        if let url = self.bundleMap[bundleId] {
            return url
        }
        throw NotFoundError.application("Bundle ID: \(bundleId)")
    }
}
