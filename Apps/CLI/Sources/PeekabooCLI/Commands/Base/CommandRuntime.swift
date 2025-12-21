//
//  CommandRuntime.swift
//  PeekabooCLI
//

import Foundation
import PeekabooBridge
import PeekabooCore
import PeekabooFoundation
import PeekabooProtocols

/// Shared options that control logging and output behavior.
struct CommandRuntimeOptions: Sendable {
    var verbose = false
    var jsonOutput = false
    var logLevel: LogLevel?
    var captureEnginePreference: String?
    var preferRemote = true
    var bridgeSocketPath: String?

    func makeConfiguration() -> CommandRuntime.Configuration {
        CommandRuntime.Configuration(
            verbose: self.verbose,
            jsonOutput: self.jsonOutput,
            logLevel: self.logLevel,
            captureEnginePreference: self.captureEnginePreference
        )
    }
}

/// Runtime context passed to runtime-aware commands.
struct CommandRuntime {
    @TaskLocal
    private static var serviceOverride: PeekabooServices?

    struct Configuration {
        var verbose: Bool
        var jsonOutput: Bool
        var logLevel: LogLevel?
        var captureEnginePreference: String?
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
        let services = self.serviceOverride ?? PeekabooServices()
        return CommandRuntime(configuration: options.makeConfiguration(), services: services)
    }

    @MainActor
    static func makeDefault() -> CommandRuntime {
        self.makeDefault(options: CommandRuntimeOptions())
    }

    @MainActor
    static func makeDefaultAsync(options: CommandRuntimeOptions) async -> CommandRuntime {
        if let override = self.serviceOverride {
            return CommandRuntime(options: options, services: override)
        }

        let resolution = await self.resolveServices(options: options)
        return CommandRuntime(
            configuration: options.makeConfiguration(),
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
        let envNoRemote = ProcessInfo.processInfo.environment["PEEKABOO_NO_REMOTE"]
        guard options.preferRemote, envNoRemote == nil else {
            return (services: PeekabooServices(), hostDescription: "local (in-process)")
        }

        let explicitSocket = options.bridgeSocketPath
            ?? ProcessInfo.processInfo.environment["PEEKABOO_BRIDGE_SOCKET"]

        let candidates: [String] = if let explicitSocket, !explicitSocket.isEmpty {
            [explicitSocket]
        } else {
            [
                PeekabooBridgeConstants.peekabooSocketPath,
                PeekabooBridgeConstants.claudeSocketPath,
                PeekabooBridgeConstants.clawdisSocketPath,
            ]
        }

        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            teamIdentifier: nil,
            processIdentifier: getpid(),
            hostname: Host.current().name
        )

        for socketPath in candidates {
            let client = PeekabooBridgeClient(socketPath: socketPath)
            do {
                let handshake = try await client.handshake(client: identity, requestedHost: nil)
                if handshake.supportedOperations.contains(.captureScreen) {
                    let hostDescription = "remote \(handshake.hostKind.rawValue) via \(socketPath)" +
                        (handshake.build.map { " (build \($0))" } ?? "")
                    return (
                        services: RemotePeekabooServices(client: client),
                        hostDescription: hostDescription
                    )
                }
            } catch {
                continue
            }
        }

        return (services: PeekabooServices(), hostDescription: "local (in-process)")
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
struct RuntimeStorage<Value> where Value: ExpressibleByNilLiteral {
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
