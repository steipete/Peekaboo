import Foundation
import PeekabooAgentRuntime
import PeekabooAutomation
import PeekabooCore
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

@MainActor
struct OpenCommandFlowTests {
    @Test
    func `Open command uses launcher for default handler`() async throws {
        let launcher = StubApplicationLauncher()
        launcher.openResponses = [StubRunningApplication(localizedName: "Safari", readyAfterChecks: 1)]
        let resolver = StubApplicationURLResolver()

        let originalLauncher = OpenCommand.launcher
        let originalResolver = OpenCommand.resolver
        OpenCommand.launcher = launcher
        OpenCommand.resolver = resolver
        defer {
            OpenCommand.launcher = originalLauncher
            OpenCommand.resolver = originalResolver
        }

        var command = OpenCommand()
        command.target = "https://example.com"
        let runtime = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: true, logLevel: nil),
            services: PeekabooServices()
        )
        try await command.run(using: runtime)

        #expect(launcher.openCalls.count == 1)
        let call = try #require(launcher.openCalls.first)
        #expect(call.handler == nil)
        #expect(call.target.absoluteString == "https://example.com")
        #expect(call.activates == true)
    }

    @Test
    func `Open command respects handler override and focus flags`() async throws {
        let launcher = StubApplicationLauncher()
        launcher.openResponses = [StubRunningApplication(localizedName: "Notes", readyAfterChecks: 1)]
        let resolver = StubApplicationURLResolver()
        resolver.applicationMap["Notes"] = URL(fileURLWithPath: "/Applications/Notes.app")

        let originalLauncher = OpenCommand.launcher
        let originalResolver = OpenCommand.resolver
        OpenCommand.launcher = launcher
        OpenCommand.resolver = resolver
        defer {
            OpenCommand.launcher = originalLauncher
            OpenCommand.resolver = originalResolver
        }

        var command = OpenCommand()
        command.target = "~/Desktop/test.txt"
        command.app = "Notes"
        command.noFocus = true
        let runtime = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: true, logLevel: nil),
            services: PeekabooServices()
        )
        try await command.run(using: runtime)

        let call = try #require(launcher.openCalls.first)
        #expect(call.handler == URL(fileURLWithPath: "/Applications/Notes.app"))
        #expect(call.activates == false)
        #expect(call.target.path.hasSuffix("/Desktop/test.txt"))
    }
}

@MainActor
struct AppCommandLaunchFlowTests {
    @Test
    func `Launch without --open activates app`() async throws {
        let launcher = StubApplicationLauncher()
        launcher.launchResponses = [StubRunningApplication(localizedName: "Finder", readyAfterChecks: 1)]
        let resolver = StubApplicationURLResolver()
        resolver.applicationMap["Finder"] = URL(fileURLWithPath: "/System/Applications/Finder.app")

        let originalLauncher = AppCommand.LaunchSubcommand.launcher
        let originalResolver = AppCommand.LaunchSubcommand.resolver
        AppCommand.LaunchSubcommand.launcher = launcher
        AppCommand.LaunchSubcommand.resolver = resolver
        defer {
            AppCommand.LaunchSubcommand.launcher = originalLauncher
            AppCommand.LaunchSubcommand.resolver = originalResolver
        }

        var command = AppCommand.LaunchSubcommand()
        command.app = "Finder"
        let runtime = self.makeRuntime()
        try await command.run(using: runtime)

        let call = try #require(launcher.launchCalls.first)
        #expect(call.appURL == URL(fileURLWithPath: "/System/Applications/Finder.app"))
        #expect(call.activates == true)
    }

    @Test
    func `Launch with --open documents skips focus when requested`() async throws {
        let launcher = StubApplicationLauncher()
        launcher.launchWithDocsResponses = [StubRunningApplication(localizedName: "Preview", readyAfterChecks: 1)]
        let resolver = StubApplicationURLResolver()
        resolver.applicationMap["Preview"] = URL(fileURLWithPath: "/Applications/Preview.app")

        let originalLauncher = AppCommand.LaunchSubcommand.launcher
        let originalResolver = AppCommand.LaunchSubcommand.resolver
        AppCommand.LaunchSubcommand.launcher = launcher
        AppCommand.LaunchSubcommand.resolver = resolver
        defer {
            AppCommand.LaunchSubcommand.launcher = originalLauncher
            AppCommand.LaunchSubcommand.resolver = originalResolver
        }

        var command = AppCommand.LaunchSubcommand()
        command.app = "Preview"
        command.noFocus = true
        command.openTargets = ["~/Desktop/file1.pdf", "https://example.com"]
        let runtime = self.makeRuntime()
        try await command.run(using: runtime)

        let call = try #require(launcher.launchWithDocsCalls.first)
        #expect(call.activates == false)
        #expect(call.documentURLs.count == 2)
        #expect(call.documentURLs[0].path.hasSuffix("/Desktop/file1.pdf"))
        #expect(call.documentURLs[1].absoluteString == "https://example.com")
    }

    @Test
    func `Launch without --open skips focus when requested`() async throws {
        let launcher = StubApplicationLauncher()
        launcher.launchResponses = [StubRunningApplication(localizedName: "Notes", readyAfterChecks: 1)]
        let resolver = StubApplicationURLResolver()
        resolver.applicationMap["Notes"] = URL(fileURLWithPath: "/Applications/Notes.app")

        let originalLauncher = AppCommand.LaunchSubcommand.launcher
        let originalResolver = AppCommand.LaunchSubcommand.resolver
        AppCommand.LaunchSubcommand.launcher = launcher
        AppCommand.LaunchSubcommand.resolver = resolver
        defer {
            AppCommand.LaunchSubcommand.launcher = originalLauncher
            AppCommand.LaunchSubcommand.resolver = originalResolver
        }

        var command = AppCommand.LaunchSubcommand()
        command.app = "Notes"
        command.noFocus = true
        let runtime = self.makeRuntime()
        try await command.run(using: runtime)

        let call = try #require(launcher.launchCalls.first)
        #expect(call.activates == false)
    }

    @Test
    func `Switch to app activates through application service`() async throws {
        let application = ServiceApplicationInfo(
            processIdentifier: 42,
            bundleIdentifier: "com.apple.finder",
            name: "Finder"
        )
        let applicationService = RecordingApplicationService(applications: [application])

        var command = AppCommand.SwitchSubcommand()
        command.to = "Finder"
        let runtime = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: true, logLevel: nil),
            services: ServicesWithApplicationStub(applications: applicationService)
        )
        try await command.run(using: runtime)

        #expect(applicationService.activateCalls == ["Finder"])
    }

    private func makeRuntime() -> CommandRuntime {
        CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: true, logLevel: nil),
            services: PeekabooServices(snapshotManager: InMemorySnapshotManager())
        )
    }
}

@MainActor
private final class ServicesWithApplicationStub: PeekabooServiceProviding {
    private let base = PeekabooServices(snapshotManager: InMemorySnapshotManager())
    private let stubApplications: any ApplicationServiceProtocol

    init(applications: any ApplicationServiceProtocol) {
        self.stubApplications = applications
    }

    func ensureVisualizerConnection() {
        self.base.ensureVisualizerConnection()
    }

    var logging: any LoggingServiceProtocol {
        self.base.logging
    }

    var screenCapture: any ScreenCaptureServiceProtocol {
        self.base.screenCapture
    }

    var applications: any ApplicationServiceProtocol {
        self.stubApplications
    }

    var automation: any UIAutomationServiceProtocol {
        self.base.automation
    }

    var windows: any WindowManagementServiceProtocol {
        self.base.windows
    }

    var menu: any MenuServiceProtocol {
        self.base.menu
    }

    var dock: any DockServiceProtocol {
        self.base.dock
    }

    var dialogs: any DialogServiceProtocol {
        self.base.dialogs
    }

    var snapshots: any SnapshotManagerProtocol {
        self.base.snapshots
    }

    var files: any FileServiceProtocol {
        self.base.files
    }

    var clipboard: any ClipboardServiceProtocol {
        self.base.clipboard
    }

    var configuration: PeekabooCore.ConfigurationManager {
        self.base.configuration
    }

    var process: any ProcessServiceProtocol {
        self.base.process
    }

    var permissions: PermissionsService {
        self.base.permissions
    }

    var audioInput: AudioInputService {
        self.base.audioInput
    }

    var screens: any ScreenServiceProtocol {
        self.base.screens
    }

    var agent: (any AgentServiceProtocol)? {
        self.base.agent
    }
}

@MainActor
private final class RecordingApplicationService: ApplicationServiceProtocol {
    private let applications: [ServiceApplicationInfo]
    private(set) var activateCalls: [String] = []

    init(applications: [ServiceApplicationInfo]) {
        self.applications = applications
    }

    func listApplications() async throws -> UnifiedToolOutput<ServiceApplicationListData> {
        UnifiedToolOutput(
            data: ServiceApplicationListData(applications: self.applications),
            summary: .init(brief: "Stub application list", status: .success),
            metadata: .init(duration: 0)
        )
    }

    func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        if let match = self.applications.first(where: { $0.name == identifier || $0.bundleIdentifier == identifier }) {
            return match
        }
        throw PeekabooError.appNotFound(identifier)
    }

    func activateApplication(identifier: String) async throws {
        self.activateCalls.append(identifier)
    }

    func listWindows(
        for _: String,
        timeout _: Float?
    ) async throws -> UnifiedToolOutput<ServiceWindowListData> {
        UnifiedToolOutput(
            data: ServiceWindowListData(windows: [], targetApplication: nil),
            summary: .init(brief: "Stub window list", status: .success),
            metadata: .init(duration: 0)
        )
    }

    func getFrontmostApplication() async throws -> ServiceApplicationInfo {
        guard let first = self.applications.first else {
            throw PeekabooError.appNotFound("frontmost")
        }
        return first
    }

    func isApplicationRunning(identifier: String) async -> Bool {
        self.applications.contains { $0.name == identifier || $0.bundleIdentifier == identifier }
    }

    func launchApplication(identifier: String) async throws -> ServiceApplicationInfo {
        try await self.findApplication(identifier: identifier)
    }

    func quitApplication(identifier _: String, force _: Bool) async throws -> Bool {
        true
    }

    func hideApplication(identifier _: String) async throws {}
    func unhideApplication(identifier _: String) async throws {}
    func hideOtherApplications(identifier _: String) async throws {}
    func showAllApplications() async throws {}
}
