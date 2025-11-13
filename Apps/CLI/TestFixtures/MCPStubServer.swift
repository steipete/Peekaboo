#!/usr/bin/env swift
import Darwin
import Foundation

struct JSONRPCMessage {
    let dictionary: [String: Any]

    var method: String? { dictionary["method"] as? String }
    var id: Any? { dictionary["id"] }
    var params: [String: Any]? {
        dictionary["params"] as? [String: Any]
    }
}

struct MCPStubTool {
    let name: String
    let description: String
    let inputSchema: [String: Any]

    func toJSON() -> [String: Any] {
        [
            "name": name,
            "description": description,
            "inputSchema": inputSchema,
        ]
    }
}

final class MCPStubServer {
    private let input = FileHandle.standardInput
    private let output = FileHandle.standardOutput
    private let stderr = FileHandle.standardError

    private lazy var tools: [[String: Any]] = {
        let echoSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "message": [
                    "type": "string",
                    "description": "Text to echo back",
                ],
            ],
            "required": ["message"],
        ]

        let addSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "a": ["type": "number"],
                "b": ["type": "number"],
            ],
            "required": ["a", "b"],
        ]

        let failSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "message": ["type": "string"],
            ],
        ]

        return [
            MCPStubTool(name: "echo", description: "Echo a message back to the caller", inputSchema: echoSchema).toJSON(),
            MCPStubTool(name: "add", description: "Add two numbers and return the sum", inputSchema: addSchema).toJSON(),
            MCPStubTool(name: "fail", description: "Always return an error response", inputSchema: failSchema).toJSON(),
        ]
    }()

    func run() {
        while true {
            guard let message = readMessage() else { break }
            handle(message)
        }
    }

    private func readMessage() -> JSONRPCMessage? {
        guard
            let headerData = readHeaders(),
            let headerString = String(data: headerData, encoding: .utf8),
            let length = contentLength(from: headerString),
            let body = readBody(length: length),
            let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else {
            return nil
        }

        return JSONRPCMessage(dictionary: json)
    }

    private func readHeaders() -> Data? {
        var buffer = Data()
        let crlfcrlf = "\r\n\r\n".data(using: .utf8)!
        let lflf = "\n\n".data(using: .utf8)!

        while true {
            guard let chunk = try? input.read(upToCount: 1), let chunk, !chunk.isEmpty else {
                return nil
            }
            buffer.append(chunk)

            if buffer.count >= crlfcrlf.count,
               buffer.suffix(crlfcrlf.count) == crlfcrlf
            {
                return buffer
            }

            if buffer.count >= lflf.count,
               buffer.suffix(lflf.count) == lflf
            {
                return buffer
            }
        }
    }

    private func contentLength(from headers: String) -> Int? {
        for line in headers.replacingOccurrences(of: "\r", with: "")
            .components(separatedBy: "\n") where !line.isEmpty
        {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if key == "content-length" {
                return Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        return nil
    }

    private func readBody(length: Int) -> Data? {
        var data = Data(capacity: max(length, 0))
        var remaining = length

        while remaining > 0 {
            guard let chunk = try? input.read(upToCount: remaining), let chunk, !chunk.isEmpty else {
                return nil
            }
            data.append(chunk)
            remaining -= chunk.count
        }

        return data
    }

    private func handle(_ message: JSONRPCMessage) {
        guard let method = message.method else { return }

        switch method {
        case "initialize":
            respondInitialize(id: message.id)
        case "notifications/initialized":
            return
        case "tools/list":
            respondToolsList(id: message.id)
        case "tools/call":
            respondToolsCall(message)
        case "shutdown":
            sendResult(id: message.id, result: [:])
        case "exit":
            sendResult(id: message.id, result: [:])
            exit(0)
        default:
            sendError(id: message.id, code: -32601, message: "Unknown method \(method)")
        }
    }

    private func respondInitialize(id: Any?) {
        let result: [String: Any] = [
            "protocolVersion": "2025-03-26",
            "capabilities": [:],
            "serverInfo": [
                "name": "peekaboo-mcp-stub",
                "version": "1.0.0",
            ],
        ]
        sendResult(id: id, result: result)
    }

    private func respondToolsList(id: Any?) {
        sendResult(id: id, result: ["tools": tools])
    }

    private func respondToolsCall(_ message: JSONRPCMessage) {
        guard
            let params = message.params,
            let name = params["name"] as? String
        else {
            sendError(id: message.id, code: -32602, message: "Missing tool name")
            return
        }

        let arguments = (params["arguments"] as? [String: Any]) ?? [:]

        switch name {
        case "echo":
            let text = arguments["message"] as? String ?? ""
            sendToolResponse(id: message.id, content: [.textPayload(text)], isError: false)
        case "add":
            let a = (arguments["a"] as? Double) ?? Double(arguments["a"] as? Int ?? 0)
            let b = (arguments["b"] as? Double) ?? Double(arguments["b"] as? Int ?? 0)
            let sum = a + b
            let message = "sum: \(Int(sum) == Int(sum.rounded()) ? String(Int(sum)) : String(sum))"
            sendToolResponse(id: message.id, content: [.textPayload(message)], isError: false)
        case "fail":
            let reason = arguments["message"] as? String ?? "Stub tool requested failure"
            sendToolResponse(id: message.id, content: [.textPayload(reason)], isError: true)
        default:
            sendToolResponse(
                id: message.id,
                content: [.textPayload("Unknown stub tool: \(name)")],
                isError: true)
        }
    }

    private func sendToolResponse(id: Any?, content: [[String: Any]], isError: Bool) {
        guard let id else { return }
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "result": [
                "content": content,
                "isError": isError,
            ],
        ]
        write(payload)
    }

    private func sendResult(id: Any?, result: [String: Any]) {
        guard let id else { return }
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "result": result,
        ]
        write(payload)
    }

    private func sendError(id: Any?, code: Int, message: String) {
        guard let id else { return }
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "error": [
                "code": code,
                "message": message,
            ],
        ]
        write(payload)
    }

    private func write(_ json: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(json),
              let data = try? JSONSerialization.data(withJSONObject: json)
        else {
            writeToStderr("Invalid JSON payload: \(json)")
            return
        }

        let header = "Content-Length: \(data.count)\r\n\r\n"
        if let headerData = header.data(using: .utf8) {
            output.write(headerData)
        }
        output.write(data)
        fflush(stdout)
    }

    private func writeToStderr(_ message: String) {
        if let data = (message + "\n").data(using: .utf8) {
            stderr.write(data)
        }
    }
}

private extension Dictionary where Key == String, Value == Any {
    static func textPayload(_ text: String) -> [String: Any] {
        [
            "type": "text",
            "text": text,
        ]
    }
}

var server = MCPStubServer()
server.run()
