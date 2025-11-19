import Commander
import Foundation

// MARK: - Binder

enum CommanderCLIBinder {
    static func instantiateCommand(
        type: any ParsableCommand.Type,
        parsedValues: ParsedValues
    ) throws -> any ParsableCommand {
        var command = type.init()
        let runtimeOptions = try self.makeRuntimeOptions(from: parsedValues)
        if var bindable = command as? any CommanderBindableCommand {
            try bindable.applyCommanderValues(.init(parsedValues: parsedValues))
            guard let rebound = bindable as? any ParsableCommand else {
                preconditionFailure("CommanderBindableCommand cast should always round-trip to original type \(type)")
            }
            command = rebound
        }
        if var configurable = command as? any RuntimeOptionsConfigurable {
            configurable.setRuntimeOptions(runtimeOptions)
            guard let rebound = configurable as? any ParsableCommand else {
                preconditionFailure("RuntimeOptionsConfigurable cast should always round-trip to original type \(type)")
            }
            command = rebound
        }
        return command
    }

    static func instantiateCommand<T>(
        ofType type: T.Type,
        parsedValues: ParsedValues
    ) throws -> T where T: ParsableCommand {
        guard let command = try instantiateCommand(type: type, parsedValues: parsedValues) as? T else {
            preconditionFailure("Commander instantiation failed to produce expected type \(T.self)")
        }
        return command
    }

    static func makeRuntimeOptions(from parsedValues: ParsedValues) throws -> CommandRuntimeOptions {
        var options = CommandRuntimeOptions()
        options.verbose = parsedValues.flags.contains("verbose")
        options.jsonOutput = parsedValues.flags.contains("jsonOutput")
        let values = CommanderBindableValues(parsedValues: parsedValues)
        if let level: LogLevel = try values.decodeOption("logLevel", as: LogLevel.self) {
            options.logLevel = level
        }
        if let captureEngine = values.singleOption("captureEngine")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !captureEngine.isEmpty {
            options.captureEnginePreference = captureEngine
        }
        return options
    }
}

// MARK: - Bindable Protocol

struct CommanderBindableValues {
    let positional: [String]
    let options: [String: [String]]
    let flags: Set<String>

    init(positional: [String], options: [String: [String]], flags: Set<String>) {
        self.positional = positional
        self.options = options
        self.flags = flags
    }

    init(parsedValues: ParsedValues) {
        self.init(positional: parsedValues.positional, options: parsedValues.options, flags: parsedValues.flags)
    }

    func positionalValue(at index: Int) -> String? {
        guard index >= 0, index < self.positional.count else { return nil }
        return self.positional[index]
    }

    func requiredPositional(_ index: Int, label: String) throws -> String {
        guard let value = positionalValue(at: index) else {
            throw CommanderBindingError.missingArgument(label: label)
        }
        return value
    }

    func singleOption(_ label: String) -> String? {
        self.options[label]?.last
    }

    func optionValues(_ label: String) -> [String] {
        self.options[label] ?? []
    }

    func flag(_ label: String) -> Bool {
        self.flags.contains(label)
    }

    func decodePositional<T: ExpressibleFromArgument>(
        _ index: Int,
        label: String,
        as type: T.Type = T.self
    ) throws -> T {
        let raw = try requiredPositional(index, label: label)
        guard let value = T(argument: raw) else {
            throw CommanderBindingError.invalidArgument(label: label, value: raw, reason: "Unable to parse \(T.self)")
        }
        return value
    }

    func decodeOptionalPositional<T: ExpressibleFromArgument>(
        _ index: Int,
        label: String,
        as type: T.Type = T.self
    ) throws -> T? {
        guard let raw = positionalValue(at: index) else {
            return nil
        }
        guard let value = T(argument: raw) else {
            throw CommanderBindingError.invalidArgument(label: label, value: raw, reason: "Unable to parse \(T.self)")
        }
        return value
    }

    func decodeOption<T: ExpressibleFromArgument>(_ label: String, as type: T.Type = T.self) throws -> T? {
        guard let raw = singleOption(label) else {
            return nil
        }
        guard let value = T(argument: raw) else {
            throw CommanderBindingError.invalidArgument(label: label, value: raw, reason: "Unable to parse \(T.self)")
        }
        return value
    }

    func requireOption<T: ExpressibleFromArgument>(_ label: String, as type: T.Type = T.self) throws -> T {
        guard let value: T = try decodeOption(label, as: type) else {
            throw CommanderBindingError.missingArgument(label: label)
        }
        return value
    }

    func decodeOptionEnum<T: RawRepresentable>(
        _ label: String,
        as type: T.Type = T.self,
        caseInsensitive: Bool = true
    ) throws -> T? where T.RawValue == String {
        guard let raw = singleOption(label) else {
            return nil
        }
        let candidate = caseInsensitive ? raw.lowercased() : raw
        guard let value = T(rawValue: candidate) else {
            throw CommanderBindingError.invalidArgument(label: label, value: raw, reason: "Unknown value for \(T.self)")
        }
        return value
    }
}

extension CommanderBindableValues {
    func makeWindowOptions() throws -> WindowIdentificationOptions {
        var options = WindowIdentificationOptions()
        try fillWindowOptions(into: &options)
        return options
    }

    func fillWindowOptions(into options: inout WindowIdentificationOptions) throws {
        options.app = self.singleOption("app")
        if let pid: Int32 = try decodeOption("pid", as: Int32.self) {
            options.pid = pid
        }
        options.windowTitle = self.singleOption("windowTitle")
        if let index: Int = try decodeOption("windowIndex", as: Int.self) {
            options.windowIndex = index
        }
    }

    func makeFocusOptions() throws -> FocusCommandOptions {
        var options = FocusCommandOptions()
        try fillFocusOptions(into: &options)
        return options
    }

    func fillFocusOptions(into options: inout FocusCommandOptions) throws {
        options.noAutoFocus = self.flag("noAutoFocus")
        options.spaceSwitch = self.flag("spaceSwitch")
        options.bringToCurrentSpace = self.flag("bringToCurrentSpace")
        if let timeout: TimeInterval = try decodeOption("focusTimeoutSeconds", as: TimeInterval.self) {
            options.focusTimeoutSeconds = timeout
        }
        if let retries: Int = try decodeOption("focusRetryCountValue", as: Int.self) {
            options.focusRetryCountValue = retries
        }
    }
}

@MainActor
protocol CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws
}

enum CommanderBindingError: LocalizedError, Sendable, Equatable {
    case missingArgument(label: String)
    case invalidArgument(label: String, value: String, reason: String)

    var errorDescription: String? {
        switch self {
        case let .missingArgument(label):
            "Missing argument: \(label)"
        case let .invalidArgument(label, value, reason):
            "Invalid value '\(value)' for \(label): \(reason)"
        }
    }
}
