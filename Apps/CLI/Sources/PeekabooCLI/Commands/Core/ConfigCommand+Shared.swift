//
//  ConfigCommand+Shared.swift
//  PeekabooCLI
//

import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
protocol ConfigRuntimeCommand {
    var runtime: CommandRuntime? { get set }
    var jsonOutput: Bool { get }
    var logger: Logger { get }

    mutating func prepare(using runtime: CommandRuntime)
}

extension ConfigRuntimeCommand {
    mutating func prepare(using runtime: CommandRuntime) {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)
    }

    var output: ConfigCommandOutput {
        ConfigCommandOutput(logger: self.logger, jsonOutput: self.jsonOutput)
    }
}

@MainActor
struct ConfigCommandOutput {
    let logger: Logger
    let jsonOutput: Bool

    func success(message: String, data: [String: Any] = [:], textLines: [String]? = nil) {
        if self.jsonOutput {
            outputJSONCodable(
                SuccessOutput(success: true, data: self.messagePayload(message: message, data: data)),
                logger: self.logger
            )
            return
        }

        (textLines ?? [message]).forEach { print($0) }
    }

    func error(code: String, message: String, details: String? = nil, textLines: [String]? = nil) {
        if self.jsonOutput {
            outputJSONCodable(
                ErrorOutput(error: true, code: code, message: message, details: details),
                logger: self.logger
            )
            return
        }

        (textLines ?? ["\(message)"]).forEach { print($0) }
    }

    func info(_ lines: [String]) {
        guard !jsonOutput else { return }
        lines.forEach { print($0) }
    }

    private func messagePayload(message: String, data: [String: Any]) -> [String: Any] {
        var payload = data
        if payload["message"] == nil {
            payload["message"] = message
        }
        return payload
    }
}

struct SuccessOutput: Encodable {
    let success: Bool
    let data: [String: Any]

    enum CodingKeys: String, CodingKey {
        case success, data
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.success, forKey: .success)
        try container.encode(JSONValue(self.data), forKey: .data)
    }
}

struct ErrorOutput: Encodable {
    let error: Bool
    let code: String
    let message: String
    let details: String?
}

struct JSONValue: Encodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self.value {
        case let val as String:
            try container.encode(val)
        case let val as Int:
            try container.encode(val)
        case let val as Double:
            try container.encode(val)
        case let val as Bool:
            try container.encode(val)
        case let val as [String: Any]:
            try container.encode(Self.encodeDictionary(val))
        case let val as [Any]:
            try container.encode(Self.encodeArray(val))
        case is NSNull:
            try container.encodeNil()
        default:
            let description = String(describing: self.value)
            try container.encode(description)
        }
    }

    private static func encodeDictionary(_ dictionary: [String: Any]) -> [String: JSONValue] {
        dictionary.mapValues { JSONValue($0) }
    }

    private static func encodeArray(_ array: [Any]) -> [JSONValue] {
        array.map { JSONValue($0) }
    }
}
