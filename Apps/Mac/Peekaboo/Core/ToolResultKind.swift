import Foundation

enum ToolResultKind: Equatable {
    case completed
    case failed
    case cancelled

    static func classify(_ result: String) -> ToolResultKind {
        guard let data = result.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .completed
        }
        if Self.jsonBool(object["cancelled"]) == true {
            return .cancelled
        }
        if Self.jsonBool(object["success"]) == false {
            return .failed
        }
        if let error = object["error"] as? String, !error.isEmpty {
            return .failed
        }
        return .completed
    }

    private static func jsonBool(_ value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            bool
        case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID():
            number.boolValue
        default:
            nil
        }
    }
}
