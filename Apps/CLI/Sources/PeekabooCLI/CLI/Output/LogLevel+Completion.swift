import Foundation

extension LogLevel: CaseIterable {
    public static var allCases: [LogLevel] {
        [.trace, .verbose, .debug, .info, .warning, .error, .critical]
    }

    var cliValue: String {
        switch self {
        case .trace:
            "trace"
        case .verbose:
            "verbose"
        case .debug:
            "debug"
        case .info:
            "info"
        case .warning:
            "warning"
        case .error:
            "error"
        case .critical:
            "critical"
        }
    }
}
