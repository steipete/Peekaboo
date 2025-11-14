import AppKit
import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

@available(macOS 14.0, *)
@MainActor
struct OpenCommand: ParsableCommand, OutputFormattable, ErrorHandlingCommand, RuntimeOptionsConfigurable {
    @MainActor
    static var launcher: any ApplicationLaunching = ApplicationLaunchEnvironment.launcher
    @MainActor
    static var resolver: any ApplicationURLResolving = ApplicationURLResolverEnvironment.resolver

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
            let targetURL = try Self.resolveTarget(self.target)
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

    static func resolveTarget(_ target: String, cwd: String = FileManager.default.currentDirectoryPath) throws -> URL {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError("Target must not be empty")
        }

        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            return url
        }

        let expanded = NSString(string: trimmed).expandingTildeInPath
        let absolutePath: String = if expanded.hasPrefix("/") {
            expanded
        } else {
            NSString(string: cwd).appendingPathComponent(expanded)
        }

        return URL(fileURLWithPath: absolutePath)
    }

    private func resolveHandlerApplication() throws -> URL? {
        if let bundleId {
            return try Self.resolver.resolveBundleIdentifier(bundleId)
        }

        if let app {
            return try Self.resolver.resolveApplication(appIdentifier: app, bundleId: nil)
        }

        return nil
    }

    private func openTarget(targetURL: URL, handlerURL: URL?) async throws -> any RunningApplicationHandle {
        try await Self.launcher.openTarget(targetURL, handlerURL: handlerURL, activates: self.shouldFocus)
    }

    private func waitIfNeeded(for app: any RunningApplicationHandle) async throws {
        guard self.waitUntilReady else { return }
        try await self.waitForApplicationReady(app)
    }

    private func activateIfNeeded(_ app: any RunningApplicationHandle) -> Bool {
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

    private func renderSuccess(app: any RunningApplicationHandle, targetURL: URL, didFocus: Bool) {
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

    private func waitForApplicationReady(_ app: any RunningApplicationHandle, timeout: TimeInterval = 10) async throws {
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
