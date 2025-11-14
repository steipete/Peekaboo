//
//  CommandRuntime.swift
//  PeekabooCLI
//

import Foundation
import PeekabooCore
import PeekabooFoundation

/// Shared options that control logging and output behavior.
struct CommandRuntimeOptions: Sendable {
    var verbose = false
    var jsonOutput = false
    var logLevel: LogLevel?

    func makeConfiguration() -> CommandRuntime.Configuration {
        CommandRuntime.Configuration(
            verbose: self.verbose,
            jsonOutput: self.jsonOutput,
            logLevel: self.logLevel
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
    }

    let configuration: Configuration
    @MainActor let services: any PeekabooServiceProviding
    @MainActor let logger: Logger

    @MainActor
    init(
        configuration: Configuration,
        services: any PeekabooServiceProviding)
    {
        self.configuration = configuration
        self.services = services
        self.logger = Logger.shared

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

        let visualizerConsoleLevel: PeekabooCore.LogLevel? = if let explicitLevel {
            explicitLevel.coreLogLevel
        } else if shouldEnableVerbose {
            .debug
        } else {
            nil
        }

        VisualizationClient.shared.setConsoleLogLevelOverride(visualizerConsoleLevel)

        self.services.ensureVisualizerConnection()
    }

    @MainActor
    init(options: CommandRuntimeOptions, services: any PeekabooServiceProviding) {
        self.init(configuration: options.makeConfiguration(), services: services)
    }
}

extension CommandRuntime {
    @MainActor
    static func makeDefault(options: CommandRuntimeOptions) -> CommandRuntime {
        CommandRuntime(
            options: options,
            services: self.serviceOverride ?? PeekabooServices())
    }

    @MainActor
    static func makeDefault() -> CommandRuntime {
        self.makeDefault(options: CommandRuntimeOptions())
    }

    @MainActor
    static func withInjectedServices<T>(
        _ services: PeekabooServices,
        perform operation: () async throws -> T) async rethrows -> T
    {
        try await self.$serviceOverride.withValue(services) {
            try await operation()
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
    fileprivate var coreLogLevel: PeekabooCore.LogLevel {
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
