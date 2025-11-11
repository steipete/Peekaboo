import Foundation

/// Commander-only binder helpers used by all clients.
public enum CommanderBinder {
    public static func runtimeFlags(from parsedValues: ParsedValues) -> RuntimeFlags {
        RuntimeFlags(
            verbose: parsedValues.flags.contains("verbose"),
            jsonOutput: parsedValues.flags.contains("jsonOutput")
        )
    }
}

public struct RuntimeFlags: Sendable, Equatable {
    public var verbose: Bool
    public var jsonOutput: Bool
}
