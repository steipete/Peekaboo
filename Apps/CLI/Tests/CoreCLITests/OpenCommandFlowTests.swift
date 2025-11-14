import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("OpenCommand Flow Tests")
@MainActor
struct OpenCommandFlowTests {
    @Test("Open command uses launcher for default handler")
    func openCommandDefaultHandler() async throws {
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

    @Test("Open command respects handler override and focus flags")
    func openCommandWithHandlerNoFocus() async throws {
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

@Suite("AppCommand Launch Flow Tests")
@MainActor
struct AppCommandLaunchFlowTests {
    @Test("Launch without --open activates app")
    func launchWithoutDocuments() async throws {
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
        let runtime = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: true, logLevel: nil),
            services: PeekabooServices()
        )
        try await command.run(using: runtime)

        let call = try #require(launcher.launchCalls.first)
        #expect(call.appURL == URL(fileURLWithPath: "/System/Applications/Finder.app"))
        #expect(call.activates == true)
    }

    @Test("Launch with --open documents skips focus when requested")
    func launchWithDocumentsNoFocus() async throws {
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
        let runtime = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: true, logLevel: nil),
            services: PeekabooServices()
        )
        try await command.run(using: runtime)

        let call = try #require(launcher.launchWithDocsCalls.first)
        #expect(call.activates == false)
        #expect(call.documentURLs.count == 2)
        #expect(call.documentURLs[0].path.hasSuffix("/Desktop/file1.pdf"))
        #expect(call.documentURLs[1].absoluteString == "https://example.com")
    }
}
