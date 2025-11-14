import AppKit
import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

@available(macOS 14.0, *)
@MainActor
struct OpenCommand: ParsableCommand, OutputFormattable, ErrorHandlingCommand, RuntimeOptionsConfigurable {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "open",
                abstract: "Open a URL or file with its default (or specified) application",
                discussion: """
                Mirrors macOS `open` while layering Peekaboo's focus controls, structured output,
                and error handling.

                EXAMPLES:
                  peekaboo open https://example.com
                  peekaboo open ~/Documents/report.pdf
                  peekaboo open ~/Desktop --app Finder --no-focus
                  peekaboo open myfile.txt --bundle-id com.apple.TextEdit --wait-until-ready
                """
            )
        }
    }

    @Argument(help: "URL or file path to open")
    var target: String

    @Option(help: "Explicit application (name or path) to handle the target")
    var app: String?

    @Option(help: "Bundle identifier of the application to handle the target")
    var bundleId: String?

    @Flag(help: "Wait until the handling application finishes launching")
    var waitUntilReady = false

    @Flag(name: .customLong("no-focus"), help: "Do not bring the handling application to the foreground")
    var noFocus = false

    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }
    private var shouldFocus: Bool { !self.noFocus }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.prepare(using: runtime)

        do {
            let targetURL = try self.resolveTargetURL()
            let handlerURL = try self.resolveHandlerApplication()
            let appInstance = try await self.openTarget(targetURL: targetURL, handlerURL: handlerURL)
            try await self.waitIfNeeded(for: appInstance)
            let didFocus = self.activateIfNeeded(appInstance)
            self.renderSuccess(app: appInstance, targetURL: targetURL, didFocus: didFocus)
        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    private mutating func prepare(using runtime: CommandRuntime) {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)
    }

    private func resolveTargetURL() throws -> URL {
        let trimmed = self.target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError("Target must not be empty")
        }

        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            return url
        }

        let expanded = NSString(string: trimmed).expandingTildeInPath
        let absolutePath: String
        if expanded.hasPrefix("/") {
            absolutePath = expanded
        } else {
            absolutePath = NSString(string: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(expanded)
        }

        return URL(fileURLWithPath: absolutePath)
    }

    private func resolveHandlerApplication() throws -> URL? {
        if let bundleId {
            guard let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                throw NotFoundError.application("Bundle ID: \(bundleId)")
            }
            return bundleURL
        }

        guard let app else { return nil }

        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) {
            return bundleURL
        }

        let expandedPath = NSString(string: app).expandingTildeInPath
        if expandedPath.hasSuffix(".app"), FileManager.default.fileExists(atPath: expandedPath) {
            return URL(fileURLWithPath: expandedPath)
        }

        if let namedURL = self.findApplicationByName(app) {
            return namedURL
        }

        if expandedPath.contains("/") {
            return URL(fileURLWithPath: expandedPath)
        }

        throw NotFoundError.application(app)
    }

    private func openTarget(targetURL: URL, handlerURL: URL?) async throws -> NSRunningApplication {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = self.shouldFocus

        if let handlerURL {
            return try await NSWorkspace.shared.open(
                [targetURL],
                withApplicationAt: handlerURL,
                configuration: config
            )
        } else {
            return try await NSWorkspace.shared.open(targetURL, configuration: config)
        }
    }

    private func waitIfNeeded(for app: NSRunningApplication) async throws {
        guard self.waitUntilReady else { return }
        try await self.waitForApplicationReady(app)
    }

    private func activateIfNeeded(_ app: NSRunningApplication) -> Bool {
        guard self.shouldFocus else { return false }

        if app.isActive {
            return true
        }

        let activated = app.activate(options: [])
        if !activated {
            self.logger.warn("Open succeeded but failed to focus \(app.localizedName ?? "application")")
        }
        return activated
    }

    private func renderSuccess(app: NSRunningApplication, targetURL: URL, didFocus: Bool) {
        let result = OpenResult(
            success: true,
            action: "open",
            target: self.target,
            resolved_target: self.normalizedTargetString(for: targetURL),
            handler_app: app.localizedName ?? app.bundleIdentifier ?? "unknown",
            bundle_id: app.bundleIdentifier,
            pid: app.processIdentifier,
            is_ready: app.isFinishedLaunching,
            focused: didFocus && self.shouldFocus
        )

        output(result) {
            let handler = app.localizedName ?? app.bundleIdentifier ?? "application"
            print("✅ Opened \(result.resolved_target) with \(handler)")
        }
    }

    private func waitForApplicationReady(_ app: NSRunningApplication, timeout: TimeInterval = 10) async throws {
        let start = Date()
        while !app.isFinishedLaunching {
            if Date().timeIntervalSince(start) > timeout {
                throw PeekabooError.timeout("Application did not become ready within \(Int(timeout)) seconds")
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func normalizedTargetString(for url: URL) -> String {
        url.isFileURL ? url.path : url.absoluteString
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

struct OpenResult: Codable {
    let success: Bool
    let action: String
    let target: String
    let resolved_target: String
    let handler_app: String
    let bundle_id: String?
    let pid: Int32
    let is_ready: Bool
    let focused: Bool
}

@MainActor
extension OpenCommand: AsyncRuntimeCommand {}

@MainActor
extension OpenCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.target = try values.decodePositional(0, label: "target", as: String.self)
        self.app = values.singleOption("app")
        self.bundleId = values.singleOption("bundleId")
        self.waitUntilReady = values.flag("waitUntilReady")
        self.noFocus = values.flag("noFocus")
    }
}
