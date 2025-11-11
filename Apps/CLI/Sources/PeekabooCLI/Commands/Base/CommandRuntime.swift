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

    func makeConfiguration() -> CommandRuntime.Configuration {
        CommandRuntime.Configuration(
            verbose: self.verbose,
            jsonOutput: self.jsonOutput
        )
    }
}

/// Runtime context passed to runtime-aware commands.
struct CommandRuntime {
    struct Configuration {
        var verbose: Bool
        var jsonOutput: Bool
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
        if configuration.jsonOutput && !configuration.verbose {
            self.logger.setVerboseMode(true)
        } else {
            self.logger.setVerboseMode(configuration.verbose)
        }
    }

    @MainActor
    init(options: CommandRuntimeOptions) {
        self.init(configuration: options.makeConfiguration())
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
