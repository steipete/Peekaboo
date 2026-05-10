//
//  CommandRuntime.swift
//  PeekabooCLI
//

import Darwin
import Foundation
import PeekabooAutomation
import PeekabooAutomationKit
import PeekabooBridge
import PeekabooCore
import PeekabooFoundation
import PeekabooProtocols
import Tachikoma

/// Shared options that control logging and output behavior.
struct CommandRuntimeOptions {
    var verbose = false
    var jsonOutput = false
    var logLevel: LogLevel?
    var captureEnginePreference: String?
    var inputStrategy: UIInputStrategy?
    var preferRemote = true
    var autoStartDaemon = true
    var bridgeSocketPath: String?
    var requiresElementActions = false

    func makeConfiguration() -> CommandRuntime.Configuration {
        CommandRuntime.Configuration(
            verbose: self.verbose,
            jsonOutput: self.jsonOutput,
            logLevel: self.logLevel,
            captureEnginePreference: self.captureEnginePreference,
            inputStrategy: self.inputStrategy
        )
    }

    func applyingEnvironmentOverrides(environment: [String: String]) -> CommandRuntimeOptions {
        var options = self
        if options.captureEnginePreference == nil,
           let captureEngine = Self.captureEnginePreference(environment: environment) {
            options.captureEnginePreference = captureEngine
            options.preferRemote = false
        }
        return options
    }

    static func captureEnginePreference(environment: [String: String]) -> String? {
        guard let value = environment["PEEKABOO_CAPTURE_ENGINE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty else {
            return nil
        }
        return value
    }
}

/// Runtime context passed to runtime-aware commands.
struct CommandRuntime {
    static let defaultDaemonIdleTimeoutSeconds: TimeInterval = 300

    @TaskLocal
    private static var serviceOverride: PeekabooServices?

    struct Configuration {
        var verbose: Bool
        var jsonOutput: Bool
        var logLevel: LogLevel?
        var captureEnginePreference: String?
        var inputStrategy: UIInputStrategy?
    }

    let configuration: Configuration
    let hostDescription: String
    @MainActor let services: any PeekabooServiceProviding
    @MainActor let logger: Logger

    @MainActor
    init(
        configuration: Configuration,
        services: any PeekabooServiceProviding,
        hostDescription: String = "local (in-process)"
    ) {
        // Keep Tachikoma credential/profile resolution aligned with Peekaboo CLI storage.
        TachikomaConfiguration.profileDirectoryName = ".peekaboo"

        self.configuration = configuration
        self.services = services
        self.hostDescription = hostDescription
        self.logger = Logger.shared

        services.installAgentRuntimeDefaults()

        self.logger.setJsonOutputMode(configuration.jsonOutput)
        let explicitLevel = configuration.logLevel
        var shouldEnableVerbose = configuration.verbose
        if configuration.jsonOutput && explicitLevel == nil {
            shouldEnableVerbose = true
        }
        if let explicitLevel, explicitLevel <= .verbose {
            shouldEnableVerbose = true
        }

        self.logger.setVerboseMode(shouldEnableVerbose)

        if let explicitLevel {
            self.logger.setMinimumLogLevel(explicitLevel)
        } else if shouldEnableVerbose {
            self.logger.setMinimumLogLevel(.verbose)
        } else {
            self.logger.resetMinimumLogLevel()
        }

        let visualizerConsoleLevel: PeekabooProtocols.LogLevel? = if let explicitLevel {
            explicitLevel.coreLogLevel
        } else if shouldEnableVerbose {
            .debug
        } else {
            nil
        }

        VisualizationClient.shared.setConsoleLogLevelOverride(visualizerConsoleLevel)
        VisualizationClient.shared.setConsoleMirroringEnabled(configuration.verbose)

        self.services.ensureVisualizerConnection()

        self.logger.debug("Runtime host: \(hostDescription)")
    }

    @MainActor
    init(options: CommandRuntimeOptions, services: any PeekabooServiceProviding) {
        self.init(configuration: options.makeConfiguration(), services: services)
    }
}

extension CommandRuntime {
    @MainActor
    static func makeDefault(options: CommandRuntimeOptions) -> CommandRuntime {
        let effectiveOptions = options.applyingEnvironmentOverrides(environment: ProcessInfo.processInfo.environment)
        let services = self.serviceOverride ?? self.makeLocalServices(options: effectiveOptions)
        return CommandRuntime(configuration: effectiveOptions.makeConfiguration(), services: services)
    }

    @MainActor
    static func makeDefault() -> CommandRuntime {
        self.makeDefault(options: CommandRuntimeOptions())
    }

    @MainActor
    static func makeDefaultAsync(options: CommandRuntimeOptions) async -> CommandRuntime {
        let effectiveOptions = options.applyingEnvironmentOverrides(environment: ProcessInfo.processInfo.environment)
        if let override = self.serviceOverride {
            return CommandRuntime(options: effectiveOptions, services: override)
        }

        let resolution = await self.resolveServices(options: effectiveOptions)
        return CommandRuntime(
            configuration: effectiveOptions.makeConfiguration(),
            services: resolution.services,
            hostDescription: resolution.hostDescription
        )
    }

    @MainActor
    static func makeDefaultAsync() async -> CommandRuntime {
        await self.makeDefaultAsync(options: CommandRuntimeOptions())
    }

    @MainActor
    static func withInjectedServices<T>(
        _ services: PeekabooServices,
        perform operation: () async throws -> T
    ) async rethrows -> T {
        try await self.$serviceOverride.withValue(services) {
            try await operation()
        }
    }

    @MainActor
    private static func resolveServices(options: CommandRuntimeOptions)
    async -> (services: any PeekabooServiceProviding, hostDescription: String) {
        let environment = ProcessInfo.processInfo.environment
        let envNoRemote = environment["PEEKABOO_NO_REMOTE"]
        guard options.preferRemote,
              envNoRemote == nil,
              options.inputStrategy == nil,
              !self.hasInputStrategyEnvironmentOverride(environment: environment),
              !self.hasInputStrategyConfigOverride(
                  input: PeekabooAutomation.ConfigurationManager.shared.getConfiguration()?.input
              )
        else {
            return (services: self.makeLocalServices(options: options), hostDescription: "local (in-process)")
        }

        let explicitSocket = self.explicitBridgeSocket(options: options, environment: environment)

        let daemonSocketPath = self.daemonSocketPath(environment: environment)
        let candidates: [String] = if let explicitSocket, !explicitSocket.isEmpty {
            [explicitSocket]
        } else {
            [daemonSocketPath]
        }

        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            teamIdentifier: nil,
            processIdentifier: getpid(),
            hostname: Host.current().name
        )

        if let resolved = await self.resolveRemoteServices(
            candidates: candidates,
            identity: identity,
            options: options
        ) {
            return resolved
        }

        if options.autoStartDaemon,
           self.shouldAutoStartDaemon(options: options, environment: environment),
           await self.startOnDemandDaemon(socketPath: daemonSocketPath, environment: environment),
           let resolved = await self.resolveRemoteServices(
               candidates: [daemonSocketPath],
               identity: identity,
               options: options
           ) {
            return resolved
        }

        return (services: self.makeLocalServices(options: options), hostDescription: "local (in-process)")
    }

    static func explicitBridgeSocket(
        options: CommandRuntimeOptions,
        environment: [String: String]
    ) -> String? {
        if let socket = options.bridgeSocketPath, !socket.isEmpty {
            return socket
        }
        if let socket = environment["PEEKABOO_BRIDGE_SOCKET"], !socket.isEmpty {
            return socket
        }
        return nil
    }

    static func shouldAutoStartDaemon(
        options: CommandRuntimeOptions,
        environment: [String: String]
    ) -> Bool {
        options.autoStartDaemon && self.explicitBridgeSocket(options: options, environment: environment) == nil
    }

    @MainActor
    private static func resolveRemoteServices(
        candidates: [String],
        identity: PeekabooBridgeClientIdentity,
        options: CommandRuntimeOptions
    )
    async -> (services: any PeekabooServiceProviding, hostDescription: String)? {
        for socketPath in candidates {
            let client = PeekabooBridgeClient(socketPath: socketPath)
            do {
                let handshake = try await client.handshake(client: identity, requestedHost: nil)
                if self.supportsRemoteRequirements(for: handshake, options: options) {
                    let targetedHotkeyAvailability = self.targetedHotkeyAvailability(for: handshake)
                    let hostDescription = "remote \(handshake.hostKind.rawValue) via \(socketPath)" +
                        (handshake.build.map { " (build \($0))" } ?? "")
                    return (
                        services: RemotePeekabooServices(
                            client: client,
                            supportsTargetedHotkeys: targetedHotkeyAvailability.isEnabled,
                            targetedHotkeyUnavailableReason: targetedHotkeyAvailability.unavailableReason,
                            targetedHotkeyRequiresEventSynthesizingPermission:
                            targetedHotkeyAvailability.missingPermissions.contains(.postEvent),
                            supportsPostEventPermissionRequest: self.supportsPostEventPermissionRequest(
                                for: handshake
                            ),
                            supportsElementActions: self.supportsElementActions(for: handshake),
                            supportsDesktopObservation: self.supportsDesktopObservation(for: handshake)
                        ),
                        hostDescription: hostDescription
                    )
                }
            } catch {
                continue
            }
        }
        return nil
    }

    static func daemonSocketPath(environment: [String: String]) -> String {
        if let socket = environment["PEEKABOO_DAEMON_SOCKET"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !socket.isEmpty {
            return socket
        }
        return PeekabooBridgeConstants.peekabooSocketPath
    }

    static func daemonIdleTimeoutSeconds(environment: [String: String]) -> TimeInterval {
        guard let raw = environment["PEEKABOO_DAEMON_IDLE_TIMEOUT_SECONDS"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let value = TimeInterval(raw),
            value > 0 else {
            return self.defaultDaemonIdleTimeoutSeconds
        }
        return value
    }

    static func onDemandDaemonArguments(socketPath: String, idleTimeoutSeconds: TimeInterval) -> [String] {
        [
            "daemon",
            "run",
            "--mode",
            "auto",
            "--bridge-socket",
            socketPath,
            "--idle-timeout-seconds",
            String(format: "%.3f", idleTimeoutSeconds),
        ]
    }

    private static func startOnDemandDaemon(socketPath: String, environment: [String: String]) async -> Bool {
        let client = DaemonControlClient(socketPath: socketPath)
        let lockHandle = DaemonPaths.openDaemonStartupLock()
        if let fileDescriptor = lockHandle?.fileDescriptor {
            flock(fileDescriptor, LOCK_EX)
        }
        defer {
            if let fileDescriptor = lockHandle?.fileDescriptor {
                flock(fileDescriptor, LOCK_UN)
            }
            try? lockHandle?.close()
        }

        if await client.fetchStatus() != nil {
            return true
        }

        let executable = CommandLine.arguments.first ?? "/usr/local/bin/peekaboo"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = self.onDemandDaemonArguments(
            socketPath: socketPath,
            idleTimeoutSeconds: self.daemonIdleTimeoutSeconds(environment: environment)
        )
        let logHandle = DaemonPaths.openDaemonLogForAppend() ?? FileHandle.nullDevice
        process.standardOutput = logHandle
        process.standardError = logHandle
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return false
        }

        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if await client.fetchStatus() != nil {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }

    @MainActor
    private static func makeLocalServices(options: CommandRuntimeOptions) -> PeekabooServices {
        PeekabooServices(
            inputPolicy: PeekabooAutomation.ConfigurationManager.shared.getUIInputPolicy(
                cliStrategy: options.inputStrategy
            )
        )
    }

    static func hasInputStrategyEnvironmentOverride(environment: [String: String]) -> Bool {
        [
            "PEEKABOO_INPUT_STRATEGY",
            "PEEKABOO_CLICK_INPUT_STRATEGY",
            "PEEKABOO_SCROLL_INPUT_STRATEGY",
            "PEEKABOO_TYPE_INPUT_STRATEGY",
            "PEEKABOO_HOTKEY_INPUT_STRATEGY",
            "PEEKABOO_SET_VALUE_INPUT_STRATEGY",
            "PEEKABOO_PERFORM_ACTION_INPUT_STRATEGY",
        ].contains { key in
            guard let value = environment[key] else {
                return false
            }
            return UIInputStrategy(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        }
    }

    static func hasInputStrategyConfigOverride(input: PeekabooAutomation.Configuration.InputConfig?) -> Bool {
        guard let input else {
            return false
        }

        if input.defaultStrategy != nil ||
            input.click != nil ||
            input.scroll != nil ||
            input.type != nil ||
            input.hotkey != nil ||
            input.setValue != nil ||
            input.performAction != nil {
            return true
        }

        return input.perApp?.values.contains { appInput in
            appInput.defaultStrategy != nil ||
                appInput.click != nil ||
                appInput.scroll != nil ||
                appInput.type != nil ||
                appInput.hotkey != nil ||
                appInput.setValue != nil ||
                appInput.performAction != nil
        } ?? false
    }

    static func supportsRemoteRequirements(
        for handshake: PeekabooBridgeHandshakeResponse,
        options: CommandRuntimeOptions
    ) -> Bool {
        guard handshake.supportedOperations.contains(.captureScreen) else {
            return false
        }

        if options.requiresElementActions && !self.supportsElementActions(for: handshake) {
            return false
        }

        return true
    }

    static func supportsTargetedHotkeys(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        self.targetedHotkeyAvailability(for: handshake).isEnabled
    }

    static func supportsElementActions(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 3) &&
            handshake.supportedOperations.contains(.setValue) &&
            handshake.supportedOperations.contains(.performAction)
    }

    static func supportsDesktopObservation(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 5) &&
            handshake.supportedOperations.contains(.desktopObservation)
    }

    static func supportsPostEventPermissionRequest(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 2) &&
            handshake.supportedOperations.contains(.requestPostEventPermission)
    }

    static func targetedHotkeyAvailability(for handshake: PeekabooBridgeHandshakeResponse)
    -> (isEnabled: Bool, unavailableReason: String?, missingPermissions: Set<PeekabooBridgePermissionKind>) {
        guard
            handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 1),
            handshake.supportedOperations.contains(.targetedHotkey)
        else {
            return (false, nil, [])
        }

        let enabledOperations = handshake.enabledOperations ?? handshake.supportedOperations
        if enabledOperations.contains(.targetedHotkey) {
            return (true, nil, [])
        }

        let missingPermissions = self.missingPermissions(for: .targetedHotkey, handshake: handshake)
        guard !missingPermissions.isEmpty else {
            return (
                false,
                "Remote bridge host supports background hotkeys, but they are disabled by current permissions",
                []
            )
        }

        return (
            false,
            "Remote bridge host supports background hotkeys, but current permissions are missing: " +
                self.missingPermissionNames(missingPermissions).joined(separator: ", "),
            missingPermissions
        )
    }

    private static func missingPermissions(
        for operation: PeekabooBridgeOperation,
        handshake: PeekabooBridgeHandshakeResponse
    ) -> Set<PeekabooBridgePermissionKind> {
        let requiredPermissions = Set(
            handshake.permissionTags[operation.rawValue] ?? Array(operation.requiredPermissions)
        )
        let grantedPermissions = self.grantedPermissions(from: handshake.permissions)
        return requiredPermissions.subtracting(grantedPermissions)
    }

    private static func missingPermissionNames(_ permissions: Set<PeekabooBridgePermissionKind>) -> [String] {
        permissions.map(\.displayName).sorted()
    }

    private static func grantedPermissions(from status: PermissionsStatus?) -> Set<PeekabooBridgePermissionKind> {
        guard let status else { return [] }

        var granted: Set<PeekabooBridgePermissionKind> = []
        if status.screenRecording {
            granted.insert(.screenRecording)
        }
        if status.accessibility {
            granted.insert(.accessibility)
        }
        if status.appleScript {
            granted.insert(.appleScript)
        }
        if status.postEvent {
            granted.insert(.postEvent)
        }
        return granted
    }
}

extension PeekabooBridgePermissionKind {
    fileprivate var displayName: String {
        switch self {
        case .screenRecording:
            "Screen Recording"
        case .accessibility:
            "Accessibility"
        case .postEvent:
            "Event Synthesizing"
        case .appleScript:
            "AppleScript"
        }
    }
}

/// Commands that need access to verbose/json flags even before a runtime is injected
/// (e.g., during unit tests) can conform to this protocol and store the parsed options.
protocol RuntimeOptionsConfigurable {
    var runtimeOptions: CommandRuntimeOptions { get set }
}

extension RuntimeOptionsConfigurable {
    mutating func setRuntimeOptions(_ options: CommandRuntimeOptions) {
        self.runtimeOptions = options
    }
}

@propertyWrapper
struct RuntimeStorage<Value: ExpressibleByNilLiteral> {
    private var storage: Value

    init() {
        self.storage = nil
    }

    var wrappedValue: Value {
        get { self.storage }
        set { self.storage = newValue }
    }
}

extension RuntimeStorage: Codable where Value: ExpressibleByNilLiteral {
    init(from _: any Decoder) throws {
        self.storage = nil
    }

    func encode(to _: any Encoder) throws {}
}

extension RuntimeStorage: Sendable where Value: Sendable {}

extension LogLevel {
    fileprivate var coreLogLevel: PeekabooProtocols.LogLevel {
        switch self {
        case .trace: .trace
        case .verbose: .debug
        case .debug: .debug
        case .info: .info
        case .warning: .warning
        case .error: .error
        case .critical: .critical
        }
    }
}
