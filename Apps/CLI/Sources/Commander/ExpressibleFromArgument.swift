import Foundation

/// Protocol used by Commander property wrappers to convert string arguments into typed values.
public protocol ExpressibleFromArgument {
    init?(argument: String)
}

extension String: ExpressibleFromArgument {
    public init?(argument: String) { self = argument }
}

extension Substring: ExpressibleFromArgument {
    public init?(argument: String) { self = Substring(argument) }
}

extension Int: ExpressibleFromArgument {
    public init?(argument: String) { self.init(argument, radix: 10) }
}

extension Int32: ExpressibleFromArgument {
    public init?(argument: String) { self.init(argument, radix: 10) }
}

extension Int64: ExpressibleFromArgument {
    public init?(argument: String) { self.init(argument, radix: 10) }
}

extension Double: ExpressibleFromArgument {
    public init?(argument: String) { self.init(argument) }
}

extension Bool: ExpressibleFromArgument {
    public init?(argument: String) {
        let lowered = argument.lowercased()
        switch lowered {
        case "true", "t", "1", "yes", "y":
            self = true
        case "false", "f", "0", "no", "n":
            self = false
        default:
            return nil
        }
    }
}
