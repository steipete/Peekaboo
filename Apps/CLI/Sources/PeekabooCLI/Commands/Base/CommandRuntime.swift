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
    var logLevel: LogLevel? = nil

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
    struct Configuration {
        var verbose: Bool
        var jsonOutput: Bool
        var logLevel: LogLevel?
    }

    let configuration: Configuration
    @MainActor let services: PeekabooServices
    @MainActor let logger: Logger

    @MainActor
    init(configuration: Configuration) {
        self.configuration = configuration
        self.services = PeekabooServices.shared
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

        let visualizerConsoleLevel: PeekabooCore.LogLevel?
        if let explicitLevel {
            visualizerConsoleLevel = explicitLevel.coreLogLevel
        } else if shouldEnableVerbose {
            visualizerConsoleLevel = .debug
        } else {
            visualizerConsoleLevel = nil
        }

        VisualizationClient.shared.setConsoleLogLevelOverride(visualizerConsoleLevel)
    }

    @MainActor
    init(options: CommandRuntimeOptions) {
        self.init(configuration: options.makeConfiguration())
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

private extension LogLevel {
    var coreLogLevel: PeekabooCore.LogLevel {
        switch self {
        case .trace: return .trace
        case .verbose: return .debug
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        }
    }
}
